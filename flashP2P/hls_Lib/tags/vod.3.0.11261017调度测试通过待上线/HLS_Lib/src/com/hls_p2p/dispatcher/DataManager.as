package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Piece;
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
	import com.hls_p2p.loaders.Gslbloader.Gslbloader;
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
				m_oGslbloader.start(_initData);
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
				//TTT
				P2PDebug.traceMsg( this,"getDataTaskList !this._blockList " );
				return retObj;
			}
			retObj.groupList = this._blockList.getGroupIDList();
			retObj.task = new Array;
			if( LiveVodConfig.NEAREST_WANT_ID - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 )
			{
				//TTT
				P2PDebug.traceMsg( this,"LiveVodConfig.NEAREST_WANT_ID - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 return" );
				return retObj;
			}
			//
			var tmpnearstblockid:Number = LiveVodConfig.NEAREST_WANT_ID;
			var blkID:Number = this.getBlockId(tmpnearstblockid);
			
			if(-1 == blkID)
			{
				//TTT
				P2PDebug.traceMsg( this,"-1 == blkID" + " LiveVodConfig.NEAREST_WANT_ID:" + tmpnearstblockid );
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
			
			
			for( i = _blockList.blockArray.indexOf(blkID) ; i < _blockList.blockArray.length; i++ )
			{
				if( _blockList.blockArray[i] >= blkID )
				{	
					block = _blockList.getBlock(_blockList.blockArray[i]) as Block;
					
					if( block.id - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 )
					{
						//TTT
						P2PDebug.traceMsg( this,"block.id - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60" );
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
						if (iCount > 60)
						{
							//TTT
							P2PDebug.traceMsg( this,"iCount > 60" );
							return retObj;
						}
					}
				}				
			}
			if(iCount == 0 && block)
			{
				/**当本次查询未找到需下载的block时*/
				LiveVodConfig.NEAREST_WANT_ID = block.id+block.duration;
				//TTT
				P2PDebug.traceMsg( this,"iCount == 0 && block LiveVodConfig.NEAREST_WANT_ID = block.id+block.duration" );
			}
			return retObj;
		}
		
		public function checkIsLoaded(blkList:Array):void
		{
			this._blockList.checkIsLoaded(blkList);
		}
		public function clearIsLoaded(CDNTaskPieceList:Array):void
		{
			this._blockList.clearIsLoaded(CDNTaskPieceList);
		}
		
		public function getCDNRandomTask():Block
		{
			if( this._blockList.CDNIsLoadPieceArr 
				&& this._blockList.CDNIsLoadPieceArr.length > 0 )
			{
				var random:Number = Math.floor(Math.random()*this._blockList.CDNIsLoadPieceArr.length);
				//this._blockList.addPNRange((this._blockList.CDNIsLoadPieceArr[random] as Piece).groupID,(this._blockList.CDNIsLoadPieceArr[random] as Piece).id);
				P2PDebug.traceMsg( this,"getCDNRandomTask random: " + random + " randomblockid: " + (this._blockList.CDNIsLoadPieceArr[random] as Piece).blockID);
				return getBlock((this._blockList.CDNIsLoadPieceArr[random] as Piece).blockID);
			}
			return null;
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
				return NaN;
			}
			
			return _blockList.getBlockId(blockId);
		}
		
		/**添加任务数据desc*/
		public function  writeClipList(clipList:Vector.<Clip>):void
		{
			var groupIDList:Array = new Array;
			if(clipList.length>0)
			{
				for(var i:int=0;i<clipList.length;i++)
				{
					_blockList.addBlock(clipList[i]);
					if( -1 == groupIDList.indexOf(clipList[i].groupID) )
					{
						groupIDList.push(clipList[i].groupID);
					}
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
			
			this.loadManager.peerHartBeat(groupIDList);
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