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
	import com.p2p.data.vo.Config;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.PlayData;
	import com.p2p.dataManager.DisPatcherFactory;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.DESC_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.Debug;
	import com.p2p.statistics.Statistic;
	import com.p2p.stream.ClientObject;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
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
		
		private var _tmpPublishHeadTime:Number=0;
		public function P2PNetStream(obj:Object=null)
		{
			if(obj==null){
				obj=new Object;
				obj.playType=Config.LIVE
			}
			Config.TYPE=obj.playType
			Debug.isDebug=true;
			Debug.traceMsg(this,"P2PNetStream"+Config.VERSION);
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
			_dispather=DisPatcherFactory.createDisPatcher(Config.TYPE);
		}
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
			destroyStartWait="";
			waitDestroyBlock=0;
			_tmpPublishHeadTime=0;
		}
		override public function play(...arguments):void
		{
			close();
			super.play(null);
			for(var arg:String in arguments[0]){
				Debug.traceMsg(this,"初始化参数"+arg+"=>"+arguments[0][arg]);
				_initData[arg]=arguments[0][arg];
			}
			reset();
			/**开始加载的位置*/
			_startTime=_initData.startTime;
			/**设置直播时间*/
			LIVE_TIME.SetLiveTime(_initData.realStartTime);
			Debug.traceMsg(this,"发送 play事件_startTime"+_startTime+":"+TimeTranslater.getTime(_startTime));
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.PLAY,_initData);
			_timer.start();
		}
		/**seek*/
		override public function seek(offset:Number):void
		{
			Debug.traceMsg(this," SEEK时间是"+offset+"->"+TimeTranslater.getTime(_startTime)+"伪直播点时间"+LIVE_TIME.GetLiveOffTime()+"->"+TimeTranslater.getTime(LIVE_TIME.GetLiveOffTime()));
			if(offset>LIVE_TIME.GetLiveOffTime()){
				offset=LIVE_TIME.GetLiveOffTime();
			}
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
		}
		
		protected function publishHead(time:Number):void{
			if(_tmpPublishHeadTime!=time&&time>0){
				_tmpPublishHeadTime=time;
				EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.HEAD,time);
			}
		}
		
		private var destroyStartWait:String="";
		private var waitDestroyBlock:Number=0;
		/**有坏数据进入等待，如果返回true，表示时间到期*/
		protected function entryWait(waitTime:Number):Boolean{
			if(destroyStartWait==""){
				destroyStartWait="wait";
				//策略是遇到损坏的数据，设置到计时，播放器处于等待
				waitDestroyBlock=waitTime;
				ExternalInterface.call("trace","遇到损坏的数据，设置到计时，播放器处于等待状态");
				return false;
			}else if(destroyStartWait=="end"){
				destroyStartWait="";
				return true;
			}
			return false;
		}
		
		/**校验是否有坏数据在等待*/
		protected function checkWait():Boolean{
			if(waitDestroyBlock>0&&destroyStartWait=="wait"){
				waitDestroyBlock=waitDestroyBlock-_timer.delay;
				return true;
			}else if(destroyStartWait=="wait"){
				destroyStartWait="end";
			}
			return false;
		}
		private var _tempNoStreamBlockID:Number=0;
		private var _tempCountNoStream:int=20;
		protected function jumpFrameHandler(block:Block,count:int=20):void{
			
			if(_tempNoStreamBlockID!=block.id){
				_tempNoStreamBlockID=block.id;
				_tempCountNoStream=count;
			}
			
			if(_tempCountNoStream--<=1){
				_tempCountNoStream=-1;
				var nearBlock2:Block=_dispather.getNextNearBlock(block.id);
				if(nearBlock2&&nearBlock2.isChecked){
					block=nearBlock2;
					_tempCountNoStream=count;
					Debug.traceMsg(this,"block没有流跳过,播放"+block.id);
					ExternalInterface.call("trace","block没有流跳过,播放"+block.id);
					Statistic.getInstance().DatSkip(String(block.id));
					
					publishHead(block.id);
				}
			}
		}
		
		/**
		 * 头文件处理
		 * @param isChange 是 立即切换头还是等待播放完流 切换头
		 */
		protected function headHandler():void{
			/**获得blockid*/
			//_lastHead
			if(_startTime>LIVE_TIME.GetLiveOffTime()){
				_startTime=LIVE_TIME.GetLiveOffTime();
			}
			
			if(_dispather.getBlockId(_startTime)!=-1){
				_startTime=_dispather.getBlockId(_startTime);
				publishHead(_startTime);
			}else{
				return;
			}
			var head:Head
			if(_lastHead==0){//当play或seek时按照_startTime切换头
				head=_dispather.getHead(_startTime);
			}else{//当自然播放切换头按照_lastHead切换头
				head=_dispather.getHead(_lastHead);
			}
			if(head && head.getHeadStream()){
				this["appendBytesAction"]("resetBegin");
				this["appendBytes"](head.getHeadStream());
				_lastHead=head.id;
				_addStreamStep=PlayData.KEY_FRAME;
				Debug.traceMsg(this,"添加头成功"+_lastHead+" block.id:"+_startTime);
			}
		}
		/**关键帧处理*/
		protected function keyFrameHandler():void{
			if(_startTime>LIVE_TIME.GetLiveOffTime()){
				_startTime=LIVE_TIME.GetLiveOffTime();
			}
			
			if(_dispather.getBlockId(_startTime)!=-1){
				_startTime=_dispather.getBlockId(_startTime);
				publishHead(_startTime);
			}else{
				return;
			}
			
			block=_dispather.getBlock(_startTime);
			
			if(!block){return;}
			//确保任何时刻不超过直播点之前的n分钟（目前3分钟）
			if(block.id>LIVE_TIME.GetLiveOffTime()){
				return;
			}
			if(block.isChecked){
				this["appendBytesAction"]("resetSeek");
				this["appendBytes"](block.getBlockStream());
				_addStreamStep=PlayData.FRAME;
				Debug.traceMsg(this,"添加关键帧成功"+block.id);
				dispatchStatusEvent({
					"code":"Stream.Play.Start",
					"startTime":""+_startTime
				});
				_timer_TIMER();
			}else{
				//纠错连续4秒没有数据，如果有下一块，就跳过本块播放
				jumpFrameHandler(block);
			}
			
			
			//是否最后
			//if(_playData.type==PlayData.END_FRAME){
			//_timer.stop();
			//_lastData=true;
			//}
		}
		
		/**非关键帧处理*/
		protected function frameHandler():void{
			//对损坏的数据等待倒计时
			if(checkWait()){return;}
			
			var tempblock:Block;
			if(!block){
				return;
			}
			if(block.nextID!=0){
				tempblock=_dispather.getBlock(block.nextID);
			}else{
				publishHead(block.id);
				Debug.traceMsg(this,block.id+"下边没有数据nextID为0");
				ExternalInterface.call("trace",block.id+"下边没有数据nextID为0,2即将跳过");
				jumpFrameHandler(block,10);
				return;
			}
			if(!tempblock){return;}
			
			if(_lastHead!=tempblock.head){
				ExternalInterface.call("trace",_lastHead+" 切换头："+tempblock.head);
				Debug.traceMsg(this,_lastHead+" 切换头："+tempblock.head);
				_isChangeHeadWait=true;
				_addStreamStep=PlayData.HEAD;
				_startTime=_lastHead=tempblock.head;
				return;
			}
			
			if(tempblock.isDestroy){
				if(entryWait(tempblock.duration-_timer.delay)){
					Debug.traceMsg(this,"block"+tempblock.id+"销毁，加载下一个block"+tempblock.nextID);
					ExternalInterface.call("trace","block"+tempblock.id+"销毁，加载下一个block"+tempblock.nextID);
					tempblock=block=_dispather.getBlock(tempblock.nextID);
					if(!block){
						jumpFrameHandler(block,0);
						return;
					}
				}
//				Debug.traceMsg(this,"下一个block"+tempblock.id);
			}
			//确保任何时刻不超过直播点之前的n分钟（目前3分钟）
			if(tempblock.id>LIVE_TIME.GetLiveOffTime()){
				Debug.traceMsg(this,"超过伪直播点");
				return;
			}
			publishHead(tempblock.id);
			if(tempblock.isChecked){
				Debug.traceMsg(this,"添加帧成功"+tempblock.id);
				this["appendBytes"](tempblock.getBlockStream());
				block=tempblock;
				publishHead(block.nextID);
			}else{
				//纠错连续4秒没有数据，如果有下一块，就跳过本块播放
				jumpFrameHandler(block);				
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
		}

		protected function isReadResetBegin():Boolean{
			return _isBufferEmpty||this.bufferLength<0.1;
		}
		public function onMetaData(obj:Object = null):void
		{
			try{
				Config.DATARATE=obj["datarate"];
				Debug.traceMsg(this,"DATARATE:"+Config.DATARATE);
			}catch(err:Error){
				Debug.traceMsg(this,err.getStackTrace());
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
//						this.appendBytes(_tempHead);
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
	}
}