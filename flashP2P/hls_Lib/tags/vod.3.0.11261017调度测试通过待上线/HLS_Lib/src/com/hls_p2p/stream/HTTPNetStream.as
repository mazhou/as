package com.hls_p2p.stream
{
	import at.matthew.httpstreaming.*;
	
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.DataManagerFactory;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ArrayClone;
	import com.p2p.utils.ParseUrl;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.Timer;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	
	import net.httpstreaming.flv.FLVHeader;
	import net.httpstreaming.flv.FLVParser;
	import net.httpstreaming.flv.FLVTag;
	import net.httpstreaming.flv.FLVTagAudio;
	import net.httpstreaming.flv.FLVTagScriptDataMode;
	import net.httpstreaming.flv.FLVTagScriptDataObject;
	import net.httpstreaming.flv.FLVTagVideo;
	
	public class HTTPNetStream extends NetStream
	{
		public var isDebug:Boolean 					= true;
		protected var _mainTimer:Timer 				= null;
		public static const END_SEQUENCE:String 	= "endSequence";
		public static const RESET_BEGIN:String 		= "resetBegin";
		public static const RESET_SEEK:String 		= "resetSeek";
		
		
		/**播放器play时传的参数*/
		protected var _initData:InitData;
		protected var _seekOK:Boolean 				= true;
		protected var _seekDataOK:Boolean 			= true;
		
		protected var _currentBlock:Block			= null;
		protected var _currentPiece:Piece			= null;
		protected var lastBlock:Block 				= null;
		
		protected var lastPiece:Number 				= -1;
		protected var _need_CDN_Bytes:int 			= 0;
		protected var _seekTimeRecord:Number		= 0;
		/**声明通道*/
		protected var _connection:NetConnection;
		/**声明调度器*/
		protected var _dataManager:IDataManager 	= null;
		/**是否缓存为空*/
		protected var _isBufferEmpty:Boolean		= true;
		/**是否暂停*/
		protected var isPause:Boolean				= false;
		protected var _currentBytes:ByteArray 		= new ByteArray();
		protected var _fileHandler:HTTPStreamingMP2TSFileHandler = null;
		
		private var statisTimeCount:int				= 0;
		private var onLoopDelay:int 				= 25;
		private var _isLastData:Boolean				= false;
		
		/**是否显示seek后的图标，如果为true，只要没有获得数据就显示图标，如果为false，有没有数据都不会触发显示图标*/
		private var _isShowSeekIcon:Boolean 		= false;

		private var input:IDataInput;
		/**直播用，该值为直播点与play|seek的时间差，缓存时判断超过某一范围，向前进一个ts**/
		private var offLiveTime:Number				= -1;

		private var _isForcedSeek:Boolean = false;
		
		public function HTTPNetStream(p_obj:Object=null)
		{
			if( null == p_obj )
			{
				p_obj = new Object;
				//TTT
				p_obj.playType = LiveVodConfig.VOD;
				p_obj.playType = LiveVodConfig.LIVE;
			}
			LiveVodConfig.TYPE = p_obj.playType.toUpperCase();
			
			P2PDebug.isDebug = true;
			P2PDebug.traceMsg(this,"P2PNetStream"+LiveVodConfig.GET_VERSION());
			
			/**创建通道*/
			_connection = new NetConnection
			_connection.connect(null);
			super(_connection);
			
			/**metadata处理*/
			super.client = new ClientObject_HLS();
			super.client.metaDataCallBackFun = onMetaData;
		}
		
		private function init():void
		{
			this.bufferTime = 0;
			
			LiveVodConfig.BirthTime	= getTime();
			
			/**统记添加监听事件*/
			Statistic.getInstance().addEventListener();
			Statistic.getInstance().setNetStream(this);
			
			if( !this.hasEventListener(NetStatusEvent.NET_STATUS) )
			{
				this.addEventListener(NetStatusEvent.NET_STATUS, _this_NET_STATUS, false, 1);
			}
			
			/**创建调度器*/
			if( !_dataManager )
			{
				_dataManager = DataManagerFactory.createDispatcher(LiveVodConfig.TYPE);
			}
			
			if( !_mainTimer )
			{
				_mainTimer = new Timer(onLoopDelay);
				_mainTimer.addEventListener(TimerEvent.TIMER,onLoop);
			}
		}
		
		public function set need_CDN_Bytes(p_nbyte:int):void
		{
			_need_CDN_Bytes = p_nbyte;
		}
		
		public function getStatisticData():Object
		{
			return null;
			//return Statistic.getInstance().getStatisticData();
		}
		
		public function set_CDN_URL(arr:Array):void
		{
			if( arr.length>0
				&& _initData
				&& _initData.hasOwnProperty("flvURL") )
			{
				_initData["flvURL"] = ArrayClone.Clone(arr);
				_initData.setIndex(0);
				P2PDebug.traceMsg(this,"set_CDN_URL:"+arr);
				
				_initData.g_bGslbComplete = true;
				_initData.g_bVodLoaded = false;
				_initData.g_nM3U8Idx = 0;
			}
		}
		
		override public function get bytesLoaded():uint
		{			
			if( _initData && _initData.totalSize>0 && LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				var block:Block = _dataManager.getBlock(LiveVodConfig.NEAREST_WANT_ID);
								
				var lastTime:Number = 0;
				
				if( block && block.isChecked )
				{
					lastTime = block.id + block.duration;
				}
				else if( block )
				{
					lastTime = block.id;
				}
				
				if( time/_initData.totalDuration>=1 || lastTime/_initData.totalDuration>=1 )
				{
					return _initData.totalSize;
				}
				
				if( lastTime<=time )
				{
					return (time/_initData.totalDuration)*_initData.totalSize;
				}
				else
				{
					return (lastTime/_initData.totalDuration)*_initData.totalSize;
				}
			}
			
			return 0;
		}
		
		/**
		 * 正加载到应用程序中的文件的总大小（以字节为单位）。
		 * */
		override public function get bytesTotal():uint
		{
			if( _initData && _initData.totalSize>0 )
			{
				return _initData.totalSize;
			}
			
			return 0;
		}
		
		override public function resume():void
		{
			isPause = false;
			
			if( !LIVE_TIME.isPause )
			{
				return;
			}
								
			if( !_isBufferEmpty )
			{
				LIVE_TIME.isPause = false;
			}
			
			P2PDebug.traceMsg(this,"r1_BaseTime"+LIVE_TIME.GetBaseTime());
		
			/**lz 0524 add*/
			_initData.setAdRemainingTime(0);
			/**************/
			
			super.resume();
		}
		
		override public function pause():void
		{
			isPause = true;
			
			if( LIVE_TIME.isPause )
			{
				return;
			}
			
			super.pause();

			LIVE_TIME.isPause = true;
		}
		
		private function realSeek( offset:Number,isReset_M3U8_MAXTIME:Boolean=false ):void
		{			
			if( offset < 0 )
			{
				offset=0;
			}
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE 
				&& offset >= LIVE_TIME.GetLiveOffTime() )
			{
				offset = LIVE_TIME.GetLiveOffTime();
			}
			
			_seekTimeRecord   = offset;
			
			LIVE_TIME.isPause = true;
			
			if( true == isReset_M3U8_MAXTIME )
			{
				LiveVodConfig.M3U8_MAXTIME = offset;
			}
			
			if( this._initData.g_seekPos == 0 )
			{
				this._initData.g_seekPos = offset;
			}
			
			P2PDebug.traceMsg(this," LiveVodConfig.M3U8_MAXTIME:"+ LiveVodConfig.M3U8_MAXTIME);
			
			LIVE_TIME.SetBaseTime(offset);
			
			LiveVodConfig.ADD_DATA_TIME = offset;
			
			offLiveTime = LIVE_TIME.GetLiveTime() - offset;
			
			LiveVodConfig.NEAREST_WANT_ID = LiveVodConfig.ADD_DATA_TIME;
			
			P2PDebug.traceMsg(this,"seek:"+LiveVodConfig.ADD_DATA_TIME);
			
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.SEEK,offset);
			
			_isShowSeekIcon = true;
			
			Reset();
			
			super.seek(0);
			
			flvHeadHandler();
			
			this["appendBytesAction"](RESET_SEEK);
			
		}
		override public function seek(offset:Number):void
		{
			realSeek( offset, true );
		}
		
		private function Reset():void
		{
			_seekOK = false;
			_seekDataOK = false;
			
			if( _currentBytes )
			{
				_currentBytes.clear();
			}
			
			_currentBlock   = null;
			_currentPiece   = null;
			lastBlock 		= null;
			_isLastData		= false;
			
			this.lastPiece  = -1;
			
			if( _fileHandler )
			{
				_fileHandler.endProcessFile(null);
			}
			
			_fileHandler = null;
			_fileHandler = new HTTPStreamingMP2TSFileHandler();
			
		}
		
		/**输出面板使用，在外部播放器输出面板显示广告剩余时间*/
		private var _adRemainingTime:int = 0;
		
		override public function play(...args):void 
		{
			init();
			
			super.play(null);
			
			_initData = new InitData();

			for( var arg:String in args[0] )
			{
				P2PDebug.traceMsg(this,"初始化参数"+arg+"=>"+args[0][arg]);
				//TTT
//				if(arg=="serverCurtime")
//				{
//					args[0][arg]=int(args[0][arg])-60;
//				}
				_initData[arg]=args[0][arg];

				if( arg=="livesftime" )
				{
					//对接伪直播时间
					LiveVodConfig.TIME_OFF=Number(args[0][arg]);
				}
			}
			
			/*var _key:String = _initData.keyCreater.calcTimeKey();
			P2PDebug.traceMsg(this,"gslb securityKey: => "+ _key);*/
			
			
			if( args[0]["adRemainingTime"] )
			{
				//TTT
				//_initData.gslbURL = "http://live.gslb.letv.com/gslb?stream_id=p2p_test&tag=live&ext=m3u8&sign=live_tv&format=2&expect=2";
				
				_initData.setAdRemainingTime(int(args[0]["adRemainingTime"])*1000);
				_adRemainingTime = int(args[0]["adRemainingTime"])*1000;
				
				P2PDebug.traceMsg(this,"初始化参数adRemainingTime=>"+int(args[0]["adRemainingTime"])*1000);
			}
			
			if( args[0]["gslbURL"] )
			{
				LiveVodConfig.TERMID = ParseUrl.getParam(args[0]["gslbURL"],"termid");
				LiveVodConfig.PLATID = ParseUrl.getParam(args[0]["gslbURL"],"platid");
				LiveVodConfig.SPLATID = ParseUrl.getParam(args[0]["gslbURL"],"splatid");
			}
			
//			if( _initData.flvURL.length > 0 )
//			{
//				_initData.groupName = parseUrl(_initData.flvURL[0]);
//				
//				P2PDebug.traceMsg(this,"groupName"+LiveVodConfig.GET_AGREEMENT_VERSION()+_initData.groupName);
//				
//				_initData.groupName = getSHA1Code(LiveVodConfig.GET_AGREEMENT_VERSION()+_initData.groupName);
//			}
			
			LiveVodConfig.ADD_DATA_TIME = _initData.startTime;
			
			//TTT 用于直播调试用，正式版本需要去掉
//			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
//			{
//				LiveVodConfig.ADD_DATA_TIME = 1384425803;
//			}
			
			LIVE_TIME.SetBaseTime(_initData.startTime);
			LIVE_TIME.isPause = true;
			
			/**设置开始运行时间*/
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				LiveVodConfig.M3U8_MAXTIME = _initData.startTime;
				P2PDebug.traceMsg(this," LiveVodConfig.M3U8_MAXTIME:"+ LiveVodConfig.M3U8_MAXTIME);
			}	
			
			LIVE_TIME.SetLiveTime(_initData.serverCurtime);	
			
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.PLAY,_initData);
			
			flvHeadHandler();
			
			if( _mainTimer && !_mainTimer.running )
			{
				_mainTimer.start();
			}
		}
		
		/**
		 *由播放器调用，恢复P2P下载和传输数据功能 
		 */		
		public function resumeP2P():Boolean
		{
			LiveVodConfig.ifCanP2PDownload = true;
			LiveVodConfig.ifCanP2PUpload   = true;
			return true;
		}
		/**
		 *由播放器调用, 暂停P2P下载和传输数据功能 
		 */	
		public function pauseP2P():Boolean
		{
			LiveVodConfig.ifCanP2PDownload = false;
			LiveVodConfig.ifCanP2PUpload   = false;
			return true;
		}
		
		private function flvHeadHandler():void
		{
			P2PDebug.traceMsg(this,"flvHeadHandler");
			
			this["appendBytesAction"]("resetBegin");
			
			var header:FLVHeader = new FLVHeader();
			var headerBytes:ByteArray = new ByteArray();
			
			header.write(headerBytes);
			this["appendBytes"](headerBytes);
		}
		
		private var bytes:ByteArray = new ByteArray();
		private function processAndAppend(inBytes:ByteArray):void
		{
			if( !_seekOK )
			{
				return;
			}
			attemptAppendBytes(inBytes);
		}
		
		private function attemptAppendBytes(bytes:ByteArray):void
		{
			this["appendBytes"](bytes);
		}
		
		private var notifyDurationGroupID:String = ""; 
		public function notifyMetaData(block:Block = null):void
		{
			P2PDebug.traceMsg(this,"notifyTotalDuration");
			if( null == block )
			{
				return;
			}
			if( block && notifyDurationGroupID == block.groupID )
			{
				return;
			}
			else if( block )
			{
				notifyDurationGroupID = block.groupID;
			}
			
			var sdo:FLVTagScriptDataObject = new FLVTagScriptDataObject();
			var metaInfo:Object = new Object();
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				LiveVodConfig.DURATION = metaInfo.duration = this._initData.totalDuration;
			}
			
			metaInfo.height = block.height;
			metaInfo.width  = block.width;
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				LiveVodConfig.DATARATE = Math.round(_initData.totalSize*8/_initData.totalDuration/1024);
			}
			
			LiveVodConfig.SET_MEMORY_TIME();
			
			sdo.objects = ["onMetaData", metaInfo];
			var bytes:ByteArray = new ByteArray;
			sdo.write(bytes);
			attemptAppendBytes(bytes);
			
			if( client )
			{
				var methodName:* = sdo.objects[0];
				var methodParameters:* = sdo.objects[1];
				
				if( client.hasOwnProperty(methodName) )
				{
					client[methodName](methodParameters);
				}
			}
			
			P2PDebug.traceMsg(this,"isFirst seek:"+LiveVodConfig.ADD_DATA_TIME);
			dispatchEventFun({"code":"Stream.Play.Start","startTime":_initData.startTime});
		}
		
		private function onLoop(evt:TimerEvent):void
		{
			statisTimeCount++;
			
			if( statisTimeCount >= 10 )
			{
				statisTimeCount = 0;
				LiveVodConfig.PLAY_TIME = this.time;
				Statistic.getInstance().timeOutput(this.currentFPS);
			}
			
			if( _currentBytes == null || _currentBytes.bytesAvailable == 0 )
			{
				_currentBytes.clear();
				fetchData();
			}
			
			if( isPause )
			{
				return;
			}
			
			if( input != null && input.bytesAvailable > 0 )
			{
				if( _fileHandler == null )
				{
					_fileHandler = new HTTPStreamingMP2TSFileHandler();
				}
				
				var buff:ByteArray = _fileHandler.processFileSegment(input);
				
				if( buff!=null )
				{
					processAndAppend(buff);
				}
			}
			
			if( _currentBytes == null || _currentBytes.bytesAvailable < 188 )
			{
				if( _currentBlock
					&& _currentBlock.id == LiveVodConfig.LAST_TS_ID
					&& _currentPiece
					&& _currentPiece.id == (_currentBlock.pieceIdxArray.length-1)
					&& this.bufferLength < 0.3
					&& Math.abs(time-LiveVodConfig.DURATION)<0.5 )
				{
					notifyPlayStop();
				}
			}
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				endHandler();
			}
			if(_isBufferEmpty && LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				if(_currentBlock && (LIVE_TIME.GetLiveTime()-this._currentBlock.id) - offLiveTime > 45)
				{
					realSeek(_currentBlock.id+_currentBlock.duration+2.5, false);
				}
			}
		}
		
		private function fetchData():void
		{
			Statistic.getInstance().bufferTime(this.bufferTime,this.bufferLength,_adRemainingTime,_initData.getAdRemainingTime());
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD && _isLastData )
			{	
				return;
			}

			var tmpBlock:Block;
			var tmpBlockID:Number;
			
			if( this.bufferLength > LiveVodConfig.BufferTimeLimit )
			{
				P2PDebug.traceMsg(this,"this.bufferLength > LiveVodConfig.BufferTimeLimit");
				return;
			}

			if( _currentBytes == null || _currentBytes.bytesAvailable == 0 )
			{
				//处理play 或 seek的逻辑
				if( _currentBlock == null )
				{
					tmpBlock=_dataManager.getBlock(LiveVodConfig.ADD_DATA_TIME);	
					if( null == tmpBlock ) 
					{
						return;
					}
					
					notifyMetaData(tmpBlock);
					seek(tmpBlock.id);
					
					if( this.bufferLength < 0.5 
						&& lastBlock != null
						&& tmpBlock.groupID != lastBlock.groupID )
					{
						notifyMetaData(tmpBlock);
						realSeek(tmpBlock.id,false);
						return;
					}
									
					_currentBlock = tmpBlock;
					lastBlock 	  = _currentBlock;
					_currentPiece = tmpBlock.getPiece(0);
					
				}
				
				if( _currentBlock
					&& _currentPiece
					&& _currentPiece.isChecked 
					&& _currentPiece.getStream().length>0 )
				{
					Statistic.getInstance().whichGroupCanDisplay = _currentBlock.groupID;

					if( _currentBytes == null )
					{
						_currentBytes = new ByteArray();
					}
					//防止重复添加数据
					if( lastPiece != _currentPiece.id )
					{
						lastPiece = _currentPiece.id;
						_currentBytes.clear();
						_currentBytes.writeBytes(_currentPiece.getStream());
						_currentBytes.position = 0;
						
						input = _currentBytes;
						
						_fileHandler.beginProcessFile();
					}
					else
					{
						if( _currentBlock && _currentPiece )
						{
							P2PDebug.traceMsg(this,"PieceRepated_Blockid:"+_currentBlock.id + " Pieceid:" + _currentPiece.id+"_"+_currentPiece.pieceKey);
						}
					}
					//查找下一片
					Statistic.getInstance().setPlayHead(String(_currentBlock.id)+"_"+_currentPiece.id);
					P2PDebug.traceMsg(this,String(_currentBlock.id)+"_"+_currentPiece.id+"_"+_currentPiece.pieceKey+"_"+_currentPiece.type+" time:"+time);
					
					if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
					{
						if( _currentBlock.id == LiveVodConfig.LAST_TS_ID
							&& _currentPiece.id == (_currentBlock.pieceIdxArray.length-1) )
						{
							_isLastData = true;
						}
					}
					
					if(_currentBlock
						&& _currentPiece 
						&& _currentPiece.id == (_currentBlock.pieceIdxArray.length-1))
					{
						if( LiveVodConfig.TYPE == LiveVodConfig.VOD
							&& _currentBlock.id + _currentBlock.duration >= LiveVodConfig.DURATION)
						{
							LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.LAST_TS_ID;
						}
						else
						{
							LiveVodConfig.ADD_DATA_TIME = _currentBlock.id + _currentBlock.duration + 2.5;
						}
						
						tmpBlock =_dataManager.getBlock(LiveVodConfig.ADD_DATA_TIME);
						
						if( tmpBlock 
							&& tmpBlock.id != _currentBlock.id
						    && tmpBlock.groupID == _currentBlock.groupID )
						{

							_initData.videoHeight = tmpBlock.width;
							_initData.videoWidth  = tmpBlock.height;

							P2PDebug.traceMsg(this,"lastpiece_tmpBlock.id:"+tmpBlock.id);
							
							_currentBlock = tmpBlock;
							lastBlock 	  = _currentBlock;
							_currentPiece = _currentBlock.getPiece(0);
						}
						else if( tmpBlock 
							&& tmpBlock.id != _currentBlock.id
							&& tmpBlock.groupID != _currentBlock.groupID )
						{
							if( this.bufferLength < 0.5 )
							{
								notifyMetaData(tmpBlock);
								realSeek(tmpBlock.id,false);
								return;
							}
						}
						else
						{
							P2PDebug.traceMsg(this,"tmpBlock is null LiveVodConfig.ADD_DATA_TIME: " + LiveVodConfig.ADD_DATA_TIME );
						}
						
						return;
					}
					else
					{
						_currentPiece = _currentBlock.getPiece(_currentPiece.id+1);
						while( _currentPiece.isChecked && _currentPiece.size == 0 )
						{
							if( _currentPiece.id+1 == (_currentBlock.pieceIdxArray.length) )
							{
								break;
							}
							else
							{
								_currentPiece = _currentBlock.getPiece(_currentPiece.id+1);
							}
						}
					}
					
					if( !_seekDataOK )
					{
						_seekTimeRecord = _currentBlock.id;
						_seekDataOK = true;
					}
				}
				else
				{
					if(_currentPiece && _currentPiece.errorCount >= 3)
					{
						realSeek(_currentBlock.id + _currentBlock.duration + 2.5,false);
					}
					if( _isShowSeekIcon )
					{
						notifyShowIcon();
					}
				}
			}
		}
		
		private function notifyShowIcon():void
		{
			_isShowSeekIcon = false;
			
			P2PDebug.traceMsg(this,"Stream.Seek.ShowIcon");
			
			if( !_isBufferEmpty )
			{
				return;
			}
			
			dispatchEvent(
				new NetStatusEvent( 
					NETSTREAM_PROTOCOL.STREAM_STATUS
					, false
					, false
					, {"code":"Stream.Seek.ShowIcon", level:"status"}
				)
			);
		}
		
		private var isNotifyPlayStop:Boolean = false;
		private function notifyPlayStop():void
		{
			trace(this,"isNotifyPlayStop : "+isNotifyPlayStop);
			
			if( !isNotifyPlayStop )
			{
				isNotifyPlayStop = true;
			}
			else
			{
				return;
			}
			
			if( _mainTimer && _mainTimer.running )
			{
				_mainTimer.stop();	
			}
			
			P2PDebug.traceMsg(this,"Stream.Play.Stop");
			
			dispatchEvent(
				new NetStatusEvent( 
					NETSTREAM_PROTOCOL.STREAM_STATUS
					, false
					, false
					, {code:"Stream.Play.Stop", level:"status"}
				)
			); 
		}
		
		
		private function resetBeginHandler():void
		{
			this["appendBytesAction"](RESET_BEGIN);
		}
		
		private function resetEndHandler():void
		{
			this["appendBytesAction"](END_SEQUENCE);
		}
		
		protected function _this_NET_STATUS(event:NetStatusEvent):void
		{
			var code:String = event.info.code;
			
			P2PDebug.traceMsg(this,"code:"+code);
			
			switch( code )
			{				
				case "NetStream.Buffer.Empty" :
					_isBufferEmpty = true;
					dispatchEventFun({"code":"Stream.Buffer.Empty"});
					
					LIVE_TIME.isPause = true;
					
					if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
					{
						endHandler();
					}
					break;
				case "NetStream.Buffer.Full" :
						
					if( !isPause )
					{
						LIVE_TIME.isPause = false;
					}
					_isBufferEmpty = false;
					dispatchEventFun({"code":"Stream.Buffer.Full"});
					break;
				case "NetStream.Pause.Notify" :
					dispatchEventFun({"code":"Stream.Pause.Notify"});
					break;
				case "NetStream.Unpause.Notify" :
					dispatchEventFun({"code":"Stream.Unpause.Notify"});
					break;
				case "NetStream.Seek.Notify" :					
				case "NetStream.Seek.Failed":
				case "NetStream.Seek.InvalidTime":
					_seekOK = true;
					if( !_mainTimer.running )
					{
						_mainTimer.start();
					}
					break;
			}
		}
		
		private var _eventObj:Object = new Object();
		private function dispatchEventFun(info:Object):void
		{
			dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,info));	
		}
		
		private function endHandler():void
		{
			if( _seekOK && _currentBlock
				&& _currentBlock.id == LiveVodConfig.LAST_TS_ID
				&& _currentPiece
				&& _currentPiece.id == (_currentBlock.pieceIdxArray.length-1)
				&& this.bufferLength < 0.3 )
			{
				notifyPlayStop();
			}
		}
		public function set callBack(obj:Object):void
		{
			Statistic.getInstance().nativeCallBackObj[obj.key] = obj;
		}
		public function set outMsg(fun:Function):void
		{
			Statistic.getInstance().outMsg = fun;	
		}
		
		override public function get time():Number
		{
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				if( _seekTimeRecord + super.time >= LiveVodConfig.DURATION )
				{
					return LiveVodConfig.DURATION;
				}
				return _seekTimeRecord + super.time;
			}
			else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				return LIVE_TIME.GetBaseTime();
			}
			
			return super.time;
		}

		/**关闭*/
		override public function close():void
		{
			P2PDebug.traceMsg(this,"close");
			
			super.close();
			
			clear();
		}
		
		protected function clear():void
		{
			if( _mainTimer )
			{
				_mainTimer.stop();
				_mainTimer.removeEventListener(TimerEvent.TIMER,onLoop);
				_mainTimer = null;
				
				if( this.hasEventListener(NetStatusEvent.NET_STATUS) )
				{
					this.removeEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS);
				}
				
				if( _connection )
				{
					if( _connection.connected )
					{
						_connection.close();
					}
					_connection = null;
				}
				
				lastBlock 		 = null;
				isPause   		 = false;
				lastPiece 		 = -1;
				_isShowSeekIcon  = false;
				_adRemainingTime = 0;
				_isBufferEmpty	 = true;
				_seekTimeRecord	 = 0;
				
				_isForcedSeek    = false;
				
				Statistic.getInstance().removeEventListener();				
				Statistic.getInstance().clear();
				
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					LIVE_TIME.CLEAR();
				}
				
				_dataManager.clear();
				_initData  = null;
				_dataManager = null;
				
				LiveVodConfig.CLEAR();
			}
		}
		
		public function onMetaData(obj:Object = null):void
		{
			
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
		
		override public function set bufferTime(value:Number):void
		{}
		
		public function getManager():Object
		{
			return this._dataManager;
		}
		
//		private function parseUrl(tempUrl:String):String
//		{
//			var obj:Object = ParseUrl.parseUrl(tempUrl);
//			if( obj )
//			{
//				return obj.path.substr(0,obj.path.lastIndexOf("."));
//			}	
//			return tempUrl;	
//		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function get version():String
		{
			return LiveVodConfig.GET_VERSION();
		}
		
		protected function getSHA1Code(str:String):String
		{							
			var enc:sha1Encrypt = new sha1Encrypt(true);
			var strSHA1:String  = sha1Encrypt.encrypt(str);
			
			return strSHA1;
		}
	}
}