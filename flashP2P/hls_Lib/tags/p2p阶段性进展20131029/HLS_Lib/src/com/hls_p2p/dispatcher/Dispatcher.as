package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.data.vo.ReceiveData;
	import com.hls_p2p.dispatcher.IDispatcher;
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

	public class Dispatcher implements IDispatcher
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
		
		public function Dispatcher()
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
			P2PDebug.traceMsg(this,"streamSeekHandler")
			
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
		
		public function getNextSeqID(seqID:Number):Block
		{
			return _blockList.getNextSeqID(seqID);
		}
		
		public function getBlockId(blockId:Number):Number
		{
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
		
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		public function getWantPiece(farID:String):Array
		{
			return _blockList.getWantPiece(farID);
		}
		
		public function getPiece(param:Object):Piece
		{
			return _blockList.getPiece(param);
		}
		public function getNearestWantID():Number
		{
			return 0;
		}
		
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		public function getDataAfterPoint(groupID:String,id:Number):Array
		{
			return _blockList.getDataAfterPoint(groupID,id);
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
		
		public function removePeerHaveData(peerID:String, peerRemoveDataArray:Array):void
		{
			_blockList.removePeerHaveData(peerID,peerRemoveDataArray);
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
				for(var m:String in _blockList.blockList[i]["blocks"])
				{
					arr.push(_blockList.blockList[i]["blocks"][m]);
				}				
			}
			arr.sortOn("id",16);			
			return arr;
		}
		/**输出方块调用*/
//		public function get p2pEndMinute():Number
//		{
//			if(_p2pLoad && _p2pLoad.ifPeerConnection() && _blockList.getWantPieceEndMinutes())
//			{
//				return _blockList.getWantPieceEndMinutes()["endMinutes"];
//			}
//			return 0;
//		}
	}
}