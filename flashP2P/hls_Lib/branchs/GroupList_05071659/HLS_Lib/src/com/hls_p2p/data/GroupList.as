package com.hls_p2p.data
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.p2p.utils.console;
	
	import flash.utils.ByteArray;

	public class GroupList
	{		
		
		public var isDebug:Boolean= true;
		
		private var _groupList:Object;
		
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
		
		public function get CDNIsLoadPieceArr():Array
		{
			//直播时，紧急区之外随机下载的数据
			if(_groupList[LiveVodConfig.currentVid])
			{
				return (_groupList[LiveVodConfig.currentVid] as BlockList).CDNIsLoadPieceArr;
			}
			return null;
		}
		
		private function init():void
		{
			_groupList = new Object;
		}
		
		private function getBlockListID(gID:String):String
		{		
			return ( LiveVodConfig.TYPE ==  LiveVodConfig.CONTINUITY_VOD ? gID : LiveVodConfig.currentVid );
		}
		
		public function getTNRange(groupID:String):Array
		{
			var tempVid:String = getBlockListID( groupID ) ;	
			if( this._groupList && this._groupList.hasOwnProperty(tempVid) )
			{
				return 	(_groupList[tempVid] as BlockList).getTNRange(groupID);
			}
			return null;
		}
		
		public function getPNRange(groupID:String):Array
		{
			var tempVid:String = getBlockListID( groupID ) ;
			if( this._groupList && this._groupList.hasOwnProperty(tempVid) )
			{
				return 	(_groupList[tempVid] as BlockList).getPNRange(groupID);
			}
			return null;
		}
		public function deleteCDNIsLoadPiece( piece:Piece ):void
		{
			var tempVid:String = getBlockListID( piece.groupID ) ;
			if( this._groupList.hasOwnProperty( tempVid ) )
			{
				(_groupList[ tempVid ] as BlockList).deleteCDNIsLoadPiece( piece );
			}
		}
		public function addBlock(clip:Clip,kbps:Number=0):Boolean
		{
			var vid:String = getBlockListID( clip.groupID ) ;
			if( !this._groupList.hasOwnProperty( vid ) )
			{
				this._groupList[ vid ] = new BlockList( _dataMgr,this,kbps );
				this._groupList[ vid ].createTime 	 = getTime();
				this._groupList[ vid ].groupID   	 = clip.groupID;
			}
			else
			{
				if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD )
				{
					//需要优化！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
					this._groupList[ vid ].createTime 	= getTime();
				}
			}
			return _groupList[vid].addBlock(clip);
		}
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		
		public function getBlockId( gId:String,id:Number ):Number
		{
			var tempVid:String = getBlockListID( gId ) ;
			if( this._groupList.hasOwnProperty( tempVid ) )
			{
				return (_groupList[tempVid] as BlockList).getBlockId(id);
			}

			return -1;
		}
		public function getNextBlockId( gId:String,p_curid:Number ):Number
		{
			var tempVid:String = getBlockListID( gId ) ;
			if( this._groupList.hasOwnProperty( tempVid ) )
			{
				return (_groupList[tempVid] as BlockList).getNextBlockId(p_curid);
			}

			return -1;
		}
		public function getPiece(param:Object):Piece
		{
			if( param && param.hasOwnProperty("groupID") )
			{
				var tempVid:String = getBlockListID( param["groupID"] ) ;
				if(this._groupList.hasOwnProperty( tempVid ))
				{
					return (_groupList[tempVid] as BlockList).getPiece(param);
				}
				/*
				if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD  && this._groupList.hasOwnProperty( param["groupID"] ) )
				{
					return (_groupList[param["groupID"]] as BlockList).getPiece(param);
				}
				if( LiveVodConfig.TYPE != LiveVodConfig.CONTINUITY_VOD  && this._groupList.hasOwnProperty( LiveVodConfig.currentVid ) )
				{
					return (_groupList[LiveVodConfig.currentVid] as BlockList).getPiece(param);
				}*/
			}
			return null;
		}
		public function getBlock( gId:String,id:Number ):Block
		{
			var tempVid:String = getBlockListID( gId ) ;
			if( this._groupList.hasOwnProperty( tempVid ) )
			{
				return (_groupList[tempVid] as BlockList).getBlock(id);
			}
			return null;
		}
		public function getBlockList( gId:String ):Object
		{
			var tempVid:String = getBlockListID( gId ) ;
			if( this._groupList.hasOwnProperty( tempVid ) )
			{
				return (_groupList[tempVid] as BlockList).blockList;
			}

			return null;
		}
		public function getBlockArray( gId:String ):Array
		{
			var tempVid:String = getBlockListID( gId ) ;
			if( this._groupList.hasOwnProperty( tempVid ) )
			{
				return (_groupList[tempVid] as BlockList).blockArray;
			}

			return null;
		}
		public function getGroupIDList():Array
		{
			var tempArray:Array = new Array;
			for( var gId:String in this._groupList )
			{
				tempArray = tempArray.concat( (_groupList[gId] as BlockList).getGroupIDList() );
				//tempArray.push(gId);
			}
			return tempArray;
		}
		
		public function getEarlyBlockList():String
		{
			var value:String = "";
			var arr:Array = new Array;
			for( var gId:String in this._groupList )
			{
				if(gId != LiveVodConfig.currentVid && gId != LiveVodConfig.nextVid )
				{
					arr.push({"createTime":(_groupList[gId] as BlockList).createTime,
						"groupId":gId
					});
				}
			}
			if( arr.length >= 1 )
			{
				arr.sortOn("createTime",16);
				return arr[0]["groupId"];
			}
			
			return value;
		}
		
		public function eliminate():void
		{
			if( LiveVodConfig.BlockID < 0 )
			{
				return;
			}
			var gId:String = "";
			if( streamSize >= LiveVodConfig.MEMORY_SIZE+1024*1024 )
			{
//				如果文件>2,淘汰非本集和下集之外，最早的视频
//				文件<=2，依据播放点和加载数据的范围淘汰，（加载数据的范围：本集或本集+下集）
				//超过两个视频Id
				//trace(streamSize+" > "+(LiveVodConfig.MEMORY_SIZE+1024*1024))
				gId = getEarlyBlockList();
				if( "" != gId && gId != LiveVodConfig.currentVid )
				{
					(_groupList[ gId ] as BlockList).eliminate("left");
					//trace("gId e l="+streamSize)
					if( streamSize < LiveVodConfig.MEMORY_SIZE )
					{
						return;
					}
				}
				
				(_groupList[ LiveVodConfig.currentVid ] as BlockList).eliminate("left");
				//trace("gId c l="+streamSize)
				if( streamSize >= LiveVodConfig.MEMORY_SIZE && 
					"" != LiveVodConfig.nextVid &&
					_groupList.hasOwnProperty( LiveVodConfig.nextVid ) &&
					(_groupList[ LiveVodConfig.nextVid ] as BlockList).streamSize > 0 )
				{
					(_groupList[ LiveVodConfig.nextVid ] as BlockList).eliminate("right");
					//trace("gId n r="+streamSize)
				}
				
				if( streamSize >= LiveVodConfig.MEMORY_SIZE )
				{
					(_groupList[ LiveVodConfig.currentVid ] as BlockList).eliminate("right");
					//trace("gId t r="+streamSize)
				}
				
			}
			
			var groupNum:int = getGroupIDList().length;
			if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD && groupNum > LiveVodConfig.MAX_GROUPS )
			{
				//当在联播状态下，同时出现了4个或4个以上的group，从最早的group开始淘汰, 直到剩下上一集本集和下集的3个group
				var tempNum:int = groupNum-LiveVodConfig.MAX_GROUPS ;
				for( var i:int=0 ; i<tempNum ; i++ )
				{
					gId = getEarlyBlockList();
					if( "" != gId 
						&& ( LiveVodConfig.nextVid != gId || LiveVodConfig.currentVid != gId ) )
					{
						deleteBlockList(gId);
						//_dataMgr.removeP2P(gId);
					}
				}
			}
		}
		
		public function deleteBlockList( gId:String ):void
		{
			if( !_groupList.hasOwnProperty(gId) )
			{
				//
				console.log(this,"groupList delete BlockList error!!!");
			}
			
			_groupList[gId].clear();
			_groupList[gId] = null;
			delete _groupList[gId];
		}
		
		public function getMemoryTimeByGid(  gId:String  ):Number
		{
			var tempVid:String = getBlockListID( gId ) ;
			if( !_groupList.hasOwnProperty(tempVid) )
			{
				//
				console.log(this,"groupList getMemoryTimeByGid BlockList error!!!");
			}
			
			if( !_groupList[tempVid] ){ return 0; }
			
			return 	(_groupList[tempVid] as BlockList).memoryTime;
		}
		
		public function clear():void
		{
			console.log(this,"clear");
			for( var gId:String in _groupList )
			{
				_groupList[gId].clear();
			}
			_groupList = null;
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