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
	import com.p2p.loaders.DATLoader;
	import com.p2p.loaders.DescLoader;
	import com.p2p.loaders.HeadLoader;
	import com.p2p.loaders.P2P_Loader;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
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
		protected var _datLoad2:DATLoader;
		/**声明metadata（即头）加载器*/
		protected var _headLoad:HeadLoader;
		/**声明p2p加载器*/
		protected var _p2pLoad:P2P_Loader;
		
		public function LiveDataManager()
		{
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			_blockList = new BlockList();
			_descLoad  = new DescLoader(this);
			_datLoad1  = new DATLoader(this);
			_datLoad2  = new DATLoader(this);
			_headLoad  = new HeadLoader(this);
			_p2pLoad   = new P2P_Loader(this);
		}
		
		/**getHead*/
		public function getHead(blockId:Number):Head
		{
			/**获得*/
			var id:Number = _blockList.getBlockId(blockId);
			var _tempblock:Block=_blockList.getBlock(id);
			if(_tempblock)
			{
				if(_blockList.getHead(_tempblock.head))
				{
					return _blockList.getHead(_tempblock.head);
				}else
				{
					return null;
				}
			}
			return null;
		}
		//
		public function getHeadTask():Head
		{
			var id:Number = _blockList.getBlockId(LIVE_TIME.GetBaseTime());
			var _tempblock:Block=_blockList.getBlock(id);
			if(_tempblock)
			{
				var hd:Head = _blockList.getHead(_tempblock.head);
				if(hd)
				{
					if (hd.getHeadStream().bytesAvailable > 0)
					{
						//return _blockList.getHeadTask();
						return null;
					}
				}
				else
				{
					return hd;
				}
			}
			//
			return _blockList.getHeadTask();
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
			
		}
		//
		public function getDescTask():Number
		{
			return this._blockList.getDescTask();
		}		
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		public function getWantPiece(remoteHaveData:Array, farID:String, wantCount:int=3):Array
		{		
			return _blockList.getWantPiece(remoteHaveData, farID,wantCount);
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
					continue;
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
		public function  writeClipList(clipList:Vector.<Clip>):void
		{
			if(clipList.length>0)
			{
				for(var i:int=0;i<clipList.length;i++)
				{
					_blockList.addBlock(clipList[i]);
				}
			}
		}
			
		private var PlayingBlockID:Number = -1;
		public function setPlayingBlockID(id:Number):void
		{
			PlayingBlockID = id;
		}
		public function getDataTask():Block
		{
			var obj:Object = TimeTranslater.getHourMinObj(LIVE_TIME.GetBaseTime());
			if (PlayingBlockID == -1)
			{
				PlayingBlockID = _blockList.getBlockId(LIVE_TIME.GetBaseTime());
				if(PlayingBlockID == -1)
				{
					return null;
				}
			}
			//
			obj = TimeTranslater.getHourMinObj(PlayingBlockID);
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
						if (block)
						{
							if (block._downLoadStat == 0 )
							{
								if (!LiveVodConfig.IS_REAL_LEAD && block.id - LIVE_TIME.GetBaseTime() > LiveVodConfig.DAT_BUFFER_TIME)
								{
									return null;
								}
								else 
								{
									return block;
								}
							}
							//
							if (block.id - LIVE_TIME.GetBaseTime() < LiveVodConfig.DAT_BUFFER_TIME)
							{
								if (block._downLoadStat == 2 || (!block.isChecked && block._downLoadStat == 3))
								{
									return block;
								}
							}
						}
					}
				}
			}
			//
			return null;
		}
				
		protected function streamSeekHandler(evt:EventExtensions):void
		{
			_descLoad.start(_initData);
			_headLoad.start(_initData);
			_datLoad1.start(_initData);
			_datLoad2.start(_initData);
			//SeqPlay = -1;
			PlayingBlockID = -1;
		}
		
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			_initData=evt.data as InitData;
			_descLoad.start(_initData);
			_headLoad.start(_initData);
			_datLoad1.start(_initData);
			_datLoad2.start(_initData);
			_p2pLoad.startLoadP2P();
			PlayingBlockID = -1;
		}
	}
}