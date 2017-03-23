package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDispatcher;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	
	/**
	 * <ul>构造函数：NETSTREAM_PROTOCOL.PLAY，获得initdata参数</ul>
	 * <ul>处理数据</ul>
	 * <ul>异常处理</ul>
	 * <ul>纠错处理：请求加载和加载过程addErrorByte</ul> 
	 * @author mazhoun
	 */
	public class DescLoader implements IDescLoader
	{
		public var isDebug:Boolean=true;
		private var _dispather:IDispatcher = null;	
		private var loader:URLLoader;
		private var _initData:InitData=null;
		private var _flvURLIndex:int=0;
		
		private var timeOutTimer:Timer;
		public var groupID:String="";
		public var width:Number=0;
		public var height:Number=0;
		public var totalDuration:Number=0;
		
		public function DescLoader(_dispather:IDispatcher)
		{
			this._dispather=_dispather;
			//
			timeOutTimer = new Timer(3*1000,1);
			timeOutTimer.addEventListener(TimerEvent.TIMER,timeOutHandler);
			//
			addListener();
		}
		public function start( _initData:InitData):void
		{
			if(!this._initData)
			{
				this._initData = _initData;
				handlerDownloadTask();
				timeOutTimer.reset();
			}
		}
		//
		private var _startTime:Number = 0;
		public function callbak( p_ClipVector:Vector.<Clip>):void
		{
			Statistic.getInstance().loadXMLSuccess();
			_dispather.writeClipList(p_ClipVector);
		}
		private function completeHandler_2(event:Event):int 
		{
			timeOutTimer.reset();		
			(new ParseM3U8_uniform).parseFile(String(event.target.data),_initData,callbak,this);
			return 0;
		}
		
		private function urlParse(_url:String,isHalOfBegin:Boolean=true,endLetter:String=""):String
		{
			var offset:int;
			offset = _url.lastIndexOf("/");
			if(isHalOfBegin){
				_url=_url.substr(0, offset+1);
			}else
			{
				_url=_url.substr( offset+1);
			}
			offset=_url.indexOf(endLetter);
			_url=_url.substr(0, offset);
			return _url;
		}
		private function urlParse1(_url:String):String
		{
			var end:int = _url.indexOf(".ts");
			var start:int = _url.lastIndexOf("/");
			_url = _url.substring(start,end);
			return _url;
		}
		
		private function urlParseClipinfo(oClip:Clip,strinfo:String):String
		{
			var end:int = strinfo.indexOf(".ts");
			var start:int = 0;
			strinfo = strinfo.substring(start,end);
			var arrInfo:Array = strinfo.split("_");
			oClip.offsize = Number(arrInfo[arrInfo.length-1]);
			oClip.size = Number(arrInfo[arrInfo.length-2]);
			oClip.KeyFrameCount = Number(arrInfo[arrInfo.length-3]);
			oClip.beginKeyFrameSeq = Number(arrInfo[arrInfo.length-4]);
			oClip.sequence = Number(arrInfo[arrInfo.length-5]);
			oClip.strBlockVer = String(arrInfo[arrInfo.length-8]) + "_" + String(arrInfo[arrInfo.length-7]) + "_" +String(arrInfo[arrInfo.length-6]); 
			
			return strinfo;
		}
		
		private function receiveDataHandler(event:ProgressEvent=null):void
		{
			timeOutTimer.reset();
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler: " + event);
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			downloadError();
		}
		
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"DESCtimeOutHandler: " + event);
			downloadError();
		}
		
		private function downloadError():void
		{
			timeOutTimer.reset();
			_flvURLIndex++;
			if(_flvURLIndex>=_initData.flvURL.length)
			{
				_flvURLIndex=0;
			}
			removeListener();
			addListener();
			handlerDownloadTask();
		}
		//
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			_startTime = getTime();
			if (_dispather)
			{
				//
				var url:String = _initData.flvURL[_flvURLIndex];
				//DOTEST
				//url="http://localhost/m3u820/a20_test_1.m3u8"
				var request:URLRequest = new URLRequest(url);
				P2PDebug.traceMsg(this,"url:"+url);
				timeOutTimer.reset();
				timeOutTimer.start();
				
				try
				{
					loader.load(request);
					
				} catch (error:Error)
				{
					trace(this,"Unable to load requested document.");
				}
			}
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		private function addListener():void
		{
			if(loader==null)
			{
				loader = new URLLoader();
				loader.dataFormat = URLLoaderDataFormat.TEXT;
				
				loader.addEventListener(Event.COMPLETE, completeHandler_2);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				loader.addEventListener(ProgressEvent.PROGRESS,receiveDataHandler);			
			}
		}
		private function removeListener():void
		{
			if(loader!=null)
			{
				try{
					loader.close();
				}catch(err:Error)
				{
				}
				loader.removeEventListener(Event.COMPLETE, completeHandler_2);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				loader.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				loader=null;
			}
		}
		public function clear():void
		{
			_flvURLIndex=0;
			timeOutTimer.stop();
			timeOutTimer.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			removeListener();
			_dispather=null;
			_initData=null;
			timeOutTimer = null;
		}
	}
}