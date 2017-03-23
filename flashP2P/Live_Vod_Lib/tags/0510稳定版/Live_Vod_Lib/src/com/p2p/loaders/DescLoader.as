package com.p2p.loaders
{
	import com.p2p.data.vo.BadDesc;
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.Config;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LOAD_TYPE;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.DESC_PROTOCOL;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.Debug;
	import com.p2p.statistics.Statistic;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
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
	public class DescLoader implements IChecksumLoad
	{
		public var isDebug:Boolean=true;
		 /**播放器传递的参数*/
		protected var _initData:InitData;
		/**http基类加载，基于urlstream*/
		protected var _httpLoad:HttpLoad;
		/**当前加载的类型*/
		protected var _loadType:String=LOAD_TYPE.LIVESHIFT;
		
		/**直播时加载器*/
		protected var _liveLoadTimer:Timer=null;
		/**直播间隔*/
		protected const DESC_FETCH_INTERVAL:uint = 3000; 
		/**请求超时*/
		protected const DESC_FETCH_TIMEOUT:uint = 3000;
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint=0;
		
		/**加载视频信息起始时间*/
		protected var minClipTime:Number=int.MAX_VALUE;
		/**加载视频信息的结束时*/
		protected var maxClipTime:Number=0;
		
		/**声明数据管理器*/
		protected var _dispather:IDataManager;
		/**是否是直播检测*/
		protected var _isCheckLive:Boolean=false;
		
		protected var _startTime:Number=0;
		/**desc是否缓存饱和*/
		public var  isEnough:Boolean=false;
		/**播放头*/
		protected var _playHead:Number=0;
		
		/**范围定时检测*/
		protected var _rangeCheckTimer:Timer=null;
		/**加载范围定时检测间隔*/
		protected const DESC_RANGECHECK_INTERVAL:uint = 3000;
		/**是否加载*/
		protected var _isLoad:Boolean=false; 
		/**第一次加载起始时间*/
		protected var _firstLoadBeginTime:Number=0;
		/**标识是否是play或seek加载*/
		protected var _loadStat:String="";
		protected var _seekPlayTime:Number=0;
		/**记录加载的分钟有问题*/
		protected var _badMin:Object=new Object;
		public function DescLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.HEAD,streamHeadHandler);
			startRangeCheckTimer();
		}
		protected function startRangeCheckTimer():void{
			if(!_rangeCheckTimer){
				_rangeCheckTimer=new Timer(DESC_RANGECHECK_INTERVAL);
				_rangeCheckTimer.addEventListener(TimerEvent.TIMER,rangeCheckTimer);				
			}
			if(!_rangeCheckTimer.running){
				_rangeCheckTimer.reset();
				_rangeCheckTimer.start();
			}
		}
		protected function stopRangeCheckTimer():void{
			if(_rangeCheckTimer){
				_rangeCheckTimer.stop();				
			}
		}
		protected function startLiveLoadTimer():void{
			if(!_liveLoadTimer){
				_liveLoadTimer=new Timer(DESC_FETCH_INTERVAL);
				_liveLoadTimer.addEventListener(TimerEvent.TIMER,liveDESCLaod)
			}
			if(!_liveLoadTimer.running){
				_liveLoadTimer.reset();
				_liveLoadTimer.start();
			}
		}
		protected function stopLiveLoadTimer():void{
			if(_liveLoadTimer){
				_liveLoadTimer.stop();
				
			}
		}
		protected function rangeCheckTimer(evt:TimerEvent=null):void{
			if(_loadType==LOAD_TYPE.LIVESHIFT){
				if(!_isLoad){//如果停止加载，并且数据不够
					if(!isEnoughData(_playHead)){//如果小于规定范围
						Debug.traceMsg(this,"时移定时加载");
						initDescLoader();
					}
				}
			}
		}
		
		protected function liveDESCLaod(evt:TimerEvent=null):void{
			Debug.traceMsg(this,"直播点定时加载");
			initDescLoader();
		}
		private var _tempLastHead:Number=0;
		protected function streamHeadHandler(evt:EventExtensions):void{
//			
			_playHead=Number(evt.data);
			if(_tempLastHead!=_playHead){
				Debug.traceMsg(this,"desc响应Head事件",_playHead);
				for(var id:* in _badMin){
					if(Number(id)<=_playHead){
						_badMin[id]=null;
						delete _badMin[id]; 
					}
				}
			}
		}
		protected function streamSeekHandler(evt:EventExtensions):void{
			reset();
			_seekPlayTime=_playHead=Number(evt.data);
			Debug.traceMsg(this,"desc响应seek事件 _playHead："+_playHead);
			_loadStat="seek";
			initDescLoader();
		}
		protected function streamPlayHandler(evt:EventExtensions):void{
			Debug.traceMsg(this,"desc响应play事件");
			_initData=evt.data as InitData;
			reset();
			_seekPlayTime=_playHead=_initData.startTime;
			_firstLoadBeginTime=getTime(); 
			_loadStat="play";
			initDescLoader();
		}
		protected function httpload():void{
			if(!_httpLoad){
				_httpLoad=new HttpLoad();
				//				//_httpLoad.isComplementCloseStream=true;
				_httpLoad.addEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
			}
		}
		protected function initDescLoader():void{
			_isLoad=true;
			//却少先判断后加载的环节
			httpload();
			if(_loadType==LOAD_TYPE.LIVESHIFT){
				//原来超过直播点会有重复数据，现在改为返回xml->error
				if(!isEnoughData(_playHead)){
					Debug.traceMsg(this,"desc_url_ab:"+(abTimeShiftURL+_startTime));
					_httpLoad.loadData(abTimeShiftURL+_startTime+"&rdm="+getTime(),DESC_FETCH_TIMEOUT);
				}
				startRangeCheckTimer(); 
				stopLiveLoadTimer();
			}else if(_loadType==LOAD_TYPE.LIVE){
				Debug.traceMsg(this,"desc_url:"+_initData.flvURL[loadURLIndex]);
				_httpLoad.loadData(_initData.flvURL[loadURLIndex]+"&rdm="+getTime(),DESC_FETCH_TIMEOUT);
				//启动直播时间驱动
				stopRangeCheckTimer();
				startLiveLoadTimer();
			}
		}
		/**获得中间的时间请求*/
		private function getMiddleMinute(id:Number):Number{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),30,0);
			return Math.floor(date.time/1000);
		}
		/**是否跳过desc*/
		private function isJumpErrorDesc(id:Number):Boolean{
			if(_badMin[id]&&(_badMin[id] as BadDesc).count>3){
				return true;
			}
			return false;
		}
		
		private function isEnoughData(id:Number):Boolean{
			if(id==0){return true}
			//取分钟的中间时间请求
			_startTime=getMiddleMinute(id);
			//当本分钟加载过，或在已经加载范围内
			while(_dispather.hasMin(_startTime)||
				(_startTime>minClipTime&&_startTime<maxClipTime)||
				isJumpErrorDesc(_startTime)//避免第一次加载不连贯重复加载
			){
				_startTime+=60;//一分钟
				resetClipTime();
				if(_startTime>=bufferRang()){
					return true;
				}
			}
			return false;
		}
		private function resetClipTime():void
		{
			minClipTime=int.MAX_VALUE;
			maxClipTime=0;
		}
		private function reset():void{
			_loadType=LOAD_TYPE.LIVESHIFT;
			errorHandler();
			resetClipTime();
			stopRangeCheckTimer();
			stopLiveLoadTimer()
			isEnough=false;
			_isLoad=false;
		}
		
		private var _xml:XML;
		private var reg:RegExp=/\/(\d+)_(\d+)_(\d+)/;
		private var i:int=0;
		private var _clipList:Vector.<Clip>;
		private var _clip:Clip
		private var _head:String="";
		private var dugString:String="";
		private var _tempTimestamp:Number=0;
		protected function dataHandler(evt:EventExtensions):void{
						
			/**过程上报第一次加载获得XML*/
			Statistic.getInstance().loadXMLSuccess(getTime()-_firstLoadBeginTime,_startTime);
			if(String(evt.data).indexOf("time too large")>-1){
				resetClipTime();
				_loadType=LOAD_TYPE.LIVE;
				Debug.traceMsg(this,"请求服务器返回切换直播信息");
				initDescLoader();
				return;
			}
			try{
				_xml=new XML(evt.data);
			}catch(err:Error){
				//上报解析错误
				return;
			}
//			对xml解析，如果error则换为直播加载
			
			Debug.traceMsg(this,"desc_xml:"+_xml);
//			_xml=<root>
//				<header name="1364221677.header"/>
//				<clip name="2013032612/1364272625_6600_593976.dat" duration="6600ms" checksum="3485068282"/>
//				<clip name="2013032612/1364272631_7920_702171.dat" duration="7920ms" checksum="2088142328"/>
//				<clip name="2013032612/1364272639_7560_702148.dat" duration="7560ms" checksum="364880931"/>
//			  </root>
			
			_clipList=new Vector.<Clip>;
			_head="";
			
			var min:Number=minClipTime;
			var max:Number=maxClipTime;
			var ishead:Boolean=true;//本次加载的数据是否是头一个
			
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
							if(_tempTimestamp>max){//去除重复加载的数据
								_clip=new Clip;
								if(_head==""){break;}
								if(ishead){
									ishead=false;
									_clip.preID=max;
									Debug.traceMsg(this,"preid2:"+max);
								}
								_clip.head=Number(_head);
								_clip.checkSum=_xml.children()[i].@checksum;
								_clip.duration=Number(_xml.children()[i].@name.match(reg)[2]);
								_clip.size=Number(_xml.children()[i].@name.match(reg)[3]);
								_clip.timestamp=Number(_xml.children()[i].@name.match(reg)[1]);
								_clip.name=_xml.children()[i].@name;
								_clipList.push(_clip);
								dugString+="\n"+_clip.head+"~_~"+_clip.timestamp+"~_~"+_clip.duration+"~_~"+_clip.size+"~_~"+_clip.checkSum;
							}
							/**记录加载的最大和最小时间戳*/
							if(maxClipTime==0 && minClipTime==int.MAX_VALUE){
								if(_tempTimestamp<minClipTime){
									min=minClipTime=_tempTimestamp;
								}
								if(_tempTimestamp>maxClipTime){
									max=maxClipTime=_tempTimestamp;
								}
							}else{
								if(_tempTimestamp<min){
									min=_tempTimestamp;
								}
								if(_tempTimestamp>max){
									max=_tempTimestamp;
								}
							}
						}
					}
				}
			}
			
			if(_clipList.length>=1){
				_dispather.writeClipList(_clipList,_loadType);
			}
			
			Debug.traceMsg(this,"descData:"+dugString);
			dugString="";
			/**记录最小最大时间戳*/
			if(min<minClipTime){
				minClipTime=min;
			}
			if(max>maxClipTime){
				maxClipTime=max;
			}
			if(maxClipTime-minClipTime>120){//在非seek情况下，如果最大和最小的超过120秒，即2分钟，前一分钟饱和
				_dispather.setLastClipFull(maxClipTime);
			}
			if(_loadType==LOAD_TYPE.LIVESHIFT){
				_isLoad=false;
			}
			isEnough=false;
			Debug.traceMsg(this,"赋值后:minClipTime="+minClipTime+":min="+min+":max="+max+":maxClipTime="+maxClipTime+":LIVESHIFT="+LOAD_TYPE.LIVESHIFT);
			//在时移加载的数据连续都是空，怎么处理？
		}
		
		/**缓存范围*/
		public function bufferRang():Number{
			return (_playHead+Config.DESC_TIME)
		}
		protected function completeHandler(evt:Event):void
		{
			if(_loadStat!=""){
				if(_seekPlayTime<minClipTime){
					EventWithData.getInstance().doAction(DESC_PROTOCOL.REPAIR_TIME,minClipTime);
				}
				_loadStat="";
			}			
			loadURLIndex=0;
		}
		
		private function errorHandler(evt:ErrorEvent=null):void
		{
			_firstLoadBeginTime=getTime();
			
			/**事件垃圾回收*/
			if(_httpLoad){
				_httpLoad.close();
				_httpLoad.removeEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.removeEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
				_httpLoad=null;
			}
			/**上报处理*/
			if(evt&&evt.text==HTTPLOAD_PROTOCOL.TIME_UP){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.IO_ERROR){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.SECURITY_ERROR){
				
			}
			/**重试或跳过机制(即跳过本分钟加载 下一分钟)加载下分钟机制*/
			if(evt){
				Debug.traceMsg(this,"error"+evt.text);
				loadURLIndex++;
				_startTime=getMiddleMinute(_startTime);
				
				if(_badMin[_startTime]){
					(_badMin[_startTime] as BadDesc).count++;
				}else{
					_badMin[_startTime]=new BadDesc();
					_badMin[_startTime].count++;
				}
				//需要做的工作-->增加变量，统计出错的次数，如果次数高于某个值，退出p2p
				_isLoad=false;
			}
		}
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			//http://123.125.89.61/leflv/jiangsu/desc.xml?tag=live&stream_id=jiangsu,
			//http://119.188.39.139/leflv/jiangsu_szq/?tag=live&path=115.182.51.113& abtimeshift=1351578576
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
			//TEST正式上线删掉test之间的代码
			var reg:RegExp=/\/\/(\d+.\d+.\d+.\d+)\//;
			if(reg.test(url)){
				url=url.replace(url.match(reg)[1],"119.167.223.131");
			}
			//TEST
			return url;
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}