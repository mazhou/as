package com.hls_p2p.dataManager
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.Head;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.PlayData;
	import com.hls_p2p.data.vo.ReceiveData;
	import com.hls_p2p.dataManager.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.loaders.DATLoader;
	import com.hls_p2p.loaders.DescLoader;
	import com.hls_p2p.loaders.P2P_Loader;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	//import mx.effects.easing.Back;

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
		protected var _descLoad:DescLoader;
		/**声明dat加载器*/
		protected var _datLoad1:DATLoader;
//		protected var _datLoad2:DATLoader;
		/**声明p2p加载器*/
		protected var _p2pLoad:P2P_Loader;
		public var startTime:Number = Math.floor((new Date()).time);
		
		public function LiveDataManager()
		{
			init();
		}
		private function init():void
		{
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			_blockList = new BlockList(this);
			_descLoad  = new DescLoader(this);
			_datLoad1  = new DATLoader(this);
			_p2pLoad   = new P2P_Loader(this);
			
		}
		/**输出方块调用*/
		public function get totalPiece():Number
		{
			return LiveVodConfig.TOTAL_PIECE;
		}
		/**输出方块调用*/
		public function get blockList():Array
		{
			var arr:Array = new Array();
			var minObj:Object = new Object();
			for(var i:String in _blockList.blockList)
			{
				for(var m:String in _blockList.blockList[i]["blocks"])
				{
					arr.push(_blockList.blockList[i]["blocks"][m]);
				}				
			}
			arr.sortOn("id",16);			
			return arr;
		}
		/**输出方块调用*/
		public function get p2pEndMinute():Number
		{
			if(_p2pLoad && _p2pLoad.ifPeerConnection())
			{
				return _blockList.getWantPieceEndMinutes()["endMinutes"];
			}
			return 0;
		}
		//
		private var _tempBlock:Block;
		public function getBytesLoaded():Block
		{
			_tempBlock = _blockList.getBlock(getNearestWantID());
			return _tempBlock; 
//			if(_tempBlock)
//			{
//				if(_tempBlock.id != LiveVodConfig.LAST_TS_ID)
//				{
//					return _tempBlock.offSize;
//				}
//				else if(_tempBlock.id == LiveVodConfig.LAST_TS_ID && _tempBlock.isChecked)
//				{
//					return _initData.totalSize;
//				}
//				else if(_tempBlock.id == LiveVodConfig.LAST_TS_ID && !_tempBlock.isChecked)
//				{
//					return _initData.totalSize-_tempBlock.size;
//				}
//			}
//			return 0;
		}
		public function removeHaveData(tempEliminateArray:Array):void
		{
			_p2pLoad.removeHaveData(tempEliminateArray);
		}
		public function removePeerHaveData(peerID:String,peerRemoveDataArray:Array):void
		{
			_blockList.removePeerHaveData(peerID,peerRemoveDataArray);
		}
		//
		public function doAddHave():void
		{
			if (_p2pLoad)
			{
				_p2pLoad.doAddHave();
			}
		}
		//
		public function getNextSeqID(seqID:Number):Block
		{
			return _blockList.getNextSeqID(seqID);
		}
		public function getBlockId(blockId:Number):Number
		{
			return _blockList.getBlockId(blockId);
		}
		//		
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
			
			var _tempblock:Block=_blockList.getBlock(receiveData.blockID);
			if(_tempblock)
			{
				try{
					//P2PDebug.traceMsg(this,"setPieceStream.p2p:"+receiveData.from+" _tempblock:"+_tempblock.from);
					_tempblock.from=receiveData.from;
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
		//
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		public function getWantPiece(/*remoteHaveData:Array, */farID:String/*, wantCount:int=3*/):Array
		{		
			//return _blockList.getWantPiece(remoteHaveData, farID,wantCount);
			return _blockList.getWantPiece(farID);
		}
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		public function getNearestWantID():Number
		{
			/*if (this.PlayingBlockID > httpDownLoadPos)
				httpDownLoadPos = PlayingBlockID;
			return this.httpDownLoadPos;*/
			//---------------------------------------------------------
			//if(!_canP2PLoad) return 0;
			//var LoadTime:Number = LiveVodConfig.ADD_DATA_TIME;
			var LoadTime:Number = PlayingBlockID;
			var intervalTime:Number=3;
			var lastBlock:Block;
			var lastBlockId:Number=-1;
			for(LoadTime ; LoadTime < LiveVodConfig.LAST_TS_ID ; LoadTime+=intervalTime)
			{
				var tmpTime:Number=_blockList.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					continue;
				}
				
				lastBlock=_blockList.getBlock(tmpTime);
				if(lastBlock && lastBlock.isChecked == false)
				{
					//trace(this,"getNearestWantID  id "+lastBlock.id+" pid "+PlayingBlockID);
					return (lastBlock.id);
				}
				//
			}
			//
			if(LiveVodConfig.LAST_TS_ID >= 0)
			{
				//trace(this,"getNearestWantID LAST_TS_ID pid "+LiveVodConfig.LAST_TS_ID);
				return LiveVodConfig.LAST_TS_ID;
			}
			//trace(this,"getNearestWantID noFound pid "+PlayingBlockID);
			return 0;
		}
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		public function getDataAfterPoint(id:Number):Array
		{
			return _blockList.getDataAfterPoint(id);
		}
		/**根据id索引获得block*/
		public function getBlock(id:Number):Block
		{
			if (-1 == id) return null;
			return _blockList.getBlock(id);
		}
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function  handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void
		{
			_blockList.handlerTimeOutWantPiece(farID, blockID, pieceID);
		}
		
		
		/**添加任务数据desc*/
		public function  writeClipList(clipList:Vector.<Clip>,isMinEnd:Boolean):void
		{
			var totalPiece:int=0;
			if(clipList.length>0)
			{
				for(var i:int=0;i<clipList.length;i++)
				{
					_blockList.addBlock(clipList[i],isMinEnd);
					totalPiece+=clipList[i].pieceTotal;
				}
				LiveVodConfig.LAST_TS_ID = clipList[clipList.length-1].timestamp;
				//trace("LiveVodConfig.LAST_TS_ID = "+LiveVodConfig.LAST_TS_ID)
			}
			//DO
			var obj:Object = new Object();
			
			LiveVodConfig.TOTAL_TS    = obj.totalTS  = clipList.length;
			LiveVodConfig.TOTAL_PIECE = totalPiece;			
			
			/*this.totalTS=obj.totalTS  = clipList.length;
			this.totalPice=totalPice;*/
			Statistic.getInstance().callBackMateData(obj);
		}
		//
		private var PlayingBlockID:Number = -1;
		public function setPlayingBlockID(id:Number):void
		{
			PlayingBlockID = id;
		}
		public function getPlayingBlockID():Number
		{
			return PlayingBlockID;
		}
		//
		//private var MaxHttpPos:Number = Number.MIN_VALUE;
		//private var stopHttp:Boolean = false;
		public function getMaxHttpPos():Number
		{
			return  startTime;// _p2pLoad.getMaxHttpLoadPos();
		}
		//
		private var _httpDownLoadPos:Number = 0;
		public function get httpDownLoadPos():Number
		{
			return _httpDownLoadPos
		}
		public function set httpDownLoadPos(value:Number):void
		{
			_httpDownLoadPos=value;
		}	
		//public var earliestStartTimeAllPeer:Number = 0;
		
		public function getDataTask():Object
		{
			
			PlayingBlockID = _blockList.getBlockId(LiveVodConfig.ADD_DATA_TIME);
			
			if(_initData.ifP2PFirst())
			{
//				P2PDebug.traceMsg(this,"ad：=>"+_initData.getAdRemainingTime());
				return null;
			}
			
			if(PlayingBlockID == -1)
			{
				return null;
			}
			//
			var obj:Object = TimeTranslater.getHourMinObj(PlayingBlockID);
			while(1)
			{
				var minutesObject:Object =  _blockList.getMinuteBlocks(obj.minutes++);
				if (minutesObject == null)
					return null;
				//
				var arr:Array = new Array();
				for (var id:String in minutesObject)
				{
					arr.push(Number(id));
				}
				//
				arr.sort(Array.NUMERIC);
				for each(var i:Number in arr)
				{
					if (i >= PlayingBlockID)
					{
						var block:Block = minutesObject[i] as Block;
						//
						if (block)
						{
							if ((block.id - PlayingBlockID) > (LiveVodConfig.MEMORY_TIME-1)*60)
							{
								return null;
							}
							//
							if (block.id - PlayingBlockID < LiveVodConfig.DAT_BUFFER_TIME)
							{
								/**在紧急区之内的block，目前为播放点之后的紧急区秒数，
								 如果没有下载到数据或下载的数据有问题，则强行将该任务分配给
								 http下载*/
								if (false == block.isChecked)
								{
									block.downLoadStat = 1;
									httpDownLoadPos = block.id;
									return {"block":block,"pieceId":-1};
								}else{
									continue;
								}
							}
							//
							if (this._p2pLoad.ifPeerConnection() == false)//如果没有成功连接节点
								return null;
							//---------------------------------------------
//							for(var j:int=0;j<block.pieces.length;j++)
//							{
//								if(block.pieces[j].isLoad 
//									&& block.pieces[j].getStream().bytesAvailable==0 
//									&& block.pieces[j].peerHaveData.length==0){
//									return {"block":block,"pieceId":j};
//								}else
//								{
//									continue;
//								}
//							}
							continue;
						}
					}
				}
			}
			//
			return null;
		}
				
		protected function streamSeekHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamSeekHandler")
//			_descLoad.start(_initData);
			_datLoad1.start(_initData);
			PlayingBlockID = -1;
		}
		
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamPlayHandler")
			_initData=evt.data as InitData;
			_descLoad.start(_initData);
			_datLoad1.start(_initData);
			_p2pLoad.startLoadP2P(_initData);
			PlayingBlockID = -1;
			
			/*_adTime = _initData**********未完*/
		}
		
		public function clear():void
		{
			startTime			=0;
			PlayingBlockID		=0;
			//MaxHttpPos			=0;
			httpDownLoadPos	 	= 0;
			//maxAllPeerHttpPos	= 0;
			//stopHttp	 		= false;
			
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			
			_blockList.clear();
			_descLoad.clear();
			_datLoad1.clear();
			_p2pLoad.clear();
			_initData = null;
			_blockList= null;
			_descLoad = null;
			_datLoad1 = null;
//			_datLoad2 = null;
			_p2pLoad  = null;
			
		}
		public function getBlockBySeq(seqId:int):Block
		{
			return _blockList.getBlockBySeqID(seqId);
		}
		public function get playHead():Number
		{
			return 0
		}
	}
}