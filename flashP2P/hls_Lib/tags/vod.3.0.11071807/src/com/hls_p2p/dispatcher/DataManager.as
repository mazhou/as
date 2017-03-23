package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.ReceiveData;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.loaders.cdnLoader.FactoryCdnLoadStream;
	import com.hls_p2p.loaders.cdnLoader.IStreamLoader;
	import com.hls_p2p.loaders.descLoader.FactoryDesc;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;

	public class DataManager implements IDataManager
	{
		public var isDebug:Boolean	= true;
		
		/**数据链表*/
		protected var _blockList:BlockList;
		/**初始化数据*/
		protected var _initData:InitData;
		/**加载desc文件*/
		protected var _descLoad:IDescLoader;
		
		protected var loadManager:LoadManager;

		public function getP2PTask(getP2PTask:Object):Object
		{
			if (null != loadManager	)
			{
				return loadManager.getP2PTask(getP2PTask);
			}
			return null;
		}
		
		public function DataManager()
		{
			init();
		}
		protected function init():void
		{
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			_blockList 	= new BlockList(this);
			_descLoad  	= new FactoryDesc().createDescLoader(LiveVodConfig.TYPE,this);
			loadManager = new LoadManager(this);
		}
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamPlayHandler")
			_initData=evt.data as InitData;
			_descLoad.start(_initData);
			loadManager.start(_initData);
		}
		protected function streamSeekHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamSeekHandler");
			if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				_descLoad.start(_initData);
			}
			
			loadManager.start(_initData);
		}
		
		public function getTNRange(groupID:String):Array
		{
			return this._blockList.getTNRange(groupID);
		}
		
		public function getPNRange(groupID:String):Array
		{
			return this._blockList.getPNRange(groupID);
		}
		
		public function getDataTask():Object
		{
			var retObj:Object = new Object;
			var iCount:uint = 0;
			
			retObj.groupList = this._blockList.getGroupIDList();
			retObj.task = new Array;
			
			var i:uint,j:uint;
			var piece:Piece;
			
			var arr:Array = new Array();
			for (var id:String in this._blockList.blockList)
			{
				arr.push(Number(id));
			}
			arr.sort(Array.NUMERIC);		
			for (i = 0 ; i<arr.length; i++)
			{
				var temp:Number = this.getBlockId(LiveVodConfig.ADD_DATA_TIME);
				if(-1 == temp)
				{
					return retObj;
				}
				
				if(arr[i] >= temp)
				{	
					var block:Block = _blockList.getBlock(arr[i]) as Block;
					if(false == block.isChecked )
					{
						retObj.task.push(block);
						iCount++;
						if (iCount > 20)
						{
							return retObj;
						}
					}
				}				
			}
			
			return retObj;
		}
		
		
		public function getBlockId(blockId:Number):Number
		{
			if (null == _blockList)
			{
				return NaN;
			}
			
			return _blockList.getBlockId(blockId);
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
				if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
				{
					LiveVodConfig.LAST_TS_ID = clipList[clipList.length-1].timestamp;
				}
			}
			//DO
			var obj:Object = new Object();
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				Statistic.getInstance().callBackMateData(obj);
			}
		}
		
		public function getPiece(param:Object):Piece
		{
			if (null != _blockList)
			{
				return _blockList.getPiece(param);
			}
			
			return null;
		}
		public function getNearestWantID(isPiece:Boolean=false):Number
		{
			if (null == _blockList)
			{
				return -1;
			}
			//---------------------------------------------------------
			if(LiveVodConfig.ADD_DATA_TIME == -1)
			{
				return -1;
			}
			var LoadTime:Number = LiveVodConfig.ADD_DATA_TIME;
			var LoadLoopRangeTime:Number = 0;
			var intervalTime:Number=3;
			var lastBlock:Block;
			var lastBlockId:Number=-1;
			var piece:Piece;
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				LoadLoopRangeTime = LiveVodConfig.LAST_TS_ID;
			}
			else if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				if(LoadTime == -1){return -1}
				LoadLoopRangeTime = LoadTime+(LiveVodConfig.MEMORY_TIME-1)*60;
				if(LoadLoopRangeTime > LIVE_TIME.GetLiveTime())
				{
					LoadLoopRangeTime = LIVE_TIME.GetLiveTime();
				}
			}
			
			for(LoadTime ; LoadTime < LoadLoopRangeTime ; LoadTime+=intervalTime)
			{
				var tmpTime:Number = _blockList.getBlockId(LoadTime);
				
				if(tmpTime==-1)
				{
					continue;
				}
				
				lastBlock=_blockList.getBlock(tmpTime);
				if(lastBlock && lastBlock.isChecked == false)
				{
					if(isPiece)
					{
						for(var j:uint = 0;j<lastBlock.pieceIdxArray.length;j++)
						{
							piece = this.getPiece(lastBlock.pieceIdxArray[j]);
							if(piece && !piece.isChecked && piece.from != "")
							{
								return Number(piece.pieceKey);
							}
						}
					}else
					{
						return (lastBlock.id);
					}
				}
			}
			
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				if(LiveVodConfig.LAST_TS_ID >= 0)
				{
					if(isPiece)
					{
						return -1;
					}
					else
					{
						return LiveVodConfig.LAST_TS_ID;
					}
				}
			}
			return -1;
		}
		
		/**根据id索引获得block*/
		public function getBlock(id:Number):Block
		{
			if (null == _blockList)
			{
				return null;
			}
			//
			var blockID:Number = _blockList.getBlockId(id); 
			if (-1 == blockID)
			{
				return null;
			}
			return _blockList.getBlock(blockID);
		}		
		
		public function getDataTaskList():Object
		{
			return getDataTask();
		}
		
		public function clear():void
		{
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			
			_blockList.clear();
			_descLoad.clear();
			loadManager.clear();
			
			loadManager = null;
			_initData 	= null;
			_blockList	= null;
			_descLoad 	= null;

		}
		
		public function getBytesLoaded():Block
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				var _tempBlock:Block = _blockList.getBlock(getNearestWantID());/**/
				return _tempBlock;
			}
			return null;
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
				arr.push(_blockList.blockList[i]);
			}
			arr.sortOn("id",16);
			return arr;
		}
	}
}