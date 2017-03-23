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
//	import com.hls_p2p.loaders.descLoader.DescLoader;
	import com.hls_p2p.loaders.descLoader.FactoryDesc;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;

	public class DataManager
	{
		public var isDebug:Boolean	= true;
		
		/**数据链表*/
		protected var _blockList:BlockList;
		/**初始化数据*/
		protected var _initData:InitData;
		/**加载desc文件*/
		protected var _descLoad:IDescLoader;
//		protected var _descLoad_1:DescLoader;

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
//			_descLoad_1	= new DescLoader(this);
			loadManager = new LoadManager(this);
		}
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamPlayHandler")
			_initData=evt.data as InitData;
			
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
//				m_oGslbloader.start(_initData);
			}

			_descLoad.start(_initData);
//			_descLoad_1.start(_initData);
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
//				_descLoad_1.start(_initData);
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
			var piece:Piece;
			var tmpID:Number = LiveVodConfig.NEAREST_WANT_ID;
			var block:Block;
	
			if( _blockList.getBlock(blkID)
				&& _blockList.getBlock(blkID).isChecked == false )
			{
				tmpID = -1;
			}
			
			var debugMsg:String = "";
			for( var i:int = _blockList.blockArray.indexOf(blkID); i < _blockList.blockArray.length; i++ )
			{
				if( _blockList.blockArray[i] >= blkID 
					&& _blockList.blockArray[i] <= LiveVodConfig.M3U8_MAXTIME )
				{	
					block = _blockList.getBlock(_blockList.blockArray[i]) as Block;
					
					if( block.id - LiveVodConfig.ADD_DATA_TIME > (LiveVodConfig.MEMORY_TIME-1)*60 )
					{
						P2PDebug.traceMsg( this,"getDataTaskList 找到边界" + debugMsg);
						if( tmpID == LiveVodConfig.NEAREST_WANT_ID )
						{
							LiveVodConfig.NEAREST_WANT_ID = block.id;
						}
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
						//trace("NEAREST_WANT_ID = "+LiveVodConfig.NEAREST_WANT_ID+", ADD_DATA_TIME = "+LiveVodConfig.ADD_DATA_TIME+", block.id = "+block.id);
//						iCount++;
						if (retObj.task.length > 60)
						{
							P2PDebug.traceMsg( this,"getDataTaskList iCount > 60:" + debugMsg);
							if( tmpID == LiveVodConfig.NEAREST_WANT_ID )
							{
								LiveVodConfig.NEAREST_WANT_ID = block.id;
							}
							return retObj;
						}
					}
				}
				else if( _blockList.blockArray[i] > LiveVodConfig.M3U8_MAXTIME )
				{
					if( block && tmpID == LiveVodConfig.NEAREST_WANT_ID )
					{
						LiveVodConfig.NEAREST_WANT_ID = block.id;
					}
					return retObj;
				}
			}

			if( "" != debugMsg )
			{
				P2PDebug.traceMsg( this,"getDataTaskList :" + debugMsg);
			}
			if( block && tmpID == LiveVodConfig.NEAREST_WANT_ID )
			{
				LiveVodConfig.NEAREST_WANT_ID = block.id;
			}
			return retObj;
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
				
				var tmpPiece:Piece = (this._blockList.CDNIsLoadPieceArr[random]["piece"] as Piece);
				if( tmpPiece )
				{
					//if(ifPeerHaveThisPiece(tmpPiece))
					if( ifPeerHaveThisPiece({"pieceKey":tmpPiece.pieceKey,"type":tmpPiece.type,"groupID":tmpPiece.groupID}) )
					{
						clearIsLoaded_1( tmpPiece );
						return getCDNRandomTask();						
					}
					if(this._blockList.CDNIsLoadPieceArr 
						&& this._blockList.CDNIsLoadPieceArr[random] 
						&& this._blockList.CDNIsLoadPieceArr[random]["blockID"])
					{
						return this._blockList.getBlock(this._blockList.CDNIsLoadPieceArr[random]["blockID"]);
					}
					else
					{
						return null;
					}
				}
				//return getBlock((this._blockList.CDNIsLoadPieceArr[random] as Piece).blockID);
			}
			return null;
		}
		
		private function ifPeerHaveThisPiece( tempPieceObj:Object ):Boolean
		{
			return loadManager.ifPeerHaveThisPiece( tempPieceObj );
		}
		
		public function getCDNTaskPieceList():Array
		{
			var arr:Array = new Array;
			if(this._blockList.CDNIsLoadPieceArr && this._blockList.CDNIsLoadPieceArr.length>0)
			{
				for( var i:uint = 0; i < this._blockList.CDNIsLoadPieceArr.length;i++)
				{
					arr.push( (this._blockList.CDNIsLoadPieceArr[i]["piece"] as Piece).getPieceIndication() );
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
					debugMsg +=(i+" bID:"+clipList[i].timestamp+" nextID:"+clipList[i].nextID+" duration:"+clipList[i].duration+" discontinuity:"+clipList[i].discontinuity+" name:"+clipList[i].name+" groupID:"+clipList[i].groupID+"\n");
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
//				this.loadManager.peerHartBeat(groupIDList);
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
//			_descLoad_1.clear();
			loadManager.clear();
			m_oGslbloader.clear();
			
			loadManager = null;
			_initData 	= null;
			_blockList	= null;
			_descLoad 	= null;
//			_descLoad_1 = null;
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
//			if( retObj.task )
//			{
//				return retObj.task;
//			}
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
		
		private var currentM3U8LoadIndex:int = 0;
		private var lastGetM3u8Time:Number = 0;
		public function getM3U8Task_1( loadM3u8Msg:Object ):Object
		{
			//点播
			//直播
			var  MEMORY_TIME:Number = LiveVodConfig.MEMORY_TIME;
			
//			{lastTsTime,error,urlIndex}
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				if( this._initData.g_bGslbComplete || -1 == loadM3u8Msg.lastTsTime )
				{
					//点播需要加载数据情况
					checkM3U8LoadIndex( loadM3u8Msg );
					
					this._initData.g_bGslbComplete = false;
					return {"abtimeshift":0,"urlIndex":currentM3U8LoadIndex}
				}
				//不需要加载数据
				return {"abtimeshift":-1,"urlIndex":currentM3U8LoadIndex}
			}else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				//直播依据上次的时间加载数据，当seek按照seek加载数据，
				//当大于边界或直播点时，停止快节奏加载（3秒一加载）
				if( LiveVodConfig.M3U8_MAXTIME != -1 )
				{
//					if(lastGetM3u8Time)
//					{
//						
//					}
					//边界判断
					var isAchieveLiveBorder:Boolean;
					var isAchieveMemoryBorder:Boolean;
					if(this._initData.g_bGslbComplete)
					{
						checkM3U8LoadIndex( loadM3u8Msg );
						
					}
					else if( isAchieveLiveBorder || isAchieveMemoryBorder )
					{
						
					}
					else 
					{
						
					}
					
//					if( ( LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME ) < 20
//						|| LiveVodConfig.ADD_DATA_TIME != -1
//						|| (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME)> ((LiveVodConfig.MEMORY_TIME-1)*60) 
//					)
//					{
//						
//					}
					//紧急加载
					
					
					
				}

			}
			
			return {"abtimeshift":LiveVodConfig.ADD_DATA_TIME,"urlIndex":0};
		}
		private function checkM3U8LoadIndex(loadM3u8Msg:Object):void
		{
			if( loadM3u8Msg.error == "securityError" 
				|| loadM3u8Msg.error == "ioError"
				|| loadM3u8Msg.error == "timeOut"
			)
			{
				if( loadM3u8Msg.urlIndex == currentM3U8LoadIndex )
				{
					currentM3U8LoadIndex++;
					if( currentM3U8LoadIndex == _initData.flvURL.length )
					{
						currentM3U8LoadIndex = 0;
					}
				}
			}
		}
		public function getM3U8Task():Object
		{   
			if( LiveVodConfig.M3U8_MAXTIME > LiveVodConfig.ADD_DATA_TIME + 210 )
				return null;
					
			return loadManager.getM3U8Task();
		}
	}
}