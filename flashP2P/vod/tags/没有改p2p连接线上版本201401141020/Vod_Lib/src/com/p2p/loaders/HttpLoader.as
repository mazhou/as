
package com.p2p.loaders
{
	/*
	此类负责从服务器下载flv数据
	*/
	/*import com.mzStudio.component.load.AssetLoader;
	import com.mzStudio.event.EventExtensions;
	import com.mzStudio.tool.Logger;*/
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.events.HttpLoaderEvent;
	import com.p2p.events.P2PEvent;
	import com.p2p.utils.httpSocket.*;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class HttpLoader extends EventDispatcher
	{
		//文件块大小
		protected var _clipInterval:uint;//每一块数据的大小,字节数
		protected var _chunks:uint;
		/*chang 创建新*/
		//protected var _mediaStream:AssetLoader;
		protected var _mediaStream:URLStream;
		protected var _httpNowIndex:int=-1;//当前下载任务的索引值（第一块chunk的索引值）
		
		protected var _url:String;
		//
		protected var _rangeURL:String;
		//
		protected var _totalBytesSize:uint;
		protected var _nChunk_number:int;//本次下载任务共需下载多少块数据
		protected var _nCount:int;//收到第几块数据
		
		protected var _nChunk_totalBytes:uint;//本次下载任务的字节数
		
		public function gethttpNowIndex():int
		{
			return _httpNowIndex;
		}
		public function GethttpChunks():int
		{
			return _nChunk_number;
		}
		public function HttpLoader(clipInterval:uint)
		{
			_clipInterval=clipInterval;
			//_fetchDataTimer = new Timer(100);
			//_fetchDataTimer.addEventListener(TimerEvent.TIMER, heartBeatFetchData);
			//_fetchDataTimer.start();			
		}
		
		public function setReady(url:String,totalBytesSize:uint,chunks:uint):void
		{
			_url = url;
			_totalBytesSize = totalBytesSize;
			_chunks = chunks;
		}
		/**
		 * 
		 * @param idx chuck的起始索引 
		 * @param n 本次任务的总块数
		 * @return 
		 * 
		 */
		public function loadData(idx:uint, n:int):Boolean
		{
			errorLevel = "HttpLoader-error";
			_nChunk_number = n;	
			if(DetermineRanges(idx))
			{				
				_nCount = 0;
				_mediaStream = new URLStream();
				_mediaStream.addEventListener(ProgressEvent.PROGRESS,mediaStream_PROGRESS);
				_mediaStream.addEventListener(Event.COMPLETE,mediaStream_COMPLETE);
				_mediaStream.addEventListener(IOErrorEvent.IO_ERROR,mediaStream_ERROR);
				_mediaStream.addEventListener(SecurityErrorEvent.SECURITY_ERROR,mediaStream_ERROR);
				//MZDebugger.trace(this,"_rangeURL:"+_rangeURL+" _nChunk_totalBytes:"+_nChunk_totalBytes);
				_mediaStream.load(new URLRequest(_rangeURL));
				//_mediaStream.load(new URLRequest("http://123.126.32.19/uus.dat"));
				
				return true;
			}						
			/*chang 初始化*/
			/*
			if(DetermineRanges(idx))
			{		
				_nCount = 0;
				chang 初始化http://123.125.89.79/9/29/75/2091241663.0.letv?crypt=645987ecaa7f2e438&b=2000&gn=103&nc=1&bf=18&p2p=1&video_type=flv&rstart=0&rend=131071
				
				return _mediaStream.load(new URLRequest(_url));
			}*/	
			//
			return false;			
		}
		private var errorLevel:String = "HttpLoader-error";//
		public function clear():void
		{	
			errorLevel = "HttpLoader-warnning";
			if(_mediaStream)
			{			
				if(_mediaStream.connected)
				{
					try
					{
						_mediaStream.close();
					}
					catch(err:Error)
					{
						//trace(this+err.message)
					}
				}
				_mediaStream.removeEventListener(ProgressEvent.PROGRESS,mediaStream_PROGRESS);
				_mediaStream.removeEventListener(Event.COMPLETE,mediaStream_COMPLETE);
				_mediaStream.removeEventListener(IOErrorEvent.IO_ERROR,mediaStream_ERROR);
				_mediaStream.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,mediaStream_ERROR);
				
				_mediaStream=null;
			}
			//
			/*if(_fetchDataTimer)
			{
				_fetchDataTimer.removeEventListener(TimerEvent.TIMER, heartBeatFetchData);
				_fetchDataTimer.stop();
			}*/
			//
			_clipInterval=0;
			_nChunk_totalBytes = 0;
			_url="";
		}
		//		
		/*private function heartBeatFetchData(e:* = null):void
		{
			var lastChunkSize:uint = _totalBytesSize % _clipInterval;
			if (lastChunkSize == 0)
			{
				lastChunkSize = _clipInterval;
			}
			//
			Logger.Monsterlog(this,"(_mediaStream.isEnough("+(_httpNowIndex + _nCount)+" >= "+(_chunks-1)+" ?"+ lastChunkSize+" :"+ _clipInterval+")");
			//_chunks 视频源的总块 数，索引从0开始  
			//_httpNowIndex 块的累积值
			if (_mediaStream.isEnough((_httpNowIndex + _nCount) >= (_chunks-1) ? lastChunkSize : _clipInterval))
			{
				mediaStream_PROGRESS();
			}
		}*/
		
		protected function getLastChunk():int
		{
			return _totalBytesSize % _clipInterval;
		}
		
		protected function mediaStream_PROGRESS(e:ProgressEvent=null):void
		{	
			/*trace(e.bytesTotal);
			trace(_rangeURL);
			trace("_nChunk_totalBytes = "+_nChunk_totalBytes);*/
			if(e.bytesTotal != _nChunk_totalBytes)
			{
				//MZDebugger.trace(this,"e.bytesTotal"+e.bytesTotal+" _nChunk_totalBytes:"+_nChunk_totalBytes,"",0x000ff0);
				errorLevel = "HttpLoader-error";
				http_error(errorLevel,"CDNError");
				clear()
				return;
			}
			
			receiveData(_nCount);	
			
		}
		protected function mediaStream_COMPLETE(e:Event):void
		{
			receiveData(_nCount);
			//trace(_nCount*131072);
			if(_nChunk_number == _nCount)
			{
				dispatchLoadComplete();
			}
			else
			{
				http_error(errorLevel,"ioError");
			}
			clear();
		}
		protected function receiveData(idx:uint):void
		{
			if((idx+_httpNowIndex) != (_chunks-1))
			{
				//不是影片最后一块数据
				if(_mediaStream.bytesAvailable >= _clipInterval)
				{							
					var length:uint = uint(_mediaStream.bytesAvailable/_clipInterval);
					
					for(var i:uint=0 ; i<length ; i++)
					{												
						dispatchGetData(_httpNowIndex+_nCount);						
						_nCount++;
					}					
				}
			}
			else
			{
				//是影片最后一块数据
				if(_mediaStream.bytesAvailable >= getLastChunk())
				{
					dispatchGetData(_httpNowIndex+idx);	
					_nCount++;
				}				
			}			
		}
		protected function dispatchGetData(idx:uint):void
		{
			var obj:Object = new Object();
			obj.id   = idx;
			obj.from = "http";					
			obj.data = new ByteArray();
			_mediaStream.readBytes(obj.data,0,getLength(idx));
			var event:HttpLoaderEvent=new HttpLoaderEvent(HttpLoaderEvent.HTTP_GOT_PROGRESS,obj);				
			dispatchEvent(event);
		}
		protected function dispatchLoadComplete():void
		{
			var object:Object = new Object();
			object.id = uint(_httpNowIndex);
			var event:HttpLoaderEvent=new HttpLoaderEvent(HttpLoaderEvent.HTTP_GOT_COMPLETE, object);				
			dispatchEvent(event);
		}
		protected function getLength(idx:int):uint
		{
			if(idx < _chunks-1)
			{
				return _clipInterval;
			}
			//影片的最后一块
			//trace(_totalBytesSize-_clipInterval*(_chunks-1));
			return _totalBytesSize-_clipInterval*(_chunks-1);			
		}
		protected function http_error(status:String,text:String):void
		{						
			var obj:Object = new Object();
			obj.type = status;
			obj.id   = uint(_httpNowIndex);
			obj.text  = text;
			obj.nCount = _nChunk_number;
			var e:P2PEvent = new P2PEvent(P2PEvent.ERROR, obj);
			dispatchEvent(e);
			//
			//trace("status  "+status+"  obj.nCount"+obj.nCount)
			if(_mediaStream)
			  _mediaStream.close();
		}
		
		protected function mediaStream_ERROR(e:Event):void
		{
			var text:String=String(e.type);
			//trace("mediaStream_ERROR  == "+text);
			if(text != "ioError" && text != "securityError")
			{
				errorLevel = "HttpLoader-warnning";
				text = "ioError";
			}
			
			http_error(errorLevel,String(text));
			
		}
		/**
		 * 根据_url地址和请求数据范围，生成带有请求数据范围的_rangeURL 
		 * @param idx
		 * @return  
		 */	
		protected function DetermineRanges(idx:uint):Boolean
		{		
			_httpNowIndex =idx;	
			//Logger.Monsterlog(this,"idx"+idx);
			var begin:uint = idx*_clipInterval;
			var end:uint = (idx + _nChunk_number) * _clipInterval -1;
			if(end > _totalBytesSize - 1)
			{
				end = _totalBytesSize - 1;
			}
			if(begin > _totalBytesSize - 1)
			{
				begin = _totalBytesSize - 1;
			}
			_nChunk_totalBytes = end - begin + 1;
			//
			//trace("range","bytes id"+idx+"=" + begin.toString() + "-" + end.toString()+"  size = "+String(end-begin));
			//Logger.Monsterlog(this,"range bytes=" + begin.toString() + "-" + end.toString());
			//
			_rangeURL = _url+"&rstart="+begin.toString()+"&rend="+end.toString();
			//
			return true;
		}
	}
}