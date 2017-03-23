/*****************************************************
 *  
 *  Copyright 2013 letv_p2p Systems Incorporated.  All Rights Reserved.
 *  
 *****************************************************
 * 
 *  
 *****************************************************/
package com.p2p.stream
{
	import com.p2p.data.Block;
	import com.p2p.data.Head;
	import com.p2p.data.LIVE_TIME;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.PlayData;
	import com.p2p.dataManager.DisPatcherFactory;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.DESC_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.stream.ClientObject;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
//	import flash.external.ExternalInterface;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * <ul>构造函数：创建通道，数据时间驱动创建，metadata处理，流状态监听NET_STATUS，创建调度器</ul>
	 * <ul>play:初始化数据处理_initData，公布事件NETSTREAM_PROTOCOL.PLAY，启动数据时间驱动</ul>
	 * <ul>seek:公布事件NETSTREAM_PROTOCOL.SEEK,seek状态记录</ul>
	 * <ul>_timer_TIMER:_playData类型的读取</ul>
	 * <ul>_this_NET_STATUS:监听状态处理</ul>
	 * <ul>bytesLoaded; bytesTotal</ul>
	 * <ul>resume; pause; close</ul>
	 * @author mazhoun
	 * 
	 */
	public class P2PNetStream  extends NetStream
	{
		public var isDebug:Boolean=true;
		/**声明通道*/
		protected var _connection:NetConnection;
		/**定时器，驱动加载数据，*/
		protected var _timer:Timer;
		/**监听优先级*/
		protected var _priority:uint = 1;
		
		/**seek中*/
		protected var _isSeeking:Boolean=false;
		/**seek完毕*/
		protected var _seekOK:Boolean = false;
		
		/**声明调度器*/
		protected var _dispather:IDataManager;
		
		/**是否缓存为空*/
		protected var _isBufferEmpty:Boolean=false;
		/**是否暂停*/
		protected var _isPause:Boolean=false;
		
		/**获得头等待数据流播放完毕，设置resetbegin后为true*/
		protected var _isChangeHeadWait:Boolean=false;
		
		/** 临时存放缓存头*/
		protected var _tempHead:ByteArray=null;
		
		/**校验缓存数据临时存储数据*/
		protected var _tmpBufferLength:Number = 0;
		protected var _tmpBufferLengthCount:uint = 0;
		/**播放器play时传的参数*/
		protected var _initData:InitData=new InitData();
		/**是否是最后一块数据*/
		protected var _lastData:Boolean=false;
		/**
		 * <p>直播按照head-0，KeyFrame-1,loop->frame-2;
		 * 点播head-0，KeyFrame-1,loop->frame-2,frame-3顺序执行;</p>
		 * <p>addStreamStep标识以上顺序</p>
		 */
		protected var _addStreamStep:int=0;
		
//		/**播放器播放用到的时间*/
		protected var _startTime:Number=0;
		/**记录上一次播放头,用来决定是否切换头 */
		protected var _lastHead:Number=0;
		/**当前播放的块*/
		protected var block:Block;
//		/**直播点时间*/
//		protected var liveTime:Number=0;
		/**起始的时间*/
		protected var _countHeadTime:Number=0;
		/**添加的块统计，限定统计上限为20块*/
		private var _addDataCount:int=0;
		private var _tmpPublishHeadTime:Number=0;
		
//		private var testChangeHead:Boolean=false;
		public function P2PNetStream(obj:Object=null)
		{
			if(obj==null){
				obj=new Object;
				obj.playType=LiveVodConfig.LIVE
			}
			LiveVodConfig.TYPE=obj.playType
			P2PDebug.isDebug=true;
			P2PDebug.traceMsg(this,"P2PNetStream"+LiveVodConfig.VERSION);
			EventWithData.getInstance().addEventListener(DESC_PROTOCOL.REPAIR_TIME,repairTime);
			/**统记添加监听事件*/
			Statistic.getInstance().addEventListener();
			Statistic.getInstance().setNetStream(this);
			/**创建通道*/
			_connection = new NetConnection
			_connection.connect(null);
			super(_connection);
			/**设置缓冲时间是3秒*/
			this.bufferTime = 3;
			/**获取数据时间驱动创建*/
			_timer = new Timer(200);
			_timer.addEventListener(TimerEvent.TIMER,_timer_TIMER);
			/**metadata处理*/
			super.client = new ClientObject();
			super.client.metaDataCallBackFun = onMetaData;
			this.addEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS,false,_priority);
			
			/**创建调度器*/
			_dispather=DisPatcherFactory.createDisPatcher(LiveVodConfig.TYPE);
			
//			ExternalInterface.addCallback("changeHead",changeHead);//切换头测试
		}
//		private function changeHead(bool:Boolean):void{//切换头测试
//			testChangeHead=bool;
//		}
		public function set callBack(obj:Object):void
		{
			Statistic.getInstance().nativeCallBackObj[obj.key] = obj;
		}
		public function set outMsg(fun:Function):void
		{
			Statistic.getInstance().outMsg = fun;	
		}
		protected function resetTime():void{
			if(_timer){
				_timer.stop();
			}
		}
		protected function reset():void{
			/**标识从头开始*/
			_addStreamStep=0;
			_lastHead=0;
			_tmpPublishHeadTime=0;
		}
		override public function play(...arguments):void
		{
			close();
			super.play(null);
			for(var arg:String in arguments[0]){
				P2PDebug.traceMsg(this,"初始化参数"+arg+"=>"+arguments[0][arg]);
				_initData[arg]=arguments[0][arg];
//				if(arg=="serverCurtime"){//测试有问题对应的时间块的时间
//					_initData[arg]=1370223602;
//				}
				if(arg=="livesftime"){//对接伪直播时间
					LiveVodConfig.TIME_OFF=-Number(arguments[0][arg]);
				}
			}
			reset();
			/**开始加载的位置*/
			_startTime=_initData.startTime;
			/**设置直播时间*/
			LIVE_TIME.SetLiveTime(_initData.serverCurtime);
			P2PDebug.traceMsg(this,"发送 play事件_startTime"+_startTime+":"+TimeTranslater.getTime(_startTime));
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.PLAY,_initData);
			_timer.start();
		}
		/**seek*/
		override public function seek(offset:Number):void
		{
			reseek(offset);
		}
		public function reseek(offset:Number):void{
			P2PDebug.traceMsg(this," SEEK时间是"+offset+"->"+TimeTranslater.getTime(offset)+"伪直播点时间"+LIVE_TIME.GetLiveOffTime()+"->"+TimeTranslater.getTime(LIVE_TIME.GetLiveOffTime()));
			if(offset>LIVE_TIME.GetLiveOffTime()){
				offset=LIVE_TIME.GetLiveOffTime();
			}
			P2PDebug.traceMsg(this," SEEK时间是"+offset+"->"+TimeTranslater.getTime(offset)+"伪直播点时间"+LIVE_TIME.GetLiveOffTime()+"->"+TimeTranslater.getTime(LIVE_TIME.GetLiveOffTime()));
			reset();
			/**开始加载的位置*/
			_startTime=offset;
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.SEEK,offset);
			_isSeeking       = true;
			_seekOK          = false;
			super.seek(0);
		}
		/**续播*/
		override public function resume():void
		{
			_isPause = false;
			super.resume();
		}
		/**暂停*/
		override public function pause():void
		{
			_isPause = true;
			super.pause();
		}
		/**关闭*/
		override public function close():void
		{
			super.close();
			resetTime();
		}
		protected function repairTime(evt:EventExtensions):void{
			_startTime=Number(evt.data);
			//伪直播的时间如果比本分钟的最小时间块还小，设置成最小块的时间（即最小块的时间大于伪直播的时间）
			if(_startTime>LIVE_TIME.GetLiveOffTime()){
				LIVE_TIME.OffLiveTime(_startTime-LIVE_TIME.GetLiveOffTime());
			}
			P2PDebug.traceMsg(this,"repairTime"+_startTime);
			publishHead(_startTime);
		}
		
		protected function publishHead(time:Number):void{
			if(_tmpPublishHeadTime!=time&&time>0){
				_tmpPublishHeadTime=time;
				P2PDebug.traceMsg(this,"publishHead"+time);
				EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.HEAD,time);
			}
		}
		
		/**
		 * 头文件处理
		 * @param isChange 是 立即切换头还是等待播放完流 切换头
		 */
		protected function headHandler():void{
			/**获得blockid*/
			if(_dispather.getBlockId(_startTime)!=-1){
				_startTime=_dispather.getBlockId(_startTime);
				block=_dispather.getBlock(_startTime);
				P2PDebug.traceMsg(this,"headHandler",block.id);
				publishHead(block.id);
			}else{
				return;
			}
			var head:Head
			if(_lastHead==0){//当play或seek时按照_startTime切换头
				head=_dispather.getHead(block.id);
			}else{//当自然播放切换头按照_lastHead切换头
				head=_dispather.getHead(_startTime);
			}
			P2PDebug.traceMsg(this,"添加头成功1:"+_lastHead+" block.id:"+_startTime);
			if(head && head.getHeadStream()){
				this["appendBytesAction"]("resetBegin");
				this["appendBytes"](head.getHeadStream());
				_lastHead=head.id;
				_addStreamStep=PlayData.KEY_FRAME;
				_addDataCount=0;
				P2PDebug.traceMsg(this,"添加头成功2"+_lastHead+" block.id:"+_startTime);
			}
		}
		
		/**关键帧处理*/
		protected function keyFrameHandler():void{
			if(!block){
				P2PDebug.traceMsg(this,"出现重大，不能播放");
				return;
			}
			//确保任何时刻不超过直播点之前的n分钟（目前3分钟）
			if(block.id>LIVE_TIME.GetLiveOffTime()){
				P2PDebug.traceMsg(this,"超过伪直播点2",block.id,LIVE_TIME.GetLiveOffTime());
				return;
			}
			P2PDebug.traceMsg(this,"播放的id"+block.id);
			if(block.isChecked){
				this["appendBytesAction"]("resetSeek");
				this["appendBytes"](block.getBlockStream());
				_addStreamStep=PlayData.FRAME;
				P2PDebug.traceMsg(this,"添加关键帧成功1"+block.id);
				_countHeadTime=block.id;//对外提供时间计时
				publishHead(block.id);
				_timer_TIMER();
			}else if(block.isDestroy){
				var temBlock:Block=_dispather.getNextNearBlock(block.id,true);
				if(temBlock){
					if(temBlock.id>LiveVodConfig.DAT_LoadBlockID){return;}
					this["appendBytesAction"]("resetSeek");
					this["appendBytes"](block.getBlockStream());
					_addStreamStep=PlayData.FRAME;
					P2PDebug.traceMsg(this,"添加关键帧成功2"+block.id);
					_countHeadTime=temBlock.id;					
					block=temBlock;
					publishHead(block.id);
					_timer_TIMER();
				}
			}
			
			//是否最后
			//if(_playData.type==PlayData.END_FRAME){
			//_timer.stop();
			//_lastData=true;
			//}
		}
		
		/**非关键帧处理*/
		protected function frameHandler():void{
			if(block.id>LIVE_TIME.GetLiveOffTime()){
				P2PDebug.traceMsg(this,"超过伪直播点1",_startTime,LIVE_TIME.GetLiveOffTime());
				return;
			}
			var tempblock:Block;
			if(!block){
				return;
			}
			
			if(block.nextID!=0){
				tempblock=_dispather.getBlock(block.nextID);
			}else if(block.nextID==0){
//				ExternalInterface.call("trace",block.id+"下边没有数据nextID为0跳过");
				tempblock=_dispather.getNextNearBlock(block.id,true);
			}
			
			if(!tempblock){return;}
			publishHead(tempblock.id);
			if(tempblock.id>LiveVodConfig.DAT_LoadBlockID){return;}//超过加载进度，将不再进行播放
			//确保任何时刻不超过直播点之前的n分钟（目前3分钟）
			if(tempblock.id>LIVE_TIME.GetLiveOffTime()){
				P2PDebug.traceMsg(this,"超过伪直播点");
				return;
			}
			//如果播放的时间和实际的时间相差2分钟，并且播放的块数多于10块（防止seek不断切换头），要重新切头计算时间
			if((Math.abs(tempblock.id-time)>120&&_addDataCount>=10)/*||testChangeHead*/){/*testChangeHead=false;*///测试代码
				_isChangeHeadWait=true;
				_addStreamStep=PlayData.HEAD;
				_lastHead=tempblock.head;
				_startTime=tempblock.id;
				P2PDebug.traceMsg(this,"change head"+_lastHead+" startTime"+_startTime);
			}
			
			if(_lastHead!=tempblock.head){
//				ExternalInterface.call("trace",_lastHead+" 切换头："+tempblock.head+" "+tempblock.id);
				P2PDebug.traceMsg(this,_lastHead+" 切换头："+tempblock.head+" "+tempblock.id);
				_isChangeHeadWait=true;
				_addStreamStep=PlayData.HEAD;
				_lastHead=tempblock.head;
				_startTime=tempblock.id;
				return;
			}
			
			if(tempblock.isDestroy){
				P2PDebug.traceMsg(this,"block"+tempblock.id+"销毁");
//				ExternalInterface.call("trace","block"+tempblock.id+"销毁，加载下一个block");
				block=tempblock;
				return;
			}
			
			if(tempblock.isChecked){
				P2PDebug.traceMsg(this,"添加帧成功"+tempblock.id);
				this["appendBytes"](tempblock.getBlockStream());
				block=tempblock;
				_addDataCount++;
				if(_addDataCount>20){
					_addDataCount=20;
				}
				publishHead(block.nextID);
			}
		}
	
		protected function _timer_TIMER(evt:TimerEvent=null):void{
			/**seek时处理*/
			if (_isSeeking){
				//读头，读关键帧流
				switch(_addStreamStep){
					case PlayData.HEAD://切换metadata
						headHandler();
						return;
						break;
					case PlayData.KEY_FRAME://stream&seek状态
						keyFrameHandler();
						_isSeeking = false;
						_seekOK = false;
						return;
						break;
				}
			}
			/**获取播放数据,如果缓冲小于3+1秒获取数据，如果evt是null即获得metadata调用情况，获取数据，如果在切换头且bufferLength小于0.1秒也获取数据*/
			if (this.bufferLength < this.bufferTime + 1){
				_tmpBufferLength = 0;
				_tmpBufferLengthCount = 0;
				switch(_addStreamStep){
					case PlayData.HEAD://切换metadata
						if(isReadResetBegin()){
							headHandler();
						}
						break;
					case PlayData.KEY_FRAME://stream&seek状态
						keyFrameHandler();
						break;
					case PlayData.FRAME://stream&seek状态
						frameHandler();
						break;
				}
			}
			Statistic.getInstance().bufferTime(this.bufferTime,this.bufferLength);
		}

		protected function isReadResetBegin():Boolean{
			return _isBufferEmpty||this.bufferLength<0.1;
		}
		public function onMetaData(obj:Object = null):void
		{
			try{
				LiveVodConfig.DATARATE=obj["datarate"];
				P2PDebug.traceMsg(this,"DATARATE:"+LiveVodConfig.DATARATE);
			}catch(err:Error){
				P2PDebug.traceMsg(this,err.getStackTrace());
			}
			_timer_TIMER();
		}
		override public function get bytesLoaded():uint
		{
			return _dispather.bytesLoaded();
		}
		override public function get bytesTotal():uint
		{
			return _dispather.bytesTotal();
		}
		protected function _this_NET_STATUS(event:NetStatusEvent):void
		{
			var code:String = event.info.code;
			switch (code)
			{
				case "NetStream.Buffer.Empty" :
					_isBufferEmpty=true;
					if(_isChangeHeadWait){
						this.headHandler();
						_isChangeHeadWait=false;
					}
					
					if ( _lastData)
					{
						dispatchStatusEvent({"code":"Stream.Play.Stop"});
					}
					else
					{
						dispatchStatusEvent({"code":"Stream.Buffer.Empty"});	
					} 
					break;
				case "NetStream.Buffer.Full" :
					_isBufferEmpty=false
					dispatchStatusEvent({"code":"Stream.Buffer.Full"});
					break;
				case "NetStream.Pause.Notify" :
					dispatchStatusEvent({"code":"Stream.Pause.Notify"});
					break;
				case "NetStream.Unpause.Notify" :
					dispatchStatusEvent({"code":"Stream.Unpause.Notify"});
					break;
				case "NetStream.Seek.Notify" :					
				case "NetStream.Seek.Failed":
				case "NetStream.Seek.InvalidTime":
					_seekOK = true;
					dispatchStatusEvent({"code":"Stream.Seek.Complete"});
					break;					
			}
		}

		protected function dispatchStatusEvent(info:Object):void
		{
			dispatchEvent(new  EventExtensions(NETSTREAM_PROTOCOL.STREAM_STATUS,info));
		}
		
		public function getStatisticData():Object
		{
			return Statistic.getInstance().getStatisticData();
		}
		/**
		 * 指定对其调用回调方法以处理流或 F4V/FLV 文件数据的对象。
		 * */
		override public function get client():Object
		{
			return super.client.client;
		}
		override public function set client(value:Object):void
		{
			super.client.client = value;
		}
		override public function get time():Number{
			return super.time+_countHeadTime;
		}
	}
}