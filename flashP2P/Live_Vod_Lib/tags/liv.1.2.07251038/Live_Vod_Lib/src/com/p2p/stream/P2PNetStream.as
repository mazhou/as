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
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.PlayData;
	import com.p2p.dataManager.DisPatcherFactory;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.stream.ClientObject;
	import com.p2p.utils.TimeTranslater;
	import com.p2p.utils.sha1Encrypt;
	
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
		protected var _isSeeking:Boolean=true;
		
		/**声明调度器*/
		protected var _dispather:IDataManager;
		
		/**是否缓存为空*/
		protected var _isBufferEmpty:Boolean=false;
		
		/**播放器play时传的参数*/
		protected var _initData:InitData=new InitData();
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
	
		public function P2PNetStream(obj:Object=null)
		{
			if(obj==null)
			{
				obj=new Object;
				obj.playType=LiveVodConfig.LIVE;
			}
			LiveVodConfig.TYPE=obj.playType
			P2PDebug.isDebug=true;
			P2PDebug.traceMsg(this,"P2PNetStream"+LiveVodConfig.VERSION);
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
		}
		override public function play(...arguments):void
		{
//			close();
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
			
			_initData.groupName = getSHA1Code(_initData.groupName+LiveVodConfig.P2P_AGREEMENT_VERSION);
			
			reset();
			/**开始加载的位置*/
			_startTime=_initData.startTime;
			/**0608 add 设置基准时间*/
			LIVE_TIME.SetBaseTime(_startTime);
			P2PDebug.traceMsg(this,"p_BaseTime"+_startTime);
			/**/
			/**设置直播时间*/
			LIVE_TIME.SetLiveTime(_initData.serverCurtime);
			P2PDebug.traceMsg(this,"发送 play事件_startTime"+_startTime+" "+TimeTranslater.getTime(_startTime));
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.PLAY,_initData);
			_timer.start();
		}
		/**seek*/
		override public function seek(offset:Number):void
		{
			reseek(offset);
		}
		public function reseek(offset:Number,seekBySelfType:String=""):void{
			
			if(offset>LIVE_TIME.GetLiveOffTime()){
				offset=LIVE_TIME.GetLiveOffTime();
			}
			P2PDebug.traceMsg(this," SEEK时间是"+offset+"->"+TimeTranslater.getTime(offset)+"伪直播点时间"+LIVE_TIME.GetLiveOffTime()+"->"+TimeTranslater.getTime(LIVE_TIME.GetLiveOffTime()),seekBySelfType);
			
			/**lz 0709 add*/
			if(seekBySelfType != "")
			{				
				Statistic.getInstance().forceSeek(seekBySelfType + " SEEK时间是"+offset+"->"+TimeTranslater.getTime(offset)+"伪直播点时间"+LIVE_TIME.GetLiveOffTime()+"->"+TimeTranslater.getTime(LIVE_TIME.GetLiveOffTime()));
			}
			
			if(LIVE_TIME.GetBaseTime() - offset > Math.abs(LiveVodConfig.TIME_OFF))
			{
				LiveVodConfig.ISLEAD = 0;
			}else
			{
				LiveVodConfig.ISLEAD = 1;
			}
			
			reset();
			/**开始加载的位置*/
			_startTime=offset;

			/**0608 add 设置基准时间*/
			LIVE_TIME.SetBaseTime(offset);
			P2PDebug.traceMsg(this,"s_BaseTime"+offset);
			/**/
			
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.SEEK,offset);
			_isSeeking       = true;

			super.seek(0);
		}
		/**续播*/
		override public function resume():void
		{
			if(!LIVE_TIME.isPause)
			{
				return;
			}
			LIVE_TIME.isPause = false;
			super.resume();
//			P2PDebug.traceMsg(this,"r_BaseTime"+LIVE_TIME.GetBaseTime());
			P2PDebug.traceMsg(this,"r1_BaseTime"+LIVE_TIME.GetBaseTime());
		}
		/**暂停*/
		override public function pause():void
		{
			if(LIVE_TIME.isPause)
			{
				return;
			}
			super.pause();
			LIVE_TIME.isPause=true;
		}
		/**关闭*/
		override public function close():void
		{
			super.close();
			resetTime();
			clear();
		}
		
		protected function clear():void{
			reset();
			if(this._timer && this._timer.hasEventListener(TimerEvent.TIMER))
			{
				this._timer.removeEventListener(TimerEvent.TIMER,_timer_TIMER);
			}
			
			if(this.hasEventListener(NetStatusEvent.NET_STATUS))
			{
				this.removeEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS);
			}
			
			Statistic.getInstance().removeEventListener();
			
			_dispather.clear();
			_initData=null;
			_dispather=null;
			this._timer=null;
			LiveVodConfig.CLEAR();
		}
		/**
		 * 头文件处理
		 * @param isChange 是 立即切换头还是等待播放完流 切换头
		 */
		protected function headHandler():void
		{
			var tmpBlock:Block = block;
			_startTime=LIVE_TIME.GetBaseTime();
			/**获得blockid*/
			if(_dispather.getBlockId(_startTime)!=-1)
			{
				_startTime=_dispather.getBlockId(_startTime);
				_dispather.setPlayingBlockID(_startTime);
				if (block && (_startTime == block.id))
				{
					P2PDebug.traceMsg(this,"headHandler1:",block.id,_startTime);
					return;
				}
				
				tmpBlock =_dispather.getBlock(_startTime);
				P2PDebug.traceMsg(this,"headHandler",tmpBlock.id);
			}
			else
			{
				P2PDebug.traceMsg(this,"headHandler2:");
				return;
			}
			//
			var head:Head =_dispather.getHead(tmpBlock.id);
			if(head && head.getHeadStream().bytesAvailable >0 && tmpBlock.isChecked)
			{
				block = tmpBlock;
				try
				{
					this["appendBytesAction"]("resetBegin");
					this["appendBytes"](head.getHeadStream());
					this["appendBytesAction"]("resetSeek");
					this["appendBytes"](tmpBlock.getBlockStream());
					
				}catch(err:Error)
				{
					P2PDebug.traceMsg(this,err);
				}
				//
				_isSeeking = false;
				_lastHead=head.id;
				_addStreamStep=PlayData.FRAME;
				Statistic.getInstance().setPlayHead(block.id+">"+TimeTranslater.getTime(block.id));
				P2PDebug.traceMsg(this,"添加头成功2"+_lastHead+" block.id:"+_startTime);
			}
		}
		
		/**非关键帧处理*/
		protected function frameHandler():void
		{
			var tempblock:Block = null;	
			if(block)
			{
				if ((LIVE_TIME.GetBaseTime() > block.id + block.duration/1000 + 6) /*&& isReadResetBegin()*/)
				{
					//this.seek(LIVE_TIME.GetBaseTime());
					reseek(LIVE_TIME.GetBaseTime(),"forceSeek !");
					return; 
				}
			}
			
			if (this.bufferLength > 30)
				return;
			
			if(this.bufferLength < 1)
			{
				var blkID:Number = _dispather.getBlockId(LIVE_TIME.GetBaseTime());
				tempblock = _dispather.getBlock(blkID);
			}else
			{
				if(block)
				{
					tempblock=_dispather.getNextSeqID(block.sequence);
				}
			}
			
			if(!tempblock)
			{
				return;
			}else
			{
				_dispather.setPlayingBlockID(tempblock.id);
			}

//			if(block)
//			{
//				_dispather.setPlayingBlockID(block.id);
//				//
//				var blkID:Number = _dispather.getBlockId(LIVE_TIME.GetBaseTime()+this.bufferLength);
//				tempblock = _dispather.getBlock(blkID);
//				if(!tempblock)
//				{
//					return;
//				}
//				
//			}else return;
			//
			if(_lastHead!=tempblock.head)
			{
				if (/*isReadResetBegin() && */LIVE_TIME.GetBaseTime() > (block.id + block.duration/1000))
				{
					//this.seek(LIVE_TIME.GetBaseTime());
					reseek(LIVE_TIME.GetBaseTime(),"changeHead !");
					return;
				}
				//
				return;
			}
			//
			if(tempblock && tempblock.isChecked && tempblock.sequence == block.sequence+1)
			{
				P2PDebug.traceMsg(this,"添加帧成功"+tempblock.id);
				try
				{
					block=tempblock;
					this["appendBytes"](tempblock.getBlockStream());
					Statistic.getInstance().setPlayHead(block.id+">"+TimeTranslater.getTime(block.id));
					
				}catch(err:Error)
				{
					P2PDebug.traceMsg(this,err);
				}
			}
		}
	
		protected function _timer_TIMER(evt:TimerEvent=null):void
		{
			/**seek时处理*/
			if (_isSeeking)
			{
				//读头，读关键帧流
				switch(_addStreamStep)
				{
					case PlayData.HEAD://切换metadata
						headHandler();
						return;
				}
			}
		    //
			switch(_addStreamStep)
			{
				case PlayData.FRAME://stream&seek状态
					frameHandler();
					break;
			}
			//
			Statistic.getInstance().bufferTime(this.bufferTime,this.bufferLength);
		}

		protected function isReadResetBegin():Boolean
		{
			return _isBufferEmpty||this.bufferLength<0.5;
		}
		public function onMetaData(obj:Object = null):void
		{
			try
			{
				if(!obj["datarate"])
				{
					LiveVodConfig.DATARATE=1300;
				}else if(int(obj["datarate"])<=200)
				{
					LiveVodConfig.DATARATE=1300;
				}else
				{
					LiveVodConfig.DATARATE=Number(obj["datarate"]);
				}
				P2PDebug.traceMsg(this,"DATARATE:"+LiveVodConfig.DATARATE);
			}catch(err:Error)
			{
				LiveVodConfig.DATARATE=800;
				P2PDebug.traceMsg(this,err.getStackTrace());
			}
			LiveVodConfig.SET_MEMORY_TIME();
			//trace(LiveVodConfig.MEMORY_TIME)
			_timer_TIMER();
		}
		protected function _this_NET_STATUS(event:NetStatusEvent):void
		{
			var code:String = event.info.code;
			switch (code)
			{
				case "NetStream.Buffer.Empty" :
					_isBufferEmpty=true;
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
		override public function get time():Number
		{
			return LIVE_TIME.GetBaseTime();
		}

		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		protected function getSHA1Code(str:String):String
		{							
			var enc:sha1Encrypt = new sha1Encrypt(true);
			var strSHA1:String = sha1Encrypt.encrypt(str);
			
			return strSHA1;
		}
	}
}