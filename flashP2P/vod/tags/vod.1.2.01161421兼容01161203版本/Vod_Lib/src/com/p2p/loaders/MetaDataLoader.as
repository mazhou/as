package com.p2p.loaders
{
	import com.p2p.events.MetaDataLoaderEvent;
	
	import flash.errors.EOFError;
	import flash.errors.IOError;
	import flash.events.*;
	import flash.net.ObjectEncoding;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class MetaDataLoader extends EventDispatcher
	{
		protected const METADATA_LOAD_TIMEOUT:Number = 4*1000;//超时时长
		protected const AMF_ONMETADATA:String = "onmetadata";
		
		protected var _httpClient:URLStream;
		protected var _clipInterval:uint;		
		protected var _arrayFLVURL:Array;        //保存flv地址的数组
		protected var _arrayFLVURLIndex:int = 0 ;//当前使用的flv地址索引
		protected var _requestTime:Number = 0 ;  //请求连接的时间，用于计算连接到cdn的时间
		protected var _timeStart:int = 0;
		protected var _timeEnd:int = 0;
		protected var _startTime:Number = 0;
		protected var metaDataArray:ByteArray;
		/**
		 * _myTimer 为连接CDN的计时器，
		 * 当超过规定时间没有成功得到头信息则视为该CDN连接失败
		 * 第一台连接限时4秒，二台3秒，三台之后2秒
		 */		
		protected var _myTimer :Timer;  
		
		protected var _need_CDN_Bytes:int;//当从CDN下载数据超过此值时进行上报，表示CDN下载数据成功
		protected var _is_need_CDN_Bytes:Boolean = false;
		
		public function MetaDataLoader(clipInterval:uint)
		{
			_clipInterval = clipInterval;		
		}
		
		public function start(urlArray:Array,timeStart:int, timeEnd:int,need_CDN_Bytes:int = 0):void
		{
			_arrayFLVURL = urlArray.concat();
			_arrayFLVURLIndex = 0;		
			
			_startTime = Math.floor((new Date()).time);
			_timeStart = timeStart;
			_timeEnd = timeEnd;
			
			_need_CDN_Bytes = need_CDN_Bytes;
			
			reload(false);
		}
		
		private function checkTimeout(e:TimerEvent):void
		{
			/*if(_startTime != 0 && (Math.floor((new Date()).time) - _startTime) >  METADATA_LOAD_TIMEOUT)
			{
				failedHandler("timeoutError");
			}*/
			failedHandler("timeoutError");
		}
		
		public function close():void
		{
			try 
			{				
				clearTimer();
				
				_startTime = 0;
				if(_httpClient/* && _httpClient.connected*/)
				{					
					_httpClient.removeEventListener(Event.COMPLETE, completeHandler);			
					_httpClient.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
					_httpClient.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
					_httpClient.removeEventListener(ProgressEvent.PROGRESS,progressHandler);
					_httpClient.close();
					_httpClient = null;
				}
				
			}catch (error:Error)
			{
				//trace("headerLoader stream could not be closed, or the stream was not open.");
			}
		}
		
		private function readMetaData(metaData:ByteArray,offset:int=0,len:int=0):Object
		{			
			if(_httpClient.bytesAvailable > 9)
			{				
				_httpClient.readBytes(metaData);				
				//only flv format is supported
				if(metaData[0] == 0x46 && metaData[1] == 0x4c && metaData[2] == 0x56)
				{
					var pos:int = metaData[8];
					//pass video or audio tag
					while(metaData[pos+4] != 18)
					{
						pos += 15;
						pos += metaData[pos+5] >> 16 | metaData[pos+6] >> 8 | metaData[pos+7];
					}
					//calculate script tag length
					var scriptLen:int = metaData[pos+5] << 16 | metaData[pos+6] << 8 | metaData[pos+7];
					//pass the script tag header
					metaData.position = pos + 15;
					//the script tag body encoded in AMF0
					metaData.objectEncoding = ObjectEncoding.AMF0;
					try{
						var onMetaData:String = metaData.readObject() as String;
						if( onMetaData.toLowerCase() == AMF_ONMETADATA)
						{
							return metaData.readObject();
						}
					}catch(err:flash.errors.EOFError)
					{
						//trace(this+err.message);
					}
				}
			}
			return null;			
		}		
		
		private function reload(touch:Boolean = true):void
		{
			close();
			//第一台CDN连接限时4秒，二台3秒，三台之后2秒
			var delay:int = (METADATA_LOAD_TIMEOUT - _arrayFLVURLIndex*1000) >= 2000 ? (METADATA_LOAD_TIMEOUT - _arrayFLVURLIndex*1000) : 2000 ;
			_myTimer = new Timer(delay,1);
			_myTimer.addEventListener(TimerEvent.TIMER,checkTimeout);
			_myTimer.start();
			//
			var theUrl:String = _arrayFLVURL[_arrayFLVURLIndex];
			_httpClient = new URLStream();
			if(!touch)
			{
				theUrl = encapsuleUrl(theUrl,_timeStart,_timeEnd);
			}else
			{
				//_httpClient.addEventListener(ProgressEvent.PROGRESS,progressHandler);
			}
			_httpClient.addEventListener(ProgressEvent.PROGRESS,progressHandler);
			_httpClient.addEventListener(Event.COMPLETE, completeHandler);			
			_httpClient.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);			
			_httpClient.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			var request:URLRequest = new URLRequest(theUrl);
			_httpClient.load(request);
			_requestTime = Math.floor((new Date()).time);
		}
		
		private function encapsuleUrl(g3Url:String,timeStart:int, timeEnd:int):String
		{			
			var hasStart:RegExp = /(?:^|\?|&)begin=(\d*)(?:&|$)/i;
			var result:Array=g3Url.match(hasStart);
			var startStr:String = "begin=" + timeStart;
			if(result == null)
			{
				g3Url += "&" + startStr;
			}else
			{
				var replaceStart:RegExp = /(&)begin=(\d*)($)/i;
				if(replaceStart.exec(g3Url) != null){					
					g3Url = g3Url.replace(replaceStart,"&" + startStr);
				}else
				{
					replaceStart = /begin=(\d*)(?:&)/i;
					g3Url = g3Url.replace(replaceStart,startStr + "&");
				}				
			}
			
			var hasEnd:RegExp = /(?:^|\?|&)stop=(\d*)(?:&|$)/i;			
			var endStr:String = "stop=" + timeEnd;
			if(g3Url.match(hasEnd) == null)
			{
				g3Url += "&" + endStr;
			}else{
				var replaceEnd:RegExp = /(&)stop(\d*)($)/i;
				if(replaceEnd.exec(g3Url) != null)
				{					
					g3Url = g3Url.replace(replaceEnd,"&" + endStr);
				}else
				{
					replaceEnd = /stop=(\d*)(?:&)/i;
					g3Url = g3Url.replace(replaceEnd,endStr + "&");
				}				
			}
			return g3Url;
		}
		
		private function progressHandler(e:ProgressEvent):void
		{
			/*if(_httpClient.bytesAvailable > 0)
			{
				var metaData:ByteArray = new ByteArray();
				_httpClient.readBytes(metaData);		
				var info:Object=new Object();
				info.code = MetaDataLoaderEvent.LOAD_METADATA_SUCCESS;
				info.urlIndex = _arrayFLVURLIndex;
				info.size = uint(e.bytesTotal);
				info.chunks = uint(e.bytesTotal % _clipInterval == 0 ? e.bytesTotal / _clipInterval:Math.ceil(e.bytesTotal / _clipInterval));
				info.utime = Math.floor((new Date()).time) - _requestTime;
				info.url = String(_arrayFLVURL[_arrayFLVURLIndex]);	//将成功的flv地址保存
				info.nodeIdx = _arrayFLVURLIndex;
				info.retry = _arrayFLVURLIndex+1;
				info.byteArray = metaData;
				info.metaData = null;
				info.allCDNFailed = 0;
				//trace("obj.utime  "+obj.utime+"  _requestTime  "+_requestTime+"  getTime()"+getTime());
				var _e:MetaDataLoaderEvent = new MetaDataLoaderEvent(MetaDataLoaderEvent.LOAD_METADATA_STATUS,info);			
			    //dispatchEvent(_e);
			}*/
			if(!_is_need_CDN_Bytes && _httpClient.bytesAvailable >= _need_CDN_Bytes)
			{
				_is_need_CDN_Bytes = true;
				var info:Object=new Object();
				info.code  = MetaDataLoaderEvent.NEED_CDN_BYTES_SUCCESS;
				info.bytes = _httpClient.bytesAvailable;
				info.utime = Math.floor((new Date()).time) - _requestTime;
				info.retry = _arrayFLVURLIndex+1;
				info.url = String(_arrayFLVURL[_arrayFLVURLIndex]);	
				dispatchEvent( new MetaDataLoaderEvent(MetaDataLoaderEvent.LOAD_METADATA_STATUS,info));
			}
		}
		
		private function completeHandler(event:Event):void 
		{			
			//trace("completeHandler: :::::" + event);
			metaDataArray = new ByteArray();
			var metaObj:Object = readMetaData(metaDataArray);			
			var info:Object=new Object();
			
			if(metaObj != null && metaObj.filesize != undefined)
			{				
				
				if(!_is_need_CDN_Bytes)
				{
					//当成功下载头文件信息，但下载的字节数小于_is_need_CDN_Byte时，强行发送成功信息
					_is_need_CDN_Bytes = true;
					info.code  = MetaDataLoaderEvent.NEED_CDN_BYTES_SUCCESS;
					info.bytes = metaObj.filesize;
					info.utime = Math.floor((new Date()).time) - _requestTime;
					info.retry = _arrayFLVURLIndex+1;
					info.url = String(_arrayFLVURL[_arrayFLVURLIndex]);	
					dispatchEvent( new MetaDataLoaderEvent(MetaDataLoaderEvent.LOAD_METADATA_STATUS,info));
				}
				
				info.size = metaObj.filesize;
				info.chunks = uint(metaObj.filesize % _clipInterval == 0 ? metaObj.filesize / _clipInterval:Math.ceil(metaObj.filesize / _clipInterval));
				info.code = MetaDataLoaderEvent.LOAD_METADATA_SUCCESS;
				info.byteArray = metaDataArray;
				info.metaData = metaObj;
				info.urlIndex = _arrayFLVURLIndex;			
				info.utime = Math.floor((new Date()).time) - _requestTime;
				info.url = String(_arrayFLVURL[_arrayFLVURLIndex]);	//将成功的flv地址保存
				info.nodeIdx = _arrayFLVURLIndex;
				info.retry = _arrayFLVURLIndex+1;
				info.allCDNFailed = 0;
				dispatchEvent(new MetaDataLoaderEvent(MetaDataLoaderEvent.LOAD_METADATA_STATUS,info));
				
			}else
			{
				failedHandler(MetaDataLoaderEvent.LOAD_METADATA_PARSE_ERROR);
			}			
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			//trace("securityErrorHandler: " + event);
			failedHandler("securityError");
		}		
		
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			//trace("ioErrorHandler: " + event);
			failedHandler("ioError");			
		}
		
		private function failedHandler(code:String):void
		{				
			//
			_myTimer.stop();
			//
			var info:Object=new Object();	
			info.size = 0;
			info.chunks =0;
			info.code = code;
			info.byteArray = null;
			info.metaData = null;			
			info.urlIndex = _arrayFLVURLIndex;			
			info.utime = Math.floor((new Date()).time) - _requestTime;
			info.url = String(_arrayFLVURL[_arrayFLVURLIndex]);
			info.nodeIdx = _arrayFLVURLIndex;
			info.retry = _arrayFLVURLIndex+1;
			if(_arrayFLVURLIndex >= _arrayFLVURL.length - 1)
			{
				info.allCDNFailed = 1;
				_arrayFLVURLIndex = 0;
				
			}else
			{
				info.allCDNFailed = 0;
				_arrayFLVURLIndex++;
				
				reload(false);
			}
			//
			//reload(false);
			dispatchEvent(new MetaDataLoaderEvent(MetaDataLoaderEvent.LOAD_METADATA_STATUS,info));
		}
		//
		private function clearTimer():void
		{
			if(_myTimer)
			{
				//trace("_myTimer = clear ! ! ! !")
				_myTimer.stop();
				_myTimer.removeEventListener(TimerEvent.TIMER,checkTimeout);
				_myTimer = null;
			}
		}
	}
}