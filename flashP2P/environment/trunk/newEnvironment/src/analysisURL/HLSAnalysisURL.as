package analysisURL
{
	
	import analysisURL.AnalysisEvent;
	
	import cmodule.keygen.CLibInit;
	
	import com.p2p.utils.Base64;
	import com.p2p.utils.json.JSONDOC;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import lee.projects.player.GlobalReference;
	
	
	public class HLSAnalysisURL extends EventDispatcher
	{		
		protected var _startloadG3:Number;
		protected var _letvLiveInfo:Object;	
		protected var _letvLiveInfoLoader:URLLoader;		
		protected var _G3URLString:String;    //保存G3地址的数组，便于在访问失败时选择其他地址
		
		//protected var _myTimer:Timer;//超时计时器,10秒钟超时
		public function HLSAnalysisURL()
		{			
		}
		private var vid:String="";
		public function start(obj:Object/*str:String*/):void
		{	
//			_G3URLString=obj.dispatch;
			if(obj.hasOwnProperty("vid"))
			{
				vid=obj.vid;
			}
			clear();	
//			gslb=str;
			//_G3URLString = "http://g3.letv.cn/24/47/53/letv-uts/1725544-AVC-537997-AAC-31586-2699960-198739996-9efc8d87b10aeade1253c38ede74fc47-1359401984422.flv?b=588&mmsid=2216654&tm=1369234305&platid=1&splatid=101&playid=0&key=cbc5f5251eb19b4dcb3c1deff1ea5877&tss=no&format=1&termid=1&hwtype=un&pay=0&tag=letv&sign=letv&expect=3&rateid=1000";
			//_G3URLString = "http://g3.letv.cn/vod/v2/MzQvNDAvMTYvbGV0di11dHMvdmVyXzAwXzEwLTc3NTcyNTUtQVZDLTUzMzA5Mi1BQUMtMzIwMDAtNjE0MjUyMC00NDA2Njk4MTUtZGMxNGI2ZDhjOGRhNzIxNWYyMmZkYzEzMTM4YzUxYjMtMTM4MzE1NzQ1MTM2OC5tcDQ=?b=575&tss=ios&pay=1&termid=1&sign=letv&key=84b34fe9c3583fa8c0b05f43620469b8&platid=1&mmsid=3067890&splatid=101&tag=letv&tm=1384759157&playid=0&hwtype=un&ostype=Mac%20OS%2010.9.0&expect=3&format=1&rateid=1000";

			_G3URLString = "http://g3.letv.cn/vod/v2/NTAvNTMvMTcvbGV0di11dHMvdmVyXzAwXzEyLTg1MjQ2MDUtQVZDLTU0ODcyMS1BQUMtMzIwMDAtMjcyOTkyMC0yMDExOTAwOTctYTUzZWM2NDgzOTZhM2NjNjMwYWYwZWM5YjBmOWYyMTEtMTM4NDc3Mjk2OTYwOS5tcDQ=?b=588&tss=ios&pay=0&hwtype=un&m3v=1&sign=letv&platid=1&splatid=101&expect=3&ostype=Windows%207&ctv=pc&mmsid=3067852&termid=1&playid=0&tag=letv&tn=0.6537229991517961&key=f33d4cd0b9a3de703fbb1ab9fe1861e1&tm=1385349662&format=1&rateid=1000"
			
//			_G3URLString = str;
//			_G3URLString = "http://live.gslb.letv.com/gslb?stream_id=cctv1&tag=live&ext=xml&format=1&expect=2";
			trace(this+"_G3URLString:"+_G3URLString);
			_letvLiveInfo = new Object();
			//_letvLiveInfo.group = getCheckURL(str);
			//-------------------------------------
			startLetvLiveInfoLoader();			
		}
		public function clear():void
		{
			clearLetvVODInfoLoader();
			_startloadG3 = 0;
			_letvLiveInfo = null;
			_G3URLString  = "" ;
			_letvLiveInfoLoader = null;			
		}
		
		private var gslb:String="";
		protected function startLetvLiveInfoLoader():void
		{
			_startloadG3 = getTime();      //取开始加载的时间；
			clearLetvVODInfoLoader();
			_letvLiveInfoLoader=new URLLoader();
			_letvLiveInfoLoader.addEventListener(Event.COMPLETE,letvVODInfoLoader_COMPLETE);
			_letvLiveInfoLoader.addEventListener(IOErrorEvent.IO_ERROR,letvVODInfoLoader_ERROR);
			_letvLiveInfoLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,letvVODInfoLoader_ERROR);			
			var tm:int=Math.floor( getTime()/1000);
			tm=tm+24*60*60*5;
			var loader:CLibInit = new CLibInit;
			var lib:Object = loader.init();
			trace(lib.calcLiveKey("cctv5_800","1371053018"));
			var _key:String=lib.calcLiveKey(getStreamID(_G3URLString),String(tm));
//			var _key:String=calcLiveKey(getStreamID(_G3URLString),String(tm));
			_G3URLString+="&tm="+tm;
			_G3URLString+="&key="+_key;
			trace(this,"_gslb:"+_G3URLString);
//			gslb=_G3URLString;
			_letvLiveInfoLoader.load(new URLRequest(_G3URLString));
		}
		protected function clearLetvVODInfoLoader():void
		{			
			
			if (_letvLiveInfoLoader)
			{
				try
				{				
					_letvLiveInfoLoader.close();
					
				}catch(err:Error)
				{
				}
				
				_letvLiveInfoLoader.removeEventListener(Event.COMPLETE,letvVODInfoLoader_COMPLETE);
				_letvLiveInfoLoader.removeEventListener(IOErrorEvent.IO_ERROR,letvVODInfoLoader_ERROR);
				_letvLiveInfoLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,letvVODInfoLoader_ERROR);
				_letvLiveInfoLoader = null;
				
			}			
			
		}
		
		protected function letvVODInfoLoader_COMPLETE(evt:Event):void
		{					
			try
			{	
				var obj:Object = JSONDOC.decode(String(_letvLiveInfoLoader.data));				
				
			}catch(e:Error)
			{
				letvVODInfoLoader_ERROR("dataError");				
				return;
			}					
			
			var flvURLArray:Array  = new Array();                // 由于通过g3地址需要返回多个flv地址保证容错播放，所以将地址保存到_flvURL数组中
			var flvNodeArray:Array = new Array();               // 存放cdn node id
			
			for(var i:int = 0 ; i<obj.nodelist.length ; i++)
			{				
				flvURLArray.push(obj.nodelist[i].location);				
				flvNodeArray.push(obj.nodelist[i].gone);				
			}		
			
			var object:Object = new Object();                   //用于保存发送统计用的内容：
			object.error = 0;                                    //0表示成功获取
			object.url   = _G3URLString;                         //成功访问的G3url
			object.utime = getTime()-_startloadG3 ;              //访问耗时
			object.retry = 1;                                    //尝试次数			
			object.res   = "-";                                  //目前先使用“-”表示	
			
			object.flvURL  = flvURLArray.concat();
			/*本地测试*/
//			object.flvURL  = ["http://127.0.0.1/hls/group/a.m3u8"];
			//object.flvURL  = ["http://123.126.32.19:1935/hls/p2p-test/test.m3u8"/*,"http://127.0.0.1/hls/p2p-test/test.m3u8"*/];
			//object.flvURL  = ["http://123.125.89.36/36/6/28/letv-uts/ver_00_01-6174398-AVC-260548-AAC-32000-196280-7413414-12c72961b9dca83be3063f9cc859fc1c-1375958066218.m3u8?crypt=96aa7f2e279&b=1100&nlh=3072&bf=20&gn=706&p2p=1&video_type=mp4&opck=1&check=0&tm=1377496800&key=4fc28ffa53e97bc5724e4cffe4d66381&proxy=2071812438&cips=10.58.100.51&geo=CN-1-0-2&lgn=letv&mmsid=2989264&platid=1&splatid=101&playid=0&tss=ios&termid=1&hwtype=un&ostype=Windows 7&pay=0&tag=letv&sign=letv&rateid=350"]
			//var str:String="http://60.217.237.161/37/43/16/letv-uts/ver_00_04-6633300-AVC-258865-AAC-32000-1968360-73842546-a6a5bd8f817d141985f136bd6e0f7b30-1377774372311.m3u8?crypt=94aa7f2e383&b=1100&nlh=3072&bf=28&gn=750&p2p=1&video_type=mp4&opck=1&check=0&tm=1378535400&key=5e0974135372c1fc26a6aedc16c18f51&proxy=2007470886&cips=10.58.100.51&geo=CN-1-0-2&lgn=letv&mmsid=3067893&platid=1&splatid=101&playid=0&tss=ios&termid=1&hwtype=un&ostype=Windows%207&pay=0&tag=letv&sign=letv&rateid=350";
			//var str:String="http://123.125.89.40/33/33/48/letv-uts/ver_00_05-6688686-AVC-547030-AAC-32000-5723200-420961368-10cb9936fc98ae0ddf244b0b97251977-1378156855981.m3u8?crypt=44aa7f2e127&b=585&nlh=3072&bf=17&gn=706&p2p=1&video_type=mp4&opck=1&check=0&tm=1378625400&key=eb535237758aaa44ec17686914fdf9f0&proxy=2071812435&cips=10.58.100.51&geo=CN-1-0-2&lgn=letv&termid=1&pay=0&sign=letv&ostype=Windows%207&mmsid=3067909&hwtype=un&playid=0&platid=1&tss=ios&splatid=101&tag=letv&rateid=1000";
			//var str:String="http://123.126.32.19:1935/hls/ver_00_10_yyyl_test_20s_1024/a.m3u8";
			//var str:String="http://123.126.32.19:1935/hls/ver_00_10_yyyl_test_20s_1024/a.m3u8";
			//var str:String="http://119.167.147.42/32/5/17/letv-uts/ver_00_10-7752747-AVC-551948-AAC-32000-192000-14226846-5c905aaed949e3b2fea49e567c283bbc-1383099988100.m3u8";
			//var str:String="http://119.188.122.33/40/53/17/letv-uts/ver_00_10-7756063-AVC-548717-AAC-32000-2729920-201188787-b4a272858783184117ada1386c29b0bb-1383112566153.m3u8?crypt=70aa7f2e203&b=588&nlh=3072&nlt=5&bf=28&gn=751&p2p=1&video_type=mp4&opck=1&check=0&tm=1383552600&key=9a98ec10bd80edcde1ca797f0b99fe62&proxy=2007487123,2071812442&cips=10.58.106.59&geo=CN-1-0-2&lgn=letv&mmsid=3067852&platid=1&splatid=101&playid=0&tss=ios&termid=1&hwtype=un&ostype=Windows%207&pay=0&tag=letv&sign=letv&tn=0.5594264077953994&rateid=1000";
			//str = "http://123.125.89.40/34/40/16/letv-uts/ver_00_10-7757255-AVC-533092-AAC-32000-6142520-440669815-dc14b6d8c8da7215f22fdc13138c51b3-1383157451368.m3u8?crypt=39aa7f2e127&b=575&nlh=3072&nlt=15&bf=18&gn=706&p2p=1&video_type=mp4&opck=1&check=0&tm=1384587000&key=103b229c3902f05f8c50f3f9d6331212&proxy=2071812436,2007487117&cips=10.58.100.173&geo=CN-1-0-2&lgn=letv&platid=1&sign=letv&splatid=101&mmsid=3067890&playid=0&tag=letv&tss=ios&ostype=Windows%207&hwtype=un&pay=0&termid=1&rateid=1000";
//			if(vid=="")
//			{
//				str=encodeURI(str);
//				object.flvURL  = [str];
//			}else
//			{
//				str=encodeURI(vid);
//				object.flvURL = [str];
//			}
			
			var str:String = "";
			if(vid=="")
			{
				str=encodeURI(object.flvURL[0]);
				object.flvURL  = [str];
			}else
			{
				str=encodeURI(vid);
				object.flvURL = [str];
			}
			//object.flvURL  = ["http://119.167.223.131/1/1/1/ver_00_02_test.m3u8"]
			//object.flvURL  = ["http://123.125.89.36/31/31/48/letv-uts/ver_00_05-6688545-AVC-548796-AAC-32000-2705760-199563523-c184d4134f5dec4b733ad38b8ed256ac-1378143473865.m3u8"]	
			////http://123.126.32.19:1935/hls/p2p-test/test.m3u8
			object.flvNode = flvNodeArray.concat();
			object.serverCurtime = 40;//Number(obj.curtime);           //秒
			object.serverStartTime  = 0; //Number(obj.starttime);      //秒
			object.serverOffsetTime = 0;//Math.round((object.serverCurtime*1000-(new Date()).time)/1000);//秒
			object.startTime =0;
			//object.groupName = _letvLiveInfo.group;
			trace(this+"groupName    = "+getStreamID(_G3URLString));
			
			//object.groupName = getCheckURL(getStreamID(_G3URLString));//getCheckURL(_G3URLString+""+getComputerRoom(object.flvURL[0]));
			//trace(this,getParam(getUrlParams("url"),"debug=true"))
//			if(getParam(getUrlParams("url"),"debug")=="true")
//			{
//				
//			}else if(getParam(getUrlParams("url"),"groupName")!="")
//			{
//				object.groupName = getParam(getUrlParams("url"),"groupName");
//			}else
//			{
//				object.groupName = getStreamID(_G3URLString);
//			}
			object.groupName = object.flvURL[0];
			trace(this+"groupName="+obj.groupName);
			object.geo   = obj.geo;                              //运营商信息
			trace(this+"geo    = "+obj.geo);			
            trace(this+object.serverCurtime+"  "+object.serverStartTime+"  "+object.serverOffsetTime);
			trace("object.flvURL = "+object.flvURL)
			//object.gslbURL = gslb;
			object.gslbURL = _G3URLString
			object.livePer      = 0.2;
			//object.timeShiftArr = [30,60,80];
			dispatchG3SuccessEvent(object);
			
		}
		private function getParam(url:String,key:String):String
		{
			var reg:RegExp=new RegExp("\[?&]"+key+"=(\\w{0,})?", "");
			//			var reg:RegExp=new RegExp(key+"=(\\w{0,})?", "");
			var findStr:String="";
			if(reg.test(url))
			{
				findStr=url.match(reg)[0];
			}
			if(findStr.length>0)
			{
				findStr=findStr.replace(key+"=","").substr(1);
			}
			return findStr;
		}
		private static function getUrlParams(param:String):String
		{
			var returnValue:String;
			switch (param)
			{
				case "PathAndName" :
					returnValue = ExternalInterface.call("function getUrlParams(){return window.location.pathname;}");
					break;
				case "query" :
					returnValue = ExternalInterface.call("function getUrlParams(){return window.location.search;}");
					break;
				case "url" :
					returnValue = ExternalInterface.call("function getUrlParams(){return window.location.href;}");
					break;
				default :
					returnValue = ExternalInterface.call("function getUrlParams(){return window.location." + param + ";}");
					break;
			}
			
			return (returnValue ? UrlDecode(returnValue):"");
		}
		public static function UrlEncode(str:String,encoding:String = ""):String
		{
			if (str == null || str == "")
			{
				return "";
			}
			if (encoding == null || encoding == "")
			{
				return encodeURI(str);
			}
			var returnValue:String = "";
			var byte:ByteArray =new ByteArray();
			byte.writeMultiByte(str,encoding);
			for (var i:int; i<byte.length; i++)
			{
				returnValue +=  escape(String.fromCharCode(byte[i]));
			}
			return returnValue;
		}
		
		/**
		 * URL解码，encoding为空时应用统一的UTF-8编码处理，可设"GB2312"、"UTF-8"等，（兼容性处理，对应JS中的unescape）
		 */
		public static function UrlDecode(str:String,encoding:String = ""):String
		{
			if (str == null || str == "")
			{
				return "";
			}
			if (encoding == null || encoding == "")
			{
				return decodeURI(str);
			}
			var returnValue:String = "";
			var byte:ByteArray =new ByteArray();
			byte.writeMultiByte(str,encoding);
			for (var i:int; i<byte.length; i++)
			{
				returnValue +=  unescape(String.fromCharCode(byte[i]));
			}
			return returnValue;
		}
		private function getStreamID(url:String):String
		{
			var reg:RegExp=/stream_id=(\w{0,})/;
			if(reg.test(url))
			{
				return url.match(reg)[1];
			}
			return "";
		}
		protected function getComputerRoom(url:String):String
		{			
			var start:int = 0;
			for(var i:int=0 ; i<4 ; i++)
			{
				start = url.indexOf("/",start)+1;
			}
			var end:int    = url.indexOf("/",start);
			var str:String = url.substring(start,end);
			return str;
		}
		protected function letvVODInfoLoader_ERROR(evt:*=null):void
		{			
			var obj:Object = new Object();
			
			obj.allG3Failed = 0;                                   //0：还有没尝试过的g3地址    1：所有g3地址都已尝试过了			
			obj.url = _G3URLString;     //此时连接的G3 url
			
			_letvLiveInfo.retry++;
							
			obj.utime  = getTime()-_startloadG3 ;    //连接耗时
			obj.res    = "-";                        //目前暂时使用“-”			
			obj.retry  = _letvLiveInfo.retry;         //尝试连接的次数
			
			if(evt is IOErrorEvent)
			{		
				obj.error = 400;                    //网络连接错误				
					
			}else if(evt is TimerEvent)
			{				
				obj.error = 401;                    //超时错误				
				
			}else if(evt is SecurityErrorEvent)
			{				
				obj.error = 402;                    //跨域错误				
				
			}else if(evt is String)
			{				
				obj.error = 403;                    //数据错误				
				
			}else
			{				
				obj.error = 999;                    //其他错误				
			}
			//			
			//startLetvLiveInfoLoader(_G3URLString);	             //重新加载
			//
			dispatchG3FailedEvent(obj);
			
		}
		protected function dispatchG3FailedEvent(obj:Object):void
		{
			obj.code = "URLAnalysisFailed";
			
			dispatchEvent(new AnalysisEvent(AnalysisEvent.ERROR,obj));
			
		}
		protected function dispatchG3SuccessEvent(obj:Object):void
		{
			obj.code = "URLAnalysisSuccess";		
			
			dispatchEvent(new AnalysisEvent(AnalysisEvent.STATUS,obj));
		}
		/** 
		 * 将原有g3地址转为可返回3个flv地址的g3 
		 */
		private function changeG3URL(str:String):String
		{			
			var str1:String = "";
			var arr:Array   = new Array();
			
			arr = str.split("expect=");
			
			var i:int = arr[1].indexOf("&"); //判断数组大小！
			if(i != -1)
			{
				str1 = String(arr[1]).substring(i);
				
			}
			var str2:String = arr[0] + "expect=3"+str1;
			
			return str2;
		}
		//---------------返回checkXML地址和经过SHA1加密的groupID----------------------------
		private function getCheckURL(str:String):String
		{							
			var enc:sha1Encrypt = new sha1Encrypt(true);
			var strSHA1:String = sha1Encrypt.encrypt(str);
					
			return strSHA1;
		}		
		//-------------------------------------------------------------------------		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}