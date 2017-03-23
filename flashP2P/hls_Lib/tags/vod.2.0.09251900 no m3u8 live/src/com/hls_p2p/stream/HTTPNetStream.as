package com.hls_p2p.stream
{
	import at.matthew.httpstreaming.*;
	
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dataManager.DisPatcherFactory;
	import com.hls_p2p.dataManager.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ArrayClone;
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
		public var isDebug:Boolean=true;
		
		protected var _mainTimer:Timer = null;
		public static const END_SEQUENCE:String = "endSequence";
		public static const RESET_BEGIN:String = "resetBegin";
		public static const RESET_SEEK:String = "resetSeek";
		
		protected var _fileHandler:HTTPStreamingMP2TSFileHandler = null;
//		protected var _flvParser:FLVParser = null;
		protected var _flvParserProcessed:uint;
		
		/**播放器play时传的参数*/
		protected var _initData:InitData;
		protected var _seekOK:Boolean = true;
		protected var _seekDataOK:Boolean = true;
		
		protected var _currentBytes:ByteArray = new ByteArray();
		protected var _currentBlock:Block=null;
		protected var _currentPiece:Piece=null;
		
		/**声明通道*/
		protected var _connection:NetConnection;
		
		/**声明调度器*/
		protected var _dispather:IDataManager = null;
		
		protected var _seekTimeRecord:Number=0;
		//protected var _totalTS:int=0;
		
		protected var _need_CDN_Bytes:int = 0;
		
		private var input:IDataInput;
		private var onLoopDelay:int = 25;
		private var outTime:int=0;
		private var _isLastData:Boolean=false;
		/**是否显示seek后的图标，如果为true，只要没有获得数据就显示图标，如果为false，有没有数据都不会触发显示图标*/
		private var _isShowSeekIcon:Boolean = false;
		private var _isFull:Boolean=false;
		public function HTTPNetStream(connection:*=null)
		{
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
			
			LiveVodConfig.TYPE=LiveVodConfig.LIVE;
			P2PDebug.traceMsg(this," P2PNetStream init:"+LiveVodConfig.VERSION);
			
			/**统记添加监听事件*/
			Statistic.getInstance().addEventListener();
			Statistic.getInstance().setNetStream(this);
			
			if(!this.hasEventListener(NetStatusEvent.NET_STATUS))
			{
				this.addEventListener(NetStatusEvent.NET_STATUS, _this_NET_STATUS, false, 1);
			}
			/**未完成事件
			 * stream.addEventListener("p2pStatus",onP2PStatus,false,0,true);
			 * stream.addEventListener("p2pAllOver",onP2PError,false,0,true);
			 * 
			 */
			/**创建调度器*/
			if(!_dispather)
			{
				_dispather=DisPatcherFactory.createDisPatcher(LiveVodConfig.TYPE);
			}
			
			if(!_mainTimer)
			{
				_mainTimer = new Timer(onLoopDelay);
				_mainTimer.addEventListener(TimerEvent.TIMER,onLoop);
			}
			
		}
		public function set need_CDN_Bytes(b:int):void
		{
			_need_CDN_Bytes = b;
		}
		
		public function getStatisticData():Object
		{
			return Statistic.getInstance().getStatisticData();
		}
		
		public function set_CDN_URL(arr:Array):void
		{
			if(arr.length>0
				&& _initData
				&& _initData.hasOwnProperty("flvURL"))
			{
				_initData["flvURL"] = ArrayClone.Clone(arr);//.concat();
				_initData.setIndex(0);
				P2PDebug.traceMsg(this,"set_CDN_URL:"+arr);
			}
		}
		
		override public function get bytesLoaded():uint
		{			
			if ( _initData && _initData.totalSize>0)
			{
				var block:Block=_dispather["getBytesLoaded"]();
				var lastTime:Number=0;
				if(block && block.isChecked)
				{
					lastTime=block.id+block.duration;
				}
				else if(block)
				{
					lastTime=block.id;
				}
				if(time/_initData.totalDuration>=1 || lastTime/_initData.totalDuration>=1)
				{
					return _initData.totalSize;
				}
				if(lastTime<=time){
					return (time/_initData.totalDuration)*_initData.totalSize;
				}else
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
			if ( _initData && _initData.totalSize>0)
			{
				return _initData.totalSize;
			}
			return 0;
		}
		override public function resume():void
		{
			/**lz 0524 add*/
			_initData.setAdRemainingTime(0);
			/**************/
			super.resume();
		}
		
		override public function pause():void
		{
			super.pause();
		}
		override public function seek(offset:Number):void
		{
			if(_mainTimer.running)
			{
				_mainTimer.stop();
			}
			if(offset<0)
			{
				offset=0;
			}
			_seekTimeRecord=offset;
			
			LiveVodConfig.ADD_DATA_TIME = offset;
			P2PDebug.traceMsg("seek:"+LiveVodConfig.ADD_DATA_TIME);
			
			_isShowSeekIcon=true;
			
			_seekOK = false;
			_seekDataOK = false;

			if(_currentBytes)
			{
				_currentBytes.clear();
			}
			_isFull=false;
			_currentBlock = null;
			_currentPiece = null;
			_isLastData=false;
			if(_fileHandler)
			{
				_fileHandler.endProcessFile(null);
			}
			_fileHandler = null;
			
			_fileHandler = new HTTPStreamingMP2TSFileHandler();
			
			super.seek(0);
			flvHeadHandler();
			this["appendBytesAction"](RESET_SEEK);
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.SEEK,offset);
		}
		/**输出面板使用，在外部播放器输出面板显示广告剩余时间*/
		private var _adRemainingTime:int = 0;
		override public function play(...args):void 
		{
			init();
			super.play(null);
			
			_initData = new InitData();
			
			for(var arg:String in args[0]){
				P2PDebug.traceMsg(this,"初始化参数"+arg+"=>"+args[0][arg]);
				_initData[arg]=args[0][arg];
			}
			_initData.setAdRemainingTime(int(args[0]["adRemainingTime"])*1000);
			_adRemainingTime = int(args[0]["adRemainingTime"])*1000
			P2PDebug.traceMsg(this,"初始化参数adRemainingTime=>"+int(args[0]["adRemainingTime"])*1000);
			if(_initData.flvURL.length>0)
			{
				_initData.groupName = parseUrl(_initData.flvURL[0]);
				P2PDebug.traceMsg(this,"groupName"+LiveVodConfig.P2P_AGREEMENT_VERSION+_initData.groupName);
				_initData.groupName = getSHA1Code(LiveVodConfig.P2P_AGREEMENT_VERSION+_initData.groupName);
			}
			/**设置开始运行时间*/
			LiveVodConfig.ADD_DATA_TIME = _initData.startTime;
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.PLAY,_initData);
			
			flvHeadHandler();
		}
		private function parseUrl(tempUrl:String):String
		{
			var pattern:RegExp = /^([a-z+\w\+\.\-]+:\/?\/?)?([^\/?#]*)?(\/[^?#]*)?(\?[^#]*)?(\#.*)?/i;		
			var result:Array = tempUrl.match(pattern);
			if (result != null)
			{
				//protocol = result[1];
				//hostName = result[2];
				//path = result[3];
				//query = result[4];
				//fragment = result[5];
				//去掉后缀名
				if(result[3].lastIndexOf(".")>0)
				{
					result[3]=result[3].substr(0,result[3].lastIndexOf("."));
				}
				return result[3];
			}
			return tempUrl;
		}
		/**
		 *由播放器调用，恢复P2P下载和传输数据功能 
		 */		
		public function resumeP2P():Boolean
		{
			return false;
		}
		/**
		 *由播放器调用, 暂停P2P下载和传输数据功能 
		 */	
		public function pauseP2P():Boolean
		{
			/*未完成*/
			return false;
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
			if (!_seekOK)
			{
				return;
			}
			attemptAppendBytes(inBytes);
		}
		
		private function attemptAppendBytes(bytes:ByteArray):void
		{
			this["appendBytes"](bytes);
		}
		
		public function notifyTotalDuration(obj:Object):void
		{
			P2PDebug.traceMsg(this,"notifyTotalDuration");
			var sdo:FLVTagScriptDataObject = new FLVTagScriptDataObject();
			var metaInfo:Object = new Object();
			LiveVodConfig.DURATION = metaInfo.duration = this._initData.totalDuration;
			
			if(!_initData.hasOwnProperty("videoHeight"))
			{
				_initData.videoHeight = 352;
				_initData.videoWidth  = 640;	
			}
			metaInfo.height = _initData.videoHeight;
			metaInfo.width  = _initData.videoWidth;	
			
			LiveVodConfig.DATARATE=Math.round(_initData.totalSize*8/_initData.totalDuration/1024);
			LiveVodConfig.SET_MEMORY_TIME();
			
			sdo.objects = ["onMetaData", metaInfo];
			var bytes:ByteArray = new ByteArray;
			sdo.write(bytes);
			attemptAppendBytes(bytes);
			if (client)
			{
				var methodName:* = sdo.objects[0];
				var methodParameters:* = sdo.objects[1];
				if (client.hasOwnProperty(methodName))
				{
					client[methodName](methodParameters);
				}
			}
			
			if(_isFirst)
			{
				_isFirst = false;
				seek(LiveVodConfig.ADD_DATA_TIME);
				P2PDebug.traceMsg(this,"isFirst seek:"+LiveVodConfig.ADD_DATA_TIME);
				
				dispatchEventFun("Stream.Play.Start");
			}
			_mainTimer.start();
		}
		private var _isFirst:Boolean = true;

		
		private function onLoop(evt:TimerEvent):void
		{
			outTime++;
			if(outTime>=10)
			{
				outTime=0;
				Statistic.getInstance().timeOutput(this.currentFPS);
			}

			if (_currentBytes == null || _currentBytes.bytesAvailable ==0)
			{
				_currentBytes.clear();
				fetchData();
			}
			//
			
			if (input != null && input.bytesAvailable>0)
			{
				if(_fileHandler == null)
				{
					_fileHandler = new HTTPStreamingMP2TSFileHandler();
				}
				//
//				P2PDebug.traceMsg(this,"_currentBytes:"+_currentBytes.bytesAvailable,_currentBytes.length,_currentBlock.id,_currentBlock.size);
				var buff:ByteArray = _fileHandler.processFileSegment(input);
				
				if(buff!=null)
				{
					processAndAppend(buff);
				}
			}
			/*trace(this,"_currentBytes : "+(_currentBytes == null)?"true":"false");
			trace(this,"_currentBytes.bytesAvailable : "+_currentBytes.bytesAvailable);*/
			if (_currentBytes == null || _currentBytes.bytesAvailable<188)
			{
				//dur-dur/length*0.5
				/*trace(this,"_currentBlock.id : "+_currentBlock.id);
				trace(this,"LiveVodConfig.LAST_TS_ID : "+LiveVodConfig.LAST_TS_ID);
				trace(this,"_currentPiece.id : "+_currentPiece.id);
				trace(this,"_currentBlock.pieces.length-1 : "+(_currentBlock.pieces.length-1));
				trace(this,"this.bufferLength : "+this.bufferLength);
				trace(this,"time : "+time);
				trace(this,"DURATION : "+LiveVodConfig.DURATION);
				trace(this,"(time-LiveVodConfig.DURATION) : "+Math.abs(time-LiveVodConfig.DURATION));*/
				if( _currentBlock
					&& _currentBlock.id == LiveVodConfig.LAST_TS_ID
					&& _currentPiece.id == (_currentBlock.pieces.length-1)
					&& this.bufferLength < 0.3
					&& Math.abs(time-LiveVodConfig.DURATION)<0.5
				)
				{
					notifyPlayStop();
				}
			}
		}
		private var flag_off:int = 1;
		private function fetchData():void
		{
			Statistic.getInstance().bufferTime(this.bufferTime,this.bufferLength,_adRemainingTime,_initData.getAdRemainingTime());
			if(_isLastData){return;}
			var tmpBlock:Block;
			var tmpBlockID:Number;

			if(this.bufferLength > 20)
			{
				return;
			}
			if(_currentBytes==null || _currentBytes.bytesAvailable==0)
			{
				if(_currentBlock == null)
				{
					tmpBlockID=_dispather.getBlockId(LiveVodConfig.ADD_DATA_TIME);
					if(tmpBlockID==-1)
					{
						if(_isShowSeekIcon)
						{
							notifyShowIcon();
						}
						return;
					}
					tmpBlock=_dispather.getBlock(tmpBlockID);
					LiveVodConfig.ADD_DATA_TIME = tmpBlock.id;
					_currentBlock=tmpBlock;
					_currentPiece=tmpBlock.getPiece(0);
					
				}
				if(_currentBlock && _currentPiece && _currentPiece.isChecked && _currentPiece.getStream().length>0)
				{
					if(_currentBytes == null)
					{
						_currentBytes = new ByteArray();
					}
					_currentBytes.clear();
					_currentBytes.writeBytes(_currentPiece.getStream());
					_currentBytes.position=0;
					input = _currentBytes;
					_fileHandler.beginProcessFile();
					
					Statistic.getInstance().setPlayHead(String(_currentBlock.id)+"_"+_currentPiece.id);
					P2PDebug.traceMsg(this,String(_currentBlock.id)+"_"+_currentPiece.id+" "+time);
					
					if(_currentBlock.id == LiveVodConfig.LAST_TS_ID && _currentPiece.id == (_currentBlock.pieces.length-1))
					{
						_isLastData=true;
					}
					
					if(_currentBlock && _currentPiece && _currentPiece.id == (_currentBlock.pieces.length-1))
					{
						tmpBlock =_dispather.getNextSeqID(_currentBlock.sequence);
						if(tmpBlock)
						{
							LiveVodConfig.ADD_DATA_TIME = tmpBlock.id;
							P2PDebug.traceMsg(this,"tmpBlock.id:"+tmpBlock.id);
							_currentBlock=tmpBlock;
							_currentPiece=_currentBlock.getPiece(0);
						}
					}else
					{
						_currentPiece=_currentBlock.getPiece(_currentPiece.id+1);
					}
					
					if(!_seekDataOK)
					{
						_seekTimeRecord = _currentBlock.id;
						_seekDataOK = true;
					}
				}else
				{
					if(_isShowSeekIcon)
					{
						notifyShowIcon();
					}
				}
			}
		}
		
		private function notifyShowIcon():void
		{
			_isShowSeekIcon=false;
			P2PDebug.traceMsg(this,"Stream.Seek.ShowIcon");
			if(_isFull){return;}
			dispatchEvent(
				new NetStatusEvent( 
					NETSTREAM_PROTOCOL.STREAM_STATUS
					, false
					, false
					, {code:"Stream.Seek.ShowIcon", level:"status"}
				)
			);
		}
		
		private var isNotifyPlayStop:Boolean=false;
		private function notifyPlayStop():void
		{
			trace(this,"isNotifyPlayStop : "+isNotifyPlayStop)
			if(!isNotifyPlayStop)
			{
				isNotifyPlayStop=true;
			}else
			{
				return;
			}
			if(_mainTimer && _mainTimer.running)
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
			P2PDebug.traceMsg(this,"code:"+code)
			switch (code)
			{				
				/*case "NetStream.Play.Start":
					dispatchEventFun("Stream.Play.Start");
					break;*/	
				case "NetStream.Buffer.Empty" :
					_isFull=false;
					endHandler();
					dispatchEventFun("Stream.Buffer.Empty");
					break;
				case "NetStream.Buffer.Full" :
					_isFull=true;
					dispatchEventFun("Stream.Buffer.Full");
					//dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,_eventObj));
					break;
				case "NetStream.Pause.Notify" :
					dispatchEventFun("Stream.Pause.Notify");
					break;
				case "NetStream.Unpause.Notify" :
					dispatchEventFun("Stream.Unpause.Notify");
					break;
				case "NetStream.Seek.Notify" :					
				case "NetStream.Seek.Failed":
				case "NetStream.Seek.InvalidTime":
					_seekOK = true;
//					setLoop(true);
					if(!_mainTimer.running)
					{
						_mainTimer.start();
					}
					break;
			}
			
		}
		
		private var _eventObj:Object = new Object();
		private function dispatchEventFun(code:String):void
		{
			_eventObj.code = code;
			dispatchEvent(new NetStatusEvent(NETSTREAM_PROTOCOL.STREAM_STATUS,false,false,_eventObj));	
		}
		
		private function endHandler():void
		{
			if( _seekOK && _currentBlock
				&& _currentBlock.id == LiveVodConfig.LAST_TS_ID
				&& _currentPiece.id == (_currentBlock.pieces.length-1)
				&& this.bufferLength < 0.3
				&& Math.abs(time-LiveVodConfig.DURATION)<0.5
			)
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
		public function get version():String
		{
			return LiveVodConfig.VERSION;
		}
		
		protected function getSHA1Code(str:String):String
		{							
			var enc:sha1Encrypt = new sha1Encrypt(true);
			var strSHA1:String = sha1Encrypt.encrypt(str);
			return strSHA1;
		}
		override public function get time():Number
		{
			if(_seekTimeRecord+super.time>=LiveVodConfig.DURATION)
			{
				return LiveVodConfig.DURATION;
			}
			return _seekTimeRecord+super.time;
		}
//		
		private function getTime():String
		{
			return " "+(new Date).time;
		}
		/**关闭*/
		override public function close():void
		{
			P2PDebug.traceMsg(this,"close");
			super.close();
			clear();
			//
		}
		
		protected function clear():void
		{
			_mainTimer.stop();
			_mainTimer.removeEventListener(TimerEvent.TIMER,onLoop);
			_mainTimer=null;
			
			if(this.hasEventListener(NetStatusEvent.NET_STATUS))
			{
				this.removeEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS);
			}
			
			Statistic.getInstance().removeEventListener();
			_isFirst=true;
			_isShowSeekIcon = false;
			_isFull = false;
			_dispather.clear();
			_initData=null;
			_dispather=null;
			LiveVodConfig.CLEAR();
			
			_adRemainingTime = 0;
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
			return this._dispather;
		}
	}
}