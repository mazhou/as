package com.p2p.loaders
{
	import com.p2p.events.EventExtensions;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	/**
	 * <ul>加载数据(见加载数据的形参解释)loadData</ul>
	 * <ul>从加载流中读取数据readData</ul>
	 * <ul>超时处理</ul>
	 * <ul>异常处理</ul>
	 * @author mazhoun
	 */
	public class HttpLoad extends EventDispatcher
	{
		public var isDebug:Boolean=false;
		protected var _mediaStream:URLStream;
		/**加载的地址*/
		public var _url:String;
		public var id:Object=new Object;
		/**加载流过程，把数据分割成固定长度的流*/
		protected var _segmentSize:uint=0;
		/** 存放分割的流*/
		protected var _segmentStream:ByteArray;
		/**超时计时器*/
		protected var _timer:Timer;
		public var isComplementCloseStream:Boolean=false;
		/**是否在读数据*/
		protected var _isRead:Boolean=false;
		/**下载流时规定时间检测数据是否有变化，如果没有变化认为存在网络异常*/
		protected var _checkTimeL:Number=0;
		/**是否开始检测下载流的变化*/
		protected var _isCheckDownload:Boolean=false;
		/**上次加载的字节*/
		protected var _lastLoadSize:Number=0;
		/**统计已经下载的字节，和正在下载的字节相加可以得到下载的进度*/
		public var _countSize:Number=0;
		public function HttpLoad(target:IEventDispatcher=null)
		{}
		/**该方法通过设置时间间隔的时长，来判断在该时长的情况，是否有新的数据下载，如果没有新数据认为有网络问题*/
		public function checkDownloadByInterval(timeLength:Number):void{
			_checkTimeL=timeLength;
		}
		/**
		 * 加载数据
		 * @param _url 加载路径的地址
		 * @param expectedTime 加载一次过期时间，单位是毫秒
		 * @param segmentSiz 把下载的数据按照segmentSiz分割的字节返回数据
		 * @param timeLength 该间隔的时长用来判断，是否有新的数据下载，如果没有新数据认为有网络问题
		 * @return 
		 * 
		 */
		public function loadData(_url:String,expectedTime:int = 0,segmentSiz:uint=0,timeLength:Number=0):Boolean
		{
			if(!_mediaStream)
			{
				P2PDebug.traceMsg(this," 创建加载流对象");
				_mediaStream = new URLStream();
				_mediaStream.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
				_mediaStream.addEventListener(ProgressEvent.PROGRESS,mediaStream_PROGRESS);
				_mediaStream.addEventListener(Event.COMPLETE,mediaStream_COMPLETE);
				_mediaStream.addEventListener(IOErrorEvent.IO_ERROR,mediaStream_ERROR);
				_mediaStream.addEventListener(SecurityErrorEvent.SECURITY_ERROR,mediaStream_ERROR);
			}
			if (expectedTime > 0) 
			{
				if(!_timer)
				{
					P2PDebug.traceMsg(this," 创建超时对象");
					_timer = new Timer(expectedTime, 1);
					_timer.addEventListener(TimerEvent.TIMER, timeup);
				}
				_timer.delay=expectedTime;
				_timer.reset();
				_timer.start();
			}
			if(segmentSiz!=0){_segmentSize=segmentSiz;}
			this._url=_url;
			this._checkTimeL=timeLength;
//			_url="http://player.letvcdn.com/aaa/bbb";
//			Debug.traceMsg(this,"加载地址："+_url);
			_mediaStream.load(new URLRequest(_url));
			_countSize=0;
			return true;
		}
		/**超时处理*/
		private function timeup(evt:TimerEvent):void
		{
			if(_isCheckDownload){
				if(_countSize+_mediaStream.bytesAvailable==_lastLoadSize){
					P2PDebug.traceMsg(this,"时间段内没有下载任何数据");
					close();
					dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, HTTPLOAD_PROTOCOL.IO_ERROR));
				}
			}else{
				P2PDebug.traceMsg(this,"超时啦");
				close();
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, HTTPLOAD_PROTOCOL.TIME_UP));
			}
		}
		public function close():void
		{	
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
						P2PDebug.traceMsg(this+err.message)
					}
				}
				_mediaStream.removeEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
				_mediaStream.removeEventListener(ProgressEvent.PROGRESS,mediaStream_PROGRESS);
				_mediaStream.removeEventListener(Event.COMPLETE,mediaStream_COMPLETE);
				_mediaStream.removeEventListener(IOErrorEvent.IO_ERROR,mediaStream_ERROR);
				_mediaStream.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,mediaStream_ERROR);
				
				_mediaStream=null;
			}
			if (_timer) {
				if (_timer.running) {
					_timer.stop();
				}                
				_timer.removeEventListener(TimerEvent.TIMER, timeup);
			}
			_url="";
		}
		protected function httpStatusHandler(evt:HTTPStatusEvent):void {
//			Debug.traceMsg(this,"httpStatusHandler:" +evt);
		}
		protected function mediaStream_PROGRESS(evt:ProgressEvent=null):void
		{	
			if(_timer&&_timer.running){
				if(_checkTimeL==0){
					P2PDebug.traceMsg(this," 关闭超时对象");
					_timer.stop();
				}else{
					_isCheckDownload=true;
					_lastLoadSize=0;
					_timer.delay=_checkTimeL;
					_timer.reset();
					_timer.start();
				}
			}
			if(_segmentSize!=0){
				if(!_isRead){
					readData();
				}
			}
		}
		protected function mediaStream_COMPLETE(evt:Event):void
		{
			readData(true);
			_timer.stop();
			if(isComplementCloseStream)
			{
				close();
			}
			this.dispatchEvent(evt);
			_countSize=0;
		}
//		private var str:String="\n";
//		private var i:int=0;
//		private var j:int=0;
		/**从加载流中读取数据，测试ok*/
		protected function readData(isComplement:Boolean=false):void
		{
			try{
				if(_segmentSize==0){
					_isRead=true;
					_segmentStream=new ByteArray;
					_countSize+=_mediaStream.bytesAvailable;
					_mediaStream.readBytes(_segmentStream,0,_mediaStream.bytesAvailable);
					_isRead=false;
					this.dispatchEvent(new EventExtensions(HTTPLOAD_PROTOCOL.SEGMENTDATA,_segmentStream));
					return;
				}
			
				while(_mediaStream.bytesAvailable>=_segmentSize){
					_isRead=true;
					_segmentStream=new ByteArray;
					_countSize+=_segmentSize;
					_mediaStream.readBytes(_segmentStream,0,_segmentSize);
	//				for(i=0;i<_segmentStream.length;i=i+16){
	//					for(j=0;j<16;j++){
	//						str+=" "+(_segmentStream[i+j].toString(16).length==1?"0"+_segmentStream[i+j].toString(16):_segmentStream[i+j].toString(16));
	//					}
	//					str+="\n";
	//				}
	//				str+="\n";
					this.dispatchEvent(new EventExtensions(HTTPLOAD_PROTOCOL.SEGMENTDATA,_segmentStream));
				}
	//			Debug.traceMsg(this,"1.加载的数据是 :\n"+str);
	//			str="";
				_isRead=false;
				if(isComplement){
					if(_mediaStream.bytesAvailable>0&&_mediaStream.bytesAvailable<=_segmentSize){
						_segmentStream=new ByteArray;
						_countSize+=_mediaStream.bytesAvailable;
	//					Debug.traceMsg(this,"最后数据长度 :"+_countSize);
						_mediaStream.readBytes(_segmentStream,0,_mediaStream.bytesAvailable);
	//					for(j=0;j<_segmentStream.length;j++){
	//						str+=" "+(_segmentStream[j].toString(16).length==1?"0"+_segmentStream[j].toString(16):_segmentStream[j].toString(16));
	//					}
	//					Debug.traceMsg(this,"2.加载的数据是 :\n"+str);
						this.dispatchEvent(new EventExtensions(HTTPLOAD_PROTOCOL.SEGMENTDATA,_segmentStream));
					}
				}
			}catch(err:Error){
				close();
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, HTTPLOAD_PROTOCOL.PARSE_ERROR));
				P2PDebug.traceMsg(this,"http解析数据错误");
			}
		}
		protected function mediaStream_ERROR(evt:Event):void
		{
			var text:String;
			if (evt is IOErrorEvent) {
				text = HTTPLOAD_PROTOCOL.IO_ERROR;
			} else if (evt is SecurityErrorEvent) {
				text = HTTPLOAD_PROTOCOL.SECURITY_ERROR;
			}
			close();
//			Debug.traceMsg(this,"网络出错啦");
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, text));
		}
	}
}