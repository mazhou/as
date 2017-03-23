package com.p2p.loaders
{
	import com.p2p.data.LIVE_TIME;
	import com.p2p.data.vo.BadDesc;
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LOAD_TYPE;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.DESC_PROTOCOL;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.*;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.*;
	import flash.text.StaticText;
	import flash.utils.Timer;

	/**
	 * <ul>构造函数：监听NETSTREAM_PROTOCOL.PLAY，NETSTREAM_PROTOCOL.SEEK</ul>
	 * <ul>NETSTREAM_PROTOCOL.PLAY事件处理：接受_initData并根据_initData换算加载desc的地址和加载的时间</ul>
	 * <ul>NETSTREAM_PROTOCOL.SEEK：根据_initData</ul>
	 * <ul>加载器：httpload类型加载器</ul>
	 * <ul>时移加载：加载播放头之后的数据达到一定的范围，改为时间驱动加载</ul>
	 * <ul>直播加载：加载到直播点，按照3秒加载直播点地址</ul>
	 * <ul>加载处理dataHandler:，是否直播点的判断，目前邢波返回xml包含error节点告诉直播点；
	 * 是否该加载下一分钟，是否达到minDESCTimestamp()+Config.DESC_TIME-60范围加载</ul>
	 * <ul>异常处理<ul>
	 * @author mazhoun
	 */
	public class DescLoopLoader// implements IChecksumLoad
	{
		private var _dispather:IDataManager = null;
		
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader;//new URLLoader();
		private var _initData:InitData;
		public function DescLoopLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			//
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			
			loader.addEventListener(Event.COMPLETE, completeHandler);
			loader.addEventListener(Event.OPEN, openHandler);
			loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
			loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
		public function start( _initData:InitData):void
		{
			this._initData = _initData;
			if (_downloadTaskTime == null)
			{
				_downloadTaskTime = new Timer(5);
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
				_downloadTaskTime.start();
			}
			
		}
		//
		private function completeHandler(event:Event):void 
		{
				
			taskTime = -1;
			//
			try
			{
				_xml=new XML(event.target.data);
			}catch(err:Error)
			{
				//errorHandler();
				P2PDebug.traceMsg(this,"解析xml错误"+abTimeShiftURL+this.taskTime);
				return;
			}
			
			//			Debug.traceMsg(this,"desc_xml:"+_xml);
			_clipList=new Vector.<Clip>;
			_head="";
			var minClipTime:Number    = Number.MAX_VALUE;//int.MIN_VALUE//int.MAX_VALUE;
			var _tempTimestamp:Number = 0;
			var duration:Number = 0;
			for(i=0;i<_xml.children().length();i++){
				if((/.header/).test(_xml.children()[i].@name)){
					//对头处理
					_head=_xml.children()[i].@name.toString().replace(".header","");
				}else{
					//对clip处理
					if(reg.test(_xml.children()[i].@name)){
						if(_xml.children()[i].@name.match(reg).length==4)
						{
							//Number(_xml.children()[i].@name.match(reg)[1])
							/**desc文件处理*/
							_clip=new Clip;
							if(_head==""){break;}
							
							_clip.head=Number(_head);
							_clip.checkSum=_xml.children()[i].@checksum;
							_clip.sequence=Number(_xml.children()[i].@sequence);
							_clip.duration=Number(_xml.children()[i].@name.match(reg)[2]);
							_clip.size=Number(_xml.children()[i].@name.match(reg)[3]);
							_tempTimestamp = _clip.timestamp=Number(_xml.children()[i].@name.match(reg)[1]);
							_clip.name=_xml.children()[i].@name;
							_clipList.push(_clip);
							dugString+="\n"+_clip.head+"~_~"+_clip.timestamp+"~_~"+_clip.duration+"~_~"+_clip.size+"~_~"+_clip.checkSum+"~_~"+_clip.sequence;
							
						}
					}
				}
			}
			
			P2PDebug.traceMsg(this,"descData:"+dugString);
			dugString="";
			if(_clipList.length>=1)
			{
				if(_clip)
				{
					Statistic.getInstance().descLastTime(TimeTranslater.getTime(_clip.timestamp));
				}
				_dispather.writeClipList(_clipList);
			}
		}
		
		private function openHandler(event:Event):void
		{
			trace("openHandler: " + event);
		}
		
		private function progressHandler(event:ProgressEvent):void
		{
			trace("progressHandler loaded:" + event.bytesLoaded + " total: " + event.bytesTotal);
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			trace("securityErrorHandler: " + event);
		}
		
		private function httpStatusHandler(event:HTTPStatusEvent):void 
		{
			trace("httpStatusHandler: " + event);
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			trace("ioErrorHandler: " + event);
		}
		//
		private var taskTime:Number = -1;
		public function handlerDownloadTask(evt:TimerEvent=null):void
		{
			if (_dispather && taskTime == -1 )
			{
				taskTime = getDescTask();
				//
				var url:String = getDatURL(abTimeShiftURL+this.getMiniMinute(taskTime)+"&rdm="+getTime());
				var request:URLRequest = new URLRequest(url);
				try
				{
					loader.load(request);
					
				} catch (error:Error)
				{
					trace("Unable to load requested document.");
				}
			}
		}
		protected function getDatURL(name:String):String
		{
			return _initData.flvURL[0].replace("desc.xml",name);
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	
		
		
		
//		public var isDebug:Boolean=true;
//		
//		 /**播放器传递的参数*/
//		protected var _initData:InitData;
//		/**http基类加载，基于urlstream*/
//		protected var _httpLoad:HttpLoad;
//		
//		/**直播时加载器*/
//		protected var _liveLoadTimer:Timer=null;
//		
//		/**请求超时*/
//		protected const DESC_FETCH_TIMEOUT:uint = 3000;
//		/**加载地址索引，因地址有多个*/
//		protected var loadURLIndex:uint=0;
//		
//		/**声明数据管理器*/
//		protected var _dispather:IDataManager;
//		
//		/**范围定时检测*/
//		protected var _rangeCheckTimer:Timer=null;
//		/**加载范围定时检测间隔*/
//		protected const DESC_RANGECHECK_INTERVAL:uint = 3000;
//		/**是否加载*/
//		protected var _isLoad:Boolean=false; 
//		/**第一次加载起始时间，统计用*/
//		protected var _firstLoadBeginTime:Number=0;
//		/**标识是否是play或seek加载*/
//		protected var _loadStat:String="";
//		
//		protected var _test_isLoad:Boolean=true;
//		
//		public function DescLoopLoader(_dispather:IDataManager)
//		{
//			ExternalInterface.addCallback("stopDesc",stopDesc);
//			ExternalInterface.addCallback("startDesc",startDesc);
//			this._dispather=_dispather;
//			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
//			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
//		}
//		public function stopDesc():void
//		{
//			_test_isLoad=false;
//		}
//		public function startDesc():void
//		{
//			_test_isLoad=true;
//		}
//		protected function startRangeCheckTimer():void
//		{
//			_isLoad = false;
//			httpLoadGarbageCollector();
//			if(!_rangeCheckTimer)
//			{
//				_rangeCheckTimer=new Timer(0);
//				_rangeCheckTimer.addEventListener(TimerEvent.TIMER,rangeCheckTimer);
//			}
//			
//			_rangeCheckTimer.reset();
//			_rangeCheckTimer.start();
//		}
//		protected function rangeCheckTimer(evt:TimerEvent=null):void
//		{
//			if(!_isLoad)
//			{//如果停止加载，并且数据不够
//				_isLoad=true;
//				initDescLoader();
//			}
//		}
//		protected function streamSeekHandler(evt:EventExtensions):void
//		{
//			this.httpLoadGarbageCollector();
//			this._isLoad=false;
//			_loadStat="seek";
//			tmpTime = 0;
//			startRangeCheckTimer();
//		}
//		protected function streamPlayHandler(evt:EventExtensions):void
//		{
//			_isLoad=false;
//			_initData=evt.data as InitData;
//			_firstLoadBeginTime=getTime(); 
//			_loadStat="play";
//			tmpTime = 0;
//			startRangeCheckTimer();
//		}
//		
//		
//		protected function httpload():void
//		{
//			if(!_httpLoad)
//			{
//				_httpLoad=new HttpLoad();
//				_httpLoad.addEventListener(Event.COMPLETE,completeHandler);
//				_httpLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
//				_httpLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
//			}
//		}
		//
//		private var tmpTime:Number = 0;
//		protected function initDescLoader():void
//		{			
//			tmpTime = getDescTask();
//	
//			httpload();
//			//findLoadData();
//			if(LIVE_TIME.GetLiveTime()-60 <= tmpTime)
//			{
//				_rangeCheckTimer.delay = DESC_RANGECHECK_INTERVAL;
//				_rangeCheckTimer.reset();
//				_rangeCheckTimer.start();
//			}else
//			{
//				_rangeCheckTimer.delay = 200;
//				_rangeCheckTimer.reset();
//				_rangeCheckTimer.start();
//			}
//			P2PDebug.traceMsg(this,"load>"+abTimeShiftURL+this.getMiniMinute(tmpTime));
//			_httpLoad.loadData(abTimeShiftURL+this.getMiniMinute(tmpTime)+"&rdm="+getTime(),DESC_FETCH_TIMEOUT);
//			_httpLoad.id={"tmpTime":this.getMiniMinute(tmpTime),"livePos": LIVE_TIME.GetLiveTime()}
//						
//		}
		private function getDescTask():Number
		{
			return _dispather.getDescTask();
		}
		//
		/**获得一分钟最小的时间请求*/
		private function getMiniMinute(id:Number):Number
		{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
			return Math.floor(date.time/1000);
		}
		
//		private function reset():void
//		{
//		}
		
		private var _xml:XML;
		private var reg:RegExp=/\/(\d+)_(\d+)_(\d+)/;
		private var i:int=0;
		private var _clipList:Vector.<Clip>;
		private var _clip:Clip
		private var _head:String="";
		private var dugString:String="";
		//private var _tempTimestamp:Number=0;
		/**加载视频信息起始时间*/
		//protected var minClipTime:Number=int.MAX_VALUE;
//		protected function dataHandler(evt:EventExtensions):void
//		{
//			
//			_isLoad=false;
//			/**过程上报第一次加载获得XML*/
//			Statistic.getInstance().loadXMLSuccess(getTime()-_firstLoadBeginTime,this.tmpTime);
//			if(String(evt.data).indexOf("time too large")>-1)
//			{
//				_isLoad=false;
//				P2PDebug.traceMsg(this,"请求服务器返回切换直播信息");
//				return;
//			}
//			
//			try
//			{
//				_xml=new XML(evt.data);
//			}catch(err:Error){
//				errorHandler();
//				P2PDebug.traceMsg(this,"解析xml错误"+abTimeShiftURL+this.tmpTime);
//				return;
//			}
//			
////			Debug.traceMsg(this,"desc_xml:"+_xml);
//			_clipList=new Vector.<Clip>;
//			_head="";
//			var minClipTime:Number    = Number.MAX_VALUE;//int.MIN_VALUE//int.MAX_VALUE;
//			var _tempTimestamp:Number = 0;
//			var duration:Number = 0;
//			for(i=0;i<_xml.children().length();i++){
//				if((/.header/).test(_xml.children()[i].@name)){
//					//对头处理
//					_head=_xml.children()[i].@name.toString().replace(".header","");
//				}else{
//					//对clip处理
//					if(reg.test(_xml.children()[i].@name)){
//						if(_xml.children()[i].@name.match(reg).length==4)
//						{
//							//Number(_xml.children()[i].@name.match(reg)[1])
//							/**desc文件处理*/
//							_clip=new Clip;
//							if(_head==""){break;}
//							
//							_clip.head=Number(_head);
//							_clip.checkSum=_xml.children()[i].@checksum;
//							_clip.sequence=Number(_xml.children()[i].@sequence);
//							_clip.duration=Number(_xml.children()[i].@name.match(reg)[2]);
//							_clip.size=Number(_xml.children()[i].@name.match(reg)[3]);
//							_tempTimestamp = _clip.timestamp=Number(_xml.children()[i].@name.match(reg)[1]);
//							_clip.name=_xml.children()[i].@name;
//							_clipList.push(_clip);
//							dugString+="\n"+_clip.head+"~_~"+_clip.timestamp+"~_~"+_clip.duration+"~_~"+_clip.size+"~_~"+_clip.checkSum+"~_~"+_clip.sequence;
//							
//						}
//					}
//				}
//			}
//			
//			P2PDebug.traceMsg(this,"descData:"+dugString);
//			dugString="";
//			if(_clipList.length>=1)
//			{
//				if(_clip)
//				{
//					Statistic.getInstance().descLastTime(TimeTranslater.getTime(_clip.timestamp));
//				}
//				_dispather.writeClipList(_clipList);
//			}
//			_isLoad=false;
////			Debug.traceMsg(this,"赋值后:minClipTime="+minClipTime+":min="+min+":max="+max+":maxClipTime="+maxClipTime+":LIVESHIFT="+LOAD_TYPE.LIVESHIFT);
//		}
		
//		/**缓存范围*/
//		public function bufferRang():Number
//		{
//			return (LIVE_TIME.GetBaseTime()+LiveVodConfig.DESC_TIME);
//		}
//		protected function completeHandler(evt:Event):void
//		{
//			this._isLoad = false;
//		}
//		private function httpLoadGarbageCollector():void
//		{
//			this._isLoad = false;
//			if(_httpLoad)
//			{
//				_httpLoad.close();
//				_httpLoad.removeEventListener(Event.COMPLETE,completeHandler);
//				_httpLoad.removeEventListener(ErrorEvent.ERROR,errorHandler);
//				_httpLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
//				_httpLoad=null;
//			}
//		}
		
//		private function errorHandler(evt:ErrorEvent=null):void
//		{
//			this._isLoad = false;
//			/**事件垃圾回收*/
//			httpLoadGarbageCollector();
//			loadURLIndex++;
//			if(loadURLIndex>=_initData.flvURL.length)
//			{
//				loadURLIndex=0;
//			}
//		}
//		
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			if(_initData)
			{
				return getShiftPath(_initData.flvURL[0]);
			}
			//
			return "";
		}
			
		protected function getShiftPath(url:String):String
		{
			url=url.replace("desc.xml","")+"&abtimeshift=";
			return url;
		}
	}
}