package com.p2p.core
{
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.core.ClientObject;
	import com.p2p.data.vo.VodConfig;
	import com.p2p.events.DataManagerEvent;
	import com.p2p.events.MetaDataLoaderEvent;
	import com.p2p.events.P2PNetStreamEvent;
	import com.p2p.events.P2PNetStreamLocalEvent;
	import com.p2p.kernelReport.KernelReport;
	import com.p2p.loaders.ConnectSocket;
	import com.p2p.loaders.MetaDataLoader;
	import com.p2p.log.P2PStatisticData;
	import com.p2p.managers.DataManager;
	import com.p2p.utils.Base64;
	import com.p2p.utils.TraceMessage;
	import com.p2p.utils.json.JSONDOC;
	import com.p2p.utils.sha1Encrypt;
	
	import com.p2p.utils.ArrayClone;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.System;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import protocol.Protocol;
	
	public class P2PNetStream extends NetStream
	{
		static public const P2P_SERVER:String = "http://p2p.letv.com/";
		protected var _connection:NetConnection;
		protected var _priority:uint = 1;
		
		protected var _statisticData:P2PStatisticData;
		protected var _manager:DataManager = null;
		protected var _timer:Timer;
		
		protected var _bufferDetection:int=0;//缓冲检测，如果超过2次就播放下一个数据
		protected var _time:Number;
		protected var _duration:Number;
		protected var _seekToTimeOnStart:Number;
		protected var _oldBufferTime:Number;
		
		protected var _bytesTotal:Number;
		protected var _byteArrayIndex:Number;
		protected var _numChunks:uint;
		protected var _chunkSize:uint;
		protected var _sliceOffset:uint;
		
		protected var _metaDataReady:Boolean = false;
		protected var _isSeeking:Boolean;
		protected var _seekOK:Boolean = false;
		protected var _beeDispatched:Boolean = false;
		
		protected var _lastChunkLoaded:Boolean;
		
		protected var _fileTimes:Array;
		protected var _filePositions:Array;
		
		protected var _letvVODInfo:Object;
		protected var _letvVODInfoLoader:URLLoader;
		
		//protected var _version:String = VodConfig.VERSION;
		
		//用于统计p2p下载率
		private var _httpSize:Number = 0;
		private var _p2pSize:Number = 0;
		private var _isPause:Boolean = false;
		
		/**是否显示seek后的图标，如果为true，只要没有获得数据就显示图标，如果为false，有没有数据都不会触发显示图标*/
		private var _isShowSeekIcon:Boolean = false;
		/**
		*lizhuo 0523 20:11 add 接收播放器回调函数，用于查看状态参数,将来扩展使用
		*/
		private var _outMsg:Function;
		private var _callBackObject:Object = new Object(); 
		
		//
		private var _CDNEventCount:int = 0;//记录连接CDN失败次数
		//
		private var _connectSocket:ConnectSocket;
		//
		private var _videoInfoObj:Object;
		//
		/**
		 *lizhuo 0809  add 播放器传入数值_need_CDN_Bytes。
		 * 当从CDN下载字节数大于_need_CDN_Bytes时进行上报，表示CDN连接成功
		 */
		private var _need_CDN_Bytes:int = 0;
		
		//_startTime记录播放器开执行play()方法的时间
		private var _startTime:Number;
		/**
		 * 表示此次播放是否进行智能调度播放测试，单位秒
		 * 如果为此变量正确赋值，则将以此为时间周期上报播放点之后的连续播放秒数，
		 * 并允许播放器停止和恢复p2p的数据上传和下载功能
		 * 当紧急区不满的时候将调用回调方法通知播放器
		 */		
		private var _testSpeed:Number = 0;  
		private var _testSpeedTimer:Timer;
		/**
		 * _P2PReportRecoder
		 * 保存是否已经上报过下列事件，确保只上报一次
		 * 0: P2PNetStream_success
		 * 1：Checksum_Success/Failed 
		 * 2：Selector_Success
		 * 3：Rtmfp_Success
		 * 4：Gather_Success
		 * 5：Load_Success   p2p成功下载第一块数据
		 */		
		private var _P2PReportRecoder:Object = new Object();
		//
		protected var _metaDataLoader:MetaDataLoader;
		//
		public function P2PNetStream()
		{
			//MZDebugger.customTrace(this,Protocol.VERSION,_version,0x0000ff);
			_connection = new NetConnection();
			_connection.connect(null);
			super(_connection);
			
			this.bufferTime = 3;
			
			_manager = new DataManager();
			_manager.addEventListener(DataManagerEvent.STATUS,_manager_STATUS);
			
			_statisticData=new P2PStatisticData();					
			
			_timer = new Timer(200);
			_timer.addEventListener(TimerEvent.TIMER,_timer_TIMER);
			
			super.client = new ClientObject();
			super.client.metaDataCallBackFun = onMetaData;
			
			this.addEventListener(NetStatusEvent.NET_STATUS, _this_NET_STATUS, false, _priority);
			
			//----------------------------设置内部监控上报
			KernelReport.SET_INFO(VodConfig.VERSION,"vod");	        
			//----------------------------
		}
		public function getManager():DataManager
		{
			return _manager;
		}
		public function getStatisticData():Object
		{
			return _statisticData.getStatisticData();
		}
		/**
		 *lizhuo 0516 17:19 add 读取版本号接口 目前该接口提供给乐俱页面与pc客户端使用
		 */
		public function get version():String
		{
			return VodConfig.VERSION;
		}
		
		public function set need_CDN_Bytes(b:int):void
		{
			_need_CDN_Bytes = b;
		}
		
		public function set_CDN_URL(arr:Array):void
		{
			if(arr.length>0
				&& _videoInfoObj
				&& _videoInfoObj.hasOwnProperty("flvURL"))
			{
				//_videoInfoObj["flvURL"] = arr.concat();
				_videoInfoObj["flvURL"] =  ArrayClone.Clone(arr)/*arr*/;
				_manager.arrayFLVURL = ArrayClone.Clone(arr);
				trace(this,"change = "+_videoInfoObj["flvURL"])
				_manager.arrayFLVURLIndex = 0;
			}
		}
		//------------lizhuo 0531 12:24 add  该接口提供给主站播放器使用
		
		public function set outMsg(fun:Function):void
		{
			if(fun is Function)
			{
				_outMsg = fun;
				_outMsg.call(null,VodConfig.VERSION,"version");
			}
			else
			{
				_outMsg = null;
			}			
		}
		
		public function set callBack(obj:Object):void
		{
			_callBackObject[obj.key] = obj;
			
		}
		/**
		 *由播放器调用，恢复P2P下载和传输数据功能 
		 */		
		public function resumeP2P():Boolean
		{		
			if(_testSpeed>0 && _manager)
			{
				_manager.resumeP2P();
				return true;
			}
			return false;
		}
		/**
		 *由播放器调用, 暂停P2P下载和传输数据功能 
		 */	
		public function pauseP2P():Boolean
		{
			if(_testSpeed>0 && _manager)
			{
				_manager.pauseP2P();
				return true;
			}
			return false;
		}
		protected function callBackFunction(obj:Object):void
		{
			for each ( var i:* in _callBackObject)
			{			  
				i.fun.call(null,obj);
			}
		}
			
		override public function play(...arguments):void
		{
			/*
			 * 
			config.flvURL    = flvURL ;    //包含flv地址的数组 Array
			config.groupName = groupName ; //播放视频的组名称字符串 String
			config.checkURL  = checkURL ;  //flv文件的验证码地址 String
			config.startTime = startTime ; //开始播放时间 Number （可选）
			*/
			close();
			_isPause = false;
			super.play(null);
			
			_oldBufferTime = this.bufferTime;			
			_seekToTimeOnStart = 0;
			//
			_videoInfoObj = new Object();
			_videoInfoObj = arguments[0];
			_videoInfoObj["flvURL"] = supportP2P(arguments[0]["flvURL"]);
			//_videoInfoObj["cnod"]   = getCnode(_videoInfoObj["flvURL"]);
			//_videoInfoObj["xmlsocket"] = getPolicyFileURL(_videoInfoObj["flvURL"]);
			//
			if(_videoInfoObj["startTime"])
			{
				_seekToTimeOnStart = _videoInfoObj["startTime"] > 0 ? _videoInfoObj["startTime"] : 0;
			}			

			for(var i:String in _videoInfoObj)
			{
				TraceMessage.tracer("--P2P核心--"+i+"   "+_videoInfoObj[i]);
			}				
			/************************************************/
			if(arguments[0]["testSpeed"])
			{
				_testSpeed = Number(arguments[0]["testSpeed"])>0 ? Number(arguments[0]["testSpeed"]) : 0;
			}
			else
			{
				_testSpeed = 0;
			}			
			/************************************************/
			realPlay();
			
			if(_outMsg != null)
			{				
				_outMsg.call(null, _videoInfoObj.groupName, "groupName");		
			}
			//
			var object:Object = new Object();
			object.name = "groupName";
			object.info = _videoInfoObj.groupName;
			callBackFunction(object);
			//
			//MZDebugger.customTrace(this,"groupName : ",_videoInfoObj.groupName);
			//
			var testObj:Object = new Object();
			testObj.name = "groupName";
			testObj.info = _videoInfoObj.groupName; 
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_STATUS,testObj));
			
			//----------------------------设置内部监控上报
			KernelReport.gID = _videoInfoObj["groupName"];
			var obj:Object = new Object();
			obj["act"] = 0;
			obj["error"] = 0;
			dispatchP2PReportEvent(obj,"P2PNetStream_success");
			//----------------------------
			
			//-----lz add 播放前先判断是否可访问843
			/*clearSocket();
			_connectSocket = new ConnectSocket();
			_connectSocket.addEventListener(DataManagerEvent.STATUS,socketSuccess);
			_connectSocket.addEventListener(DataManagerEvent.ERROR,socketFailed);			
			_connectSocket.start(_videoInfoObj["flvURL"][0]);*/	
			
			_manager.startTime = (new Date()).time;
			
			//
			if(_outMsg != null)
			{
				_outMsg.call(null,"--P2P核心--start play :  url:"+arguments[0]+"  groupName:"+arguments[1]+"  checkURL:"+arguments[2]+"  startTime:"+arguments[3]);
								
			    _outMsg.call(null, _videoInfoObj.geo, "geo");		
				
			}				
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
				if(result[3].lastIndexOf(".")>0)
				{
					result[3]=result[3].substr(0,result[3].lastIndexOf("."));
				}
				return result[3];
			}
			return tempUrl;
		}
		override public function resume():void
		{
			_isPause = false;
			/**lz 0524 add*/
			_manager.adTime = 0;
			/**************/
			super.resume();
			TraceMessage.tracer("--P2P核心--resume");
		}
		
		override public function pause():void
		{
			_isPause = true;
			super.pause();
			TraceMessage.tracer("--P2P核心--pause");
		}
		/**
		 * 停止播放流上的所有数据，将 time 属性设置为 0，并使该流可用于其他用途。
		 * */
		override public function close():void
		{
			super.close();
			reset();
		}
		/**
		 * 搜索与指定位置最接近的关键帧（在视频行业中也称为 I 帧）。
		 * */
		override public function seek(offset:Number):void
		{
			if ( /*_seekToTimeOnStart == -1  &&*/ _metaDataReady)
			{
				_isShowSeekIcon=true;
				_seekToTimeOnStart = offset;
				seekTo(_seekToTimeOnStart);
				//_seekToTimeOnStart = -1;
				return;				
			}
		}
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
		{
			if (priority>_priority&&type==NetStatusEvent.NET_STATUS)
			{
				this.removeEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS,false);
				_priority = priority + 1;
				this.addEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS,false,_priority);
			}
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}
		//
		override public function get time():Number
		{
			return _time+(!_isSeeking?super.time:0);
		}
		//
		override public function get bytesLoaded():uint
		{
			if (_metaDataReady)
			{
				var buffertime:Number = _manager.getBuffer(_byteArrayIndex,_filePositions,_fileTimes);
				//var buffertime:uint=getBufferTime(buffer);
				var loaded:Number=buffertime/_duration;
				return uint(loaded*_bytesTotal);
			}
			else
			{
				return 0;
			}
		}
		
		/**
		 * 正加载到应用程序中的文件的总大小（以字节为单位）。
		 * */
		override public function get bytesTotal():uint
		{
			return _bytesTotal;
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
		/**
		 * 查询flv数组将乐视的（p2p=1）CDN保留并返回
		 * @param arr
		 * @return 
		 * 
		 */		
		protected function supportP2P(arr:Array):Array
		{
			var tempArray:Array = new Array();
			for(var i:int=0 ; i<arr.length ; i++)
			{
				var str:String = arr[i];
				if(str.indexOf("p2p=1") != -1)
				{
					tempArray.push(arr[i]);
				}
			}
			return tempArray;
		}	
		/*protected function getCnode(arr:Array):Array
		{
			var tempArray:Array = new Array();
			for(var i:int=0 ; i<arr.length ; i++)
			{
				var str:String = arr[i];
				if(str.indexOf("gn=") != -1)
				{
					var start:int = str.indexOf("gn=")+3;
					var end:int   = str.indexOf("&",start);
					if(end==-1)
					{
						end = str.length;
					}
					tempArray.push(str.substring(start,end));
				}
			}
			return tempArray;
		}*/
		//---------------------------------------lz add 
		/*protected function socketSuccess(e:DataManagerEvent):void
		{			
			clearSocket();
			
			//
			realPlay();
			
			if(_outMsg != null)
			{				
				_outMsg.call(null, _videoInfoObj.groupName, "groupName");		
			}
			//
			var object:Object = new Object();
			object.name = "groupName";
			object.info = _videoInfoObj.groupName;
			callBackFunction(object);
			//
			var testObj:Object = new Object();
			testObj.name = "groupName";
			testObj.info = _videoInfoObj.groupName; 
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_STATUS,testObj));
			
			trace("--P2P核心--socketSuccess")
		}		
		protected function socketFailed(e:DataManagerEvent):void
		{
			clearSocket();
			
			var obj:Object  = new Object();
			obj.allCDNFailed = 1;			
			obj.sockStatus   = "Failed";
			obj.code         = "Stream.Play.Failed";	
			
			dispatchPlayFailedEvent(obj,"securityError");	
			
			trace("--P2P核心--socketFailed");
		}
		protected function clearSocket():void
		{			
			if (_connectSocket)
			{
				_connectSocket.removeEventListener(DataManagerEvent.STATUS,socketSuccess);
				_connectSocket.removeEventListener(DataManagerEvent.ERROR,socketFailed);
				//_connectSocket.clear();
				_connectSocket = null;
			}
			
		}*/
		//-------------------------------------------
		
		protected function realPlay():void
		{	
			//_seekToTimeOnStart = 250;
			this["appendBytesAction"]("resetBegin");
			_metaDataLoader = new MetaDataLoader(128*1024);
			_metaDataLoader.addEventListener(MetaDataLoaderEvent.LOAD_METADATA_STATUS,metaDataLoaderStatus);
			_metaDataLoader.start(_videoInfoObj.flvURL as Array, 1, 1,_need_CDN_Bytes);
		}
		protected function metaDataLoaderStatus(e:MetaDataLoaderEvent):void
		{
			//trace("e.info.codee.info.code = "+e.info.code)
			var obj:Object = new Object();
			if(e.info.code == MetaDataLoaderEvent.LOAD_METADATA_SUCCESS)
			{
				obj.fileSize = e.info.size;
				obj.metaDataArray = e.info.byteArray;
				obj.metaData = e.info.metaData;
				
				obj.text = e.info.code;
				obj.url = e.info.url;
				obj.utime = e.info.utime;
				obj.retry = e.info.retry;
				obj.node = "-";
				
				obj.error = 0;
				obj.ksp = 1;
				
				_duration      = obj.metaData.duration;
				_fileTimes     = obj.metaData.keyframes.times as Array;
				_filePositions = obj.metaData.keyframes.filepositions as Array;
				
				if(_bytesTotal == 0) 
				{
					_chunkSize = 128 * 1024;
					_bytesTotal = obj.fileSize;
					_numChunks=uint(Math.ceil(_bytesTotal/_chunkSize));	
					_videoInfoObj.filesize = _bytesTotal;
					_videoInfoObj.chunksnumber = _numChunks;
					
					/**lz 0613 add*/
					_videoInfoObj.duration = _duration;
					
					var object:Object = new Object();
					object.name = "size";
					object.info = Math.ceil(_bytesTotal/1024);
					callBackFunction(object);
					//
					//MZDebugger.customTrace(this,Protocol.SIZE,object.info);
					//
					object.name = "chunks";
					object.info = _numChunks;
					callBackFunction(object);
					//
					//MZDebugger.customTrace(this,Protocol.CHUNKS,object.info);
					//
					_videoInfoObj.urgenceBufferSize = Math.ceil((_bytesTotal / _duration)*30 / _chunkSize);
					_videoInfoObj.kbps = obj.metaData.videodatarate;
					/**
					 * 判断是否支持在播放广告时开启P2P加载
					 * 当存在广告剩余时间变量并且广告剩余时间大于 5秒 时才开启P2P优先加载
					 * */
					if( _videoInfoObj.adRemainingTime                        //当存在广告剩余时间变量
						&& (_videoInfoObj.adRemainingTime*1000-obj.utime)>5*1000  //当广告剩余时间大于5秒
						)
					{
						_videoInfoObj.adRemainingTime = _videoInfoObj.adRemainingTime*1000-obj.utime;
					}
					else
					{
						_videoInfoObj.adRemainingTime = 0;
					}
					/**************************/
					_manager.setInit(_videoInfoObj);
					FakeseekTo(_seekToTimeOnStart);
					
					//
					this["appendBytesAction"]("resetBegin");
					this["appendBytes"](obj.metaDataArray as ByteArray);
					
					_metaDataReady = true;	
					_timer.start();
					_statisticData.setInitTime(this,_numChunks);
					/******************************************************/
					if(_testSpeed > 0)
					{
						if(_testSpeed<10)
						{
							_testSpeed = 10;
						}
						_testSpeedTimer = new Timer(_testSpeed*1000);
						_testSpeedTimer.addEventListener(TimerEvent.TIMER,testSpeedTimerHandler);
						_testSpeedTimer.start();
					}
					/******************************************************/
				}
				
				_metaDataLoader.removeEventListener(MetaDataLoaderEvent.LOAD_METADATA_STATUS,metaDataLoaderStatus);
				_metaDataLoader.close();
				
				dispatchPlayStartEvent(obj);
				
				if(_outMsg != null)
				{
					_outMsg.call(null,Math.round(_bytesTotal/(1024*1024)),"totalSize");	
				}/**/
			}
			else if(e.info.code == MetaDataLoaderEvent.NEED_CDN_BYTES_SUCCESS)
			{
				obj.url = e.info.url;
				obj.utime = e.info.utime;
				obj.retry = e.info.retry;
				obj.node = "-";				
				obj.error = 0;
				obj.ksp = 1;
				
				dispatchNeedBytesSuccess(obj);
			}
			else
			{
				this["appendBytesAction"]("resetBegin");
				_bytesTotal = 0;
				
				
				obj.text = e.info.code;
				obj.allCDNFailed = e.info.allCDNFailed;
				//obj.allCDNFailed = 1;
				obj.retry = e.info.retry;
				obj.utime = e.info.utime;
				obj.url = e.info.url;
				obj.node = "-";
				
				obj.ksp = 1;	
				obj.text = String(e.info.text);
				
				if(obj.allCDNFailed == 1)
				{
					_metaDataLoader.removeEventListener(MetaDataLoaderEvent.LOAD_METADATA_STATUS,metaDataLoaderStatus);
					_metaDataLoader.close();
				}
				
				if (String(e.info.code)=="ioError")
				{						
					obj.error = 505;
					dispatchPlayFailedEvent(obj,"ioError");
				}
				else if (String(e.info.code)=="securityError")
				{					
					obj.error = 506;
					dispatchPlayFailedEvent(obj,"securityError");
				}					
				else if (String(e.info.code)=="timeoutError")
				{					
					obj.error = 501;
					dispatchPlayFailedEvent(obj,"timeoutError");
				}
				else
				{
					obj.error = 909;
					dispatchPlayFailedEvent(obj);
				}
				return ;
			}
			
			
		}
		protected function onMetaData(obj:Object = null):void
		{
			if (_metaDataReady)
			{
				return ;
			}
			_metaDataReady = true;				
			TraceMessage.tracer("--P2P核心--onMetaData");
		}
		
		protected function reset():void
		{
			if(_timer)
				_timer.stop();
						
			if (_manager)
				_manager.clear();
			
			if(_statisticData != null)
				_statisticData.clear();
			
			if(_metaDataLoader && _metaDataLoader.hasEventListener(MetaDataLoaderEvent.LOAD_METADATA_STATUS))
			{
				_metaDataLoader.removeEventListener(MetaDataLoaderEvent.LOAD_METADATA_STATUS,metaDataLoaderStatus);
				_metaDataLoader.close();
				_metaDataLoader = null;
			}
			
			//clearSocket();
			_bufferDetection=0
			_time = 0;
			_oldBufferTime = 0;
			_seekToTimeOnStart = 0;
			_bytesTotal = 0;
			_byteArrayIndex = 0;
			_numChunks = 0;
			_chunkSize = 0;
			_sliceOffset = 0;
			_metaDataReady = false;
			_isSeeking = false;
			_seekOK    = false;
			_beeDispatched = false;
			_lastChunkLoaded = false;
			
			_duration = 0;
			_fileTimes = null;
			_filePositions = null;
			
			_letvVODInfo = null;
			
			_httpSize = 0;
			_p2pSize = 0;
			
			_CDNEventCount = 0;
			
			_P2PReportRecoder = new Object();
			
			_testSpeed = 0;
			if(_testSpeedTimer)
			{
				_testSpeedTimer.stop();
				_testSpeedTimer.removeEventListener(TimerEvent.TIMER,testSpeedTimerHandler);
				_testSpeedTimer = null;
			}
			
		}
		protected function FakeseekTo(offset:Number):void
		{			
			var frame:Object = getFrameByTime(offset);
			if (frame == null)
				return;
			//
			_time            = Number(frame.time);
			_sliceOffset     = uint(uint(frame.position) % _chunkSize);
			_byteArrayIndex  = uint(Math.floor(uint(frame.position) / _chunkSize));
			_lastChunkLoaded = false;
			_isSeeking       = true;
			_seekOK          = true;
			_manager.seek(_byteArrayIndex);
			//super.seek(0);
			//this["appendBytesAction"]("resetBegin");
			//seek(0);
			//dispatchSeekCompleteEvent
			//super.seek(_time);
			//dispatchSeekStartEvent();
			
		}
		protected function seekTo(offset:Number):void
		{			
			var frame:Object = getFrameByTime(offset);
			if (frame == null)
			{
				frame = getFrameByTime(this.time);
				if (frame == null)
					return;
			}
			//
			_time            = Number(frame.time);
			_sliceOffset     = uint(uint(frame.position) % _chunkSize);
			_byteArrayIndex  = uint(Math.floor(uint(frame.position) / _chunkSize));
			_lastChunkLoaded = false;
			_isSeeking       = true;
			_seekOK          = false;
			_beeDispatched   = false;
			//
			_manager.seek(_byteArrayIndex);			
			dispatchSeekStartEvent();
			//super.seek(_time);
			super.seek(0);
			//seek(0);
			//dispatchSeekCompleteEvent();
			//_seekOK = 
			TraceMessage.tracer("--P2P核心--seekTo  time="+time+", byteArrayIndex="+_byteArrayIndex);
			
			
		}
		//获取某个时间点前面一个关键帧
		protected function getFrameByTime(time:Number):Object
		{
			//the time should not be exceed
			if(time > _duration - this.bufferTime)
			{
				time = _duration - this.bufferTime;
			}
			// yjqi edit 2012.05.07
			var obj:Object=new Object();
			var len:int = _fileTimes.length-1;
			obj.time = _fileTimes[0];
			obj.position = _filePositions[0];
			for (var i:int=len; i>0; i--)
			{
				if (_fileTimes[i-1] <= time)
				{
					obj.time = _fileTimes[i - 1];
					obj.position = _filePositions[i - 1];
					if(i<len){//数组边界判断
						if(Math.abs(_fileTimes[i-1]- time)>Math.abs(_fileTimes[i]- time)){//seek找最近的关键帧
							obj.time = _fileTimes[i];
							obj.position = _filePositions[i];
						}
					}
					return obj;
					
				}
			}
			//
			return null;
		}
		protected function seekToNextKeyFrame(offset:Number):void
		{
			
			var frame:Object = getNextFrameByTime(offset);
			if (frame == null)
			{
				frame = getNextFrameByTime(this.time);
				if (frame == null)
					return;
			}
			//
			_time            = Number(frame.time);
			_sliceOffset     = uint(uint(frame.position) % _chunkSize);
			_byteArrayIndex  = uint(Math.floor(uint(frame.position) / _chunkSize));
			_lastChunkLoaded = false;
			_isSeeking       = true;
			_seekOK          = false;
			_manager.seek(_byteArrayIndex);
			
			dispatchSeekStartEvent();
			super.seek(0);	
			//_seekOK = true;
			//dispatchSeekCompleteEvent();
			
		}
		//获取某个时间点前面一个关键帧
		protected function getNextFrameByTime(time:Number):Object
		{
			var obj:Object = new Object();
			var len:int    = _fileTimes.length-1;
			obj.time       = _fileTimes[0];
			obj.position   = _filePositions[0];
			for (var i:int = len; i>0; i--)
			{
				if (_fileTimes[i-1] <= time)
				{
					
					if (i >= 0 && i <= len)
					{
						obj.time     = _fileTimes[i];
						obj.position = _filePositions[i];
						return obj;
					}else
					{
						obj.time     = _fileTimes[i - 1];
						obj.position = _filePositions[i - 1];
						return obj;
					}
					//	
				}
			}
			//
			return null;
		}
		
		private function getPolicyFileURL(arr:Array):Array
		{
			var arr1:Array = new Array();
			for(var i:int = 0 ; i<arr.length ; i++)
			{
				var str:String = doRegExp(arr[i]);
				arr1.push(str);
			}
			
			return arr1;
		}
		private function doRegExp(str:String):String
		{
			var regExp:RegExp = /\d+\.\d+\.\d+\.\d+/g;
			regExp.lastIndex = 7;
			var obj:Object = regExp.exec(str);
			if (obj)
			{
				return "xmlsocket://"+String(obj["0"])+":843";
			}
			else
			{
				return "";
			}
		}
		
		/*protected function getVideoInfo(flvURL:Array,groupName:String,checkURL:String,xmlsocket:Array):Object
		{
			var obj:Object=new Object();
			obj.flvURL = flvURL;
			obj.groupName = groupName;
			obj.checkURL = checkURL;
			obj.xmlsocket = xmlsocket;
			
			TraceMessage.tracer("--P2P核心--checkURL   "+checkURL);
			TraceMessage.tracer("--P2P核心--groupName   "+groupName);
			
			return obj;
		}*/
		//---------------------------------------
		protected function _timer_TIMER(event:TimerEvent):void
		{
			if (_lastChunkLoaded || !_metaDataReady)
				return ;
			//
			var object:Object = new Object();//回调发送数据对象
			//
			object.name = "chunkIndex";
			//
			//MZDebugger.customTrace(this,Protocol.MEMORY,""+System.totalMemory,0x0000ff);
			
			_manager.adTime -= _timer.delay;
			
			if (_isSeeking)
			{
//				_countBuffer++;
//				if(_countBuffer>5){//累计为1秒，抛出缓冲事件
//					if(!_playBuffering){//如果没有缓冲满将不做任何处理
//						dispatchBufferEmptyEvent();	
//						_playBuffering = true;
//					}
//				}
				if (_seekOK)
				{				
					
					var seekBytes:ByteArray = _manager.readSeekData(_byteArrayIndex, _sliceOffset);				
					
					if (seekBytes)
					{
						//
						_CDNEventCount = 0;
						//
						if(this.bufferTime <= 0.1)
						{
							this.bufferTime = _oldBufferTime;
						}
						this["appendBytesAction"]("resetSeek");
						if(_duration - this.time <= this.bufferTime)
						{
							TraceMessage.tracer("--P2P核心--isSeeking, _duration-time <= bufferTime   ,(_duration-time)="+(_duration-this.time)+", bufferTime="+this.bufferTime);
							
							this.bufferTime = 0.1;
							//dispatchBufferFullEvent();
						}
						this["appendBytes"](seekBytes);
						_byteArrayIndex += 2;
						/*if (_sliceOffset > 50* 1024)
						{
						_byteArrayIndex += 2;
						}else
						{
						_byteArrayIndex += 1;
						}*/
						//
						object.info = _byteArrayIndex;
						//lz							
						callBackFunction(object);
						
						//MZDebugger.customTrace(this,Protocol.CHUNKINDEX,object.info);
						if (_byteArrayIndex >= _numChunks)
						{
							_byteArrayIndex  = _numChunks -1;
							_lastChunkLoaded = true;
							TraceMessage.tracer("--P2P核心--isSeeking, _byteArrayIndex >= _numChunks, _lastChunkLoaded = true");
						}
						_isSeeking = false;
						_seekOK = false;
					}else{
						if(_isShowSeekIcon){
							//trace("没有数据显示图标");
							_isShowSeekIcon=false;
							var info:Object=new Object();
							info.code = "Stream.Seek.ShowIcon";
							dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
						}
					}
				}
				return ;
			}
//			_countBuffer=0;//不是seek该值恢复为0
			
			var tmp:Number = bufferLength;	
			if (this.bufferLength < this.bufferTime + 1)
			{				
				tmpBufferLength = 0;
				tmpBufferLengthCount = 0;
				//
				var bytes:ByteArray = _manager.readByteArray(_byteArrayIndex);
				if (bytes)
				{	
					//
					_CDNEventCount = 0;
					//
					object.info = _byteArrayIndex;
					callBackFunction(object);
					
					if(this.bufferTime <= 0.1)
					{
						this.bufferTime = _oldBufferTime;
					}
					//trace("_duration = "+_duration+"  time = "+this.time+"   _duration - time = "+(_duration - this.time))
					if(_duration - (this.time+1) <= this.bufferTime)
					{
						//trace("_duration - this.time <= this.bufferTime");
						TraceMessage.tracer("--P2P核心--isSeeking, _duration-time <= bufferTime   ,(_duration-time)="+(_duration-this.time)+", bufferTime="+this.bufferTime);						
						this.bufferTime = 0.1;
						//dispatchBufferFullEvent();
					}
					
					this["appendBytes"](bytes);				
					//
					_byteArrayIndex++;
					if (_byteArrayIndex >= _numChunks)
					{
						_lastChunkLoaded = true;
						TraceMessage.tracer("--P2P核心--_byteArrayIndex >= _numChunks, _lastChunkLoaded = true");
					}
					//
					if (tmp == bufferLength && _metaDataReady)
					{
						_bufferDetection++;
						if(_bufferDetection==2){
							seekToNextKeyFrame(this.time);
							return ;
						}
					}else{
						_bufferDetection=0;
					}					
				}else{
					if(_isShowSeekIcon){
						//trace("没有数据显示图标");
						_isShowSeekIcon=false;
						var info1:Object=new Object();
						info1.code = "Stream.Seek.ShowIcon";
						dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info1));
					}
				}					
			}else if (!_isPause)
			{
				if (tmpBufferLength == 0)
				{
					tmpBufferLength = this.bufferLength;
				}
				//
				if (tmpBufferLength == this.bufferLength)
				{
					if (tmpBufferLengthCount > 10)
					{
						tmpBufferLength = 0;
						tmpBufferLengthCount = 0;
						if (_metaDataReady)
						{
							seekToNextKeyFrame(this.time);
							return ;
						}
					}
					//
					tmpBufferLengthCount++;
				}				
			}
			//MZDebugger.customTrace(this,Protocol.BUFFERLENGTH,object.info);
			//MZDebugger.customTrace(this,Protocol.BUFFERTIME,this.bufferTime);
			//MZDebugger.customTrace(this,Protocol.TIME,time);
			//lizhuo 0601 13:35 add
			if(_outMsg != null)
			{
				_outMsg.call(null,String(this.bufferTime+",  bufferLength = "+bufferLength+",  time = "+time),"bufferTime");
				//
			}
			//
			
			object.name = "bufferLength";
			object.info = bufferLength;
			callBackFunction(object);
			//
			//
			object.name = "time";
			object.info = time;
			callBackFunction(object);
			//
			//
			object.name = "bufferTime";
			object.info = bufferTime;
			callBackFunction(object);
			//
			//
			object = null;
			
			//
		}
		private var tmpBufferLength:Number = 0;
		private var tmpBufferLengthCount:uint = 0;
		private var _playBuffering:Boolean = false;
		//
		protected function _this_NET_STATUS(event:NetStatusEvent):void
		{
			var code:String = event.info.code;
			switch (code)
			{
				case "NetStream.Buffer.Empty" :
					if ( _lastChunkLoaded)
					{
						dispatchPlayStopEvent();
					}
					else
					{
//						if(_isSeeking){//如果seek将不不抛出事件
//							
//						}else{
							dispatchBufferEmptyEvent();	
							_playBuffering = true;						
//						}
					}
					break;
				case "NetStream.Buffer.Full" :
//					if(_playBuffering){//只有先缓冲为空或首次的情况才抛出事件
						dispatchBufferFullEvent();
						_playBuffering = false;
//					}
					break;
				case "NetStream.Pause.Notify" :
					dispatchPauseNotifyEvent();
					if(_playBuffering)
						_playBuffering = false;
					break;
				case "NetStream.Unpause.Notify" :
					dispatchUnpauseNotifyEvent();
					break;
				case "NetStream.Seek.Notify" :					
				case "NetStream.Seek.Failed":
				case "NetStream.Seek.InvalidTime":									
					//this["appendBytesAction"]("resetSeek");
					if(_playBuffering)
						_playBuffering = false;
					
					_CDNEventCount = 0;
					
					_seekOK = true;
					dispatchSeekCompleteEvent();
					break;					
			}
		}	
		//
		
		protected function _manager_STATUS(event:DataManagerEvent):void
		{						
			var object:Object = new Object();
			var code:String = event.info.code;
			var obj:Object = new Object();
			
			//此P2PNetStreamLocalEvent事件发给_statisticData，提供数据统计,
			//P2PNetStreamLocalEvent事件不对外公布！！
			if(code.indexOf("gatherConnect") == -1 || code == "P2P.gatherConnect.Success")
			{
				dispatchEvent(new P2PNetStreamLocalEvent(P2PNetStreamLocalEvent.P2P_STATUS, event.info));
			}
			
			switch (code)
			{
				case "P2P.HttpGetChunk.Failed" :	
					//
					//obj.allCDNFailed = event.info.allCDNFailed;
					obj.allCDNFailed =  -1;
					if((_CDNEventCount <= 2) && (_playBuffering || bufferLength == 0))
					{
						_CDNEventCount++;
						obj.retry = _CDNEventCount;
						obj.allCDNFailed = 0;
					}
					//
					if (_CDNEventCount > 2)
					{
						_CDNEventCount = 0;
						obj.retry = 3;
						obj.allCDNFailed = 1;
					}
					
					if (obj.allCDNFailed == -1)
						return;
					//
					obj.url = event.info.url;				
					obj.node = "-";
					
					if(event.info.utime)
					{
						obj.utime =  event.info.utime;
					}else
					{
						obj.utime = 0.1;
					}
					
					obj.ksp = 1;
					obj.text = String(event.info.text);		
					//					
					if (String(event.info.text)=="ioError")
					{
						obj.error = 505;
						dispatchPlayFailedEvent(obj,"ioError");
					}
					else if (String(event.info.text)=="securityError")
					{
						obj.error = 506;
						dispatchPlayFailedEvent(obj,"securityError");
					}
					else if (String(event.info.text)=="timeoutError")
					{
						obj.error = 501;
						dispatchPlayFailedEvent(obj,"timeoutError");
					}
					else if(String(event.info.text)=="CDNError")
					{
						obj.error = 900;
						dispatchPlayFailedEvent(obj,"CDNError");
					}
					else
					{
						obj.error = 909;
						dispatchPlayFailedEvent(obj);
					}
					//
					break;
				case "P2P.selectorConnect.Success":
					//
					dispatchP2PReportEvent(event.info,"selector_success");
					//
					break;
				case "P2P.LoadCheckInfo.Success" :
					object.name = "checkSum";
					//object.info = "OK"+"  njs";
					/*trace(_version);
					trace(VodConfig.VERSION);*/
					object.info = VodConfig.VERSION;
					
					callBackFunction(object);
					//
					dispatchP2PReportEvent(event.info,"checksum_success");
					//
					break;
				case "P2P.LoadCheckInfo.Failed" :
					object.name = "checkSum";
					object.info = "Failed"+"  njs";
					callBackFunction(object);
					//
					dispatchP2PReportEvent(event.info,"checksum_failed");
					//
					break;			
				//------------lizhuo 0531 12:06 add
				case  "P2P.gatherConnect.Start":					
					if(_outMsg != null)
					{
						_outMsg.call(null,String(event.info.gatherName+":"+event.info.gatherPort),"gatherName");
					}
					//
					object.name = "gather";
					object.info = String(event.info.gatherName+":"+event.info.gatherPort);
					callBackFunction(object);
					//
					//MZDebugger.customTrace(this,Protocol.GATHER,String(event.info.gatherName+":"+event.info.gatherPort));
					//
					break;
				case "P2P.gatherConnect.Success":
					if(_outMsg != null)
					{
						_outMsg.call(null,String(event.info.gatherName+":"+event.info.gatherPort+"  OK"),"gatherName");
					}
					object.name = "gatherOk";
					callBackFunction(object);
					dispatchP2PReportEvent(event.info,"gather_success");
					//
					//MZDebugger.customTrace(this,Protocol.GATHER,String(event.info.gatherName+":"+event.info.gatherPort+" (Y)"),0xff0000);
					//
					break;
				case "P2P.gatherConnect.Failed":
					if(_outMsg != null)
					{
						_outMsg.call(null,String(event.info.gatherName+":"+event.info.gatherPort+"  Failed"),"gatherName");
					}
					object.name = "gatherFailed";
					callBackFunction(object);
					//
					//MZDebugger.customTrace(this,Protocol.GATHER,String(event.info.gatherName+":"+event.info.gatherPort+" (N)"));
					//
					break;
				case  "P2P.rtmfpConnect.Start":
					if(_outMsg != null)
					{
						_outMsg.call(null,event.info.rtmfpName,"rtmfpName");
					}
					object.name = "rtmfp";
					object.info = event.info.rtmfpName;
					callBackFunction(object);
					//
					//MZDebugger.customTrace(this,Protocol.RTMFP,event.info.rtmfpName);
					//
					break;
				case "P2P.rtmfpConnect.Success":
					if(_outMsg != null)
					{
						_outMsg.call(null,event.info.rtmfpName+":"+event.info.rtmfpPort+"  OK","rtmfpName");						
						_outMsg.call(null,String(event.info.ID).substr(0,10),"myName");
					}
					object.name = "myPeerID";
					object.info = event.info.ID;
					callBackFunction(object);
					object.name = "rtmfpOk";
					callBackFunction(object);
					//
					dispatchP2PReportEvent(event.info,"rtmfp_success");
					//
					//MZDebugger.customTrace(this,Protocol.RTMFP,event.info.rtmfpName+" (Y)",0xff0000);
					//
					break;
				case "P2P.rtmfpConnect.Failed":
					if(_outMsg != null)
					{
						_outMsg.call(null,event.info.rtmfpName+"  Failed","rtmfpName");
					}
					object.name = "rtmfpFailed";
					callBackFunction(object);
					//
					//MZDebugger.customTrace(this,Protocol.RTMFP,event.info.rtmfpName+" (N)");
					//
					break;
				case "P2P.P2PGetChunk.Success" :					
					if(_outMsg != null)
					{
						_outMsg.call(null,String("p2p get  id = "+event.info.id+"， peerID = "+String(event.info.peerID).substr(0,10)));
						//MZDebugger.customTrace(this,Protocol.PEERID,String(event.info.peerID));
						_p2pSize += _chunkSize;
						_outMsg.call(null,String(Math.round(_p2pSize/(_httpSize+_p2pSize)*10000)/100+"%"),"p2p下载率");
					}
					//
					dispatchP2PReportEvent(event.info,"load_success");
					//
					//
					//MZDebugger.trace(this,"P2P ---> id = "+event.info.id+"， peerID = "+String(event.info.peerID).substr(0,10),"",0x00ff00);
					//
					//
					break;
				case "P2P.HttpGetChunk.Success" :
					
					if(_outMsg != null)
					{
						_outMsg.call(null,String("http get  id = "+event.info.id));
						//
						_httpSize += _chunkSize;
						_outMsg.call(null,String(Math.round(_p2pSize/(_httpSize+_p2pSize)*10000)/100+"%"),"p2p下载率");
						//
					}
					//
					//MZDebugger.trace(this,"Http ---> id = "+event.info.id,"",0x0000ff);
					//
					break;
				case "P2P.Neighbor.Connect":
					if(_outMsg != null)
					{
						if(event.info.dnode)
						{
							_outMsg.call(null,event.info.dnode,"dnode");
						}
						if(event.info.lnode)
						{
							_outMsg.call(null,event.info.lnode,"lnode");
						}						
					}
					object.name = "peerID";
					object.info = event.info.peerID;
					callBackFunction(object);
					break;
				case "P2P.HttpGetChunk.Speed":
					if(_outMsg != null && !event.info.haveSentHttpSpeed)
					{
						_outMsg.call(null,event.info.speed,"speed");
					}
					//trace("---------------speed-------------"+event.info.speed);
					break;
				case "HttpZoneNotFull":
					if(_outMsg != null)
					{
						_outMsg.call(null,"","testSpeedBufferNotFull");
					}
					//trace("---------------HttpZoneNotFull-----------");
					break;
			}
			//
			object = null;
			obj    = null;
		}
		//===================
		protected function dispatchSeekStartEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Seek.Start";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
				
			}
			//MZDebugger.trace(this,"Stream.Seek.Start,time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			//TraceMessage.tracer("--P2P核心--Stream.Seek.Start,time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchSeekCompleteEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Seek.Complete";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
				
			}
			//MZDebugger.trace(this,"--P2P核心--Stream.Seek.Complete,time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			//TraceMessage.tracer("--P2P核心--Stream.Seek.Complete,time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchNeedBytesSuccess(obj:Object):void
		{
			var info:Object=new Object();
			info      = obj;
			info.code = "need_CDN_Bytes_Success";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_STATUS,info));
			//MZDebugger.trace(this,"need_CDN_Bytes_Success","",0xff0000);
		}
		protected function dispatchPlayStartEvent(obj:Object):void
		{				
			var info:Object=new Object();
			info = obj;
			info.code = "Stream.Play.Start";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code);
				
			}
			//MZDebugger.trace(this,"Stream.Play.Start","",0xff0000);
			//TraceMessage.tracer("--P2P核心--Stream.Play.Start");
			//-----------------------
		}
		protected function dispatchPlayStopEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Play.Stop";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code);
				
			}
			//MZDebugger.trace(this,"Stream.Play.Stop","",0xff0000);
			TraceMessage.tracer("--P2P核心--Stream.Play.Stop");
			//-----------------------
		}
		protected function dispatchBufferEmptyEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Buffer.Empty";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
				
			}
			//
			//MZDebugger.trace(this,"--P2P核心--"+info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			//TraceMessage.tracer("--P2P核心--"+info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchBufferFullEvent():void
		{
			_isShowSeekIcon=false;
			var info:Object=new Object();
			info.code = "Stream.Buffer.Full";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
				
			}
			//MZDebugger.trace(this,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			//TraceMessage.tracer("--P2P核心--"+info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchPauseNotifyEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Pause.Notify";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
				
			}
			//MZDebugger.trace(this,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			
			//TraceMessage.tracer("--P2P核心--"+info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		
		protected function dispatchUnpauseNotifyEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Unpause.Notify";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
				
			}
			//MZDebugger.trace(this,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			
			//TraceMessage.tracer("--P2P核心--"+info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}	
		
		protected function dispatchPlayFailedEvent(obj:Object,type:String=null):void
		{
			
			var info:Object=new Object();
			info = obj ; 
			info.code = "Stream.Play.Failed";				
			
			//---------------lz add 当843端口出现问题时			
			if(obj.sockStatus == "Failed")
			{				
				info.url   = _videoInfoObj.flvURL[0];
				info.utime = Math.floor((new Date()).time) - _manager.startTime;
				info.retry = 1;
				info.node  = "-";				
				info.error = 506;
				info.ksp   = 1;
				info.p2pErrorCode = "0000";
				info.allCDNFailed = 1
				dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_All_OVER,info));
				
				if(_outMsg != null)
				{
					_outMsg.call(null,"sock Failed ,utime = "+info.utime);					
				}				
				return ;
			}
			//-----------------------lizhuo 0601 14:06 add
			if(_outMsg != null)
			{
				_outMsg.call(null,""+info.code+","+info.error+","+info.text+",time="+time+",bufferLength="+bufferLength+",bufferTime="+bufferTime+",allCDNFailed="+info.allCDNFailed+",URL="+info.url);
				
			}/**/
			//MZDebugger.trace(this,info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime,"",0xff0000);
			
			//TraceMessage.tracer("--P2P核心--"+info.code+","+info.error+","+info.text+",time="+time+",bufferLength="+bufferLength+",bufferTime="+bufferTime+",allCDNFailed="+info.allCDNFailed+",URL="+info.url);
			//-----------------------
			if(info.allCDNFailed != 1)
			{
				dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			}else
			{
				info.p2pErrorCode = "0000";
				dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_All_OVER,info));
			}			
			
		}
		
		private function dispatchP2PReportEvent(obj:Object,type:String):void
		{
			if(_P2PReportRecoder.hasOwnProperty(type))
			{
				return;
			}
			
			var thisTime:Number = Math.floor((new Date()).time);
			
			var info:Object = new Object();
			info.code  = type;
			//info.act   = obj.act;
			//info.err   = obj.error;
			info.utime = 0;
			
			if(type != "P2PNetStream_success" 
				&& type != "checksum_success" 
				&& type != "checksum_failed")
			{
				info.utime = thisTime - _manager.startTime;
			}
			
			if(type == "checksum_success" || type == "checksum_failed")
			{
				/**关于checksum的加载过程上报时间由checksum内部单独统计*/
				info.utime = obj.utime;
			}
			
			if(type == "gather_success")
			{
				info.ip   = obj.gatherName;
				info.port = obj.gatherPort;
			}
			else if(type == "rtmfp_success")
			{
				info.ip   = obj.rtmfpName;
				info.port = obj.rtmfpPort;
			}
			else
			{
				info.ip   = "0";
				info.port = 0;
			}
			//dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_STATUS,info));
			//----------------------------内部监控上报
			KernelReport.PROGRESS(info);
			//----------------------------
			
			_P2PReportRecoder[type] = type;
			
			if( type != "checksum_success" || type != "checksum_failed" )
			{
				_manager.startTime = thisTime;
			}
						
			
			//trace("核心_____________________info.act = "+info.act+"  utime = "+info.utime+"  error = "+info.err);
		
		}
		private function testSpeedTimerHandler(e:TimerEvent):void
		{
			var time:Number = _manager.getTestSpeedBuffer(_byteArrayIndex);
			//trace("testSpeed--------------------"+time);
			if(_outMsg != null)
			{
				_outMsg.call(null,time,"testSpeedBufferTime");
			}			
		}
	}
}