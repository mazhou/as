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
	
	import org.osmf.events.TimeEvent;
	
	public class HttpLiveSeekDescLoader extends EventDispatcher
	{
		protected const DESC_FETCH_INTERVAL:uint = 6*1000 //
		protected var _descUrlArr:Array;
		protected var _CDNIndex:int = 0;     //保存正在使用的cdn数组的索引	
		protected var _httpClient:URLStream;
		protected var _engineTimer:Timer;
		protected var _shiftTime:Number;         //时移的时间
		protected var _realShiftTime:Number;     //写在请求地址里的时间值，同时用于输出显示信息使用
		protected var _startDelayTime:Number = 0; //用来抵消各种加载延时造成的误差
		/**
		 * _preSeekXML保存预加载desc文件的XML,用来判断加载的文件是否已经刷新了，如果没有刷新则重新加载
		 */
		protected var _preSeekXML:XML;
				
		public function HttpLiveSeekDescLoader(urlArr:Array)
		{
			_descUrlArr = urlArr;			
			_httpClient = new URLStream();
			_httpClient.addEventListener(Event.COMPLETE, completeHandler);			
			_httpClient.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
			_httpClient.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			//_httpClient.addEventListener(HTTPStatusEvent.HTTP_STATUS,httpStatusHandler);
			
			_engineTimer = new Timer(DESC_FETCH_INTERVAL,1);
			_engineTimer.addEventListener(TimerEvent.TIMER,timerHandler);
			
			_preSeekXML = new XML();
		}

		public function start(index:int,shiftTime:Number):void
		{	
			if(index >=0 && index<_descUrlArr.length)
			{
				//trace(this+"开始加载"+index+"shiftTime"+shiftTime);
				_CDNIndex  = index;	
				_shiftTime = shiftTime;
				_realShiftTime = shiftTime;
				
				_engineTimer.reset();
				_engineTimer.start();
				
				if(_httpClient.connected){
					try
					{
						_httpClient.close();
					}
					catch(e:Error)
					{trace("load xml----close----Error ")}
				}
				_startDelayTime = getTime();
				var url:String = _descUrlArr[index] + shiftTime;
				_httpClient.load(new URLRequest(url+"&r="+getTime()));
				MZDebugger.trace(this,{"key":"DESC","value":url});
				trace("load xml---start---- "+url);
				trace("---------------------------------");
			}			
			
		}
		public function close():void
		{
			if(_httpClient.connected)
			{
				try
				{					
					_httpClient.close();			
				}
				catch(e:Error)
				{
					trace("load xml----close----Error ")
				}
		    }
			if(_engineTimer.running)
			{
				_engineTimer.reset();
			}
			_engineTimer.delay = DESC_FETCH_INTERVAL;
			//_descUrlArr = null;
			_CDNIndex = 0;
			_startDelayTime = 0;
			_preSeekXML = new XML();
		}
		public function clear():void
		{
			if(_httpClient)
			{
				close();
				clearHttpClient();				
			}
			if(_engineTimer)
			{				
				clearEngineTimer();
			}			
		}		
		private function clearHttpClient():void
		{
			_httpClient.removeEventListener(Event.COMPLETE, completeHandler);			
			_httpClient.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
			_httpClient.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			//_httpClient.removeEventListener(HTTPStatusEvent.HTTP_STATUS,httpStatusHandler);
			_httpClient = null;
		}
		private function clearEngineTimer():void
		{
			_engineTimer.removeEventListener(TimerEvent.TIMER,timerHandler);
			_engineTimer = null;
		}
		private function timerHandler(event:TimerEvent):void
		{
			if(_engineTimer.delay == DESC_FETCH_INTERVAL)
			{
				reLoad();
			}
			else
			{
				var shiftTime:Number;
				if(_shiftTime<-10)
				{
					shiftTime = _shiftTime-Math.round((getTime()-_startDelayTime)/1000);							
				}
				else
				{
					shiftTime = -10;
				}
				_realShiftTime = shiftTime;
				var url:String = _descUrlArr[_CDNIndex] + shiftTime;
				_httpClient.load(new URLRequest(url+"&r="+getTime()));
				trace("load xml---reLoad---- "+url);
				_engineTimer.delay == DESC_FETCH_INTERVAL;
				_engineTimer.reset();
				_engineTimer.start();
			}			
		}
		private function completeHandler(event:Event):void 
		{		
			var info:Object = new Object();
			//trace("load xml---------completeHandler ")
			try
			{
				_engineTimer.reset();
				
				var data:ByteArray = new ByteArray();
				_httpClient.readBytes(data);
				if(data.length==0)
				{
					reLoad();
					return;
				}
				//parse xml only when the data is updated
										
				info.code = HttpLiveEvent.LOAD_DESC_SUCCESS;
				info.descXml = new XML(data);
				//trace("info.descXml "+info.descXml);
				
				if(info.descXml
					&& info.descXml["header"]
					&& info.descXml["header"].@name
					&& info.descXml["clip"]
					&& info.descXml["clip"].@name)
				{
					if(_preSeekXML == info.descXml)
					{
						reLoad();
						return;
					}
					
					_engineTimer.delay = DESC_FETCH_INTERVAL;
					_preSeekXML = info.descXml;	
				}
				else
				{
					reLoad();
					trace("============");
					
					return;
				}
							
			}
			catch(ex:Error)
			{
				trace("completeHandler  Error");
				info.code = HttpLiveEvent.LOAD_DESC_PARSE_ERROR;	
				reLoad();
			}
			info.shiftTime = _realShiftTime;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
			dispatchEvent(e);
		}
		/*
		private function httpStatusHandler(event:HTTPStatusEvent):void
		{			
			if(event.status == 404){
				trace("load xml---------404 ");
			    trace("_descUrl = "+_descUrl);
				closeHttpClient();
				var info:Object = new Object();
				info.code = HttpLiveEvent.LOAD_DESC_NOT_EXIST;
				var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
				dispatchEvent(e);
			}
		}
		*/
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			trace("load xml---------securityErrorHandler "+_descUrlArr[_CDNIndex]);
			/**更换cdn地址*/
			_CDNIndex = nextCDNIndex(_CDNIndex);
			reLoad();
			var info:Object = new Object();
			info.code = HttpLiveEvent.LOAD_DESC_SECURITY_ERROR;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
			dispatchEvent(e);
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			trace("load xml---------ioErrorHandler "+_descUrlArr[_CDNIndex]);
			/**更换cdn地址*/
			_CDNIndex = nextCDNIndex(_CDNIndex);
			reLoad();
			var info:Object = new Object();
			info.code = HttpLiveEvent.LOAD_DESC_IO_ERROR;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
			dispatchEvent(e);
		}
		
		private function reLoad():void
		{
			closeHttpClient();							
			
			if(_engineTimer.running)
			{
				trace("_engineTimer.running = "+_engineTimer.running)
				_engineTimer.reset();				
			}
			_engineTimer.delay = 3*1000;
			_engineTimer.start();
		}
		
		private function closeHttpClient():void
		{			
			if(_httpClient.connected)
			{
				try
				{					
					_httpClient.close();			
				}
				catch(e:Error)
				{
					trace("load xml----close----Error ")
				}
			}
			clearHttpClient();
			
			_httpClient = new URLStream();
			_httpClient.addEventListener(Event.COMPLETE, completeHandler);			
			_httpClient.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
			_httpClient.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			//_httpClient.addEventListener(HTTPStatusEvent.HTTP_STATUS,httpStatusHandler);
		}
		
		private function nextCDNIndex(index:int):int
		{				
			index++;
			if(index >= _descUrlArr.length)
			{
				index = 0;
			}
			return index;			
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}