package analysisURL
{
	
	import analysisURL.AnalysisEvent;
	
	import com.p2p.utils.Base64;
	import com.p2p.utils.json.JSONDOC;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Timer;
	
	
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
			trace(_G3URLString);
			_letvLiveInfo = new Object();
			//_letvLiveInfo.group = getCheckURL(str);
			//-------------------------------------
			startLetvLiveInfoLoader(str);			
		}
		public function clear():void
		{
			clearLetvVODInfoLoader();
			_startloadG3 = 0;
			_letvLiveInfo = null;
			_G3URLString  = "" ;
			_letvLiveInfoLoader = null;			
		}
		
		
		protected function startLetvLiveInfoLoader(str:String):void
		{
			_startloadG3 = getTime();      //取开始加载的时间；	
			
			clearLetvVODInfoLoader();
			
			_letvLiveInfoLoader=new URLLoader();
			_letvLiveInfoLoader.addEventListener(Event.COMPLETE,letvVODInfoLoader_COMPLETE);
			_letvLiveInfoLoader.addEventListener(IOErrorEvent.IO_ERROR,letvVODInfoLoader_ERROR);
			_letvLiveInfoLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,letvVODInfoLoader_ERROR);			
				
			_letvLiveInfoLoader.load(new URLRequest(str));
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
			object.flvNode = flvNodeArray.concat();
			object.serverCurtime = Number(obj.curtime);           //秒
			object.serverStartTime  = Number(obj.starttime);      //秒
			object.serverOffsetTime = Math.round((object.serverCurtime*1000-(new Date()).time)/1000);//秒
			
			//object.groupName = _letvLiveInfo.group;
			object.groupName = getCheckURL(_G3URLString+""+getComputerRoom(object.flvURL[0]));
			
			object.geo   = obj.geo;                              //运营商信息
			trace("geo    = "+obj.geo);			
            trace(object.serverCurtime+"  "+object.serverStartTime+"  "+object.serverOffsetTime);
			object.livePer      = 0.2;
			//object.timeShiftArr = [30,60,80];
			dispatchG3SuccessEvent(object);
			
		}		
		protected function getComputerRoom(url:String):String
		{			
			//http://123.125.89.39/leflv/jiangsu_bjlt1/desc.xml?tag=live&video_type=xml&useloc=1&clipsize=128&clipcount=10&f_ulrg=0&cmin=3&cmax=10&path=123.125.89.13&cipi=168448162&isp=2&pnl=706,215&stream_id=jiangsu
			//取jiangsu_bjlt1			
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