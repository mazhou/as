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
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
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
	public class DescLoopLoader implements IChecksumLoad
	{
		public var isDebug:Boolean=true;
		
		 /**播放器传递的参数*/
		protected var _initData:InitData;
		/**http基类加载，基于urlstream*/
		protected var _httpLoad:HttpLoad;
//		/**直播当前加载的分钟,当默认的值为0时,表示从一个周期开始加载*/
//		protected var liveCurretTime:Number=0;
//		/**当前加载的类型*/
		protected var _loadType:String=LOAD_TYPE.LIVESHIFT;
		
		/**直播时加载器*/
		protected var _liveLoadTimer:Timer=null;
		/**直播间隔*/
		protected const DESC_FETCH_INTERVAL:uint = 3000; 
		/**请求超时*/
		protected const DESC_FETCH_TIMEOUT:uint = 3000;
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint=0;
		
		/**声明数据管理器*/
		protected var _dispather:IDataManager;
		/**是否是直播检测*/
		protected var _isCheckLive:Boolean=false;
		/**起止时间,当默认的值为0时,表示从一个周期开始加载*/
	//	protected var _startTime:Number=0;
		/**播放头*/
		protected var _playHead:Number=0;
		/**范围定时检测*/
		protected var _rangeCheckTimer:Timer=null;
		/**加载范围定时检测间隔*/
		protected const DESC_RANGECHECK_INTERVAL:uint = 3000;
		/**是否加载*/
		protected var _isLoad:Boolean=false; 
		/**第一次加载起始时间，统计用*/
		protected var _firstLoadBeginTime:Number=0;
		/**标识是否是play或seek加载*/
		protected var _loadStat:String="";
		/**用来纠错在一分钟内开始的时间小于最小的clip*/
		//protected var _seekPlayTime:Number=0;
		
		/**某种情况，夹在没有返回结果，重新加载处理*/
		protected var _noLoadCount:int=0;
		
		//protected var _lastLoadConnext:LoadRecod;
		
		protected var _test_isLoad:Boolean=true;
		
		public function DescLoopLoader(_dispather:IDataManager)
		{
			ExternalInterface.addCallback("stopDesc",stopDesc);
			ExternalInterface.addCallback("startDesc",startDesc);
			this._dispather=_dispather;
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
		}
		public function stopDesc():void
		{
			_test_isLoad=false;
		}
		public function startDesc():void
		{
			_test_isLoad=true;
		}
		protected function startRangeCheckTimer():void
		{
			_isLoad = false;
			httpLoadGarbageCollector();
			if(!_rangeCheckTimer)
			{
				_rangeCheckTimer=new Timer(0);
				_rangeCheckTimer.addEventListener(TimerEvent.TIMER,rangeCheckTimer);
			}
			//if(!_rangeCheckTimer.running)
			{
				_rangeCheckTimer.reset();
				//_rangeCheckTimer.delay = DESC_RANGECHECK_INTERVAL;
				_rangeCheckTimer.start();
				//rangeCheckTimer();
			}
		}
		/*protected function stopRangeCheckTimer():void
		{
			if(_rangeCheckTimer)
			{
				_rangeCheckTimer.stop();				
			}
		}*/

		protected function rangeCheckTimer(evt:TimerEvent=null):void
		{
			if(!_isLoad)
			{//如果停止加载，并且数据不够
				//_noLoadCount=0;
				_isLoad=true;
				initDescLoader();
			}
		}
		protected function streamSeekHandler(evt:EventExtensions):void
		{
			//_seekPlayTime=Number(evt.data)
			//reset();
			//_loadStat="seek";
			startRangeCheckTimer();
		}
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			/*_initData=evt.data as InitData;
			_firstLoadBeginTime=getTime(); 
			//_seekPlayTime=Number(_initData.startTime);
			reset();
			_loadStat="play";*/
			_initData=evt.data as InitData;
			startRangeCheckTimer();
		}
		protected function httpload():void
		{
			if(!_httpLoad)
			{
				_httpLoad=new HttpLoad();
				_httpLoad.addEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
			}
		}
		private var tmpTime:Number = 0;
		private var livePos:Number = 0;
		protected function initDescLoader():void
		{
			tmpTime = this.getMiniMinute(LIVE_TIME.GetBaseTime());
			httpload();
			findLoadData();
			_httpLoad.loadData(abTimeShiftURL+this.getMiniMinute(tmpTime)+"&rdm="+getTime(),DESC_FETCH_TIMEOUT);
//			_httpLoad.id=this.getMiniMinute(tmpTime);
			_httpLoad.id={"tmpTime":this.getMiniMinute(tmpTime),"livePos": LIVE_TIME.GetLiveTime()}
			livePos = LIVE_TIME.GetLiveTime();
		}
		private function findLoadData():void
		{
			while(1)
			{
				if (LIVE_TIME.GetLiveTime() <= tmpTime)
				{
//					_rangeCheckTimer.delay = DESC_RANGECHECK_INTERVAL;
//					_rangeCheckTimer.reset();
//					_rangeCheckTimer.start();
					tmpTime = LIVE_TIME.GetLiveTime();
					if(LIVE_TIME.GetLiveTime()-60 <= tmpTime)
					{
						_rangeCheckTimer.delay = DESC_RANGECHECK_INTERVAL;
						_rangeCheckTimer.reset();
						_rangeCheckTimer.start();
					}else
					{
						_rangeCheckTimer.delay = 200;
						_rangeCheckTimer.reset();
						_rangeCheckTimer.start();
					}
					break;
				}
				//
				if (_dispather.hasMin(tmpTime))
				{
//					_rangeCheckTimer.delay = 200;
//					_rangeCheckTimer.reset();
//					_rangeCheckTimer.start();
					tmpTime += 60;
				}else
				{
					if(LIVE_TIME.GetLiveTime()-60 <= tmpTime)
					{
						_rangeCheckTimer.delay = DESC_RANGECHECK_INTERVAL;
						_rangeCheckTimer.reset();
						_rangeCheckTimer.start();
					}else
					{
						_rangeCheckTimer.delay = 200;
						_rangeCheckTimer.reset();
						_rangeCheckTimer.start();
					}
					break;
				}
			}
		}
		/**获得一分钟最小的时间请求*/
		private function getMiniMinute(id:Number):Number
		{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
			//P2PDebug.traceMsg(this,"date.time1:"+date.time,Math.floor(date.time/1000));
			return Math.floor(date.time/1000);
		}
//		/**获得一分钟最大的时间请求*/
//		private function getMaxMinute(id:Number):Number{
//			var date:Date  = new Date(id*1000);
//			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),59,999);
//			//P2PDebug.traceMsg(this,"date.time2:"+date.time,Math.floor(date.time/1000));
//			return Math.floor(date.time/1000);
//		}
		
		/*private function resetClipTime():void
		{
			_loadStat="";
		}*/
		private function reset():void
		{
			//_loadType=LOAD_TYPE.LIVESHIFT;
			//_startTime=0;
			//	_lastLoadConnext=null;
			//errorHandler();
			//resetClipTime();
			//stopRangeCheckTimer();
		}
		
		private var _xml:XML;
		private var reg:RegExp=/\/(\d+)_(\d+)_(\d+)/;
		private var i:int=0;
		private var _clipList:Vector.<Clip>;
		private var _clip:Clip
		private var _head:String="";
		private var dugString:String="";
		private var _tempTimestamp:Number=0;
		/**加载视频信息起始时间*/
		protected var minClipTime:Number=int.MAX_VALUE;
		protected function dataHandler(evt:EventExtensions):void
		{
			_isLoad=false;
			/**过程上报第一次加载获得XML*/
			Statistic.getInstance().loadXMLSuccess(getTime()-_firstLoadBeginTime,this.tmpTime);
			if(String(evt.data).indexOf("time too large")>-1)
			{
				//resetClipTime();
				//_startTime=0;
				//_lastLoadConnext=null;
				_isLoad=false;
				P2PDebug.traceMsg(this,"请求服务器返回切换直播信息");
				return;
			}
			
			try
			{
				_xml=new XML(evt.data);
			}catch(err:Error){
				errorHandler();
				P2PDebug.traceMsg(this,"解析xml错误"+abTimeShiftURL+this.tmpTime);
//				ExternalInterface.call("trace","解析xml错误"+abTimeShiftURL+_startTime);
				return;
			}
			
			
//			Debug.traceMsg(this,"desc_xml:"+_xml);
			_clipList=new Vector.<Clip>;
			_head="";
			minClipTime= int.MIN_VALUE//int.MAX_VALUE;
			for(i=0;i<_xml.children().length();i++){
				if((/.header/).test(_xml.children()[i].@name)){
					//对头处理
					_head=_xml.children()[i].@name.toString().replace(".header","");
				}else{
					//对clip处理
					if(reg.test(_xml.children()[i].@name)){
						if(_xml.children()[i].@name.match(reg).length==4){
							_tempTimestamp=Number(_xml.children()[i].@name.match(reg)[1])
							/**desc文件处理*/
							_clip=new Clip;
							if(_head==""){break;}
							
							_clip.head=Number(_head);
							_clip.checkSum=_xml.children()[i].@checksum;
							_clip.duration=Number(_xml.children()[i].@name.match(reg)[2]);
							_clip.size=Number(_xml.children()[i].@name.match(reg)[3]);
							_clip.timestamp=Number(_xml.children()[i].@name.match(reg)[1]);
							_clip.name=_xml.children()[i].@name;
							_clipList.push(_clip);
							dugString+="\n"+_clip.head+"~_~"+_clip.timestamp+"~_~"+_clip.duration+"~_~"+_clip.size+"~_~"+_clip.checkSum;
							
							/**记录加载的最大和最小时间戳*/
							if( minClipTime==int.MIN_VALUE)
							{
								if(_tempTimestamp>minClipTime)
								{
									minClipTime=_tempTimestamp;
								}
							}else
							{
								if(_tempTimestamp>minClipTime)
								{
									minClipTime =_tempTimestamp;
								}
							}
						}
					}
				}
			}
			
			P2PDebug.traceMsg(this,"descData:"+dugString);
			dugString="";
			if(_clipList.length>=1)
			{
				_dispather.writeClipList(_clipList);
			}
			//loadConnextHandler(this.tmpTime,true);
			//
//			var tempHttpLoad:HttpLoad=(evt.currentTarget as HttpLoad);
//			tempHttpLoad.id.tmpTime
//			tempHttpLoad.id.livePos
				
			if (this.getMiniMinute(this.tmpTime) < this.getMiniMinute(livePos))
			{
				_dispather.setLastClipFull(this.tmpTime);
			}
			//this._startTime+=60;
			_isLoad=false;
//			Debug.traceMsg(this,"赋值后:minClipTime="+minClipTime+":min="+min+":max="+max+":maxClipTime="+maxClipTime+":LIVESHIFT="+LOAD_TYPE.LIVESHIFT);
		}
		
		/**缓存范围*/
		public function bufferRang():Number
		{
			return (LIVE_TIME.GetBaseTime()+LiveVodConfig.DESC_TIME);
		}
		protected function completeHandler(evt:Event):void
		{
			this._isLoad = false;
			//tmpTime += 60;
			/**在解析xml,_seek时间小于clip最小时间戳异常*/
			/*if(_loadStat!="")
			{
				if(LIVE_TIME.GetBaseTime()<minClipTime&&minClipTime!=int.MAX_VALUE){
					P2PDebug.traceMsg(this,"play or seek dispatch mindata:"+minClipTime);
					EventWithData.getInstance().doAction(DESC_PROTOCOL.REPAIR_TIME,minClipTime);
				}
				_loadStat="";
			}*/
		}
		private function httpLoadGarbageCollector():void
		{
			if(_httpLoad)
			{
				_httpLoad.close();
				_httpLoad.removeEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.removeEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
				_httpLoad=null;
			}
		}
		
		/*private function loadConnextHandler(_loadTime:Number,isSuccess:Boolean):void{
			if(!_lastLoadConnext)
			{
				_lastLoadConnext=new LoadRecod();
				_lastLoadConnext.time=_loadTime;
				_lastLoadConnext.isSuccess=isSuccess;
				return;
			}
			
			if(_loadTime==_lastLoadConnext.time)
			{
				if(isSuccess)
				{
					return;
				}else
				{
					_lastLoadConnext.loadCount++;
				}
			}else if(_loadTime!=_lastLoadConnext.time)
			{
				if(isSuccess&&_lastLoadConnext.isSuccess)
				{
					_dispather.setLastClipFull(_lastLoadConnext.time);
				}
				_lastLoadConnext.time=_loadTime;
				_lastLoadConnext.isSuccess=isSuccess;
			}
		}*/
		
		private function errorHandler(evt:ErrorEvent=null):void
		{
			this._isLoad = false;
			//_firstLoadBeginTime=getTime();
			/**事件垃圾回收*/
			httpLoadGarbageCollector();
			loadURLIndex++;
			if(loadURLIndex>=_initData.flvURL.length)
			{
				loadURLIndex=0;
			}
			/*loadConnextHandler(this.tmpTime,false);
			if(_lastLoadConnext.loadCount>=_initData.flvURL.length)
			{
				//this._startTime+=60;
			}*/
		}
		
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			if(_initData && _initData.flvURL && _initData.flvURL[loadURLIndex]){
				return getShiftPath(_initData.flvURL[loadURLIndex]);
			}else{
				loadURLIndex=0;
				return "";
			}
		}
			
		protected function getShiftPath(url:String):String
		{
			url=url.replace("desc.xml","")+"&abtimeshift=";
			return url;
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}
/*class LoadRecod
{
	public var time:Number;
	public var isSuccess:Boolean=false;
	public var loadCount:int=0;
}*/