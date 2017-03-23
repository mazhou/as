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
		
		public function getDataTaskList():Object
		{
			
			var retObj:Object = new Object;
			if( !this._blockList )
			{
				return retObj;
			}
			retObj.groupList = this._blockList.getGroupIDList();
			retObj.task = new Array;
			if (LiveVodConfig.NEAREST_WANT_ID - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60)
			{
				return retObj;
			}
			//
			var tmpnearstblockid:Number = LiveVodConfig.NEAREST_WANT_ID;
			var blkID:Number = this.getBlockId(tmpnearstblockid);
			
			if(-1 == blkID)
			{
				return retObj;
			}
			//
			var iCount:uint = 0;			
			var i:int,j:uint;
			var piece:Piece;
			var tmpID:Number = LiveVodConfig.NEAREST_WANT_ID;
			var block:Block;
	
			if( _blockList.getBlock(blkID)
				&& _blockList.getBlock(blkID).isChecked == false)
			{
				tmpID = -1;
			}
			
			
			for (i = _blockList._blockArray.indexOf(blkID) ; i < _blockList._blockArray.length; i++)
			{
				if(_blockList._blockArray[i] >= blkID)
				{	
					block = _blockList.getBlock(_blockList._blockArray[i]) as Block;
					
					if( block.id - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 )
					{
						return retObj;
					}					
					
					if( false == block.isChecked )
					{
						if(tmpID == LiveVodConfig.NEAREST_WANT_ID
							&&  block.id > LiveVodConfig.NEAREST_WANT_ID)
						{
							LiveVodConfig.NEAREST_WANT_ID = block.id;
						}
						
						retObj.task.push(block);
						iCount++;
						if (iCount > 20)
						{
							return retObj;
						}
					}
				}				
			}
			if(iCount == 0 && block)
			{
				/**当本次查询未找到需下载的block时*/
				LiveVodConfig.NEAREST_WANT_ID = block.id+block.duration;
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
			//TTT 直播测试用
			else
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