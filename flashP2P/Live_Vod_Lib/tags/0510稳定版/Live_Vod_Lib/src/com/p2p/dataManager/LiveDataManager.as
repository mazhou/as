package com.p2p.dataManager
{
	import com.p2p.data.Block;
	import com.p2p.data.BlockList;
	import com.p2p.data.Head;
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.Config;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.PlayData;
	import com.p2p.data.vo.ReceiveData;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.loaders.ChecksumLoadFactory;
	import com.p2p.loaders.DATLoader;
	import com.p2p.loaders.DescLoader;
	import com.p2p.loaders.HeadLoader;
	import com.p2p.loaders.HttpLoad;
	import com.p2p.loaders.IChecksumLoad;
	import com.p2p.loaders.P2P_Loader;
	import com.p2p.logs.Debug;
	import com.p2p.statistics.Statistic;
	
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
		public var isDebug:Boolean=false;
		
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
		/**临时存放block*/
		protected var _tempblock:Block=null;
		/**临时记录dat中name的时间戳*/
		private var _timestamp_name:String;
		/**记录上次加载的dat，作用：如果加载路径一样，将不再加载*/
		private var _lastLoadDatURL:String="";
		/**记录上次加载的head，作用：如果加载路径一样，将不再加载*/
		private var _lastLoadHeadURL:String="";
		
		private var _isHttp:Boolean=false;
		
		private var _stopP2P:Boolean = false;//true;//
		
		private var _canP2PLoad:Boolean = true;
		
		private var _canP2PShare:Boolean = true;
		
		private var downloadTaskTime:Timer
		/**是否第一块*/	
		protected var isFirstBlock:Boolean=true;
		public function LiveDataManager()
		{
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.HEAD,streamHeadHandler);
			//关闭 流 增加监听 EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			_blockList=new BlockList();
			_descLoad=ChecksumLoadFactory.createChecksumLoad(Config.LIVE,this);
			_datLoad=new DATLoader(this);
			_headLoad=new HeadLoader(this);
			_p2pLoad=new P2P_Loader(this);
		}
		
		protected function reset():void{
			_loadDatBlock=null;
			_lastLoadDatURL="";
			_lastLoadHeadURL="";
			_headLoad.stop();
			_datLoad.stop();
			_stopP2P = false;
			_canP2PLoad  = true;
			_canP2PShare = true;
			_startTime = -1;
		}
		/**开启任务加载功能*/
		protected function startDownloadTask():void{
			if(downloadTaskTime==null){
				downloadTaskTime=new Timer(300);
				downloadTaskTime.addEventListener(TimerEvent.TIMER,handlerDownloadTask);
				Debug.traceMsg(this,"调度器启动下载任务");
			}
			downloadTaskTime.start();
		}
		
		/**是否http分配满*/
		protected function isHttpZoneFull(timestamp:Number,bufferTime:Number):Boolean
		{
			//正在播放的块desc不存在
			timestamp=_blockList.getBlockId(timestamp);
			if(timestamp==-1){return false;}
			//
			_loadDatBlock=_blockList.getBlock(timestamp);
			/*if(_loadDatBlock&&_loadDatBlock.isDestroy){
				return false;
			}*/
			//如果当前块存在，下一个节点存在，并且有流，获得下一个block
			while(_loadDatBlock/*&&_loadDatBlock.isDestroy*/&&_loadDatBlock.nextID!=0&&_loadDatBlock.isFull){
				if(_loadDatBlock.nextID-timestamp>bufferTime){
					return true;
				}
				_loadDatBlock=_blockList.getBlock(_loadDatBlock.nextID);
			}
			return false;
		}
		
		/**getHead*/
		public function getHead(blockId:Number):Head{
			
			/**获得*/
			_tempblock=_blockList.getBlock(blockId);
			if(_tempblock){
				if(_blockList.getHead(_tempblock.head)){
					return _blockList.getHead(_tempblock.head);
				}else{
					return null;
				}
			}
			return null;
		}
		public function getNextNearBlock(blockId:Number):Block{
			return _blockList.getNextNearBlock(blockId);
		}
		public function getBlockId(blockId:Number):Number{
			return _blockList.getBlockId(blockId);
		}
		
		/**当下载dat无法下载时，跳过该块继续播放*/
		public function addErrorByte(_blockID:Number=0):void{
			_blockList.getBlock(_blockID).isDestroy=true;
		}
		
		//public function addByte(_blockID:Number=0,_pieceID:int=0,data:ByteArray=null,begin:Number=0,end:Number=0,from:String="p2p",remoteName:String=""):void
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
			if(receiveData.blockID!=0){
				_tempblock=_blockList.getBlock(receiveData.blockID);
				if(_tempblock){
					try{
						if(receiveData.pieceID==0||receiveData.pieceID==_tempblock.pieces.length-1){
							Debug.traceMsg(this,"添加流"+receiveData.blockID,receiveData.pieceID,_tempblock.pieces.length);
						}
						
						if(receiveData.from == "http")
						{
							_tempblock.getPiece(receiveData.pieceID).from=receiveData.from;
							_tempblock.getPiece(receiveData.pieceID).begin=receiveData.begin;
							_tempblock.getPiece(receiveData.pieceID).end=receiveData.end;
						}						
						_tempblock.setPieceStream(receiveData.pieceID,receiveData.data,receiveData.remoteName);
					}catch(err:Error){
						for(var i:String in receiveData)
						{
							Debug.traceMsg(this,"添加pieces出错  "+i+" = "+receiveData[i]);
						}
					}
				}
			}
			// 在首次加载block的速率计算receiveData.pieceID==1计算较准确，receiveData.pieceID==0会包含寻址过程
			if(isFirstBlock&&receiveData.from=="http"&&receiveData.pieceID==1){
				isFirstBlock=false;
				if(receiveData.data.length*8/(receiveData.end-receiveData.begin)>Config.DATARATE*Config.RATE_MULTIPLE){
					Config.ISLEAD=1;
					Debug.traceMsg(this,"下载速率："+receiveData.data.length*8+"/("+receiveData.end+"-"+receiveData.begin+")="+receiveData.data.length*8/(receiveData.end-receiveData.begin),Config.DATARATE*Config.RATE_MULTIPLE)
				}
			}
			/** 控制加载任务*/
			//handlerDownloadTask();
		}
		/**是否本时间戳所在的分钟加载过*/
		public function hasMin(id:Number):Boolean
		{
			return _blockList.hasMin(id);
		}
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		public function getWantPiece(remoteHaveData:Array,farID:String,wantCount:int=3):Array
		{		
			if(_canP2PLoad/*!_stopP2P*/)
			{
				return _blockList.getWantPiece(remoteHaveData,farID,wantCount);
			}
			return null;
			
		}
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		public function getNearestWantID():String
		{
			if(_canP2PLoad/*!_stopP2P*/)
			{
				return _blockList.getNearestWantID();
			}
			return "0_0";
		}
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		public function getDataAfterPoint(id:String):Array
		{
			if(_canP2PShare/*!_stopP2P*/)
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
		public function  handlerTimeOutWantPiece(farID:String,clear:Boolean=false):void
		{
			_blockList.handlerTimeOutWantPiece(farID);
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
			Debug.traceMsg(this,"加载头地址"+headURL+".header");
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
				Debug.traceMsg(this,"添加头:"+_name);
				head.setHeadStream(data);
			}else{
				Debug.traceMsg(this,"添加头:"+_name);
				throw new Error("添加头出了问题");
			}
		}
		//设置上一分钟的desc是否是否饱和
		public function setLastClipFull(time:Number):void{
			this._blockList.setLastClipFull(time);
		}
		/**添加任务数据desc*/
		public function  writeClipList(clipList:Vector.<Clip>,loadType:String):void{////live liveShift
			//当是头一个clip，查找头之前的数据是否衔接，衔接规则：clip-前的数据+duration<5;
			if(clipList.length>0){
				/**处理desc*/
				if(clipList.length>=1){
					for(var i:int=0;i<clipList.length-1;i++){
						//下一个指针设置
						clipList[i].nextID=clipList[i+1].timestamp;
						if(i==0){//队列中第一个向前指针设置
							Debug.traceMsg(this,"addBlock:"+clipList[i].timestamp);
							if(clipList[i].preID==0){
								clipList[i].preID=_blockList.getLastBlock(clipList[i].timestamp);
								_blockList.getLastBlock(clipList[i].timestamp);//TEST
							}
							if(clipList[i].preID!=0){
								_blockList.repairNextBlockId(clipList[i].preID,clipList[i].timestamp);
							}
							Debug.traceMsg(this,"修补—id:",clipList[i].preID,clipList[i].timestamp);
						}else{
							clipList[i].preID=clipList[i-1].timestamp;
						}
						Debug.traceMsg(this,"clipList:"+clipList[i].timestamp+" preID:"+clipList[i].preID+" nextID:"+clipList[i].nextID);
						loadHeadHandler(clipList[i].head);
						_blockList.addBlock(clipList[i],loadType);
					}
					
					if(i>=1){
						//最后的数据
						clipList[i].preID=clipList[i-1].timestamp;
					}else if(i==0){
						//只有一个数据
						if(clipList[i].preID==0){
							clipList[i].preID=_blockList.getLastBlock(clipList[i].timestamp);
							//_blockList.getLastBlock(clipList[i].timestamp);//TEST
						}
						if(clipList[i].preID!=0){
							_blockList.repairNextBlockId(clipList[i].preID,clipList[i].timestamp);
						}
						Debug.traceMsg(this,"修补id",clipList[i].preID,clipList[i].timestamp);
					}
					loadHeadHandler(clipList[i].head);
					_blockList.addBlock(clipList[i],loadType);
					Debug.traceMsg(this,"clipList:"+clipList[i].timestamp+" preID:"+clipList[i].preID+" nextID:"+clipList[i].nextID);
				}
			}
		}
			
		/**在读取数据和写入数据时做调度策略*/
		public function handlerDownloadTask(evt:TimerEvent=null):void{
			if(Config.IS_REAL_LEAD)
			{
				if(!isHttpZoneFull(_startTime,(-Config.TIME_OFF)))
				{
					startHttpLoad(_startTime,(-Config.TIME_OFF));
				}else{
					//					Debug.traceMsg(this,"缓冲区已填满！！！，开启p2p");
					startP2PLoad();
					stopHttpLoad();
				}
			}
			else
			{				
				if(!isHttpZoneFull(_startTime,Config.DAT_BUFFER_TIME))
				{
					Debug.traceMsg(this,"缓冲区未满，停止p2p下载");
					startHttpLoad(_startTime,Config.DAT_BUFFER_TIME);
					stopP2PLoad();
				}else{
					Debug.traceMsg(this,"缓冲区已填满，开启p2p下载");
					startP2PLoad();
					stopHttpLoad();
				}
			}
			
		}
		
		protected function startHttpLoad(timestamp:Number,bufferTime:Number):void{
			//新规则，每次驱动，都会从播放点向后查询紧急区的数据是否饱和有空缺，如果有加载空缺
			//timestamp时间比_datLoad大，_datLoad停止加载，
			if(timestamp>_datLoad.getBlockID()){
				_datLoad.stop();
			}
			if(_datLoad.isDownLoad){return;}//正在加载不做处理，等待下一次时间驱动
			timestamp=_blockList.getBlockId(timestamp);
			if(timestamp==-1){return;}//没有desc不做处理
			_loadDatBlock=_blockList.getBlock(timestamp);
			while(_loadDatBlock&&_loadDatBlock.nextID!=0&&_loadDatBlock.isFull){
				if(_loadDatBlock.nextID-timestamp>bufferTime){
					return;
				}
				_loadDatBlock=_blockList.getBlock(_loadDatBlock.nextID);
			}
			//desc没有加载
			if(!_loadDatBlock){return}
			//Debug.traceMsg(this,"加载http流1:"+_loadDatBlock.nextID,_loadDatBlock.isFull);
			//开始进行加载http
			if(_lastLoadDatURL==""){
				_lastLoadDatURL=_loadDatBlock.name;
				Debug.traceMsg(this,"加载http流1:"+_lastLoadDatURL);
				_datLoad.start(_loadDatBlock.name,0,_loadDatBlock.size);	
			}else{
				if(_lastLoadDatURL!=_loadDatBlock.name){
					_lastLoadDatURL=_loadDatBlock.name;
					Debug.traceMsg(this,"加载http流2:"+_lastLoadDatURL);
					_datLoad.start(_loadDatBlock.name,0,_loadDatBlock.size);	
				}else if(_lastLoadDatURL ==_loadDatBlock.name){
					var nextBlock:Block=_blockList.getNextNearBlock(_loadDatBlock.id);
					if(nextBlock){
						_lastLoadDatURL=nextBlock.name;
						Debug.traceMsg(this,"加载http流3:"+_lastLoadDatURL);
						_datLoad.start(nextBlock.name,0,nextBlock.size);
					}
				}
			}
		}
		protected function stopHttpLoad():void{
			_datLoad.stop();
		}
		
		protected function startP2PLoad():void{
			//_stopP2P = false;
			_canP2PLoad = true;
		}
		protected function stopP2PLoad():void{
			//_stopP2P = true;
			_canP2PLoad = false;
		}
		
		public function  bytesLoaded():uint{
			return 0;
		}
		
		public function  bytesTotal():uint{
			return 0;
		}
		protected function streamHeadHandler(evt:EventExtensions):void{
			this._startTime=Number(evt.data);
			this._blockList.playHead=_startTime;
//			Debug.traceMsg(this,"调度器响应播放头事件"+_startTime);
			
			/**输出面板上报*/
			Statistic.getInstance().setPlayHead(_startTime);
			
		}
		
		protected function streamSeekHandler(evt:EventExtensions):void{
			Debug.traceMsg(this,"调度器响应Seek事件");
			reset();
		}
		
		protected function streamPlayHandler(evt:EventExtensions):void{
			Debug.traceMsg(this,"调度器响应play事件");
			_initData=evt.data as InitData;
			reset();
			_p2pLoad.startLoadP2P();
			startDownloadTask()
		}
		/**最小的desc的时间戳*/
		public function headTimestamp():Number{
			return this._startTime;
		}
	}
}