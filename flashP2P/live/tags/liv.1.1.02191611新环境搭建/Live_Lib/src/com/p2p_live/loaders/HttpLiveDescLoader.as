// ActionScript file
package com.p2p_live.loaders
{
	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p_live.events.HttpLiveEvent;
	
	import flash.errors.EOFError;
	import flash.errors.IOError;
	import flash.events.*;
	import flash.net.ObjectEncoding;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class HttpLiveDescLoader extends EventDispatcher
	{
		protected const DESC_FETCH_INTERVAL:uint = 3000; 
		protected const DESC_FETCH_TIMEOUT:uint = 6000;  
		protected var _descUrl:String;
		protected var _httpClient:URLStream;
		protected var _engineTimer:Timer;
		protected var _timeoutTimer:Timer;
		protected var _isDownloading:Boolean;
		protected var _fetchStartTime:Number;
		protected var _lastDescData:ByteArray; //
		
		protected var _failedTime:Number;
		
		public function HttpLiveDescLoader()
		{
			init();
		}
		
		private function init():void
		{
			_httpClient = new URLStream();
			_httpClient.addEventListener(Event.COMPLETE, completeHandler);			
			_httpClient.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
			_httpClient.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			
			_engineTimer = new Timer(DESC_FETCH_INTERVAL);
			_timeoutTimer = new Timer(DESC_FETCH_TIMEOUT);
			_engineTimer.addEventListener(TimerEvent.TIMER,engineTimer_TIMER);
			_timeoutTimer.addEventListener(TimerEvent.TIMER,timeroutTimer_Timer);
			_failedTime = 0;
			_isDownloading = false;			
		}
		
		public function start(url:String):void
		{	
			_descUrl = url;
			_engineTimer.delay = 0;
			_engineTimer.start();
		}
		public function close():void
		{
			if(_httpClient && _httpClient.connected)
			{				
				try
				{
					_httpClient.close();
				}
				catch(e:Error)
				{
					trace("httpDescLoad close error");
				}
			}
			if(_engineTimer)
			{
				_engineTimer.stop();
			}
			if(_timeoutTimer)
			{
				_timeoutTimer.stop();
			}
			_fetchStartTime = 0;
			_failedTime = 0;
			_isDownloading = false;
		}
		public function clear():void
		{
			close();
			
			if(_httpClient)
			{			
				_httpClient.removeEventListener(Event.COMPLETE, completeHandler);			
				_httpClient.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
				_httpClient.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				_httpClient = null;
			}
			
			if(_engineTimer)
			{
				_engineTimer.removeEventListener(TimerEvent.TIMER,engineTimer_TIMER);
				_engineTimer = null;
			}
			if(_timeoutTimer)
			{
				_timeoutTimer.removeEventListener(TimerEvent.TIMER,timeroutTimer_Timer);
				_timeoutTimer = null;
			}
		}
		
		private function engineTimer_TIMER(event:TimerEvent):void
		{			
			if( !_isDownloading && (_failedTime == 0 || getTime() - _failedTime >= 10*1000))			    
			{
				_failedTime = 0;
				_fetchStartTime = getTime();
				var url:String=_descUrl + "&ran=" + _fetchStartTime;
				MZDebugger.trace(this,{"key":"DESC","value":url});
				var request:URLRequest = new URLRequest(url);
				_httpClient.load(request);
				_isDownloading = true;
				
				_timeoutTimer.reset();
				_timeoutTimer.start();
			}			
		}
		
		private function timeroutTimer_Timer(event:TimerEvent):void
		{
			try{
				_httpClient.close();
			}catch(ex:Error)
			{
				trace(this+":"+ex.getStackTrace())
			}
			_isDownloading = false;
			restartTimer();
		}
		
		private function restartTimer(interval:Number = -1):void
		{
			var timeUsed:Number = getTime() - _fetchStartTime;			
			if(interval != -1)
			{
				_engineTimer.delay = interval;
			}
			else if(timeUsed > DESC_FETCH_INTERVAL)
			{
				_engineTimer.delay = 0;
				
			}else{
				_engineTimer.delay = DESC_FETCH_INTERVAL - timeUsed;
			}			
			_engineTimer.reset();
			_engineTimer.start();
		}
		
		private function completeHandler(event:Event):void 
		{		
			var info:Object = new Object();
			try
			{
				var data:ByteArray = new ByteArray();
				_httpClient.readBytes(data);
				//parse xml only when the data is updated
				if(_lastDescData != null && eqByteArray(_lastDescData,data))
				{					
					restartTimer();
					_timeoutTimer.reset();
					_isDownloading = false;
					return;
				}
				_lastDescData = data;				
				info.code = HttpLiveEvent.LOAD_DESC_SUCCESS;
				info.descXml = new XML(data);
				trace(this+info.descXml)
				_isDownloading = false;
				restartTimer();
			}
			catch(ex:Error)
			{
				_failedTime = getTime();
				_timeoutTimer.reset();
				info.code = HttpLiveEvent.LOAD_DESC_PARSE_ERROR;
				_isDownloading = false;
				restartTimer(0);
			}
			info.shiftTime = -10;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
			dispatchEvent(e);
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			MZDebugger.trace(this,{"key":"DESC","value":"安全错误重新加载"});
			_failedTime = getTime();
			_timeoutTimer.reset();
			_isDownloading = false;
			restartTimer();
			var info:Object = new Object();
			info.code = HttpLiveEvent.LOAD_DESC_SECURITY_ERROR;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
			dispatchEvent(e);
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			MZDebugger.trace(this,{"key":"DESC","value":"io错误重新加载"});
			_failedTime = getTime();
			_timeoutTimer.reset();
			_isDownloading = false;
			restartTimer();
			var info:Object = new Object();
			info.code = HttpLiveEvent.LOAD_DESC_IO_ERROR;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
			dispatchEvent(e);
		}
		
		private function eqByteArray(a:ByteArray, b:ByteArray):Boolean {
			if(a.length != b.length) {
				return false;
			}
			var posA:int = a.position;
			var posB:int = b.position;
			var result:Boolean = true;
			a.position = b.position = 0;
			while(a.bytesAvailable >= 4) {
				if(a.readUnsignedInt() != b.readUnsignedInt()) {
					result = false;
					break;
				}
			}
			if(result && a.bytesAvailable != 0) {
				var last:int = a.bytesAvailable;
				result =
					last == 1 ? a.readByte() == b.readByte() :
					last == 2 ? a.readShort() == b.readShort() :
					last == 3 ? a.readShort() == b.readShort()
					&& a.readByte() == b.readByte() :
					true;
			}
			a.position = posA;
			b.position = posB;
			return result;
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}