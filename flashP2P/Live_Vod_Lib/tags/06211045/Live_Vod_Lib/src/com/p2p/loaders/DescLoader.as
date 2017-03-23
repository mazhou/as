package com.p2p.loaders
{
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
		/**在直播情况,在分钟改变时,请求一下时移,以确定完整性*/
		protected var _repaireLoad:HttpLoad;
		/**直播当前加载的分钟*/
		protected var liveCurretTime:Number=0;
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
		/**起止时间*/
		protected var _startTime:Number=0;
		
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
		protected var _seekPlayTime:Number=0;
		/**记录加载的分钟有问题*/
		protected var _badMin:Object=new Object;
		/**加载完成*/
		protected var _completeTime:Number=0;
		/**解析错误，在完成时做判断用*/
		protected var _parseError:int=0;
		/**某种情况，夹在没有返回结果，重新加载处理*/
		protected var _noLoadCount:int=0;
		
//		protected var _test_isLoad:Boolean=true;
		
		public function DescLoader(_dispather:IDataManager)
		{
//			ExternalInterface.addCallback("stopDesc",stopDesc);
//			ExternalInterface.addCallback("startDesc",startDesc);
			this._dispather=_dispather;
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.HEAD,streamHeadHandler);
			startRangeCheckTimer();
		}
//		public function stopDesc():void
//		{
//			_test_isLoad=false;
//		}
//		public function startDesc():void
//		{
//			_test_isLoad=true;
//		}
		protected function startRangeCheckTimer():void{
			if(!_rangeCheckTimer){
				_rangeCheckTimer=new Timer(DESC_RANGECHECK_INTERVAL);
				_rangeCheckTimer.addEventListener(TimerEvent.TIMER,rangeCheckTimer);
			}
			if(!_rangeCheckTimer.running){
				_rangeCheckTimer.reset();
				_rangeCheckTimer.start();
				rangeCheckTimer();
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
				liveDESCLaod();
			}
		}
		protected function stopLiveLoadTimer():void{
			if(_liveLoadTimer){
				_liveLoadTimer.stop();
			}
		}
		protected function rangeCheckTimer(evt:TimerEvent=null):void{
			if(_loadType==LOAD_TYPE.LIVESHIFT||_loadType==LOAD_TYPE.LIVE_CHANGE_SHIFT){
				liveCurretTime=0;
				if(!_isLoad){//如果停止加载，并且数据不够
					_noLoadCount=0;
					if(!isEnoughData(_playHead)){//如果小于规定范围
						initDescLoader();
					}
				}else{
					_noLoadCount++;
					if(_noLoadCount>=1){//时间设置是3秒大于一次，时间设置1秒最好大于5秒
						httpLoadGarbageCollector();
						_noLoadCount=0;
						_isLoad=false;
					}
				}
			}else if(_loadType==LOAD_TYPE.LIVE){
				resetClipTime();
				stopRangeCheckTimer();
				startLiveLoadTimer();
			}
		}
		
		protected function liveDESCLaod(evt:TimerEvent=null):void{
			if(_loadType==LOAD_TYPE.LIVE){
				initDescLoader();
			}else if(_loadType==LOAD_TYPE.LIVESHIFT||_loadType==LOAD_TYPE.LIVE_CHANGE_SHIFT){
				startRangeCheckTimer();
				stopLiveLoadTimer();
			}
		}
		private var _tempLastHead:Number=0;
		protected function streamHeadHandler(evt:EventExtensions):void{
			_playHead=Number(evt.data);
			if(_tempLastHead!=_playHead)
			{
				_tempLastHead = _playHead
				P2PDebug.traceMsg(this,"desc响应Head事件",_playHead);
				for(var id:* in _badMin){
					if(Number(id)<=_playHead){
						P2PDebug.traceMsg(this,"bad",Number(id));
						_badMin[id]=null;
						delete _badMin[id];
					}
					P2PDebug.traceMsg(this,"bad",Number(id),_badMin[id]);
				}
			}
		}

		protected function streamSeekHandler(evt:EventExtensions):void{
			reset();
			_seekPlayTime=_playHead=Number(evt.data);
			P2PDebug.traceMsg(this,"desc响应seek事件 _playHead："+_playHead);
			_loadStat="seek";
			startRangeCheckTimer();
		}
		protected function streamPlayHandler(evt:EventExtensions):void{
			_initData=evt.data as InitData;
			reset();
			_seekPlayTime=_playHead=_initData.startTime;
			P2PDebug.traceMsg(this,"desc响应play事件"+_playHead);
			_firstLoadBeginTime=getTime(); 
			_loadStat="play";
			startRangeCheckTimer();
		}
		protected function repaireLoadGarbageCollector():void{
			if(_repaireLoad){
				_repaireLoad.close();
				_repaireLoad.removeEventListener(Event.COMPLETE,repaireCompleteHandler);
				_repaireLoad.removeEventListener(ErrorEvent.ERROR,repaireErrorHandler);
				_repaireLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,repaireDataHandler);
				_repaireLoad=null;
			}
		}
		protected function repaireload(_repaireTime:Number):void{
//			var _repaireTime:Number=getMaxMinute(id);
			if(!_repaireLoad){
				_repaireLoad=new HttpLoad();
				_repaireLoad.addEventListener(Event.COMPLETE,repaireCompleteHandler);
				_repaireLoad.addEventListener(ErrorEvent.ERROR,repaireErrorHandler);
				_repaireLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,repaireDataHandler);
			}
			P2PDebug.traceMsg(this,"desc_url_ab2:"+(abTimeShiftURL+_repaireTime));
			_repaireLoad.loadData(abTimeShiftURL+_repaireTime,DESC_FETCH_TIMEOUT);
//			_repaireLoad.id=_repaireTime;
		}
		
		private function repaireErrorHandler(evt:ErrorEvent=null):void
		{
			repaireLoadGarbageCollector();
		}
		private function repaireDataHandler(evt:EventExtensions):void{
			if(String(evt.data).indexOf("time too large")>-1){
				repaireLoadGarbageCollector();
				return;
			}
			//如果是切换过程，要变更为直播状态
			try{
				_xml=new XML(evt.data);
			}catch(err:Error){
				repaireLoadGarbageCollector();
				return;
			}
			_clipList=new Vector.<Clip>;
			_head="";
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
						}
					}
				}
			}
			
			P2PDebug.traceMsg(this,"descData:"+dugString);
			dugString="";
			if(_clipList.length>=1){
				_dispather.writeClipList(_clipList,LOAD_TYPE.LIVESHIFT);
			}
		}
		protected function repaireCompleteHandler(evt:Event):void
		{
		}
		protected function httpload():void{
			if(!_httpLoad){
				_httpLoad=new HttpLoad();
				_httpLoad.addEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
			}
		}
		protected function initDescLoader():void{
//			if(!_test_isLoad){P2PDebug.traceMsg(this,"测试停止加载");return;}
			_isLoad=true;
			//却少先判断后加载的环节
			httpload();
			if(_loadType==LOAD_TYPE.LIVE_CHANGE_SHIFT){
				P2PDebug.traceMsg(this,"desc_url_ab:"+(abTimeShiftURL+_startTime));
				_httpLoad.loadData(abTimeShiftURL+this.getMiniMinute(_startTime),DESC_FETCH_TIMEOUT);
			}else if(_loadType==LOAD_TYPE.LIVESHIFT){
				//原来超过直播点会有重复数据，现在改为返回xml->error
				P2PDebug.traceMsg(this,"isEnoughData:"+(_playHead));
				if(!isEnoughData(_playHead)){
					P2PDebug.traceMsg(this,"desc_url_ab:"+(abTimeShiftURL+_startTime));
					_httpLoad.loadData(abTimeShiftURL+_startTime,DESC_FETCH_TIMEOUT);
				}
			}else if(_loadType==LOAD_TYPE.LIVE){
				P2PDebug.traceMsg(this,"desc_url:"+_initData.flvURL[loadURLIndex]);
				_httpLoad.loadData(_initData.flvURL[loadURLIndex]+"&rdm="+getTime(),DESC_FETCH_TIMEOUT);
			}
		}
		/**获得一分钟最小的时间请求*/
		private function getMiniMinute(id:Number):Number{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
			//P2PDebug.traceMsg(this,"date.time1:"+date.time,Math.floor(date.time/1000));
			
			return Math.floor(date.time/1000);
		}
		/**获得一分钟最大的时间请求*/
		private function getMaxMinute(id:Number):Number{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),59,999);
			//P2PDebug.traceMsg(this,"date.time2:"+date.time,Math.floor(date.time/1000));
			return Math.floor(date.time/1000);
		}
		/**是否跳过desc*/
		private function isJumpErrorDesc(id:Number):Boolean{
			if(_badMin[id]&&(_badMin[id] as BadDesc).count>LiveVodConfig.DESC_RPEAT_LOAD_COUNT*_initData.flvURL.length){
				return true;
			}
			return false;
		}
		private function isEnoughData(id:Number):Boolean{
			if(id==0){return true}//如果id为0不做加载
			//取分钟的中间时间请求
			var _sTime:Number=getMaxMinute(id);
			//当本分钟加载过，或在已经加载范围内
			while(_dispather.hasMin(_sTime)||//本分钟加载过
				isJumpErrorDesc(_sTime)||//避免第一次加载不连贯重复加载||
				_completeTime==_sTime//成功加载过的desc将跳过
			){
				_sTime+=60;//一分钟
				resetClipTime();//如果跳过一分钟，分配任务时，要重置变量
				if(_sTime>=bufferRang()){
					_startTime=_sTime;
					P2PDebug.traceMsg(this,"不用加载desc"+_startTime);
					return true;
				}
			}
			
			_startTime=_sTime;
			P2PDebug.traceMsg(this,"加载desc"+_startTime);
			return false;
		}
		private function resetClipTime():void
		{
			minClipTime=int.MAX_VALUE;
			maxClipTime=0;
			_loadStat="";
			
		}
		private function reset():void{
			_loadType=LOAD_TYPE.LIVESHIFT;
			_badMin=new Object;
			_completeTime=0;
			errorHandler();
			resetClipTime();
			stopRangeCheckTimer();
			stopLiveLoadTimer();
			_isLoad=false;
			liveCurretTime=0;
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
				_loadType=LOAD_TYPE.LIVE_CHANGE_SHIFT
				P2PDebug.traceMsg(this,"请求服务器返回切换直播信息");
				initDescLoader();
				return;
			}
			//如果是切换过程，要变更为直播状态
			if(_loadType==LOAD_TYPE.LIVE_CHANGE_SHIFT){
				P2PDebug.traceMsg(this,"真正切换直播信息");
				_loadType=LOAD_TYPE.LIVE;
			}
			try{
				_xml=new XML(evt.data);
			}catch(err:Error){
				//上报解析错误
				_parseError=1;
				P2PDebug.traceMsg(this,"解析xml错误"+abTimeShiftURL+_startTime);
//				ExternalInterface.call("trace","解析xml错误"+abTimeShiftURL+_startTime);
//				descFaileAllEnd();
				countErrorDescLoad(_startTime);
				return;
			}
//			Debug.traceMsg(this,"desc_xml:"+_xml);
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
//									Debug.traceMsg(this,"preid2:"+max);
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
			
			P2PDebug.traceMsg(this,"descData:"+dugString);
			dugString="";
			if(_clipList.length>=1){
				_dispather.writeClipList(_clipList,_loadType);
			}
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
			
			if(_loadType==LOAD_TYPE.LIVE){
				if(liveCurretTime==0){
					liveCurretTime=maxClipTime;
				}else if(getMaxMinute(liveCurretTime)!=getMaxMinute(maxClipTime)){
					repaireload(liveCurretTime);
					liveCurretTime=maxClipTime;
				}
			}
//			Debug.traceMsg(this,"赋值后:minClipTime="+minClipTime+":min="+min+":max="+max+":maxClipTime="+maxClipTime+":LIVESHIFT="+LOAD_TYPE.LIVESHIFT);
		}
		
		/**缓存范围*/
		public function bufferRang():Number{
			return (_playHead+LiveVodConfig.DESC_TIME);
		}
		protected function completeHandler(evt:Event):void
		{
			if(_parseError==0){
				_completeTime=_startTime;
			}else{
				_completeTime=0;
				_parseError=0;
			}
			if(_loadStat!=""){
				/**在解析xml,_seek时间小于clip最小时间戳异常*/
				if(_seekPlayTime<minClipTime&&minClipTime!=int.MAX_VALUE){
					P2PDebug.traceMsg(this,"play or seek dispatch mindata:"+minClipTime);
					EventWithData.getInstance().doAction(DESC_PROTOCOL.REPAIR_TIME,minClipTime);
				}
				_loadStat="";
			}
			_isLoad=false;
		}
		private function countErrorDescLoad(_badTime:Number):void{
			if(_badMin[_badTime]){
				(_badMin[_badTime] as BadDesc).count++;
			}else{
				_badMin[_badTime]=new BadDesc();
				_badMin[_badTime].count++;
			}
		}
		private function httpLoadGarbageCollector():void{
			if(_httpLoad){
				_httpLoad.close();
				_httpLoad.removeEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.removeEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
				_httpLoad=null;
			}
		}
		private function errorHandler(evt:ErrorEvent=null):void
		{
			_firstLoadBeginTime=getTime();
//			/**上报处理*/
//			if(evt&&evt.text==HTTPLOAD_PROTOCOL.TIME_UP){
//			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.IO_ERROR){
//			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.SECURITY_ERROR){
//			}
			/**事件垃圾回收*/
			httpLoadGarbageCollector();
			/**重试或跳过机制(即跳过本分钟加载 下一分钟)加载下分钟机制*/
			if(evt){
				P2PDebug.traceMsg(this,evt.text+" "+abTimeShiftURL+_startTime);
//				ExternalInterface.call("trace",evt.text+" "+abTimeShiftURL+_startTime);
				loadURLIndex++;
				if(loadURLIndex>=_initData.flvURL.length){
					loadURLIndex=0;
				}
//				//如果连续两分钟都失败，不再累加坏数据加载的次数
//				descFaileAllEnd();
				//统计desc坏数据加载的次数
				countErrorDescLoad(_startTime);
			}
			if(_loadType==LOAD_TYPE.LIVE_CHANGE_SHIFT){
				P2PDebug.traceMsg(this,"真正切换直播信息");
				_loadType=LOAD_TYPE.LIVE;
			}
			_isLoad=false;
		}
		
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			//直播地址http://123.125.89.61/leflv/jiangsu/desc.xml?tag=live&stream_id=jiangsu,
			//时移地址http://119.188.39.139/leflv/jiangsu_szq/?tag=live&path=115.182.51.113& abtimeshift=1351578576
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
//			var reg:RegExp=/\/\/(\d+.\d+.\d+.\d+)\//;
//			if(reg.test(url)){
//				url=url.replace(url.match(reg)[1],"119.167.223.131");
//				url=url.replace(url.match(reg)[1],"127.0.0.1");
//			}
			return url;
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}