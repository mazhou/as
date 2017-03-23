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
	
	
	public class LetvLiveAnalysisURL extends EventDispatcher
	{		
		protected var _startloadG3:Number;
		protected var _letvLiveInfo:Object;	
		protected var _letvLiveInfoLoader:URLLoader;		
		protected var _G3URLString:String;    //保存G3地址的数组，便于在访问失败时选择其他地址
		
		//protected var _myTimer:Timer;//超时计时器,10秒钟超时
		public function LetvLiveAnalysisURL()
		{			
		}
		public function start(str:String):void
		{			
			clear();	
			_G3URLString = str;
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
			gslb=_G3URLString;
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
			object.url   = _G3URLString;                         //成功访问的G3url
			
			//["http://119.188.122.68/leflv/channel_1_pc/desc.xml?tag=live&video_type=xml&stream_id=channel_1_pc&useloc=0&mslice=3&path=119.188.122.44,60.217.237.194,60.217.237.229&geo=CN-1-0-2&cips=10.58.100.156&tmn=1378373606&pnl=751,750,225&sign=live_web&scheme=rtmp&termid=1&pay=0&ostype=Windows 7&hwtype=un&tm=1378459369&key=5738d9b4b596c3f5caa2e3eaa92d027b"] //
			object.flvURL  =flvURLArray.concat();
			//["751","750"] //
			object.flvNode =flvNodeArray.concat();
			//1378373546;//
			object.serverCurtime = Number(obj.curtime);           //秒
			//24//
			object.serverStartTime  = Number(obj.starttime);      //秒
			//1;//
			object.serverOffsetTime = Math.round((object.serverCurtime*1000-(new Date()).time)/1000);//秒
			//"http://live.gslb.letv.com/gslb?stream_id=channel_1_pc&tag=live&ext=xml&sign=live_web&format=2&expect=2&scheme=rtmp&termid=1&pay=0&ostype=Windows%207&hwtype=un&tm=1378459369&key=5738d9b4b596c3f5caa2e3eaa92d027b"//
			object.gslb = gslb;
			object.livePer      = 0.2;
			object.livesftime = 60;
			
			//object.groupName = _letvLiveInfo.group;
			trace(this+"groupName    = "+getStreamID(_G3URLString));
			
			//object.groupName = getCheckURL(getStreamID(_G3URLString));//getCheckURL(_G3URLString+""+getComputerRoom(object.flvURL[0]));
			//trace(this,getParam(getUrlParams("url"),"debug=true"))
			if(getParam(getUrlParams("url"),"debug")=="true")
			{
				//object.groupName = getStreamID("123");
				object.groupName = getStreamID(_G3URLString);
			}else if(getParam(getUrlParams("url"),"groupName")!="")
			{
				object.groupName = getParam(getUrlParams("url"),"groupName");
			}else
			{
				object.groupName = getStreamID(_G3URLString);
			}
			//obj.groupName="channel_1_pc_1111";
			trace(this+"groupName="+obj.groupName);		
			object.geo   = obj.geo;                              //运营商信息
			trace(this+"geo    = "+obj.geo);			
            trace(this+object.serverCurtime+"  "+object.serverStartTime+"  "+object.serverOffsetTime);
			trace("object.flvURL = "+object.flvURL)
			
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