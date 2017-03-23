package com.p2p.dataManager
{
	import com.p2p.data.Block;
	import com.p2p.data.BlockList;
	import com.p2p.data.Head;
	import com.p2p.data.LIVE_TIME;
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.PlayData;
	import com.p2p.data.vo.ReceiveData;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.loaders.ChecksumLoadFactory;
	import com.p2p.loaders.DATLoader;
	import com.p2p.loaders.HeadLoader;
	import com.p2p.loaders.HttpLoad;
	import com.p2p.loaders.IChecksumLoad;
	import com.p2p.loaders.P2P_Loader;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * <ul>构造函数：监听NETSTREAM_PROTOCOL.PLAY，NETSTREAM_PROTOCOL.SEEK;
	 * 创建_blockList _descLoad _datLoad _headLoad _p2pLoad _p2pLoad</ul>
	 * <ul>接口功能解释参见接口类</ul>
	 * <ul>http和p2p调度策略handlerDownloadTask</ul>
	 * @author mazhoun
	 */
	public class LiveDataManager implements IDataManager
	{
		public var isDebug:Boolean=true;
		
		/**数据链表*/
		protected var _blockList:BlockList;
		/**初始化数据*/
		protected var _initData:InitData;
		/**加载desc文件*/
		protected var _descLoad:IChecksumLoad;
		/**声明dat加载器*/
		protected var _datLoad:DATLoader;
		/**声明metadata（即头）加载器*/
		protected var _headLoad:HeadLoader;
		/**声明p2p加载器*/
		protected var _p2pLoad:P2P_Loader;
		/**喂给播放器用到的时间*/
		protected var _startTime:Number=-1;
		
		/**加载dat的block*/
		protected var _loadDatBlock:Block=null;
		/**记录上次加载的dat，作用：如果加载路径一样，将不再加载*/
		private var _lastLoadDatURL:String="";
		/**记录上次加载的head，作用：如果加载路径一样，将不再加载*/
		private var _lastLoadHeadURL:String="";
		
		private var _canP2PLoad:Boolean = true;
		
		private var _canP2PShare:Boolean = true;
		
		private var _downloadTaskTime:Timer
		/**是否第一块*/	
		protected var isFirstBlock:Boolean=true;
		public function LiveDataManager()
		{
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			_blockList=new BlockList();
			_descLoad=ChecksumLoadFactory.createChecksumLoad(LiveVodConfig.LIVE,this);
			_datLoad=new DATLoader(this);
			_headLoad=new HeadLoader(this);
			_p2pLoad=new P2P_Loader(this);
		}
		
		public function get downloadTaskTime():Timer
		{
			return _downloadTaskTime;
		}

		protected function reset():void{
			P2PDebug.traceMsg(this,"reset");
			LiveVodConfig.DAT_LoadBlockID=0;
			_loadDatBlock=null;
			_lastLoadDatURL="";
			_lastLoadHeadURL="";
			_headLoad.stop();
			_datLoad.stop();
			_canP2PLoad  = true;
			_canP2PShare = true;
			_startTime = -1;
			stopDownloadTask();
		}
		/**开启任务加载功能*/
		protected function startDownloadTask():void
		{
			if(_downloadTaskTime==null)
			{
				_downloadTaskTime=new Timer(200);
				_downloadTaskTime.addEventListener(TimerEvent.TIMER,handlerDownloadTask);
				P2PDebug.traceMsg(this,"调度器启动下载任务");
			}
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
		}
		protected function stopDownloadTask():void{
			if(_downloadTaskTime&&_downloadTaskTime.running){
				_downloadTaskTime.stop();
			}
		}
		/**是否http分配满*/
		private var LoadTime:Number = -1;
		protected function GetHttpTask(timestamp:Number,bufferTime:Number,isDebugShow:Boolean=false):Block
		{
			LoadTime = timestamp;
			var intervalTime:Number=1;
			var lastBlock:Block;
			var lastBlockId:Number=-1;
			var btime:Number = timestamp;
			for(LoadTime;LoadTime - btime < bufferTime; LoadTime+=intervalTime)
			{
				var tmpTime:Number=_blockList.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					return null;
				}
				
				lastBlock=_blockList.getBlock(tmpTime);
				if(lastBlock&&lastBlock.isChecked == false)
				{
					return lastBlock;
				}
				//
			}
			//
			return null;
		}
//		protected function GetHttpTask(timestamp:Number,bufferTime:Number,isDebugShow:Boolean=false):Block
//		{
//			//P2PDebug.traceMsg(this,"seq:"+_blockList._toString());
//			LoadTime = timestamp;
//			var intervalTime:Number=2;
//			var lastBlock:Block;
//			var lastBlockId:Number=-1;
//			var btime:Number = timestamp;
//			var seq:Number = 0;
//			//
//			/*var tmpTime:Number=this._blockList.getBlockId(LoadTime);
//			if(tmpTime==-1)
//			{
//				return null;
//			}
//			
//			lastBlock = _blockList.getBlock(tmpTime);*/
//			/*lastBlock = _blockList.getMinSeq(LoadTime);
//			if (lastBlock && lastBlock.id >= LoadTime)
//			{
//				if(lastBlock&&lastBlock.isChecked == false)
//				{
//					return lastBlock;
//				}else
//				{
//					seq = lastBlock.sequence;
//				}
//			}*/
//			//	
//			
//			for(LoadTime;LoadTime - btime < bufferTime; LoadTime+=intervalTime)
//			{
//				lastBlock = _blockList.getTask(LoadTime, seq);
//				/*if (lastBlock)
//				{
//					seq = lastBlock.sequence;
//				}*/
//				//
//				/*if (lastBlock && lastBlock.id < LoadTime)
//				{
//					continue;
//				}*/
//				
//				if(lastBlock&&lastBlock.isChecked == false)
//				{
//					return lastBlock;
//				}
//				//
//			}
//			//
//			return null;
//		}
		
		/**getHead*/
		public function getHead(blockId:Number):Head{
			/**获得*/
			var _tempblock:Block=_blockList.getBlock(blockId);
			if(_tempblock){
				if(_blockList.getHead(_tempblock.head)){
					return _blockList.getHead(_tempblock.head);
				}else{
					return null;
				}
			}
			return null;
		}

		public function getData(blockId:Number, seq:Number):Block
		{
			return _blockList.getData(blockId, seq);
		}
		public function getBlockId(blockId:Number):Number{
			return _blockList.getBlockId(blockId);
		}
		
		/**当下载dat无法下载时，跳过该块继续播放*/
		public function addErrorByte(_blockID:Number=0):void{
			_blockList.getBlock(_blockID).isDestroy=true;
		}
		
		public function addByte(receiveData:ReceiveData):void
		{
			/**
			 * receiveData数据结构
			 * from:String=""  数据来源 http 或 p2p;
			 * blockID:Number; 数据所属的block id;
		     * pieceID:int     数据所属的piece id
		     * begin:Number=0  数据下载的起始时间（毫秒）
			 * end:Number=0    数据下载的结束时间（毫秒）
		     * data:ByteArray  数据流
		     * remoteName:String 如果此数据从p2p获得，表示对方的名称
		     * CheckSum:String校验码，暂时不使用
			 * */
			 //添加片
			if(receiveData.blockID!=0)
			{
				var _tempblock:Block=_blockList.getBlock(receiveData.blockID);
				if(_tempblock)
				{
					try{
						if(/*receiveData.pieceID==0||*/receiveData.pieceID==_tempblock.pieces.length-1)
						{
							P2PDebug.traceMsg(this,"添加流"+receiveData.blockID,receiveData.pieceID,_tempblock.pieces.length);
						}
						
						if(receiveData.from == "http")
						{
							_tempblock.getPiece(receiveData.pieceID).from=receiveData.from;
							_tempblock.getPiece(receiveData.pieceID).begin=receiveData.begin;
							_tempblock.getPiece(receiveData.pieceID).end=receiveData.end;
						}						
						_tempblock.setPieceStream(receiveData.pieceID,receiveData.data,receiveData.remoteName);
					}catch(err:Error)
					{
						for(var i:String in receiveData)
						{
							P2PDebug.traceMsg(this,"添加pieces出错  "+i+" = "+receiveData[i]);
						}
					}
				}
			}
			// 在首次加载block的速率计算receiveData.pieceID==1计算较准确，receiveData.pieceID==0会包含寻址过程
			if(isFirstBlock&&receiveData.from=="http"&&receiveData.pieceID==1)
			{
				isFirstBlock=false;
				if(receiveData.data.length*8/(receiveData.end-receiveData.begin)>LiveVodConfig.DATARATE*LiveVodConfig.RATE_MULTIPLE)
				{
					LiveVodConfig.ISLEAD=1;
					P2PDebug.traceMsg(this,"下载速率："+receiveData.data.length*8+"/("+receiveData.end+"-"+receiveData.begin+")="+receiveData.data.length*8/(receiveData.end-receiveData.begin),LiveVodConfig.DATARATE*LiveVodConfig.RATE_MULTIPLE)
				}
			}
		}
		/**是否本时间戳所在的分钟加载过*/
		public function hasMin(id:Number):Boolean
		{
			return _blockList.hasMin(id);
		}
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		public function getWantPiece(remoteHaveData:Array,farID:String,wantCount:int=3):Array
		{		
			if(_canP2PLoad)
			{
				return _blockList.getWantPiece(remoteHaveData,farID,wantCount);
			}
			return null;
			
		}
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		public function getNearestWantID():Number
		{
			//if(!_canP2PLoad) return 0;
			var LoadTime:Number = LIVE_TIME.GetBaseTime();
			var intervalTime:Number=3;
			var lastBlock:Block;
			var lastBlockId:Number=-1;
			var btime:Number = LoadTime;
			for(LoadTime;LoadTime - btime < 20*60; LoadTime+=intervalTime)
			{
				var tmpTime:Number=_blockList.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					return 0;
				}
				
				lastBlock=_blockList.getBlock(tmpTime);
				if(lastBlock&&lastBlock.isChecked == false)
				{
					return (lastBlock.id);
				}
				//
			}
			//
			return 0;
		}
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		public function getDataAfterPoint(id:String):Array
		{
			if(_canP2PShare)
			{
				return _blockList.getDataAfterPoint(id);
			}
			return null;
		}
		/**根据id索引获得block*/
		public function getBlock(id:Number):Block
		{
			return _blockList.getBlock(id);
		}
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function  handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void
		{
			_blockList.handlerTimeOutWantPiece(farID, blockID, pieceID);
		}
		/**加载head*/
		protected function loadHeadHandler(headURL:Number,forceBegin:Boolean=false):void{
			//过滤连续重复的地址
			if(_lastLoadHeadURL==""){
				_lastLoadHeadURL=""+headURL;
			}else{
				if(_lastLoadHeadURL==""+headURL){
					return;
				}
			}
			
			//是否有加载，如果有加载就不再加载
			if(_blockList.getHead(headURL)&&_blockList.getHead(headURL).getHeadStream()){
				return;
			}
			
			//加载head
			if(forceBegin){_headLoad.stop();}
			P2PDebug.traceMsg(this,"加载头地址"+headURL+".header");
			if(_headLoad.isDownLoad){
				_headLoad.extendsLoad(headURL+".header");
			}else{
				_headLoad.start(headURL+".header");
			}
		}
		public function  addHead(_name:String="",data:ByteArray=null):void{
			_name=_name.replace(".header","");
			var head:Head=_blockList.getHead(Number(_name));
			if(head){
				P2PDebug.traceMsg(this,"添加头:"+_name);
				head.setHeadStream(data);
			}else{
				P2PDebug.traceMsg(this,"添加头:"+_name);
//				throw new Error("添加头出了问题");
			}
		}
		//设置上一分钟的desc是否是否饱和
		public function setLastClipFull(time:Number):void{
			this._blockList.setLastClipFull(time);
		}
		
		/**添加任务数据desc*/
		public function  writeClipList(clipList:Vector.<Clip>,loadType:String=""):void
		{////live liveShift
			//当是头一个clip，查找头之前的数据是否衔接，衔接规则：clip-前的数据+duration<5;
			
			if(clipList.length>0)
			{
				for(var i:int=0;i<clipList.length;i++)
				{
					loadHeadHandler(clipList[i].head);
					_blockList.addBlock(clipList[i],loadType);
				}
			}
		}
			
		/**在读取数据和写入数据时做调度策略*/
		public function handlerDownloadTask(evt:TimerEvent=null):void
		{
			var _startT:Number=LIVE_TIME.GetBaseTime();
			var task:Block = null;
			if(LiveVodConfig.IS_REAL_LEAD)
			{
				task = GetHttpTask(_startT,(-LiveVodConfig.TIME_OFF));
				if(task)
				{
					startHttpLoad(task);
				}
			}
			else
			{		
				task = GetHttpTask(_startT,(LiveVodConfig.DAT_BUFFER_TIME));
				if(task)
				{
					startHttpLoad(task);
					//stopP2PLoad();
				}
			}
		}
		private var _datLoadErrorCount:int=0;
		protected function startHttpLoad(tk:Block):void
		{
			if(_datLoad.isDownLoad)
			{//正在加载不做处理，等待下一次时间驱动
				return;
			}
			_lastLoadDatURL=tk.name;
			_datLoad.start(tk.name,0,tk.size);
		}
		protected function stopHttpLoad():void{
			_datLoad.stop();
		}
		
		/*protected function startP2PLoad():void{
			_canP2PLoad = true;
		}
		protected function stopP2PLoad():void{
			_canP2PLoad = false;
		}
		*/
		public function  bytesLoaded():uint{
			return 0;
		}
		
		public function  bytesTotal():uint{
			return 0;
		}
		
		protected function streamSeekHandler(evt:EventExtensions):void{
			reset();
			P2PDebug.traceMsg(this,"调度器响应Seek事件"+evt.data);
			startDownloadTask();
		}
		
		protected function streamPlayHandler(evt:EventExtensions):void{
			P2PDebug.traceMsg(this,"调度器响应play事件");
			_initData=evt.data as InitData;
			reset();
			_p2pLoad.startLoadP2P();
			startDownloadTask();
		}
	}
}