package com.hls_p2p.dataManager
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.loaders.Gslbloader.Gslbloader;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.loaders.cdnLoader.FactoryCdnLoadStream;
	import com.hls_p2p.loaders.cdnLoader.IStreamLoader;
	import com.hls_p2p.loaders.descLoader.FactoryDesc;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;

	public class DataManager
	{
		public var isDebug:Boolean	= false;
		
		/**数据链表*/
		protected var _blockList:BlockList;
		/**初始化数据*/
		protected var _initData:InitData;
		/**加载desc文件*/
		protected var _descLoad:IDescLoader;
		
		protected var loadManager:LoadManager;
		protected var m_oGslbloader:Gslbloader;
		
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
			
			m_oGslbloader = new Gslbloader(this);
			_descLoad  	= new FactoryDesc().createDescLoader(LiveVodConfig.TYPE,this);
			loadManager = new LoadManager(this);
		}
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamPlayHandler")
			_initData=evt.data as InitData;
			
			//TTT
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
//				m_oGslbloader.start(_initData);
			}

			_descLoad.start(_initData);
			loadManager.start(_initData);
		}
		
		public function startm3u8loader(p_initData:InitData):void
		{
			_descLoad.start(p_initData);
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
		
		private var retObj:Object;
		
		public function getDataTaskList():Object
		{
			retObj = new Object;
			
			if( !this._blockList )
			{
				return retObj;
			}
			retObj.groupList = this._blockList.getGroupIDList();
			retObj.task = new Array;
			if( LiveVodConfig.NEAREST_WANT_ID - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 )
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
				&& _blockList.getBlock(blkID).isChecked == false )
			{
				tmpID = -1;
			}
			
			var debugMsg:String = "";
			
			for( i = _blockList.blockArray.indexOf(blkID) ; i < _blockList.blockArray.length; i++ )
			{
				if( _blockList.blockArray[i] >= blkID )
				{	
					block = _blockList.getBlock(_blockList.blockArray[i]) as Block;
					
					if( block.id - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 )
					{
						P2PDebug.traceMsg( this,"getDataTaskList 找到边界" + debugMsg);
						return retObj;
					}					
					
					if( false == block.isChecked )
					{
						if(tmpID == LiveVodConfig.NEAREST_WANT_ID
							&&  block.id > LiveVodConfig.NEAREST_WANT_ID)
						{
							LiveVodConfig.NEAREST_WANT_ID = block.id;
//							P2PDebug.traceMsg( this,"NEAREST_WANT_ID:"+LiveVodConfig.NEAREST_WANT_ID )
						}
						debugMsg += block.id+" ";
						retObj.task.push(block);
//						iCount++;
						if (retObj.task.length > 60)
						{
							P2PDebug.traceMsg( this,"getDataTaskList iCount > 60:" + debugMsg);
							return retObj;
						}
					}
				}				
			}
//			if(iCount == 0 && block)
//			{
//				/**当本次查询未找到需下载的block时*/
//				LiveVodConfig.NEAREST_WANT_ID = block.id+block.duration;
//				P2PDebug.traceMsg( this,"iCount == 0 && NEAREST_WANT_ID =" + LiveVodConfig.NEAREST_WANT_ID);
//			}
			if( "" != debugMsg )
			{
				P2PDebug.traceMsg( this,"getDataTaskList :" + debugMsg);
			}
			return retObj;
		}
		
		public function clearIsLoaded(groupID:String,CDNTaskPieceList:Array,remoteTNList:Array=null,remotePNList:Array=null):void
		{
			this._blockList.clearIsLoaded(groupID,CDNTaskPieceList,remoteTNList,remotePNList);
		}
		
		public function clearIsLoaded_1( tempPiece:Piece ):void
		{
			this._blockList.deleteCDNIsLoadPiece(tempPiece);
		}
		
		public function getCDNRandomTask():Block
		{
			if( this._blockList.CDNIsLoadPieceArr 
				&& this._blockList.CDNIsLoadPieceArr.length > 0 )
			{
				var random:Number = Math.floor(Math.random()*this._blockList.CDNIsLoadPieceArr.length);
				
				var tmpBlock:Block = null;
				var tmpPiece:Piece = (this._blockList.CDNIsLoadPieceArr[random] as Piece);
				if( tmpPiece )
				{
					if( ifPeerHaveThisPiece(tmpPiece) )
					{
						/*P2PDebug.traceMsg( this,"getCDNRandomTask random: " + random + " bID: " + tmpPiece.blockID);
						tmpBlock = _blockList.blockList[(this._blockList.CDNIsLoadPieceArr[random] as Piece).blockID];*/
						return getCDNRandomTask();						
					}
				}

				return tmpBlock;
				//return getBlock((this._blockList.CDNIsLoadPieceArr[random] as Piece).blockID);
			}
			return null;
		}
		
		private function ifPeerHaveThisPiece( tempPiece:Piece ):Boolean
		{
			return loadManager.ifPeerHaveThisPiece( tempPiece );
		}
		
		public function getCDNTaskPieceList():Array
		{
			var arr:Array = new Array;
			if(this._blockList.CDNIsLoadPieceArr && this._blockList.CDNIsLoadPieceArr.length>0)
			{
				for( var i:uint = 0; i < this._blockList.CDNIsLoadPieceArr.length;i++)
				{
					arr.push( this._blockList.CDNIsLoadPieceArr[i].getPieceIndication() );
				}
			}
			return arr;
		}
		
		public function getBlockId(blockId:Number):Number
		{
			if (null == _blockList)
			{
				return -1;
			}
			
			return _blockList.getBlockId(blockId);
		}
		
		/**添加任务数据desc*/
		public function  writeClipList(clipList:Vector.<Clip>):void
		{
			var debugMsg:String = "";
			var groupIDList:Array = new Array;
			if( clipList.length > 0 )
			{
				for( var i:int=0;i<clipList.length-1;i++ )
				{
					clipList[i].nextID = clipList[i+1].timestamp;
					_blockList.addBlock(clipList[i]);
					debugMsg +=(i+" bID:"+clipList[i].timestamp+" nextID:"+clipList[i].nextID+" duration:"+clipList[i].duration+" name:"+clipList[i].name+" groupID:"+clipList[i].groupID+"\n");
					if( -1 == groupIDList.indexOf(clipList[i].groupID) )
					{
						groupIDList.push(clipList[i].groupID);
					}
				}
				
				debugMsg +=(i+" bID:"+clipList[i].timestamp+" nextID:"+clipList[i].nextID+" duration:"+clipList[i].duration+" name:"+clipList[i].name+" groupID:"+clipList[i].groupID+"\n");
				_blockList.addBlock(clipList[i]);
				
				if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
				{
					LiveVodConfig.LAST_TS_ID = clipList[clipList.length-1].timestamp;
				}
			}
			P2PDebug.traceMsg(this,"writeClip:\n"+debugMsg);
			//DO
			var obj:Object = new Object();
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				Statistic.getInstance().callBackMateData(obj);
			}
			//TTT 直播测试用
			else
			{
				Statistic.getInstance().callBackMateData(obj);
			}
			
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				this.loadManager.peerHartBeat(groupIDList);
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
		public function getBlock(id:Number,isDirect:Boolean = false):Block
		{
			if (null == _blockList)
			{
				return null;
			}
			if( !isDirect )
			{
				//
				id = _blockList.getBlockId(id); 
				if (-1 == id)
				{
					return null;
				}
			}
			return _blockList.getBlock(id);
		}
		
		public function getNextBlock(p_curid:Number,p_id:Number):Block
		{
			if( null == _blockList )
			{
				return null;
			}
			//
			var blockID:Number = _blockList.getNextBlockId(p_curid,p_id); 
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
			m_oGslbloader.clear();
			retObj = null;
			
			loadManager = null;
			_initData 	= null;
			_blockList	= null;
			_descLoad 	= null;
			m_oGslbloader = null;

		}
		/**输出方块调用*/
		public function get totalPiece():Number
		{
			return LiveVodConfig.TOTAL_PIECE;
		}
		/**输出方块调用*/
		public function get blockList():Object
		{
			return _blockList.blockList;
		}
		/**输出方块调用*/
		public function get blockArray():Array
		{
			return _blockList.blockArray;
		}
		/**输出方块调用*/
		public function getPlayingBlockID():Number
		{			
			return LiveVodConfig.ADD_DATA_TIME;
		}
		/**输出方块调用*/
		public function getP2PTaskArray():Array
		{
			if( retObj.task )
			{
				return retObj.task;
			}
			return null;
		}
		/**输出方块调用*/
		public function getPlayType():String
		{
			return LiveVodConfig.TYPE;
		}
		/**输出方块调用*/
		public function getMemorySize():uint
		{
			return LiveVodConfig.MEMORY_SIZE;
		}
		/**输出方块调用*/
		public function getBufferTime():Number
		{
			return loadManager.CacheLen;
		}
		
		public function getM3U8Task():Object
		{
			return loadManager.getM3U8Task();
		}
	}
}