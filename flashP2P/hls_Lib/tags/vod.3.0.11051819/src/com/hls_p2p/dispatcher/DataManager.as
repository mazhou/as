package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
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
	import com.p2p.utils.TimeTranslater;
	
	import flash.utils.ByteArray;

	public class DataManager implements IDataManager
	{
		public var isDebug:Boolean=true;
		
		/**数据链表*/
		protected var _blockList:BlockList;
		/**初始化数据*/
		protected var _initData:InitData;
		/**加载desc文件*/
		protected var _descLoad:IDescLoader;
		
		protected var loadManager:LoadManager;

		public var startTime:Number = Math.floor((new Date()).time);
		
		public function getP2PTask(groupID:String, remoteID:String):Piece
		{
			if (null != loadManager	)
				return loadManager.getP2PTask(groupID,remoteID);
			//
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
		
		
		public function getDataTask():Object
		{
			return Object;
		}
		
		
		public function getBlockId(blockId:Number):Number
		{
			if (null == _blockList)
				return NaN;
			//
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
				LiveVodConfig.LAST_TS_ID = clipList[clipList.length-1].timestamp;
			}
			//DO
			var obj:Object = new Object();
			Statistic.getInstance().callBackMateData(obj);
		}
		
		public function getPiece(param:Object):Piece
		{
			if (null != _blockList)
				return _blockList.getPiece(param);
			//
			return null;
		}
		public function getNearestWantID():Number
		{
			return 0;
		}
		
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		public function getDataAfterPoint(groupID:String,id:Number):Array
		{
			if (null != _blockList)
				return _blockList.getDataAfterPoint(groupID,id);
			//
			return null;
		}
		
		/**根据id索引获得block*/
		public function getBlock(id:Number):Block
		{
			if (null == _blockList)
				return null;
			//
			var blockID:Number = _blockList.getBlockId(id); 
			if (-1 == blockID) return null;
			return _blockList.getBlock(blockID);
		}
		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function  handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void
		{
			if (null == _blockList)
				return ;
			//
			_blockList.handlerTimeOutWantPiece(farID, blockID, pieceID);
		}
		public function getDataTaskList():Object
		{
			return getDataTask();
		}
				
		public function doAddHave(groupID:String):void
		{
			if(loadManager)
			{
				loadManager.doAddHave(groupID);
			}
		}
		
		public function removeHaveData(eliminateArray:Array):void
		{
			if(loadManager)
			{
				loadManager.removeHaveData(eliminateArray);
			}
		}
		
		public function clear():void
		{
			startTime			=0;
			//MaxHttpPos		=0;
			//maxAllPeerHttpPos	= 0;
			//stopHttp	 		= false;
			
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			
			_blockList.clear();
			_descLoad.clear();
			loadManager.clear();
			
			loadManager = null;
			_initData = null;
			_blockList= null;
			_descLoad = null;
			
			//			_datLoad2 = null;
			
		}
		
		public function getBytesLoaded():Block
		{
			return null;
		}
		
		protected function getBlockBySeq(seqId:int):Block
		{
			if (null == _blockList)
				return null;
			//
			return _blockList.getBlockBySeqID(seqId);
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