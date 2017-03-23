package com.p2p.managers
{
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.data.Chunk;
	import com.p2p.data.Chunks;
	import com.p2p.events.*;
	import com.p2p.events.P2PEvent;
	import com.p2p.events.P2PLoaderEvent;
	import com.p2p.loaders.CheckLoader;
	import com.p2p.loaders.HttpLoader;
	import com.p2p.loaders.P2PLoader;
	import com.p2p.loaders.VODDataLoader;
	import com.p2p.utils.CRC32;
	
	import flash.events.*;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import protocol.Protocol;

	public class DataManager extends EventDispatcher
	{
		
		public var chunks:Chunks;
		public var checkXML:XML;
		public var isJoinNetGroup:Boolean;//-----当成功链接播放组时为true,此时可以向p2p发送数据
		public var  userName:Object = new Object();      //用于存放邻居的peerID或邻居名称，并且其中的myName属性保存自己的ID或名称
		/**
		 * startTime记录第一次加载checkSum,selector,
		 * gather,rtmfp以及第一块p2p数据的下载的开始时间,
		 * 以便于计算出下载耗时	
		 */		
		public var startTime:Number = 0;
		
		protected static const CHUNK_SHARE_WEIGHT:Number = 1.0;
		protected static const CHUNK_TIME_WEIGHT:int = 1;
		protected static var MEMORY_LENGTH:uint = 300*1024*1024;
		protected static const CLIP_INTERVAL:uint = 128*1024;
		protected static var Chuncks_NUMBER:uint =  uint(Math.floor(MEMORY_LENGTH / CLIP_INTERVAL));
		
		protected var clip_interval:uint = CLIP_INTERVAL;//-----由checkXML文件信息决定，
		                                       //如果XML加载失败则使用默认值			
		protected var _vodDataLoader:VODDataLoader;
		protected var _p2pLoader:P2PLoader;
		protected var _checkLoader:CheckLoader;		
		protected var _videoInfo:Object;//-----_videoInfo保存播放器传递的信息：		
        protected var _playHead:uint;//-----当前播放器请求的chunk位置
		protected var _arrayFLVURL:Array;        //保存flv地址的数组
		public var arrayFLVURLIndex:int = 0 ;//当前使用的flv地址索引
		//protected var _arrayXMLSocketURL:Array;  //保存允许访问的socket端口地址的数组，与_arrayFLVURL的索引保持一致
		
        private var _fileTotalBytes:uint;//-----总文件字节数
		
		private var _duration:Number;    //-----总播放时长
		
		private var _fileTotalChunks:uint;//-----总片段数量
		private var _bufferTimeArray:Array=null;				//用于存放全部数据块对应的缓冲数据时间点
		private var _bufferTimerChunkIndexStartSave:uint = 0;	//用于存放当前播放点对应的连续缓冲数据块起点
		private var _bufferTimerChunkIndexEndSave:uint = 0;	//用于存放当前播放点对应的连续缓冲数据块终点
		
		private var _urgenceBufferSize:int = 20;
		private var _httpSpeedStartChunk:int = -1;//计算http下载速度时使用的变量，记录采样起始chunk的索引值
		private var _httpSpeedEndChunk:int = -1;//计算http下载速度时使用的变量，记录采样截止chunk的索引值
		//private var _haveSentHttpSpeed:Boolean = false;//表示是否已经上报过P2P.HttpGetChunk.Speed事件；
		private var _pendHttpTime:Boolean=false;//下载http未能决定总下载时间
		private var _httpLoadTimeRecord:Number=0;//每次下载http的累计时间，多次http的累计时间由统计代码控制
		private var _httpstartLoadTime:Number=0;
		private var p2pTimer:Timer;
	
		private var _kbps:Number = 0;
		private var _pauseP2P:Boolean;
		
		public  var isCheckSumSuccess:Boolean;
		
		private var _canCheck:Boolean = true;//是否支持数据下载校验功能，测试数据校验是否占用系统资源使用
		
		/**
		 * _adTime保存播放器播放广告的剩余时间，该值随时钟递减，
		 * 只有当_adTime大于5秒时开启P2P优先加载的策略
		 * 单位：毫秒
		 * */
		private var _adTime:Number = 0;
		
		public function DataManager()
		{
			
		}

		/**lz add 0524*/
		public function set memoryLength(length:uint):void
		{
			MEMORY_LENGTH  = length*1024*1024;
			Chuncks_NUMBER = uint(Math.floor(MEMORY_LENGTH / CLIP_INTERVAL));
			if(chunks)
			{
				chunks.memoryLength = length*1024*1024;
			}
		}
		
		public function get bufferTimeArray():Array
		{
			return _bufferTimeArray;
		}
		public function get httpBufferLength():uint
		{
			return _urgenceBufferSize;
		}
		
		public function set httpBufferLength(length:uint):void
		{
			/**根据传入的秒数length，计算出紧急区时的chunk数*/
			_urgenceBufferSize = Math.ceil((_fileTotalBytes / _duration)*length / CLIP_INTERVAL);
			//_urgenceBufferSize = length;
		}

		public function get playHead():uint
		{
			return _playHead;
		}

		public function get fileTotalChunks():uint
		{
			return _fileTotalChunks;
		}

		public function get fileTotalBytes():uint
		{
			return _fileTotalBytes;
		}
		
		public function get adTime():Number
		{
			return 	_adTime;
		}
		public function set adTime(time:Number):void
		{
			if(time>5*1000)
			{
				_adTime = time;
			}
			else
			{
				_adTime = 0;
			}			
		}
		
		public function chunk(_idx:int):Chunk
		{
			if (chunks == null)
				return null;
			//
			return chunks.getChunk(_idx);
		}
				
		public function setInit(obj:Object):void
		{ 			
			_urgenceBufferSize = obj.urgenceBufferSize;
			_fileTotalBytes    = obj.filesize;
			
			_duration          = obj.duration;
			
			clip_interval      = 128*1024;
			_fileTotalChunks   = obj.chunksnumber;
			_arrayFLVURL       = (obj.flvURL as Array).concat();
			_kbps              = obj.kbps;
			_videoInfo         = obj;
			_videoInfo.clip_interval = clip_interval;
			
			/**lz 0819 add*/
			if(obj.hasOwnProperty("canCheck"))
			{
				_canCheck = obj.canCheck;
			}
			/**************/
			
			/*******************0523add 是否支持播放广告时，开启P2P加载****************/			
			_adTime = obj.adRemainingTime;			
			/**********************************************************************/
			
			//_arrayXMLSocketURL = (obj.xmlsocket as Array).concat();
			
			chunks     = new Chunks(MEMORY_LENGTH,clip_interval);
			_p2pLoader = new P2PLoader(this,_videoInfo.geo,_videoInfo.groupName);
			_p2pLoader.addEventListener(P2PLoaderEvent.STATUS,dispatchEvent);
			_p2pLoader.startLoadP2P();
			//
			initVodDataLoader();
			startCheckSumLoader();
			//
			p2pTimer = new Timer(3000);
			p2pTimer.addEventListener(TimerEvent.TIMER, _p2pTimer);
			p2pTimer.start();
		}
		public function resumeP2P():void
		{
			_pauseP2P = false;
		}
		public function pauseP2P():void
		{
			_pauseP2P = true;
			/*
			if(isHttpZoneFull(_urgenceBufferSize) == false)
			{
				//如果紧急区不满则进行上报
				var obj:Object = new Object();
				obj.code = "HttpZoneNotFull";
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
			}
			*/
			remarkWant(0, fileTotalChunks-1);
			
		}
		protected function initVodDataLoader():void
		{
			_vodDataLoader = new VODDataLoader(_videoInfo);
			//_vodDataLoader.addEventListener(MetaDataLoaderEvent.LOAD_METADATA_STATUS,metaDataLoaderHandler);
			_vodDataLoader.addEventListener(HttpLoaderEvent.HTTP_GOT_PROGRESS,writeData);
			_vodDataLoader.addEventListener(HttpLoaderEvent.HTTP_GOT_COMPLETE,clearHttpLoader);					
			_vodDataLoader.addEventListener(P2PEvent.ERROR,errorHandler);
			_vodDataLoader.addEventListener(P2PLoaderEvent.STATUS,dispatchEvent);
			//_vodDataLoader.init();
		}
		//
		protected function startCheckSumLoader():void
		{
			if(_checkLoader)
			{
				if(_checkLoader.hasEventListener(CheckLoaderEvent.SUCCESS))
				{
					_checkLoader.removeEventListener(CheckLoaderEvent.SUCCESS,checkLoadSuccess);
				}
				if(_checkLoader.hasEventListener(P2PEvent.ERROR))
				{
					_checkLoader.removeEventListener(P2PEvent.ERROR,errorHandler);
				}
				//
				_checkLoader.clear();
				_checkLoader = null;
			}
			//
			_checkLoader  = new CheckLoader();
			_checkLoader.addEventListener(CheckLoaderEvent.SUCCESS,checkLoadSuccess);
			_checkLoader.addEventListener(P2PEvent.ERROR,errorHandler);
			//
			_checkLoader.startLoadCheck(String(_videoInfo.checkURL));
			//
			if(startTime == 0)
			{
				startTime = getTime();
			}
		}
		
		/** lz0523 add*/
		private function ifP2PFirst():Boolean
		{
			/**
			 * 当播放器正在播放广告且_adTime>5*1000毫秒时，执行p2p优先加载的策略；
			 * 当_adTime<=5*1000毫秒时，执行正常加载策略
			 * */
			if(_adTime <= 5*1000)
			{
				return false;
			}
			return true;
		}
		
		public function clear():void
		{
			if(p2pTimer)
			{
				p2pTimer.removeEventListener(TimerEvent.TIMER, _p2pTimer);
				p2pTimer.stop();
			}
			
			if (_vodDataLoader)
			{			
				if(_vodDataLoader.hasEventListener(HttpLoaderEvent.HTTP_GOT_PROGRESS))
				{
					_vodDataLoader.removeEventListener(HttpLoaderEvent.HTTP_GOT_PROGRESS,writeData);
				}
				if(_vodDataLoader.hasEventListener(HttpLoaderEvent.HTTP_GOT_COMPLETE))
				{
					_vodDataLoader.removeEventListener(HttpLoaderEvent.HTTP_GOT_COMPLETE,clearHttpLoader);
				}
				if(_vodDataLoader.hasEventListener(P2PEvent.ERROR))
				{
					_vodDataLoader.removeEventListener(P2PEvent.ERROR,errorHandler);
					_vodDataLoader.removeEventListener(P2PLoaderEvent.STATUS,dispatchEvent);
				}			
				
				_vodDataLoader.clear();
				_vodDataLoader = null;
			}
			if(_checkLoader)
			{
				if(_checkLoader.hasEventListener(CheckLoaderEvent.SUCCESS))
				{
					_checkLoader.removeEventListener(CheckLoaderEvent.SUCCESS,checkLoadSuccess);
				}
				if(_checkLoader.hasEventListener(P2PEvent.ERROR))
				{
					_checkLoader.removeEventListener(P2PEvent.ERROR,errorHandler);
				}
				//
				_checkLoader.clear();
				_checkLoader = null;
			}
			//
			if (_p2pLoader)
			{
				_p2pLoader.removeEventListener(P2PLoaderEvent.STATUS,dispatchEvent);
				_p2pLoader.clear();
				_p2pLoader = null;
			}
			if (chunks)
			{
				chunks.clear();
				chunks = null;
			}
			_videoInfo = null;
			_playHead = 0;
			isJoinNetGroup = false;
			_fileTotalBytes = 0;
			_fileTotalChunks = 0;
			checkXML = null;
			
			_arrayFLVURL = null;
			arrayFLVURLIndex = 0;
			_utime = 0.1;
			
			userName = new Object();
			startTime = 0;
			_httpSpeedStartChunk = -1;
			_httpSpeedEndChunk = -1;
			//_haveSentHttpSpeed = false;
			
			_kbps = 0;
			_pauseP2P = false;
			isCheckSumSuccess = false
			_adTime = 0;
			
			_canCheck = true;
		}
		//
		public function getTestSpeedBuffer(head:uint):Number
		{
			var chs:Number=0;
			if(chunks)
			{
				head = head <_fileTotalChunks ? head :_fileTotalChunks -1;
				for(var i:uint=head ; i<_fileTotalChunks ; i++)
				{
					var ch:Chunk = chunks.getChunk(i);
					if(ch != null && ch.iLoadType == 3)
					{
						chs++
					}
					else
					{
						break;
					}
				}
			}
			return uint(chs*(CLIP_INTERVAL/1024)*8/_kbps);
		}
		//		
		public function getBuffer(head:uint,arrPos:Array,arrTime:Array):Number
		{
			head = head <_fileTotalChunks ? head :_fileTotalChunks -1;
			if( _bufferTimerChunkIndexEndSave >= head && head >= _bufferTimerChunkIndexStartSave )
			{
				head = _bufferTimerChunkIndexEndSave;
			}
			else
			{
				_bufferTimerChunkIndexStartSave = head;
			}
			
			var ch:Chunk = chunks.getChunk(head);
			while(ch != null//对象存在
				&& ch.iLoadType == 3//数据确实有
			)
			{
				head++;
				
				ch = null;
				ch = chunks.getChunk(head);
				//trace("ch  "+ch)
			}
			
			_bufferTimerChunkIndexEndSave = head <_fileTotalChunks ? head :_fileTotalChunks -1;
			
			if( ! _bufferTimeArray )
			{
				//trace("bufferTimerArray:",arrTime[arrTime.length-1],arrPos[arrPos.length - 1],_fileTotalBytes);
				_bufferTimeArray = new Array();
				var iPos:uint = 0;
				var nDistance:uint = 0;
				//var iChunk:uint = 0;
				for( var iChunk:uint = 0;iChunk < _fileTotalChunks-1; iChunk++ )
				{
					nDistance = (iChunk + 1)*clip_interval;
					while( nDistance > arrPos[iPos] )
					{
						iPos++;
					}
					//_bufferTimeArray[iChunk] =  arrPos[iPos] - nDistance < nDistance - arrPos[iPos-1] ? arrTime[iPos]:arrTime[iPos-1];
					_bufferTimeArray[iChunk] = arrTime[iPos-1] + Number( nDistance - arrPos[iPos-1] )*Number(arrTime[iPos] - arrTime[iPos-1])/Number(arrPos[iPos] - arrPos[iPos-1]) ;
					
				}
				_bufferTimeArray[_fileTotalChunks-1] = arrTime[arrTime.length-1];
				
			}
			return _bufferTimeArray[_bufferTimerChunkIndexEndSave ];
			//return _bufferTimeArray[_bufferTimerChunkIndexEndSave <_fileTotalChunks ? _bufferTimerChunkIndexEndSave:_fileTotalChunks -1 ];
		}
		/*
		此方法供P2PNetStream使用，当影片播放时根据index读取所需的chunk数据
		*/
		public function seek(index:uint):void
		{
			if (null == chunks)
				return ;
			//当跳跃进度时，停止当前正在下载的任务
			_playHead = index;
			clearHttpLoading(index);
			
			/**
			 * lz0523 add
			 * 判断执行p2p优先加载的策略还是执行正常加载策略
			 * */
			if( !ifP2PFirst() )
			{
				/**执行正常加载策略*/
				httpDispatch(index);
				//p2pDispatch();	
				//停止正在p2p请求的数据
				if( isJoinNetGroup )
				{
					remarkWant(0, fileTotalChunks-1);
				}
			}
			else
			{
				/**执行p2p优先加载的策略*/
				p2pDispatch();
			}
			
		}
		public function readSeekData(index:uint, offset:uint):ByteArray
		{
			
			if (null == chunks)
				return null;		
			
			/**
			 * lz0523 add
			 * 判断执行p2p优先加载的策略还是执行正常加载策略
			 * */
			if( !ifP2PFirst() )
			{
				/**执行正常加载策略*/
				httpDispatch(_playHead);
			}
			else
			{
				/**执行p2p优先加载的策略*/
				p2pDispatch();
			}			
			
			//
			var buf:ByteArray = null;
			/*if (offset <= 50* 1024)
			{
				var ch:Chunk=chunks.getChunk(index);	
				if (ch != null)
				{  	
					if(ch.iLoadType == 3 )//说有数据
					{	
						buf = new ByteArray();
						buf.writeBytes(ch.data, offset);
						return buf;
					}				
				}
			}*/
			//
			
			var ch0:Chunk=chunks.getChunk(index);			
			var ch1:Chunk=chunks.getChunk(index+1);
			if (ch0 != null && ch1 != null)
			{  	
				if(ch0.iLoadType == 3 && ch1.iLoadType == 3)//说有数据
				{	
					buf = new ByteArray();
					buf.writeBytes(ch0.data, offset);
					buf.writeBytes(ch1.data);
					//return buf;
				}				
			}
			//
			if (index+1 == _fileTotalChunks)
			{
				if (ch0 != null && ch0.iLoadType == 3)
				{
					buf = new ByteArray();
					buf.writeBytes(ch0.data, offset);
				}
			}
			//
			return buf;
		}
		public function readByteArray(index:uint):ByteArray
		{			
			if (null == chunks)
			{
				return null;
			}
			
			_playHead = index;
			
			/**
			 * lz0523 add
			 * 判断执行p2p优先加载的策略还是执行正常加载策略
			 * */
			if( !ifP2PFirst() )
			{
				/**执行正常加载策略*/
				if (isHttpZoneFull(_urgenceBufferSize/2) == false)//如果没有超过紧急区一半，需要http加载
				{
					//发出紧急区事件
					httpDispatch(index);
				}
			}
			
			p2pDispatch();
			
			/**当暂停p2p功能时***************/
			if(_pauseP2P)
			{
				if(isHttpZoneFull(_urgenceBufferSize) == false)
				{
					//如果紧急区不满则进行上报
					var obj:Object = new Object();
					obj.code = "HttpZoneNotFull";
					this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
				}
			}
			/*******************************/
			
			var ch:Chunk=chunks.getChunk(index);			
			if (ch!=null)
			{  	
				if(ch.iLoadType == 3)//说有数据
				{	
					return ch.data;
				}				
			}
			//
			return null;
		}
		private function _p2pTimer(e:*):void
		{
			p2pDispatch();
		}
		/*
		当成功从http或p2p下载到数据时调用
		*/
		
		public function writeData(e:P2PEvent):Boolean
		{
			if (null == chunks)
				return false;
			//
			var obj:Object = e.info as Object;	
			var ch:Chunk = chunks.getChunk(uint(obj.id));
			if(ch != null)
			{
				if( ch.iLoadType == 1 ||
					(ch.iLoadType == 2 && checkData(obj.data, obj.id)))//p2p数据，并且调度成功
			
				{
					/*var _crc32:CRC32 = new CRC32();
					_crc32.update(obj.data);
					trace("Number(_crc32).toString(10) = "+Number(_crc32).toString(10))*/
					
					addChunk(obj);	
					remrange(eliminate());
					if (this.isJoinNetGroup)
					{
						_p2pLoader.removeWantData(uint(obj.id),uint(obj.id));
						//_vodDataLoader.p2pRemoveWantData(uint(obj.id),uint(obj.id));
					}		
					//
					addrange(obj.id);
					return true;
				}else if (ch.iLoadType == 3)
				{
					return true;
				}
			}
			//
			return false;
		}
		//
		//public var dataRange:Object   = new Object();
		private var _dataRange:Array = new Array();
		public function get dataRange():Array
		{
			if(_pauseP2P)
			{
				return null;
			}
			return _dataRange;
		}
		private function addrange(index:int):void
		{			
			if (_dataRange[index] == null)
			{
				_dataRange[index] = new Object();
				_dataRange[index].start = index;
				_dataRange[index].end = index;
			}
			//
			for each(var rg:* in _dataRange)
			{
				if (_dataRange[rg.end+1])
				{
				    rg.end = _dataRange[rg.end+1].end;
					//_dataRange.splice(rg.end, 1)
					delete _dataRange[rg.end];
					//return;
				}				
			}
			//
		}
		private function remrange(index:uint):void
		{
			if (index == -1) return;
			if (_dataRange[index])
			{
				if (_dataRange[index].start == _dataRange[index].end)
				{
					delete _dataRange[index];
					return;
				}else
				{
					_dataRange[index+1] = new Object();
					_dataRange[index+1].start = index+1;
					_dataRange[index+1].end   = _dataRange[index].end;
					//
					delete _dataRange[index];
					return;
				}
			}
			//
			for each(var rg:* in _dataRange)
			{
				if (rg.start < index && rg.end >= index)
				{
					_dataRange[index+1] = new Object();
					_dataRange[index+1].start = index+1;
					_dataRange[index+1].end   = rg.end;
					//
					rg.end = index -1;
					//
					return ;
					//break;
				}
			}
			
		}
		//
		protected function checkData(data:ByteArray, index:uint):Boolean
		{
			if(_canCheck == false)
			{
				return true;
			}
			if (checkXML != null)
			{
				if(checkXML.clip[index].@ck)
				{
					var _crc32:CRC32 = new CRC32();
					_crc32.update(data);
					//trace("Number(_crc32).toString(10) = "+Number(_crc32).toString(10))
					if(checkXML.clip[index].@ck==Number(_crc32).toString(10))
					{
						return  true;
					}
					//
					_crc32 = null;
				}
			}
			//
			return false;
		}
		/*
		向chunks中写入数据
		*/
		protected function  addChunk( obj:Object):void
		{					
			if (null == chunks)
				return ;
			
		    var ch:Chunk=chunks.getChunk(obj.id);
		    
			if(null != ch //对象存在
				&& ch.iLoadType != 3 
				&& ch.id == obj.id
				)//还没有数据
			{
				
				//
				if(obj["from"]=="http")
				{
					obj.begin = Number(ch.begin);//将原来chunks中的chunk.begin时间取出
				}
				else
				{
					obj.begin = Number(obj["begin"]);//将_p2pWaitTaskList任务列表中的begin时间取出
				}
				
				//trace("obj.begin = "+obj.begin)
				obj.end=getTime();
				//trace("obj.end "+obj.end)
				obj.iLoadType = 3;//说明数据已经有了
				//trace("obj.id ---  "+obj.id)
				chunks.addChunk(obj);
				//
				reportWriteDataStatus(obj);
				//
			}
			
		}
		/*
		将成功下载到数据的信息发送出去，包括数据的来源下载等待的时间等
		*/
		protected function reportWriteDataStatus(obj:Object):void
		{			
			if(uint(obj.id)<fileTotalChunks)
			{
				if(uint(obj.id)!=(fileTotalChunks-1))
				{
					obj.size=clip_interval;
				}else
				{
					obj.size=fileTotalBytes-(fileTotalChunks-2)*clip_interval;
				}
			}
			//
			if(obj.from=="http")
			{
				obj.code="P2P.HttpGetChunk.Success";
				obj.cnod=getCnode(_arrayFLVURL[arrayFLVURLIndex]);
				if(_httpstartLoadTime!=0){
					obj.sumHttpTime=_httpLoadTimeRecord+(getTime()-_httpstartLoadTime);
				}else{
					obj.sumHttpTime=_httpLoadTimeRecord
				}
				//
			}else
			{
				obj.code="P2P.P2PGetChunk.Success";
				obj.peerID = obj.peerID;
				obj.act    = "load";
				obj.error  = 0;
				//trace("obj.peerID    "+obj.peerID)
			}
			obj.level="status";
			this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
			
			//为林洋统计CDN的下载速度，只有在第一次运行时统计一次并上报
			if( _httpSpeedEndChunk != -1 
				&& _httpSpeedEndChunk == obj.id 
				&& obj.from == "http" )
			{						
				var bytes:int   = Math.round(((_httpSpeedEndChunk-_httpSpeedStartChunk+1) * clip_interval)/1024);
				var time:Number = (obj.end - obj.begin)/1000;	
				
				var object:Object = new Object();
				object.code  = "P2P.HttpGetChunk.Speed";				
				
				object.size  = bytes;                 // K字节
				object.time  = time;                  // 秒
				object.speed = Math.round(bytes/time);// K字节/秒
				//object.haveSentHttpSpeed = _haveSentHttpSpeed;
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,object));
				//_haveSentHttpSpeed = true;
				/*trace("_httpSpeedEndChunk = "+_httpSpeedEndChunk);
				trace("bytes = "+bytes);
				trace("time = "+time);
				trace("speed = "+object.speed);*/
				_httpSpeedEndChunk = -1;
			}
		}
		/*
		清除http的下载任务，在http成功执行完下载任务、跳进度时调用
		*/
		protected function clearHttpLoader(e:P2PEvent):void
		{
			if (null == chunks)
				return ;
			
		    var obj:Object=e.info as Object;
			//trace("trace(_vodDataLoader.GetHttpChunks("+uint(_obj.id)+"))  "+_vodDataLoader.GetHttpChunks(uint(_obj.id)))
			var j:int = _vodDataLoader.GetHttpChunks(uint(obj.id)).GethttpChunks();
			
			for(var i:int; i < j; i++)
			{
				//trace("chunks.getChunk("+(uint(_obj.id)+i)+") = "+chunks.getChunk(uint(_obj.id)+i))
				
				var ch:Chunk=chunks.getChunk(uint(obj.id)+i);
				
				if(ch!=null)//对象存在
				{
					if(ch.iLoadType == 1)//正在http调度
					{
						ch.iLoadType = 0;
					}	
				}
				
			}
			endHttpLoadStatistcs();
			_vodDataLoader.clearHttpLoader(uint(obj.id));
		
		}
		/*
		当将数据分享给别人时加权重并将分享进行事件发送
		*/
		public function weightPlus(index:uint):void
		{
			if (null == chunks)
				return ;
			
			var ch:Chunk = chunks.getChunk(index);
			if(null != ch && ch.iLoadType == 3)
			{
				ch.share += CHUNK_SHARE_WEIGHT;	
				
				var info:Object = new Object();
				info.code = "P2P.P2PShareChunk.Success";
				info.size = ch.data.length;
				info.id   = index;
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,info));
			}			
		}
		/*
		判断紧急区是否填满
		*/
		protected function isHttpZoneFull(size:uint):Boolean
		{
			var index:uint = _playHead;
			var maxHttp:uint=_playHead+ size;//_httpBufferLength;
			while(index < maxHttp)
			{
				var ch:Chunk = chunks.getChunk(index);
				//if(!(ch != null && ch.iLoadType==3))
				if((ch == null || ch.iLoadType != 3))
				{ 					   
					return false;//说明http调度区域不满
				}
				//
				++index;
			}
			return true;
		}
        /*
		清除http下载任务
		*/
		protected function clearHttpLoading(_idx:uint):void
		{
			if (null == chunks)
				return ;
			
			var ho:HttpLoader = _vodDataLoader.gethttpObject() as HttpLoader;
			while(ho)//并且在紧急区之内				
			{
				var count:uint = _vodDataLoader.GetHttpChunks(ho.gethttpNowIndex()).GethttpChunks();
				for(var idx:int=0; idx < count; idx++)
				{
					var ch:Chunk=chunks.getChunk(ho.gethttpNowIndex() + idx)
					
					if(ch!=null)
					{
						if(ch.iLoadType == 1)//正在http调度
						{
							ch.iLoadType = 0;
						}
					}
						
				}
				//
				_vodDataLoader.clearHttpLoader(ho.gethttpNowIndex());
				ho = _vodDataLoader.gethttpObject() as HttpLoader;
						
			}
			endHttpLoadStatistcs();
		}
        /*
		http调度
		*/
		protected function httpDispatch(index:uint):void
		{
			if (null == chunks)
				return ;
			
			var p:uint = index;
			var maxHttp:uint=_playHead+_urgenceBufferSize;
			
			if( _httpSpeedStartChunk == -1 && _httpSpeedEndChunk == -1)
			{
				//确保是第一次执行且执行一次
				_httpSpeedStartChunk = index;
				var end:int = maxHttp < fileTotalChunks ? maxHttp : fileTotalChunks;
				_httpSpeedEndChunk = index + int((end-index)/2);			
				//_httpSpeedEndChunk = index + int(end-index-1);
			}
			/**/
			//trace("~~~~~~~~~~~~httpDispatch "+_playHead);
			var httpArray:Array = new Array();
			while(p < maxHttp && p < fileTotalChunks)//并且在紧急区之内				
			{
				var ch:Chunk = chunks.getChunk(p);
				
				if (ch != null)
				{
					if (ch.iLoadType == 2 ////正在p2p调度
						|| ch.iLoadType == 0)//没有被调度
					{
						httpArray.push(p);
					}
					
				}else if (ch == null)//对象存在
				{
					httpArray.push(p);
				}
				p++;	
				
			}
			var Uindex:uint = httpArray[0];
			var n:int = 1;//当前加载任务需要加载的连续chunk数量
			for(var i:int =0; i < httpArray.length; i++)
			{
				if (httpArray.length > i+1 //保证不越界
					&& httpArray[i] +1  == httpArray[i+1])//判断是否连续
				{
					n++;
					continue;
				}else
				{					
					if(_vodDataLoader.gethttpObjectCount() < 1)
					{
						if(_vodDataLoader.httpLoadData(Uindex, n, _arrayFLVURL[arrayFLVURLIndex]))
						{
							startHttpLoadStatistcs();
							for(var j:int = 0; j < n; j++)
							{
								var obj:Object = new Object();
								obj.id  = Uindex+j;
								obj.data = null;
								obj.from = "http";
								
								obj.begin = getTime();
								
								obj.end   = 0;
								obj.iLoadType = 1;//说明正在http调度
								
								chunks.addChunk(obj);
								obj = null;;
							}
						}
					}
					else
					{						
						break;//说明http请求数超限
					}
					
					if(i == httpArray.length - 1)
					{
						break;
					}
					
					Uindex = httpArray[i+1];
					n = 1;
					
				}
			}
			httpArray=null;
		}
		private function startHttpLoadStatistcs():void{
			_httpstartLoadTime=getTime();
			_pendHttpTime=true;
		}
		
		private function endHttpLoadStatistcs():void{
			if(_pendHttpTime){
				_httpLoadTimeRecord+=(getTime()-_httpstartLoadTime);
				_httpstartLoadTime=0;
				_pendHttpTime=false;
			}
		}
		/*
		p2p调度-------------------
		*/
		protected function p2pDispatch():void
		{
			if(chunks == null)
			{
				return ;
			}
			
			/**当CheckSum 未 成功时 lz 0613 add**********/
			if(!isCheckSumSuccess)
			{
				return;
			}
		    
			/**当暂停p2p功能时***************/
			if(_pauseP2P)
			{
				return;
			}
			
		    //当成功加载到checkXML并且成功加入组时
			if(checkXML && isJoinNetGroup)
			{			
			    
				if((_playHead/*_httpBufferLength*/) < (fileTotalChunks))
				{							
					var start:uint=playHead;//_httpBufferLength;
					var end:uint=start+ Chuncks_NUMBER * 0.7;//10*_httpBufferLength-1;
							
					if(end>=fileTotalChunks)
					{
						end=fileTotalChunks-1;
					}
					
					if ( !ifP2PFirst() && isHttpZoneFull(_urgenceBufferSize/2) == false)
					{
						remarkWant(0, fileTotalChunks-1);
						return ;
					}
					else 
					{
						markWant(start, end);
					}
					
					/**lz 0524 add*/
					if(start-1>=0)
					{
						remarkWant(0, start-1);
					}
					/**************/
					remarkWant(end+1, fileTotalChunks-1);					
	            }
			}else if(!isJoinNetGroup)
			{
				remarkWant(0, fileTotalChunks-1);
			}
		}
		/*
		向邻居请求从start到end之间的数据，包含start和end值
		*/
		protected function markWant(start:uint,end:uint):void
		{
			if (null == chunks)
				return ;
			if (_p2pLoader == null)
				return;
			for(var i:int = start; i <= end; i++)
			{
				var ch:Chunk = chunks.getChunk(i)
				
				if(ch == null //不存在chunk
					|| (ch != null && (ch.iLoadType == 2 || ch.iLoadType == 0)))//ch.iLoadType != 3 && ch.iLoadType != 1))//存在对象，数据没有获得的
				{
					var obj:Object = new Object();
					obj.data = null;
					obj.from = "p2p";						
					obj.begin = getTime();
					
					obj.end   = 0;
					obj.iLoadType = 2;
					obj.id = i;
					chunks.addChunk(obj);
					//_vodDataLoader.p2pWantData(i,i);
					_p2pLoader.addWantData(i, i);
					
					obj = null;
				}				
			}
		}
		/*
		取消已经向邻居请求的数据
		*/
		protected function remarkWant(start:uint,end:uint):void
		{
			if (null == chunks)
				return ;
			
			if (_p2pLoader == null)
				return;
			
			/**当CheckSum 未 成功时 lz 0613 add**********/
			if(!isCheckSumSuccess)
			{
				return;
			}
			//trace("remove s="+start+" e="+end);
			for(var _i:String in chunks.chunksObject)
			{
				if(uint(_i)>=start && uint(_i)<=end)
				{
					var ch:Chunk = chunks.getChunk(uint(_i));
					
					if(ch != null /*&& ch.iLoadType == 2*/)
					{		
						//_vodDataLoader.p2pRemoveWantData(uint(_i), uint(_i));
						_p2pLoader.removeWantData(uint(_i), uint(_i));
						if (ch.iLoadType == 2)
						{
							ch.iLoadType = 0;
							ch.from = "";
						}
					}
				}			    
			}
		}
		protected function checkLoadSuccess(e:CheckLoaderEvent):void
		{	
			checkXML = XML(e.info.myXML);			
			var e1:DataManagerEvent;
			
			var obj:Object = new Object();			
			
			if( uint(checkXML.@chunkSize) > 0 //XML中chunk大小的值有效
				&& uint(checkXML.@chunkNum) == checkXML.clip.length() 
				&& uint(checkXML.@chunkNum) == _fileTotalChunks) //XML中的chunk数量正确
			{
				//_p2pLoader.startLoadP2P(_videoInfo.groupName);
				//数据正确
				obj = getCheckInfoObj(true);
				obj.act   = "checksum";
				obj.error = e.info.error;
				
				obj.utime = e.info.utime;
				
				e1=new DataManagerEvent(DataManagerEvent.STATUS,obj);
				
				isCheckSumSuccess = true;
				
			}
			else
			{
				//数据错误
				obj = getCheckInfoObj(false);
				obj.act   = "checksum";
				obj.error = 999;
				
				obj.utime = e.info.utime;
				
				e1=new DataManagerEvent(DataManagerEvent.STATUS,obj);
				
				isCheckSumSuccess = false;
			}
			//
			this.dispatchEvent(e1);
			e1 = null;
			
		}
		/*
		根据加载验证码xml的结果进行处理并返回，并设置clip_interval，将chunks的初始化和initVodDataLoader的初始化
		*/
		protected function getCheckInfoObj(b:Boolean):Object
		{
			var obj:Object = new Object();
			//
			if(b)
			{
				obj.code = "P2P.LoadCheckInfo.Success";
				obj.level = "status";
				
				clip_interval=uint(checkXML.@chunkSize);
				
			}else
			{
				obj.code = "P2P.LoadCheckInfo.Failed";
				obj.level = "error";
				
				checkXML=null;
				
				clip_interval=CLIP_INTERVAL;
				
			}	
			
			obj.chunkSize = clip_interval;
			
			return obj;
		}
		/*
		处理数据淘汰
		*/
		protected function eliminate():int
		{
			if (null == chunks)
				return -1;
			
			var i:int=chunks.eliminate(playHead);
			
			if(i >= 0)
			{
				if(checkXML && isJoinNetGroup)
				{
					//_vodDataLoader.p2pRemoveHaveData(i,i);
					_p2pLoader.removeHaveData(i, i);
				}
			}
			//
			return i;
			
		}
		
		/*
		统一对错误事件进行处理
		*/
		private function gcChunks(e:P2PEvent):void
		{
			var offset:int = -1;
			//
			for (var i:int = 0; i < e.info.nCount; i++)
			{								
				var ch:Chunk = chunks.getChunk(uint(e.info.id)+i);
				if(null != ch && ch.iLoadType == 1)//正在http调度
				{
					if(-1 == offset)
					{									
						offset = i;
						if(!ch.begin)
						{
							_utime = Math.round(getTime()-ch.begin);
						}else
						{
							_utime = 200;
						}
						//obj.utime = getTime()-ch.begin;						
						//trace("_utime = "+_utime)
					}
					//
					ch.iLoadType = 0;//恢复到未调度状态						
				}
			}
			//
			_vodDataLoader.clearHttpLoader(uint(e.info.id));//回收http请求
		}
		protected var _utime:Number = 200;
		protected function errorHandler(e:P2PEvent):void
		{
			var obj:Object = new Object();
			obj.level = "error"
			//
			switch(e.info.type)
			{
				case "HttpLoader-warnning":
					gcChunks(e);//回收
					//trace("HttpLoader-warnning  "+e.info.text);
					return ;
				case "HttpLoader-error" :
					gcChunks(e);//回收
					//
					obj.code       = "P2P.HttpGetChunk.Failed";
					obj.text       = e.info.text;
					obj.url        = _arrayFLVURL[arrayFLVURLIndex];
					obj.nodeIdx    = arrayFLVURLIndex;					
					obj.utime      = _utime;
					//
					arrayFLVURLIndex++;
					//retry从1开始计数
					obj.retry = arrayFLVURLIndex;
					
					if(_arrayFLVURL[arrayFLVURLIndex] != undefined)
					{
						
						//doXMLSocket();
						obj.allCDNFailed  = 0;
						
					}else
					{					
						arrayFLVURLIndex =0;
						//doXMLSocket();
						obj.allCDNFailed  = 1;
					}					
					
					break;
				
				case "CheckLoader" :	
					obj = getCheckInfoObj(false);	
					obj.text  = e.info.text;
					obj.act   = "checksum";
					obj.error = e.info.error;
					
					obj.utime = e.info.utime;
					
					isCheckSumSuccess = false;
					
					//startCheckSumLoader();
					break;				
				default :
					break;
			}
			dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
			obj = null;
		}
		
		protected function getCnode(str:String):String
		{		
			var string:String = "";
			if(str.indexOf("gn=") != -1)
			{
				var start:int = str.indexOf("gn=")+3;
				var end:int   = str.indexOf("&",start);
				if(end==-1)
				{
					end = str.length;
				}
				string = str.substring(start,end);
			}			
			return string;
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		} 
		
		/*protected function doXMLSocket():void
		{
			//flash.system.Security.loadPolicyFile(_arrayXMLSocketURL[arrayFLVURLIndex]);
			flash.system.Security.loadPolicyFile(_arrayXMLSocketURL[arrayFLVURLIndex]);
		}*/
	}
}