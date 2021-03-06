package com.hls_p2p.stream
{
	import at.matthew.httpstreaming.*;
	
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.dataManager.DataManagerFactory;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.loaders.ReportDownloadError;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ArrayClone;
	import com.p2p.utils.ParseUrl;
	import com.p2p.utils.Utils;
	import com.p2p.utils.console;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.System;
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
		public var isDebug:Boolean 					= true;//false;
		protected var _mainTimer:Timer 				= null;
		public static const END_SEQUENCE:String 	= "endSequence";
		public static const RESET_BEGIN:String 		= "resetBegin";
		public static const RESET_SEEK:String 		= "resetSeek";
		
		
		/**播放器play时传的参数*/
		protected var _initData:InitData;
		protected var _seekOK:Boolean 				= true;
		protected var _seekDataOK:Boolean 			= false;
		protected var _seekType:int  				= 0;
		
		protected var _currentBlock:Block			= null;
		protected var _currentPiece:Piece			= null;
		protected var lastBlock:Block 				= null;
		
		protected var lastPiece:Number 				= -1;
		protected var _need_CDN_Bytes:int 			= 0;
		protected var _seekTimeRecord:Number		= 0;
		/**声明通道*/
		protected var _connection:NetConnection;
		/**声明调度器*/
		protected var _dataManager:DataManager 	= null;
		/**是否缓存为空*/
		protected var _isBufferEmpty:Boolean		= true;
		/**是否暂停*/
		protected var isPause:Boolean				= false;
		protected var _currentBytes:ByteArray 		= new ByteArray();
		protected var _fileHandler:HTTPStreamingMP2TSFileHandler = null;
		
		private var statisTimeCount:int				= 0;
		
		private var onLoopDelay:int 				= 7;//25;//100;//
		private var _isLastData:Boolean				= false;
		
		/**是否显示seek后的图标，如果为true，只要没有获得数据就显示图标，如果为false，有没有数据都不会触发显示图标*/
		private var _isShowSeekIcon:Boolean 		= false;

		private var input:IDataInput;
		/**直播用，该值为直播点与play|seek的时间差，缓存时判断超过某一范围，向前进一个ts**/
		private var offLiveTime:Number				= -1;

		private var _isForcedSeek:Boolean 			= false;
		private var g_Lastbuflen:Number 			= -1;
		private var iErrorCount:int					= 0;
		
		private var _bufferEmptyStartTime:Number	= -1;
		
		private var _reportDownloadError:ReportDownloadError;
		
		private var _isNotifyPlayStop:Boolean = false;
		private var _isNoticeLoadNextData:Boolean = false;
				
		public function HTTPNetStream(p_obj:Object=null)
		{
			if( null == p_obj )
			{
				p_obj = new Object;
				//TTT
				p_obj.playType = LiveVodConfig.VOD;
				//p_obj.playType = LiveVodConfig.LIVE;
			}
			LiveVodConfig.TYPE = p_obj.playType.toUpperCase();
			if( LiveVodConfig.uuid==""){
				LiveVodConfig.uuid = (new Utils).get40SizeUUID();
//				"147a8efc5f2412d7b95a3b1696a4848df5c8b94b";	
			}
			console.log(this,"P2PNetStream"+LiveVodConfig.GET_VERSION()+LiveVodConfig.GET_TEMP_VERSION());
//			ExternalInterface.call("version",LiveVodConfig.GET_VERSION());
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
			//this.bufferTime = 1;
			
			lastBlock 		 = null;
			isPause   		 = false;
			lastPiece 		 = -1;
			_isShowSeekIcon  = false;
			_adRemainingTime = 0;
			_isBufferEmpty	 = true;
			_seekTimeRecord	 = 0;
			
			_isForcedSeek    = false;
			
			_isNotifyPlayStop = false;
			
			_isNoticeLoadNextData = false;
			
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
			
			_initData = new InitData();
			
			if( _reportDownloadError )
			{
				_reportDownloadError.clear();
				_reportDownloadError = null;
			}
			_reportDownloadError = new ReportDownloadError(_initData);
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
		
		public function getDownloadSpeed():Number
		{
			return Statistic.getInstance().downLoadSpeed;
		}
		
		/*public function change_KBPS(obj:Object):void
		{
			if(true)
			{
				this.isChangeKBPS = true;
				obj.kbps;
				_initData.otherKBPSURLobj.cdnInfo;
				obj.gslbURL;
			}
		}*/
		
		public function set_CDN_URL(arr:Array):void
		{
			//向下兼容
			if( arr.length>0
				&& _initData
				&& _initData.hasOwnProperty("flvURL") )
			{
				_initData["flvURL"] = arr.concat();
				_initData.setIndex(0);
				console.log(this,"set_CDN_URL:"+arr);
				
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					_initData.g_bGslbComplete = true;
					_initData.g_bVodLoaded = false;
				}
				_initData.g_nM3U8Idx = 0;
			}
		}
		
		public function setNextCdnUrl(arr:Array):void
		{
			if( arr.length>0 && _initData )
			{
				//_initData.nextFlvURL = ArrayClone.Clone(arr);
				_initData.nextFlvURL = arr.concat();
				
				console.log(this,"set_NEXT_CDN_URL:"+arr);
				
				_initData.g_next_nM3U8Idx = 0;
			}
		}
		
		public function set_CDN_INFO(arr:Array):void
		{
			if( arr.length>0
				&& _initData
				&& _initData.hasOwnProperty("cdnInfo") )
			{
				_initData["cdnInfo"] = arr;
				console.log(this,"set_CDN_INFO:"+arr);
				
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					_initData.g_bGslbComplete = true;
					_initData.g_bVodLoaded = false;
				}
				_initData.g_nM3U8Idx = 0;
			}
		}
		
		public function setNextCdnInfo(arr:Array):void
		{
			if( arr.length>0	&& _initData )
			{
				_initData.nextCdnInfo = arr;
				console.log(this,"set_NEXT_CDN_INFO:"+arr);
				
				_initData.g_next_nM3U8Idx = 0;
			}
		}
		
		override public function get bytesLoaded():uint
		{			
			if( _initData && _initData.totalSize>0 && LiveVodConfig.TYPE != LiveVodConfig.LIVE )
			{
				var block:Block = _dataManager.getBlock(  LiveVodConfig.currentVid,LiveVodConfig.NEAREST_WANT_ID );
								
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
			if( !_isBufferEmpty )
			{
				LIVE_TIME.isPause = false;
				_bufferEmptyStartTime = -1;				
			}
			else
			{				
				_bufferEmptyStartTime = getTime();
			}
			
			/*if( !LIVE_TIME.isPause && LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				return;
			}*/
			
			/**lz 0524 add*/
			_initData.setAdRemainingTime(0);
			/**************/
			offLiveTime = LIVE_TIME.GetLiveTime() - LiveVodConfig.ADD_DATA_TIME;
			console.log(this,"resume _isBufferEmpty="+_isBufferEmpty+", _bufferEmptyStartTime="+_bufferEmptyStartTime);
			super.resume();
		}
		
		override public function pause():void
		{
			isPause = true;
			//_bufferEmptyStartTime = -1;
			/*if( LIVE_TIME.isPause && LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				return;
			}*/
			console.log(this,"pause _isBufferEmpty="+_isBufferEmpty+", _bufferEmptyStartTime="+_bufferEmptyStartTime);
			super.pause();
			LIVE_TIME.isPause = true;
		}
		
		/**
		 * @param offset seek的时间
		 * @param type seek的类型，0为用户seek,1为异常不更改m3u8的seek，2为异常更改m3u8的seek，3为已知block的seek
		 */		
		private function realSeek( offset:Number,type:int=0 ):void
		{			
			//标准m3u8和标准的一源一流重新设置
			LiveVodConfig.canChangeM3U8 = false;
			LiveVodConfig.changeBlockId = -1;
			
			if( offset < 0 )
			{
				offset=0;
			}
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE
				&& offset >= LIVE_TIME.GetLiveOffTime() )
			{
				offset = LIVE_TIME.GetLiveOffTime();
			}
			
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE
				&& offset >= LiveVodConfig.LAST_TS_ID )
			{
				offset = LiveVodConfig.LAST_TS_ID;
			}
			
			_seekTimeRecord   = offset;
			
			LIVE_TIME.isPause = true;
			
			if( 0 == type || 2 == type )
			{
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					LiveVodConfig.M3U8_MAXTIME = offset;
				}
				
				if(this._initData)
				{
					this._initData.g_seekPos = offset;
				}
				
				LiveVodConfig.G_SEEKPOS = offset;
			}

			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				LIVE_TIME.SetBaseTime(offset);
				offLiveTime = LIVE_TIME.GetLiveTime() - offset;
				console.log(this,"seek offLiveTime"+offLiveTime+" LiveTime:"+LIVE_TIME.GetLiveTime()+" = "+(LIVE_TIME.GetLiveTime() - offset));
			}
			
			LiveVodConfig.ADD_DATA_TIME = offset;
			LiveVodConfig.SEEK_TIME = offset;
			LiveVodConfig.NEAREST_WANT_ID = LiveVodConfig.ADD_DATA_TIME;
			
			LiveVodConfig.IS_SEEKING = true;
			
			console.log(this,"seek:"+LiveVodConfig.ADD_DATA_TIME+" M3U8_MAXTIME:"+ LiveVodConfig.M3U8_MAXTIME+" type:"+type+" offLiveTime:"+offLiveTime);
			_isShowSeekIcon = true;
			
			Reset(type);
			
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.SEEK,offset);
			_seekType = type;
			super.seek(0);
			
			flvHeadHandler();
			
			this["appendBytesAction"](RESET_SEEK);
			
		}
		override public function seek(offset:Number):void
		{
			realSeek( offset, 0 );
		}
		
		private function Reset(type:int):void
		{
			_seekOK = false;
			_seekDataOK = false;
			
			if( _currentBytes )
			{
				_currentBytes.clear();
			}
			
			if( 3!=type )
			{
				_currentBlock   = null;
			}
			_currentPiece   = null;
			lastBlock 		= null;
			_isLastData		= false;
			_isBufferEmpty	= true;
			_isNotifyPlayStop = false;
			this.lastPiece  = -1;			
			
			_isEmptyIn15	= false;
			this.bufferTime	= 1;
			
			//_bufferEmptyStartTime = -1;
			
			if( _fileHandler )
			{
				_fileHandler.endProcessFile(null);
			}
			
			_fileHandler = null;
			_fileHandler = new HTTPStreamingMP2TSFileHandler();
			
		}
		
		private var _startPlayTime:Number = 0;//秒
		private var _isEmptyIn15:Boolean  = false;
		
		private function setBufferTime(isEmptyIn15:Boolean=false):void
		{
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				if(getTime()-_startPlayTime>=15*1000)
				{
					this.bufferTime = 15;
				}
				else
				{
					if( true == isEmptyIn15 )
					{
						if( false == _isEmptyIn15 )
						{
							this.bufferTime = 2;
							_isEmptyIn15 = true;
						}
						else
						{
							this.bufferTime = 15;
						}
					}					
				}
			}
			else
			{
				if( _initData.totalDuration-this.time < 3 )
				{
					this.bufferTime = 0.1;
				}
				else
				{
					if( _initData.totalDuration >= 15 )
					{
						if(this.time*1000-_startPlayTime>=15*1000)
						{
							this.bufferTime = 15;
						}
						else
						{
							if( true == isEmptyIn15 )
							{
								if( false == _isEmptyIn15 )
								{
									this.bufferTime = 2;
									_isEmptyIn15 = true;
								}
								else
								{
									this.bufferTime = 15;
								}
							}							
						}
					}
					else
					{
						if( _initData.totalDuration > 3 )
						{
							this.bufferTime = 2;
						}
						else
						{
							this.bufferTime = 0.1;
						}
					}
				}
				//trace("this.bufferTime = "+this.bufferTime)
				if( this.bufferTime < 1 )
				{
					LiveVodConfig.BufferTimeLimit = 1;
				}
				else
				{
					LiveVodConfig.BufferTimeLimit = this.bufferTime;
				}
			}
		}
		
		/**输出面板使用，在外部播放器输出面板显示广告剩余时间*/
		private var _adRemainingTime:int = 0;
		
		override public function play(...args):void 
		{
			//防止直播重复调用play
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE && null != _initData)
			{
				return;
			}
			init();
			
			super.play(null);
			
			//_initData = new InitData();			
			//_reportDownloadError = new ReportDownloadError(_initData);
			console.log(this,"初始化参数",args);
			for( var arg:String in args[0] )
			{	
				_initData[arg]=args[0][arg];
				
				if( arg == "flvURL" && LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					//向下兼容
					LiveVodConfig.STREAMID = ParseUrl.getParam(_initData[arg][0],"stream_id");
					/*if( (LiveVodConfig.TEST_ID == ParseUrl.getParam(_initData[arg][0],"stream_id") 
							|| LiveVodConfig.TEST_ID_1 == ParseUrl.getParam(_initData[arg][0],"stream_id") )
						&& LiveVodConfig.TYPE == LiveVodConfig.LIVE )
					{
						LiveVodConfig.TEST_TYPE_ID = ParseUrl.getParam(_initData[arg][0],"stream_id");
						LiveVodConfig.IS_TEST_ID   = true;
					}*/
				}
				if( arg == "cdnInfo" && LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					LiveVodConfig.STREAMID = ParseUrl.getParam(args[0][arg]["location"],"stream_id");
					/*if( LiveVodConfig.TEST_ID == ParseUrl.getParam(args[0][arg]["location"],"stream_id") 
							|| LiveVodConfig.TEST_ID_1 == ParseUrl.getParam(args[0][arg]["location"],"stream_id" ) )
					{
						LiveVodConfig.TEST_TYPE_ID = ParseUrl.getParam(args[0][arg]["location"],"stream_id");
						LiveVodConfig.IS_TEST_ID   = true;
					}*/
				}
				
				if( arg=="livesftime" )
				{
					//对接伪直播时间
					LiveVodConfig.TIME_OFF=Number(args[0][arg]);
				}
			}			
			
			if( args[0]["adRemainingTime"] )
			{
				_initData.setAdRemainingTime(int(args[0]["adRemainingTime"])*1000);
				_adRemainingTime = int(args[0]["adRemainingTime"])*1000;
				
				console.log(this,"初始化参数adRemainingTime=>"+int(args[0]["adRemainingTime"])*1000);
			}
			
			if( args[0]["gslbURL"] )
			{
				LiveVodConfig.TERMID = ParseUrl.getParam(args[0]["gslbURL"],"termid");
				LiveVodConfig.PLATID = ParseUrl.getParam(args[0]["gslbURL"],"platid");
				LiveVodConfig.SPLATID = ParseUrl.getParam(args[0]["gslbURL"],"splatid");
				LiveVodConfig.VTYPE	 = ParseUrl.getParam(args[0]["gslbURL"],"vtype");
			}
			else if( args[0]["gslb"] )
			{
				LiveVodConfig.TERMID = ParseUrl.getParam(args[0]["gslb"],"termid");
				LiveVodConfig.PLATID = ParseUrl.getParam(args[0]["gslb"],"platid");
				LiveVodConfig.SPLATID = ParseUrl.getParam(args[0]["gslb"],"splatid");
				LiveVodConfig.VTYPE	 = ParseUrl.getParam(args[0]["gslb"],"vtype");
			}
			
			LiveVodConfig.ADD_DATA_TIME = _initData.startTime;//播放点起始设置
			LiveVodConfig.SEEK_TIME = _initData.startTime;//seek起始设置
			/**设置开始运行时间*/
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				LIVE_TIME.SetBaseTime(_initData.startTime);
				LIVE_TIME.isPause = true;
				LiveVodConfig.M3U8_MAXTIME = _initData.startTime;
				LIVE_TIME.SetLiveTime(_initData.serverCurtime);	
			}
			
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.PLAY,{"initData":_initData,"reportDownloadError":_reportDownloadError});
			
			flvHeadHandler();
			
			if( _mainTimer && !_mainTimer.running )
			{
				_mainTimer.start();
			}
			
			Statistic.getInstance().startRunningForDownLoad();
			
			_bufferEmptyStartTime = getTime();
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
			console.log(this,"flvHeadHandler");
			
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
//			if( inBytes.bytesAvailable == 0 && !this._seekDataOK)
//			{
//				console.log(this,"inBytes:"+inBytes.bytesAvailable+"_"+inBytes.length);
//			}
			attemptAppendBytes(inBytes);
		}
		
		private function attemptAppendBytes(bytes:ByteArray):void
		{
			this["appendBytes"](bytes);
		}
		
		private var notifyDurationGroupID:String = ""; 
		private var notifyWidth:Number			 = 0;
		private var notifyHeight:Number			 = 0;
		private function notifyMetaData(block:Block = null):void
		{
			
			if( null == block )
			{
				return;
			}
			if( block && notifyDurationGroupID == block.groupID 
				&& notifyWidth == block.width && notifyHeight == block.height )
			{
				return;
			}
			else if( block )
			{
				notifyDurationGroupID = block.groupID;
				notifyWidth			  = block.width;
				notifyHeight 		  = block.height;
			}
			
			var sdo:FLVTagScriptDataObject = new FLVTagScriptDataObject();
			var metaInfo:Object = new Object();
			
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE/*LiveVodConfig.TYPE == LiveVodConfig.VOD*/ )
			{
				LiveVodConfig.TOTAL_DURATION = metaInfo.duration = this._initData.totalDuration;
				metaInfo.mediaDuration = this._initData.mediaDuration;
				Statistic.getInstance().callPlayerDuration(this._initData.totalDuration);
				LiveVodConfig.DATARATE = Math.round(_initData.totalSize*8/_initData.totalDuration/1024);
			}
			
			metaInfo.height = block.height;
			metaInfo.width  = block.width;			
			
			//LiveVodConfig.SET_MEMORY_TIME();
			
			var metamsg:String = "";
			for(var msg:String in metaInfo )
			{
				metamsg += " msg:"+msg+"="+metaInfo[msg];
			}
			console.log(this,"notifyTotalDuration:"+metamsg);
			
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
			
			dispatchEventFun({"code":"Stream.Play.Start","startTime":_initData.startTime});
		}
		
		private function onLoop(evt:TimerEvent):void
		{
			statisTimeCount++;
			
//			ExternalInterface.call("setMemoryMsg",System.totalMemory);
//			ExternalInterface.call("setKFPMsg",this.currentFPS);
			
			if( statisTimeCount >= 10 )
			{
				statisTimeCount = 0;
				LiveVodConfig.PLAY_TIME = this.time;
				Statistic.getInstance().timeOutput(this.currentFPS);
				if(this.currentFPS < 18)
				{
					console.log(this,"fps<18");
				}
				doAllCDNFailed();
			}
			
			Statistic.getInstance().getDownloadSpeed();
						
			if( _currentBytes == null || _currentBytes.bytesAvailable == 0 )
			{
				_currentBytes.clear();
				fetchData();
			}
			
//			if( isPause )
//			{
//				return;
//			}
			
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
			
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE/*LiveVodConfig.TYPE == LiveVodConfig.VOD*/ )
			{
				if( _currentBlock
					&& _currentBlock.id == LiveVodConfig.LAST_TS_ID
					&& _currentPiece
					&& _currentPiece.id == (_currentBlock.pieceIdxArray.length-1)
					&& this.bufferLength < 0.1
					&& input.bytesAvailable < 188
					&& Math.abs(time-LiveVodConfig.TOTAL_DURATION)<1 )
				{
					notifyPlayStop();
				}
			}
			
			if(_isBufferEmpty && LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				//需要切换到标准的m3u8中//changeBlockPreId
				if(LiveVodConfig.canChangeM3U8 && ( LiveVodConfig.changeBlockId - LiveVodConfig.ADD_DATA_TIME )<20)
				{
					console.log(this,"NetStream.change.player time:"+LiveVodConfig.changeBlockId);
					dispatchEvent(
						new NetStatusEvent( 
							NETSTREAM_PROTOCOL.STREAM_STATUS
							, false
							, false
							, {"code":"NetStream.change.player", "level":"status","changeTime":LiveVodConfig.changeBlockId}
						)
					); 
					return;
				}
//				当用户暂停怎么处理？
				/*if( !isPause && (LIVE_TIME.GetLiveTime()-LiveVodConfig.ADD_DATA_TIME) - offLiveTime > 45 && _seekDataOK)
				{
					console.log(this,"buffer is empty && delay time>45:"+(LIVE_TIME.GetLiveOffTime()-LiveVodConfig.ADD_DATA_TIME));
					realSeek(LiveVodConfig.ADD_DATA_TIME+45, 2);
				}*/
//				
				if( offLiveTime!=-1 &&!isPause )
				{
					if( true == _seekDataOK )
					{
						//当前处于播放状态，已经喂过数据，但播放进度超过90秒没有变化则执行一次“被迫”seek
						if( (LIVE_TIME.GetLiveTime()-LiveVodConfig.ADD_DATA_TIME) - offLiveTime > 90 )
						{
							console.log(this,"buffer is empty, delay time 90:"+(LIVE_TIME.GetLiveOffTime()-LiveVodConfig.ADD_DATA_TIME));
							realSeek(LiveVodConfig.ADD_DATA_TIME+90, 2);
						}						
					}
					else
					{
						//当前处于播放状态，未下载到播放数据，播放进度超过90秒没有变化则执行一次seek；或处于“被迫”seek之后仍没有获得下载数据
						if(  (LIVE_TIME.GetLiveTime()-LiveVodConfig.ADD_DATA_TIME) - offLiveTime > 90 )
						{
							console.log(this,"seek buffer is empty, delay time 90:"+LIVE_TIME.GetLiveTime()+" "+LiveVodConfig.ADD_DATA_TIME+" "+offLiveTime);
							realSeek(LiveVodConfig.ADD_DATA_TIME+90, 2);
						}
					}					
				}
			}
		}
		
		private function fetchData():void
		{
			if( _initData )
			{
				Statistic.getInstance().bufferTime(this.bufferTime/*System.totalMemory*/,this.bufferLength,_adRemainingTime,_initData.getAdRemainingTime());
			}			
			
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE && _isLastData )
			{	
				setBufferTime();
				return;
			}
			
			if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD 
				&& false == _isNoticeLoadNextData
				&& this.bufferTime == 15
				&& false == _isBufferEmpty )
			{
				_isNoticeLoadNextData = true;
				Statistic.getInstance().noticeLoadNextData();
			}
			
			if(   LiveVodConfig.TYPE == LiveVodConfig.LIVE  )
			{
				if( LIVE_TIME.GetLiveTime() - LiveVodConfig.ADD_DATA_TIME < 30 ) 
				{
					//console.log( this,"> wei zhi bo" );
					return;
				}
			}

			var tmpBlock:Block;
			var tmpBlockID:Number;
			
//			if( LiveVodConfig.ADD_DATA_TIME > LIVE_TIME.GetLiveOffTime()+20 )
//			{
//				return;
//			}

			if( this.bufferLength > LiveVodConfig.BufferTimeLimit && this.bufferLength <= 60)
			{
				//console.log( this," > buffer " );
				return;
			}
			else if( _currentBlock && this.bufferLength > 60 )
			{
				console.log( this,"data error1-time error" );
				var tmpBlock_2:Block = null;
				if( _currentBlock.nextblkid != -1 )
				{
					tmpBlock_2 = _dataManager.getBlock( LiveVodConfig.currentVid,_currentBlock.nextblkid,true);
				}
				else
				{
					tmpBlock_2 =_dataManager.getNextBlock(  LiveVodConfig.currentVid,_currentBlock.id );
				}
				if( null != tmpBlock_2 )
				{
					LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.BlockID = tmpBlock_2.id;
					_currentBlock = tmpBlock_2
					notifyMetaData(tmpBlock_2);
					realSeek(tmpBlock_2.id,3);
					g_Lastbuflen = this.bufferLength;
					console.log( this,"g_Lastbuflen == 0 && this.bufferLength == 0 block.id: "+tmpBlock_2.id );
					return;
				}
			}
			else if(  _currentBlock == null && this.bufferLength > 60 )
			{
				console.log( this,"data error2-time error" );
				return;
			}

			if( _currentBytes == null || _currentBytes.bytesAvailable == 0 )
			{
				//处理play 或 seek的逻辑
				if( _currentBlock == null )
				{
					if(!_dataManager)
					{
						return;
					}
					tmpBlock=_dataManager.getBlock(  LiveVodConfig.currentVid, LiveVodConfig.ADD_DATA_TIME);
					//trace(LiveVodConfig.currentVid+" seek================== "+LiveVodConfig.ADD_DATA_TIME);
					if( tmpBlock && _seekType == 0 && -1 != tmpBlock.nextblkid )
					{
						if( (tmpBlock.id + tmpBlock.nextblkid)/2 < LiveVodConfig.ADD_DATA_TIME )
						{
							tmpBlock = _dataManager.getBlock(  LiveVodConfig.currentVid, tmpBlock.nextblkid );
						}
					}
					
					if( tmpBlock )
					{
						Statistic.getInstance().setGroupID(tmpBlock.groupID);
					}

					while( tmpBlock && tmpBlock.duration == 0)
					{
						if( tmpBlock.nextblkid != -1 )
						{
							tmpBlock = _dataManager.getBlock(  LiveVodConfig.currentVid, tmpBlock.nextblkid,true);
							if( -1 == tmpBlock.nextblkid )
							{
								break;
							}
						}
					}
					
					if( !tmpBlock ) 
					{
						return;
					}
					
					_currentBlock = tmpBlock;
					LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.BlockID = _currentBlock.id;
					notifyMetaData(tmpBlock);
					
					if( LiveVodConfig.TYPE != LiveVodConfig.LIVE )
					{
						_startPlayTime = this.time*1000;
					}
					else
					{
						_startPlayTime = getTime();
					}
					//
					//this.bufferTime = 1;
					
					realSeek(tmpBlock.id,3);
					
					lastBlock 	  = _currentBlock;
					_currentPiece = tmpBlock.getPiece(0);
					
					if(_currentPiece)
					{
						LiveVodConfig.PieceID = _currentPiece.id;
					}
					
				}
				//切换头，获得block落在重叠的区间处理
				if( _currentBlock && !_currentPiece )
				{
					_currentPiece = _currentBlock.getPiece(0);
					if(_currentPiece)
					{
						LiveVodConfig.PieceID = _currentPiece.id;
					}
					else
					{
						trace("")
					}
				}
				
				setBufferTime();
				
				if( _currentBlock
					&& _currentPiece
					&& _currentPiece.isChecked 
					&& _currentPiece.getStream().length > 0 )
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
						console.log(this,"play->bID:"+_currentBlock.id + " pID:" + _currentPiece.id+"_"+_currentPiece.pieceKey+" url:"+_currentBlock.name);
						input = _currentBytes;
						if(!_seekDataOK)
						{
							_seekDataOK = true;
							offLiveTime = LIVE_TIME.GetLiveTime()-LiveVodConfig.ADD_DATA_TIME;
						}
						if( null == _fileHandler )
						{
							_fileHandler = new HTTPStreamingMP2TSFileHandler();
						}
						_fileHandler.beginProcessFile();
						
						_isShowSeekIcon = false;
						
						var tmppause:Boolean = LIVE_TIME.isPause;
						if( g_Lastbuflen == -1 && this.bufferLength > 0 )
						{
							g_Lastbuflen = this.bufferLength;
						}
						else if( (g_Lastbuflen == this.bufferLength) && ( tmppause == false || _isBufferEmpty == true) )
						{
							++iErrorCount;
							if( iErrorCount >= 8 )
							{
								iErrorCount = 0;
								var tmpBlock_1:Block = null;
								if( _currentBlock.nextblkid != -1 )
								{
									tmpBlock_1 = _dataManager.getBlock(  LiveVodConfig.currentVid, _currentBlock.nextblkid,true);
								}
								else
								{
									tmpBlock_1 =_dataManager.getNextBlock( LiveVodConfig.currentVid, _currentBlock.id );
								}
								
								if( tmpBlock_1 )
								{
									notifyMetaData(tmpBlock_1);
									realSeek(tmpBlock_1.id,3);
								}
								
								
								g_Lastbuflen = this.bufferLength;
								console.log( this,"g_Lastbuflen:" + g_Lastbuflen + "== bufferLength:"+bufferLength+" seek->"+tmpBlock_1 ? tmpBlock_1.id : "null");
								return;
							}
						}else
						{
							iErrorCount = 0;
						}
					}
					else
					{
						if( !isPause && _seekDataOK && g_Lastbuflen == this.bufferLength )
						{
							++iErrorCount;
							if( iErrorCount >= 8 )
							{
								iErrorCount = 0;
								var tmpBlock_3:Block = null;
								if( _currentBlock.nextblkid != -1 )
								{
									tmpBlock_3 = _dataManager.getBlock( LiveVodConfig.currentVid, _currentBlock.nextblkid,true);
								}
								else
								{
									tmpBlock_3 =_dataManager.getNextBlock( LiveVodConfig.currentVid, _currentBlock.id );
								}
								
								
								if( tmpBlock_3 )
								{
									notifyMetaData(tmpBlock_3);
									realSeek(tmpBlock_3.id,2);
									g_Lastbuflen = this.bufferLength;
									console.log( this,"g_Lastbuflen != this.bufferLength s block.id: "+tmpBlock_3.id );
									return;
								}
							}
						}else
						{
							iErrorCount = 0;
						}
						if( _currentBlock && _currentPiece )
						{
							console.log(this,"PieceRepated_Blockid:"+_currentBlock.id + " Pieceid:" + _currentPiece.id+"_"+_currentPiece.pieceKey);
						}
					}

					g_Lastbuflen = this.bufferLength;
					//查找下一片
					if( _currentBlock && _currentPiece )
					{
						Statistic.getInstance().setPlayHead(String(_currentBlock.id)+"_"+_currentPiece.id);
					}
					
					
					if( LiveVodConfig.TYPE != LiveVodConfig.LIVE/*LiveVodConfig.TYPE == LiveVodConfig.VOD*/ )
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
						if( LiveVodConfig.TYPE != LiveVodConfig.LIVE/*LiveVodConfig.TYPE == LiveVodConfig.VOD*/
							&& _currentBlock.id + _currentBlock.duration >= LiveVodConfig.TOTAL_DURATION)
						{
							LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.LAST_TS_ID;
						}
//						
						if( _currentBlock.nextblkid != -1 )
						{
							tmpBlock = _dataManager.getBlock( LiveVodConfig.currentVid, _currentBlock.nextblkid,true);
						}
						else
						{
							tmpBlock =_dataManager.getNextBlock( LiveVodConfig.currentVid, _currentBlock.id );
						}
						
						while( tmpBlock && tmpBlock.duration == 0)
						{
							if( tmpBlock.nextblkid != 0 )
							{
								tmpBlock = _dataManager.getBlock( LiveVodConfig.currentVid, tmpBlock.nextblkid,true);
							}
							else
							{
								tmpBlock =_dataManager.getNextBlock( LiveVodConfig.currentVid, _currentBlock.id );
								break;
							}
						}
						
						if( tmpBlock 
							&& tmpBlock.id != _currentBlock.id
						    && (tmpBlock.discontinuity == 0 && tmpBlock.groupID == _currentBlock.groupID 
								&& tmpBlock.width == _currentBlock.width && tmpBlock.height == _currentBlock.height ) )
						{

							_initData.videoHeight = tmpBlock.width;
							_initData.videoWidth  = tmpBlock.height;

							console.log(this,"lastpiece_tmpBlock.id:"+tmpBlock.id);
							
							_currentBlock = tmpBlock;
							LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.BlockID = _currentBlock.id;
							lastBlock 	  = _currentBlock;
							_currentPiece = _currentBlock.getPiece(0);
							
							if(_currentPiece)
							{
								LiveVodConfig.PieceID = _currentPiece.id;
							}
							
						}
						else if( tmpBlock 
							&& tmpBlock.id != _currentBlock.id
							&& ( tmpBlock.discontinuity == 1 
								|| tmpBlock.groupID != _currentBlock.groupID || tmpBlock.width != _currentBlock.width  || tmpBlock.height != _currentBlock.height ) )
						{
							if( this.bufferLength < 0.5 )
							{
								_currentBlock = tmpBlock;
								LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.BlockID = _currentBlock.id;
								notifyMetaData(tmpBlock);
								realSeek(tmpBlock.id,3);
								console.log(this,"change group seek "+tmpBlock.discontinuity);
								return;
							}
						}
						else
						{
							console.log(this,"tmpBlock is null LiveVodConfig.ADD_DATA_TIME: " + LiveVodConfig.ADD_DATA_TIME );
						}
						
						return;
					}
					else
					{
						if( _currentBlock && _currentPiece )
						{
							_currentPiece = _currentBlock.getPiece(_currentPiece.id+1);
							
							if( _currentPiece )
							{
								while( _currentPiece.isChecked && _currentPiece.size == 0 )
								{
									if( _currentPiece.id+1 == (_currentBlock.pieceIdxArray.length) )
									{
										if( -1!=_currentBlock.nextblkid )
										{
											tmpBlock = _dataManager.getBlock( LiveVodConfig.currentVid, _currentBlock.nextblkid,true);
											if(tmpBlock)
											{
												_currentBlock = tmpBlock;
												LiveVodConfig.ADD_DATA_TIME = LiveVodConfig.BlockID = _currentBlock.id;
												_currentPiece = _currentBlock.getPiece(0);
												LiveVodConfig.PieceID = _currentPiece.id;
											}
										}
										
										break;
									}
									else
									{
										_currentPiece = _currentBlock.getPiece(_currentPiece.id+1);
										LiveVodConfig.PieceID = _currentPiece.id;
									}
								}
							}
						}
					}
					
					if( !_seekDataOK )
					{
						_seekTimeRecord = _currentBlock.id;
						//_seekDataOK = true;
					}
				}
				else
				{
					if(_currentPiece && _currentPiece.errorCount >= 3)
					{
						if( -1 != _currentBlock.nextblkid )
						{
							realSeek( _currentBlock.nextblkid,1 );
						}else
						{
							realSeek(_currentBlock.id + _currentBlock.duration + 2.5,1);
						}
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
			
			console.log(this,"Stream.Seek.ShowIcon");
			
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
		
		private function notifyPlayStop():void
		{
			console.log(this,"_isNotifyPlayStop : "+_isNotifyPlayStop);
			
			if( !_isNotifyPlayStop )
			{
				_isNotifyPlayStop = true;
			}
			else
			{
				return;
			}
			
			if( _mainTimer && _mainTimer.running )
			{
				_mainTimer.stop();	
			}
			
			console.log(this,"Stream.Play.Stop");
			
			var obj:Object 	= new Object();
			obj.code 		= "Stream.Play.Stop";
			obj.level 		= "status";
			obj.isPlayNext  = false;
			if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD && true == _initData.g_bNextVodLoaded )
			{
				obj.isPlayNext = true;
			}
			
			dispatchEvent(
				new NetStatusEvent( 
					NETSTREAM_PROTOCOL.STREAM_STATUS
					, false
					, false
					, obj
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
		
		private function doAllCDNFailed():void
		{
			if( _initData
				&& _reportDownloadError
				&& false == isPause
				&& _bufferEmptyStartTime > 0
				&& (getTime() - _bufferEmptyStartTime > 15*1000) )
			{
				console.log(this,"isPause = "+isPause+", _bufferEmptyStartTime = "+_bufferEmptyStartTime+", "+(getTime() - _bufferEmptyStartTime));
				var info:Object=new Object();
				info.code = "Stream.Play.Failed";
				info.p2pErrorCode = "0000";
				info.allCDNFailed = 1;
				
				var whichDownloadError:String = _reportDownloadError.whichDownloadError();
				
				if( whichDownloadError != "" )
				{
					console.log(this,"whichDownloadError = "+whichDownloadError)
					info.error = whichDownloadError;
					dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,info));
				}
				/*
				if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
				{
					console.log(this,"ts LiveVodConfig.TYPE ="+LiveVodConfig.TYPE)
					if( _initData.g_bVodLoaded == true )
					{
						if( _initData.isPlayPieceDownlandFailed() )							 
						{
							console.log(this,"ts")
							info.error = "ts";
							dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,info));
						}
					}
					else
					{
						if( _initData.isM3U8DownlandFailed() )
						{
							console.log(this,"m3u8")
							info.error = "m3u8";
							dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,info));
						}
					}
				}
				else
				{
					console.log(this,"m3u8 LiveVodConfig.TYPE ="+LiveVodConfig.TYPE)
					//加m3u8判断
					if( _initData.isPlayPieceDownlandFailed() )							 
					{
						info.error = "ts";
						dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,info));
					}					
				}*/
			}
		}
		
		protected function _this_NET_STATUS(event:NetStatusEvent):void
		{
			var code:String = event.info.code;
			
			console.log(this,"code:"+code);
			
			switch( code )
			{				
				case "NetStream.Buffer.Empty" :
					_bufferEmptyStartTime = getTime();
					_isBufferEmpty = true;
					_isShowSeekIcon = true;
					notifyShowIcon();
					setBufferTime(true);
					
					LIVE_TIME.isPause = true;
					console.log(this,"NetStream.Buffer.Empty _bufferEmptyStartTime="+_bufferEmptyStartTime);
					dispatchEventFun({"code":"Stream.Buffer.Empty"});					
					
					if( LiveVodConfig.TYPE != LiveVodConfig.LIVE )
					{
						endHandler();
					}
					break;
				case "NetStream.Buffer.Full" :
					_bufferEmptyStartTime = -1;	
					//trace("NetStream.Buffer.Full;  bufferTime = "+this.bufferTime);
					console.log(this,"NetStream.Buffer.Full _bufferEmptyStartTime="+_bufferEmptyStartTime);
					if( !isPause )
					{
						LIVE_TIME.isPause = false;
					}
					_isBufferEmpty = false;
					_isShowSeekIcon = false;
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
				&& input.bytesAvailable < 188 )
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
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE/*LiveVodConfig.TYPE == LiveVodConfig.VOD*/ )
			{
				if( _seekTimeRecord + super.time >= LiveVodConfig.TOTAL_DURATION )
				{
					return LiveVodConfig.TOTAL_DURATION;
				}
				return _seekTimeRecord + super.time;
			}
			else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				return _seekTimeRecord + super.time;
//				return LIVE_TIME.GetBaseTime();
			}
			
			return super.time;
		}

		/**关闭*/
		override public function close():void
		{
			console.log(this,"close");
			
			super.close();
			
			clear();
		}
		
		protected function clear():void
		{
			console.log(this,"clear");
			if( _mainTimer )
			{
				console.log(this,"clear");
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
				
				_isNotifyPlayStop = false;
				
				Statistic.getInstance().removeEventListener();				
				Statistic.getInstance().clear();
				
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					LIVE_TIME.CLEAR();
				}
				
				_dataManager.clear();
				_initData  = null;
				_dataManager = null;
				_reportDownloadError = null;
				
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
		
		/*override public function set bufferTime(value:Number):void
		{}*/
		
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