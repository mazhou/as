package com.hls_p2p.data
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.logs.P2PDebug;
	
	import flash.utils.ByteArray;
	public class GroupList
	{		
		private var _blockListArr:Array;
		//_blockListArr[blockList[blockID][pieceIdxArr]]
		private var _dataManger:DataManager;
		/**保存piece的总列表*/
		private var _pieceList:Object 				= new Object;
		/**当成功添加数据流时，由block调用赋值，当执行淘汰时，用该值进行判断是否淘汰*/
		public var streamSize:Number = 0;
		/**直播状态下保存CDN在紧急区之外需要下载的piece*/
		//public var CDNIsLoadPieceArr:Array	= new Array;
		public var _dataMgr:DataManager 	= null;
		private var _tempBlockList:BlockList;
		
		public function GroupList(dataMgr:DataManager)
		{
			_dataMgr = dataMgr;
			init();
		}
		/*public function set CDNIsLoadPieceArr():void
		{
			(_blockListArr[0] as BlockList).CDNIsLoadPieceArr
		}*/
		public function get CDNIsLoadPieceArr():Array
		{
			//直播时，紧急区之外随机下载的数据
			return (_blockListArr[0] as BlockList).CDNIsLoadPieceArr;
		}
		
		private function init():void
		{
			_blockListArr = new Array();
		}
		private function sortGroup():void
		{
			if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD )
			{
				//如果是联播，需要根据group的创建时间结合thisGroup与nextGroup对_blockListArr进行排序
				_blockListArr.sort("creatTime");
			}
		}
		private function isHaveGroup( id:String ):int
		{
			if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD )
			{
				//当联播时_blockListArr里有多个group,目前最多维持3个group
				for( var i:int=0 ; i<_blockListArr.length ; i++)
				{
					if( (_blockListArr[i] as BlockList).groupID == id  )
					{
						return i;
					}
				}
				return -1;
			}
			//当不是联播状态时，_blockListArr里只维持一个group,所以返回0索引
			if( _blockListArr.length == 0 )
			{
				return -1;
			}
			return 0;
		}
		public function getTNRange(groupID:String):Array
		{
			var idx:int = isHaveGroup( groupID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).getTNRange(groupID);
			}
			return null;
		}
		
		public function getPNRange(groupID:String):Array
		{
			var idx:int = isHaveGroup( groupID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).getPNRange(groupID);
			}
			return null;
		}
		public function deleteCDNIsLoadPiece( piece:Piece ):void
		{
			var idx:int = isHaveGroup( piece.groupID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).deleteCDNIsLoadPiece( piece );
			}
		}
		public function addBlock(clip:Clip):Boolean
		{
			var idx:int = isHaveGroup(clip.groupID);
			if( -1 == idx )
			{
				var newBlockList:BlockList = new BlockList( _dataMgr,this );
				newBlockList.creatTime = getTime();
				newBlockList.groupID   = clip.groupID;
				_blockListArr.push(newBlockList);
				idx = _blockListArr.length-1;
			}
			return _blockListArr[idx].addBlock(clip);
		}
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		
		public function getBlockId( gID:String,id:Number ):Number
		{
			var idx:int = isHaveGroup( gID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).getBlockId(id);
			}
			return -1;
		}
		public function getNextBlockId( gID:String,p_curid:Number ):Number
		{
			var idx:int = isHaveGroup( gID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).getNextBlockId(p_curid);
			}
			return -1;
		}
		public function getPiece(param:Object):Piece
		{
			var idx:int = -1;
			if( param && param.hasOwnProperty("groupID")  )
			{
				idx = isHaveGroup( param["groupID"] );
			}
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).getPiece(param);
			}
			return null;
		}
		public function getBlock( gID:String,id:Number ):Block
		{
			var idx:int = isHaveGroup( gID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).getBlock(id);
			}
			return null;
		}
		public function getBlockList( gID:String ):Object
		{
			var idx:int = isHaveGroup( gID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).blockList;
			}
			return null;
		}
		public function getBlockArray( gID:String ):Array
		{
			var idx:int = isHaveGroup( gID );
			if( -1 != idx )
			{
				return (_blockListArr[idx] as BlockList).blockArray;
			}
			return null;
		}
		public function getGroupIDList():Array
		{
			var tempArray:Array = new Array;
			if( _pieceList )
			{
				for(var i:int=0 ; i<_blockListArr.length ; i++)
				{
					tempArray = tempArray.concat( (_blockListArr[i] as BlockList).getGroupIDList() ) ;
				}
				/*for(var param:String in _pieceList)
				{
					tempArray.push(param);
				}*/
			}
			return tempArray;
		}
		private function getBlockNum():Number
		{
			var tempNum:Number = 0;
			for( var i:int=0 ; i<_blockListArr.length ; i++ )
			{
				tempNum += (_blockListArr[i] as BlockList).blockArray.length;
			}
			return tempNum;
		}
		public function eliminate():void
		{
			if( LiveVodConfig.BlockID < 0 )
			{
				return;
			}
			if( LiveVodConfig.TYPE != LiveVodConfig.CONTINUITY_VOD )
			{
				(_blockListArr[0] as BlockList).eliminate();
			}
			else
			{
				for( var i:int=0 ; i<_blockListArr.length ; i++ )
				{
					(_blockListArr[i] as BlockList).eliminate();
					//?????????????????????????
				}
			}
		}
		public function clear():void
		{
			for( var i:int=0 ; i<_blockListArr.length ; i++ )
			{
				(_blockListArr[i] as BlockList).clear();
			}
			_blockListArr = null;
			_dataManger = null;
			streamSize = 0;
			_tempBlockList = null;
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}