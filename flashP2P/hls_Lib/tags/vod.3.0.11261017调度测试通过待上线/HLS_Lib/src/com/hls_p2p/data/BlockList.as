package com.hls_p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * BlockList用来存放数据结构
	 */	
	
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Head;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;
	
	/**
	 * <ul>构造函数:_blockList _headerList</ul>
	 * <ul>_blockList增,删,handlerTimeOutWantPiece</ul>
	 * <ul>_headerList增,删(暂时不做) </ul>
	 * <ul>hasMin</ul>
	 * @author mazhoun
	 * 特殊地方：物理分片，不是逻辑分片
	 */
	public class BlockList 
	{
		public var isDebug:Boolean=true;
			
		/**Block总列表*/
		private var _blockList:Object 		= new Object;
		public  var blockArray:Array        = new Array;
		private var _fileMap:Object 		= new Object;
		/**保存piece的总列表*/
		private var _pieceList:Object 		= new Object;
		/**保存CDN在紧急区之外需要下载的piece*/
		public var CDNIsLoadPieceArr:Array	= new Array;
		/**构造*/
		public var dataMgr_:IDataManager 	= null;
		
		public function getTNRange(groupID:String):Array
		{
			if(
				this.pieceList &&
				this.pieceList[groupID] &&
				this.pieceList[groupID]["TNRange"]
			)
			{
				return this.pieceList[groupID]["TNRange"]
			}
			return null;
		}
		
		public function addTNRange(groupID:String,index:Number):void
		{
			if(index <= -1)
			{
				return;
			}
			
			if(null == this.pieceList || null == this.pieceList[groupID])
			{
				return;
			}
			
			if(null == this.pieceList[groupID]["TNRange"])
			{
				this.pieceList[groupID]["TNRange"] = new Array;
			}
			
			var _TNRange:Array = (this.pieceList[groupID]["TNRange"] as Array);
			
			if(_TNRange[index] == null)
			{
				_TNRange[index] = new Object();
				_TNRange[index].start = index;
				_TNRange[index].end = index;
			}
			
			for each(var rg:* in _TNRange)
			{
				if (_TNRange[rg.end+1])
				{
					rg.end = _TNRange[rg.end+1].end;
					delete _TNRange[rg.end];
				}				
			}
		}
		
		public function deleteTNRange(groupID:String,index:Number):void
		{
			if (index <= -1)
			{
				return;
			}
			if(
				null == this.pieceList || 
				null == this.pieceList[groupID] || 
				null == this.pieceList[groupID]["TNRange"]
			)
			{
				return;
			}
			
			var _TNRange:Array = (this.pieceList[groupID]["TNRange"] as Array);
			//range 起点包含的数据
			if(_TNRange[index])
			{
				//range 是一个元素情况
				if(_TNRange[index].start == _TNRange[index].end)
				{
					delete _TNRange[index];
					return;
				}
				else
				{
					//range 是多个元素情况
					_TNRange[index+1] = new Object();
					_TNRange[index+1].start = index+1;
					_TNRange[index+1].end   = _TNRange[index].end;
					
					delete _TNRange[index];
					return;
				}
			}
			
			for each(var rg:* in _TNRange)
			{
				if (rg.start < index && rg.end >= index)
				{
					_TNRange[index+1] = new Object();
					_TNRange[index+1].start = index+1;
					_TNRange[index+1].end   = rg.end;
					
					rg.end = index -1;
					
					return ;
				}
			}
		}
		
		public function getPNRange(groupID:String):Array
		{
			if(
				this.pieceList &&
				this.pieceList[groupID] &&
				this.pieceList[groupID]["PNRange"] 
			)
			{
				return this.pieceList[groupID]["PNRange"]
			}
			return null;
		}
		
		public function addPNRange(groupID:String,index:Number):void
		{
			if(index <= -1)
			{
				return;
			}
			
			if(null == this.pieceList || null == this.pieceList[groupID])
			{
				return;
			}
			
			if(null == this.pieceList[groupID]["PNRange"])
			{
				this.pieceList[groupID]["PNRange"] =new Array;
			}
			
			var _PNRange:Array = (this.pieceList[groupID]["PNRange"] as Array);
			
			if (_PNRange[index] == null)
			{
				_PNRange[index] = new Object();
				_PNRange[index].start = index;
				_PNRange[index].end = index;
			}
			
			for each(var rg:* in _PNRange)
			{
				if (_PNRange[rg.end+1])
				{
					rg.end = _PNRange[rg.end+1].end;
					delete _PNRange[rg.end];
				}				
			}
		}
		
		public function deletePNRange(groupID:String,index:Number):void
		{
			if (index <= -1) return;
			//range 起点包含的数据
			if(
				null == this.pieceList || 
				null == this.pieceList[groupID] || 
				null == this.pieceList[groupID]["PNRange"]
			)
			{
				return;
			}
			
			var _PNRange:Array = (this.pieceList[groupID]["PNRange"] as Array);
			
			if (_PNRange[index])
			{
				if (_PNRange[index].start == _PNRange[index].end)
				{
					delete _PNRange[index];
					return;
				}
				else
				{
					_PNRange[index+1] = new Object();
					_PNRange[index+1].start = index+1;
					_PNRange[index+1].end   = _PNRange[index].end;
					
					delete _PNRange[index];
					return;
				}
			}
			
			for each(var rg:* in _PNRange)
			{
				if (rg.start < index && rg.end >= index)
				{
					_PNRange[index+1] = new Object();
					_PNRange[index+1].start = index+1;
					_PNRange[index+1].end   = rg.end;
					
					rg.end = index -1;
					
					return ;
					//break;
				}
			}
		}
		
		/**方块调用*/
		public function get blockList():Object
		{
			return _blockList;
		}

		public function get pieceList():Object
		{
			return _pieceList;
		}
		
		/**当成功添加数据流时，由block调用赋值，当执行淘汰时，用该值进行判断是否淘汰*/
		private var _streamSize:Number = 0;
		
		public function get streamSize():Number
		{
			return _streamSize;
		}
		public function set streamSize(value:Number):void
		{
			_streamSize = value;
		}
		
		public function BlockList(dataMgr:IDataManager)
		{
			dataMgr_ = dataMgr;
		}
		
		/**
		 * 请求desc后处理，每次添加块时，会依具Clip的时间戳timestamp按小时分钟添加到对应的列表中，
		 * @param block 添加块
		 * 需要返回是否成功添加
		 * 先检查创建好，然后添加
		 */
		public function addBlock(clip:Clip):Boolean
		{
			if(_blockList == null)
			{
				_blockList = new Object;
			}
			if (blockArray == null)
			{
				blockArray = new Array;
			}
			
			var tmpBlock:Block = _blockList[clip.timestamp];
			if(null != tmpBlock)
			{
				tmpBlock.url_ts = clip.url_ts;
				return true;
			}
			return realAddBlock(clip);
		}
		
		public function deleteCDNIsLoadPiece( piec:Piece ):void
		{
			var i:int = CDNIsLoadPieceArr.indexOf(piec);
			if( i != -1 )
			{
				CDNIsLoadPieceArr.splice(i,1);
			}
		}
		public function checkIsLoaded(blkList:Array):void
		{
			if (null == blkList)
				return ;
			var temoPiec:Piece;
			for each(var blk:Block in blkList)
			{
				for each (var piec:Object in blk.pieceIdxArray)
				{
					temoPiec = getPiece(piec);
					if( temoPiec && true == temoPiec.isLoad )
					{
						if (-1 == CDNIsLoadPieceArr.indexOf(temoPiec))
						{
							CDNIsLoadPieceArr.push(temoPiec);
						}
					}
				}
			}			
		}
		public function clearIsLoaded(p_aCDNTaskPieceList:Array):void
		{
			var peerPiece:Piece;
			for each(var myPiece:Piece in CDNIsLoadPieceArr)
			{
				for(var i:uint = 0; i<p_aCDNTaskPieceList.length;i++)
				{
					peerPiece = getPiece(p_aCDNTaskPieceList[i]);
					if( peerPiece && myPiece == peerPiece )
					{
						myPiece.isLoad = false;
						deleteCDNIsLoadPiece( myPiece );
					}
				}
//				var XRg:Array = rgPN;
//				if (pie.type == "TN")
//				{
//					XRg = rgTN;	
//				}
//				var p_data:*;
//				for each( p_data in XRg )
//				{
//					if(	p_data.start<=Number(pie.pieceKey)
//						&& Number(pie.pieceKey)<=p_data.end )
//					{										
//						pie.isLoad = false;
//					}
//				}			
			}
		}
		/***设置block属性并添加到list中************/
		private function realAddBlock(clip:Clip):Boolean
		{
			var block:Block = null;
			if(!_fileMap.hasOwnProperty(clip.name))
			{
				block			   	 = new Block(this);
				block.id           	 = clip.timestamp;			
				block.duration       = clip.duration;
				block.width			 = clip.width;
				block.height		 = clip.height;
				block.name           = clip.name;
				block.url_ts		 = clip.url_ts;
				block.offSize		 = clip.offsize;
				block.size           = clip.size;
				block.groupID        = clip.groupID;
				block.pieceInfoArray = clip.pieceInfoArray;
				_fileMap[clip.name] = block;
			}
			else
			{
				block = _fileMap[clip.name];
				block.id = clip.timestamp;
			}
			
			_blockList[clip.timestamp] = block;
			blockArray.push(block.id);
			blockArray.sort(Array.NUMERIC);
			return true;
		}
		
		public function binarySearch( array:Array,target:Number ):int
		{
			if( null == array )
			{
				return -1;
			}
			var midIndex:int = int(array.length / 2);
			var blockID:Number = array[midIndex];
			var midBlock:Block = this._blockList[blockID];
			if( null == midBlock)
			{
				return -1;
			}
			if ( midBlock.id <= target && target < midBlock.id + midBlock.duration)
			{
				return midBlock.id;
			}
			if (array.length == 0 )//mid 为0
			{
				return  -1;
			}
			if(array.length == 1 )
			{
				if(array[0].id <= target && target < array[0].id + array[0].duration)
				{
					return array[0];
				}
				return  -1;
			}
			var leftArray:Array = array.slice(0,midIndex);
			var rightArray:Array = array.slice(midIndex,array.length);
			if (target >= midBlock.id+midBlock.duration)
			{
				return binarySearch(rightArray,target);
			}
			else 
			{
				return binarySearch(leftArray,target);
			}
			return -1;
		}
		
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId( id:Number ):Number
		{
			return getBlockIdLoop( id,id );
		}
		
		public function getBlockIdLoop( id:Number,orgID:Number ):Number
		{
			if (null == _blockList) return -1;
			
			var block:Block;
			var maxId:Number = 0;
			for each(block in this._blockList)
			{
				if (block.id > maxId)
				{
					maxId = block.id;
				}
				//
				if(block)
				{
					if(block.id<=id && id< Math.round((block.id+block.duration)*100)/100)
					{
						return block.id;
					}
				}
			}
			//
			if( Math.abs(orgID-id)>23 )
			{
				return -1;
			}
			
			if (maxId > id)
			{
				return getBlockIdLoop(id+1,orgID);
			}
			else 
			{
				return maxId;
			}
			
			return -1;
		}
		
		public function getPiece(param:Object):Piece
		{
			if (null == pieceList)
			{
				return null;
			}
			if(param && param.hasOwnProperty("groupID") && param.hasOwnProperty("pieceKey") && param.hasOwnProperty("type"))
			{
				
				if(
					pieceList[param.groupID] && 
					pieceList[param.groupID][param.type] && 
					pieceList[param.groupID][param.type][param.pieceKey]
				)
				{
					return pieceList[param.groupID][param.type][param.pieceKey];
				}
			}
			return null;
		}
		
		/**确保getBlock的时间戳是block id，如果不能确保id,调用getBlockId*/
		public function getBlock(id:Number):Block
		{
			if (null == _blockList)
			{
				return null;
			}
			if(id==-1)
			{
				return null;
			}
			return _blockList[id];
		}
		
		public function getGroupIDList():Array
		{
			var tempArray:Array = new Array;
			if( _pieceList )
			{
				for(var param:String in _pieceList)
				{
					tempArray.push(param);
				}
			}
			return tempArray;
		}		
		
		public function eliminate():void
		{
			if(_streamSize>=LiveVodConfig.MEMORY_SIZE)
			{
				var i:uint = 0;
				var j:uint = 0;
				var eliminateSize:Number = 0;//1024*188*7*6;//约一分钟
				//-60表示淘汰时，不淘汰播放点左侧一分钟之内的数据
				var playID:Number = this.getBlockId(LiveVodConfig.ADD_DATA_TIME-60);
				var block:Block = null;
				
				
				for(j = 0; j < blockArray.indexOf(playID);j++)
				{
					if(blockArray[j]<playID)
					{
						/**淘汰播放点左侧数据*/
						block = this.getBlock(blockArray[j]);
						if (block.isChecked == false)
							continue;
						//fileMap的block是按照最大的id标识
						realEliminate(block,false,block.id == blockArray[j]);
							
						if(_streamSize >= (LiveVodConfig.MEMORY_SIZE - eliminateSize))
						{
							return ;
							continue;
						}
						else
						{
							cleanUpPieceList();
							return;
						}
					}
				}
				//
				if(_streamSize >= LiveVodConfig.MEMORY_SIZE)
				{
					for(j=blockArray.length-1;j>=0;j--)
					{
						if(blockArray[j]>playID+60)
						{
							block = this.getBlock(blockArray[j]);
							if (block.isChecked == false)
								continue;
							
							//fileMap的block是按照最大的id标识
							realEliminate(block,true,block.id == blockArray[j]);
								
							if(_streamSize >= LiveVodConfig.MEMORY_SIZE - eliminateSize )
							{
								return;
								continue;
							}
							else
							{
								cleanUpPieceList();
								return;
							}
						}
					}
				}
			}
		}
		
		private function cleanUpPieceList():void
		{
			for(var groupID:String in pieceList)
			{
				/**是否存在属于groupID的数据*/
				var j:int=0;
				for( var i:String in pieceList[groupID] )
				{
					j++;
					break;
				}
				if( j!=0 )
				{
					var tn_j:int=0;
					var pn_j:int=0;
					if(pieceList[groupID]["TN"])
					{
						for( var p:String in pieceList[groupID]["TN"] )
						{
							tn_j++;
							break;
						}
					}
					if(pieceList[groupID]["PN"])
					{
						for( var q:String in pieceList[groupID]["PN"] )
						{
							pn_j++;
							break;
						}
					}
					if( tn_j==0 && pn_j==0 )
					{
						/**如果groupID中的TN,PN数据为空，则删除该group*/
						delete pieceList[groupID];
					}
				}
				else
				{
					/**如果groupID的数据为空，则删除该group*/
					delete pieceList[groupID];
				}
			}			
		}
		
		private function realEliminate(block:Block,isRight:Boolean=false,isSame:Boolean=false):void
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				/**点播淘汰数据*/
				block.reset();
			}
			else
			{
				if(	false == isRight )
				{
					/**直播淘汰数据左侧数据*/
					if(isSame)
					{
						/**淘汰fileMap和 blockList都唯一的数据**/
						block.clear();
						_fileMap[block.name] = null;
						delete _fileMap[block.name];
						blockArray.splice(blockArray.indexOf(block.id),1);
						_blockList[block.id] = null;
						delete _blockList[block.id];						
						block = null;
					}
					else
					{
						_blockList[block.id] = null;
						delete _blockList[block.id];
					}
				}
				else
				{
					/**直播淘汰数据右侧数据*/
					block.reset();
				}
			}
			
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			if(_fileMap)
			{
				for(var i:String in _fileMap)
				{
					_fileMap[i].clear();
					_fileMap[i] = null;
					delete _fileMap[i];
				}
				_fileMap = null;
			}

			blockArray = null;
			_blockList	= null;
			_pieceList	= null;
			dataMgr_	= null;
			CDNIsLoadPieceArr = null;
		}
	}
}