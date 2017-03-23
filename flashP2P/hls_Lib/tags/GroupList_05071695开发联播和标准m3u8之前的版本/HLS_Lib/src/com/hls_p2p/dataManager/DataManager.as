package com.hls_p2p.dataManager
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.GroupList;
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
	import com.hls_p2p.loaders.ReportDownloadError;
	import com.hls_p2p.loaders.cdnLoader.FactoryCdnLoadStream;
	import com.hls_p2p.loaders.cdnLoader.IStreamLoader;
	import com.hls_p2p.loaders.descLoader.FactoryDesc;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;

	public class DataManager
	{
		public var isDebug:Boolean	= true;
		
		/**数据链表*/
		//protected var _blockList:BlockList;
		protected var _groupList:GroupList;
		/**初始化数据*/
		protected var _initData:InitData;
		/**加载desc文件*/
		protected var _descLoad:IDescLoader;
		
		protected var _reportDownloadError:ReportDownloadError;
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
			
			//_blockList 	= new BlockList(this);
			_groupList = new GroupList(this);
			
			m_oGslbloader = new Gslbloader(this);
			_descLoad  	= new FactoryDesc().createDescLoader(LiveVodConfig.TYPE,this);
//			_descLoad_1	= new DescLoader(this);
			loadManager = new LoadManager(this);
		}
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"streamPlayHandler")
			_initData = evt.data["initData"] as InitData;
			_reportDownloadError =  evt.data["reportDownloadError"] as ReportDownloadError;
			
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				m_oGslbloader.start(_initData);
			}
//			_descLoad_1.start(_initData);
			loadManager.start(_initData);
			_descLoad.start(_initData);
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
			return this._groupList.getTNRange(groupID);
		}
		
		public function getPNRange(groupID:String):Array
		{
			return this._groupList.getPNRange(groupID);
		}
		
		public function getGroupIDList():Array
		{
			return _groupList.getGroupIDList();
		}
		public function clearIsLoaded_1( tempPiece:Piece ):void
		{
			this._groupList.deleteCDNIsLoadPiece(tempPiece);
		}
		
		public function getCDNRandomTask():Block
		{
			if( this._groupList.CDNIsLoadPieceArr 
				&& this._groupList.CDNIsLoadPieceArr.length > 0 )
			{
				var random:Number = Math.floor(Math.random()*this._groupList.CDNIsLoadPieceArr.length);
				
				var tmpPiece:Piece = (this._groupList.CDNIsLoadPieceArr[random]["piece"] as Piece);
				if( tmpPiece )
				{
					if(this._groupList.CDNIsLoadPieceArr 
						&& this._groupList.CDNIsLoadPieceArr[random] 
						&& this._groupList.CDNIsLoadPieceArr[random]["blockID"])
					{
						P2PDebug.traceMsg(this,"getCDNRandomTask:" + tmpPiece.pieceKey );
						return this._groupList.getBlock(_groupList.CDNIsLoadPieceArr[random]["piece"]["groupID"],this._groupList.CDNIsLoadPieceArr[random]["blockID"]);
					}
					else
					{
						return null;
					}
				}
				//return getBlock((this._groupList.CDNIsLoadPieceArr[random] as Piece).blockID);
			}
			return null;
		}
		
		public function removeTheHitCDNRandomTask(remoteArray:Array):void
		{
			if( this._groupList.CDNIsLoadPieceArr 
				&& this._groupList.CDNIsLoadPieceArr.length > 0
				&& remoteArray
				&& remoteArray.length > 0 )
			{
				for (var i:int = 0; i < _groupList.CDNIsLoadPieceArr.length; i++)
				{
					var tmpPiece:Piece = (this._groupList.CDNIsLoadPieceArr[i]["piece"] as Piece);
					if( tmpPiece )
					{
						for (var j:int = 0; j < remoteArray.length; j++)
						{
							var obj:Object = remoteArray[j];
							if (  tmpPiece.groupID   == obj.groupID 
								&& tmpPiece.pieceKey == obj.pieceKey
								&& tmpPiece.type     == obj.type)
							{
								
								_groupList.CDNIsLoadPieceArr.splice(i,1);
								break;
							}
						}
					}
				}
			}
		}
		
		public function getCDNTaskPieceList():Array
		{
			var arr:Array = new Array;
			if(this._groupList.CDNIsLoadPieceArr && this._groupList.CDNIsLoadPieceArr.length>0)
			{
				for( var i:uint = 0; i < this._groupList.CDNIsLoadPieceArr.length;i++)
				{
					arr.push( (this._groupList.CDNIsLoadPieceArr[i]["piece"] as Piece).getPieceIndication() );
				}
			}
			return arr;
		}
		
		public function getBlockId(groupID:String,blockId:Number):Number
		{
			if (null == _groupList)
			{
				return -1;
			}
			
			return _groupList.getBlockId(groupID,blockId);
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
					_groupList.addBlock(clipList[i]);
					debugMsg +=(i+" bID:"+clipList[i].timestamp+" nextID:"+clipList[i].nextID+" duration:" + clipList[i].duration +" discontinuity:" + clipList[i].discontinuity + " pieceInfo:" + clipList[i].pieceInfoArray + " name:"+clipList[i].name + " groupID:"+clipList[i].groupID+"\n");
					if( -1 == groupIDList.indexOf(clipList[i].groupID) )
					{
						groupIDList.push(clipList[i].groupID);
					}
				}
				
				debugMsg +=(i+" bID:"+clipList[i].timestamp+" nextID:"+clipList[i].nextID+" duration:"+clipList[i].duration + " discontinuity:" + clipList[i].discontinuity + " pieceInfo:" + clipList[i].pieceInfoArray + " name:"+clipList[i].name+" groupID:"+clipList[i].groupID+"\n");
				_groupList.addBlock(clipList[i]);
				
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
			if (null != _groupList)
			{
				return _groupList.getPiece(param);
			}
			
			return null;
		}
		
		/**根据id索引获得block*/
		public function getBlock(gID:String,id:Number,isDirect:Boolean = false):Block
		{
			if (null == _groupList)
			{
				return null;
			}
			if( !isDirect )
			{
				//
				id = _groupList.getBlockId(gID,id); 
				if (-1 == id)
				{
					return null;
				}
			}
			return _groupList.getBlock(gID,id);
		}
		
		public function getNextBlock( gID:String,p_curid:Number ):Block
		{
			if( null == _groupList )
			{
				return null;
			}
			//
			var blockID:Number = _groupList.getNextBlockId( gID,p_curid ); 
			if (-1 == blockID)
			{
				return null;
			}
			return _groupList.getBlock( gID,blockID );
		}
		
		public function downloadTSFailed(bID:Number,pID:Number):void
		{
			_reportDownloadError.downloadTSFailed(bID,pID);
		}
		public function downloadM3U8Failed():void
		{
			_reportDownloadError.downloadM3U8Failed();
		}
		public function startDownloadTS(bID:Number,pID:Number):void
		{
			_reportDownloadError.startDownloadTS(bID,pID);
		}
		public function startDownloadM3U8():void
		{
			_reportDownloadError.startDownloadM3U8();
		}
		
		public function clear():void
		{
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.SEEK,streamSeekHandler);
			
			_groupList.clear();
			_descLoad.clear();
//			_descLoad_1.clear();
			loadManager.clear();
			m_oGslbloader.clear();
			
			loadManager = null;
			_initData 	= null;
			_groupList	= null;
			_descLoad 	= null;
//			_descLoad_1 = null;
			m_oGslbloader = null;
			_reportDownloadError = null;
		}
		/**输出方块调用*/
		public function get totalPiece():Number
		{
			return LiveVodConfig.TOTAL_PIECE;
		}
		/**输出方块调用*/
		public function getBlockList( gID:String ):Object
		{
			return _groupList.getBlockList( gID );
		}
		/**输出方块调用*/
		public function getBlockArray( gID:String ):Array
		{
			return _groupList.getBlockArray( gID );
		}
		/**输出方块调用*/
		public function getPlayingBlockID():Number
		{			
			return LiveVodConfig.ADD_DATA_TIME;
		}
		/**输出方块调用*/
		
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
			if( LiveVodConfig.M3U8_MAXTIME > LiveVodConfig.ADD_DATA_TIME + 2100 )//2100约300×7（秒）的时间
				return null;
					
			return loadManager.getM3U8Task();
		}
		
		public function getP2PTaskArray():Array
		{
			return null;
		}
	}
}