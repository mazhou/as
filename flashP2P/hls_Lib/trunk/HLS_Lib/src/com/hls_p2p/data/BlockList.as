package com.hls_p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * BlockList用来存放数据结构
	 */	
	
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.p2p.utils.console;
	
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
		public var isDebug:Boolean= true;
			
		/**Block总列表*/
		private var _blockList:Object 		= new Object;
		public  var blockArray:Array        = new Array;
		/**保存piece的总列表*/
		private var _pieceList:Object 		= new Object;
		/**保存CDN在紧急区之外需要下载的piece*/
		public var CDNIsLoadPieceArr:Array	= new Array;
		/**构造*/
		public var dataMgr_:DataManager 	= null;
		
		private function addRange(range:Array,idx:Number):void
		{
			if( range.length == 0 )
			{
				range.push({"start":idx,"end":idx});
				return;
			}
			
			for( var n:int=0 ; n<range.length ; n++ )
			{
				if( idx+1 < range[n]["start"] )
				{
					range.splice(n,0,{"start":idx,"end":idx});
					return;
				}
				else if( idx+1 == range[n]["start"] )
				{
					range[n]["start"] = idx;
					return;
				}
				else if( idx>= range[n]["start"] && idx<=range[n]["end"] )
				{
					return;
				}
				else if( idx-1 == range[n]["end"] )
				{
					range[n]["end"] = idx;
					if( range[n+1] 
						&& range[n]["end"]+1 == range[n+1]["start"] )
					{
						range[n]["end"] = range[n+1]["end"];
						range.splice(n+1,1);
					}
					return;
				}
				else if( idx-1 > range[n]["end"] )
				{
					if( range[n+1] )
					{
						if( idx+1 < range[n+1]["start"] )
						{
							range.splice(n+1,0,{"start":idx,"end":idx});
							return;
						}
						else if( idx+1 == range[n+1]["start"] )
						{
							range[n+1]["start"] = idx;
							return;
						}
					}
					else
					{
						range.push({"start":idx,"end":idx});
						return;
					}
				}
			}
		}
		
		public function deleteRange(range:Array,index:Number):void
		{
			//			trace("index:"+index)
			if (index <= -1)
			{
				return;
			}
			
			for(var idx:int = 0;idx < range.length;idx++)
			{
				if( index >= range[idx]["start"] && index <= range[idx]["end"] )
				{
					if( index == range[idx]["start"] && index == range[idx]["end"] )
					{
						range.splice(idx,1);
						return;
					}
					if( index == range[idx]["start"] )
					{
						range[idx]["start"]++;
						return;
					}
					if( index == range[idx]["end"] )
					{
						range[idx]["end"]--;
						return;
					}
					var tempEnd:Number = range[idx]["end"];
					range[idx]["end"] = index-1;
					range.splice(idx+1,0,{"start":index+1,"end":tempEnd});
					return;
				}
			}
		}
		
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
			
			addRange( _TNRange,index );
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
			deleteRange( _TNRange,index );
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
			
			addRange( _PNRange,index );
			
			//			if( _PNRange.length > 100 )
			{
				for( var i:int = 0; i<_PNRange.length-1; i++ )
				{
					if( _PNRange[i]["start"]> _PNRange[i]["end"] )
					{
						console.log( this, "超出警戒" );
					}
					if(_PNRange[i]["end"]>=_PNRange[i+1]["start"])
					{
						console.log( this, "超出警戒" );
					}
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
			deleteRange( _PNRange,index );
		}
		
		
//		public function getTNRange(groupID:String):Array
//		{
//			if( this.pieceList && this.pieceList[groupID] && this.pieceList[groupID]["TN"] )
//			{
//				var arr:Array = new Array();
//			 	for(var pieceKey:String in this.pieceList[groupID]["TN"] )
//				{
//					if( (this.pieceList[groupID]["TN"][pieceKey] as Piece).isChecked )
//					{
//						
//						addRange(arr,Number(pieceKey));
//					}
//				}
//				if(arr.length>0)
//				{
//					return arr;
//				}
//			}
//			
//			return null;
//		}
		
//		public function getPNRange( groupID:String ):Array
//		{
//			if( this.pieceList && this.pieceList[groupID] && this.pieceList[groupID]["PN"] )
//			{
//				var arr:Array = new Array();
//				for(var pieceKey:String in this.pieceList[groupID]["PN"] )
//				{
//					if( (this.pieceList[groupID]["PN"][pieceKey] as Piece).isChecked )
//					{
//						addRange(arr,Number(pieceKey));
//					}
//				}
//				if(arr.length>0)
//				{
//					return arr;
//				}
//			}
//			
//			return null;
//		}
//		
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
		
		public function BlockList(dataMgr:DataManager)
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
				if( -1 != clip.nextID )
				{
					tmpBlock.nextblkid		 = clip.nextID;
				}
				tmpBlock.url_ts = clip.url_ts;
				return true;
			}
			return realAddBlock(clip);
		}
		
		public function deleteCDNIsLoadPiece( piec:Piece ):void
		{
			for(var i:int=0 ; i<CDNIsLoadPieceArr.length ; i++)
			{
				if( piec == CDNIsLoadPieceArr[i]["piece"] )
				{
					CDNIsLoadPieceArr.splice(i,1);
					break;
				}
			}
			
		}

		/***设置block属性并添加到list中************/
		private function realAddBlock(clip:Clip):Boolean
		{
			var block:Block = null;
				block			   	 = new Block(this);
				block.id           	 = clip.timestamp;			
				block.duration       = clip.duration;
				block.width			 = clip.width;
				block.height		 = clip.height;
				block.name           = clip.name;
				block.url_ts		 = clip.url_ts;
				block.offSize		 = clip.offsize;
				block.size           = clip.size;
				block.discontinuity	 = clip.discontinuity;
				block.groupID        = clip.groupID;
				block.nextblkid		 = clip.nextID;
				block.pieceInfoArray = clip.pieceInfoArray;
				
				if( block.duration == 0 )
				{
					/**有时最后一块会出现这种情况*/
					block.dodurationHandler();
				}
			
			_blockList[clip.timestamp] = block;
			blockArray.push(block.id);
			blockArray.sort(Array.NUMERIC);
			
			if (block.isChecked == false)
			{
				LiveVodConfig.TaskCacheArray.push(block.id);
				LiveVodConfig.TaskCacheArray.sort(Array.NUMERIC);
			}
			
			LiveVodConfig.M3U8LASTBLOCKID = block.id;
			return true;
		}
		
//		public function binarySearch( array:Array,target:Number ):int
//		{
//			if( null == array )
//			{
//				return -1;
//			}
//			var midIndex:int = int(array.length / 2);
//			var blockID:Number = array[midIndex];
//			var midBlock:Block = this._blockList[blockID];
//			if( null == midBlock)
//			{
//				return -1;
//			}
//			if ( midBlock.id <= target && target < midBlock.id + midBlock.duration)
//			{
//				return midBlock.id;
//			}
//			if (array.length == 0 )//mid 为0
//			{
//				return  -1;
//			}
//			if(array.length == 1 )
//			{
//				if(array[0].id <= target && target < array[0].id + array[0].duration)
//				{
//					return array[0];
//				}
//				return  -1;
//			}
//			var leftArray:Array = array.slice(0,midIndex);
//			var rightArray:Array = array.slice(midIndex,array.length);
//			if (target >= midBlock.id+midBlock.duration)
//			{
//				return binarySearch(rightArray,target);
//			}
//			else 
//			{
//				return binarySearch(leftArray,target);
//			}
//			return -1;
//		}
		
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId( id:Number ):Number
		{
			//return BingetBlockId( id );
			
			if( -1 == id )
			{
				return -1;
			}
			
			var firstIndex:Number = 0;
			var secondIndex:Number = 0;
			var tempData:Number = 0;
			
			if( this.blockArray.length == 1 )
			{
				if( Math.abs(id -this.blockArray[0]) < 16)
				{
					return this.blockArray[0];
				}
			}
			
			if( id < this.blockArray[0] )
			{
				if( this.blockArray[0] - id < 16)
				{
					return this.blockArray[0];
				}
			}
			
			for( var index:int = 0; index < this.blockArray.length-1;index++ )
			{
				if( id >= this.blockArray[index] && id < this.blockArray[index+1] )
				{
					if( this.getBlock(this.blockArray[index]) )
					{
						if( this.getBlock(this.blockArray[index]).nextblkid != -1 && id < this.getBlock(this.blockArray[index]).nextblkid )
						{
							return this.blockArray[index];
						}
						else if( this.getBlock(this.blockArray[index]).nextblkid == -1 )
						{
							tempData = (this.blockArray[index]+this.blockArray[index+1])/2;
							if( tempData > id )
							{
								if( id -this.blockArray[index] < 16)
								{
									return this.blockArray[index];
								}
							}
							else
							{
								if( this.blockArray[index+1] - id < 16 )
								{
									return this.blockArray[index+1];
								}
							}
						}
					}
				}
			}
			if( id >= this.blockArray[blockArray.length-1] )
			{
				if( id -this.blockArray[blockArray.length-1] < 16)
				{
					return this.blockArray[blockArray.length-1];
				}
			}
			
			return -1;
			
//			return getBlockIdLoop( id,id );
			//return getNextBlockIdLoop( id,id );
		}
		
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function BingetBlockId( p_id:Number ):Number
		{
			if( -1 == p_id )
			{
				return -1;
			}
			
			var firstIndex:Number = 0;
			var secondIndex:Number = 0;
			var tempData:Number = 0;
			
			if( this.blockArray.length == 1 )
			{
				if( Math.abs(p_id -this.blockArray[0]) < 16)
				{
					return this.blockArray[0];
				}
			}
			
			if( p_id < this.blockArray[0] )
			{
				if( this.blockArray[0] - p_id < 16)
				{
					return this.blockArray[0];
				}
			}
			
			
			var iLow:int = 0;
			var iHigh:int = blockArray.length -1;
			var imid:int = 0;
			var tmpblockid:Number = -1;
			var tmpnextblockid:Number = -1;
			var curblock:Block = null;
			while( iLow <= iHigh )
			{
				imid= ( iLow + iHigh )/2;
				tmpblockid = blockArray[imid];
				
				if( imid == blockArray.length -1 )
				{
					if( p_id - this.blockArray[imid] < 16)
					{
						return this.blockArray[imid];
					}
					else
					{
						return -1;
					}
				}
				else if( p_id >= this.blockArray[imid] && p_id < this.blockArray[imid+1] )
				{
					if( this.getBlock(this.blockArray[imid]).nextblkid != -1 && p_id < this.getBlock(this.blockArray[imid]).nextblkid )
					{
						return this.blockArray[imid];
					}
					else if( this.getBlock(this.blockArray[imid]).nextblkid != -1 && p_id > this.getBlock(this.blockArray[imid]).nextblkid )
					{
						if( (p_id - this.getBlock(this.blockArray[imid]).nextblkid) < 16 )
						{
							return this.getBlock(this.blockArray[imid]).nextblkid;
						}
						else
						{
							return -1;
						}
					}
					else if( this.getBlock(this.blockArray[imid]).nextblkid == -1 )
					{
						tempData = (this.blockArray[imid]+this.blockArray[imid+1])/2;
						if( tempData > p_id )
						{
							if( p_id -this.blockArray[imid] < 16)
							{
								return this.blockArray[imid];
							}
							else
							{
								return -1;
							}
						}
						else
						{
							if( this.blockArray[imid+1] - p_id < 16 )
							{
								return this.blockArray[imid+1];
							}
							else
							{
								return -1;
							}
						}
					}
				}
				else
				{
					if( p_id > this.blockArray[imid] )
					{
						// 右侧查找
						iLow = imid + 1;
					}
					else if( p_id < this.blockArray[imid] )
					{
						iHigh = imid -1;
					}
				}
					
			}
			
			return -1;
			
			//			return getBlockIdLoop( id,id );
			//return getNextBlockIdLoop( id,id );
		}
		
		
		public function getNextBlockId( p_curid:Number ):Number
		{
			var firstIndex:Number = 0;
			var secondIndex:Number = 0;
			
			for( var index:int = 0; index<this.blockArray.length;index++ )
			{
				if (this.blockArray[index] == p_curid)
				{
					firstIndex = this.blockArray[index];
					if( index == this.blockArray.length-1 )
					{
						return -1;
					}
					else
					{
						secondIndex = this.blockArray[index+1]
					}
					
					if( secondIndex - firstIndex < 16  )
					{
						return secondIndex;
					}else
					{
						return -1;
					}
				}
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
		
		public function deletePiece( pieceIndication:Object ):void
		{
			pieceList[pieceIndication.groupID][pieceIndication.type][pieceIndication.pieceKey] = null;
			delete pieceList[pieceIndication.groupID][pieceIndication.type][pieceIndication.pieceKey];
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
			if( LiveVodConfig.BlockID < 0 )
			{
				return;
			}
			if( _streamSize >= LiveVodConfig.MEMORY_SIZE+1024*1024 || (blockArray.length > 300 && LiveVodConfig.TYPE == LiveVodConfig.LIVE ) )
			{
				var i:int = 0;
				var j:int = 0;
				
				console.log( this,"淘汰前 set memorySize:"+LiveVodConfig.MEMORY_SIZE+" _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")",blockArray.length,LiveVodConfig.ADD_DATA_TIME,LiveVodConfig.BlockID);
				var block:Block = null;
				if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
				{
					//check left
					for(j = 0; j < blockArray.length;j++)
					{
						if( blockArray[j] >= LiveVodConfig.BlockID-60 )
						{
							console.log( this,"左侧数据已经淘汰");
							break;
						}
						
						block = this.getBlock(blockArray[j]);
						realEliminate(block,true);
						
						if( _streamSize >= LiveVodConfig.MEMORY_SIZE )
						{
							continue;
						}
						else
						{
							console.log( this,"淘汰后 set memorySize:"+LiveVodConfig.MEMORY_SIZE+" _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
							cleanUpPieceList();
							return;
						}
					}

					//check right
					for(j = blockArray.length -1; j >= 0;j--)
					{
						
						if( blockArray[j]/*block.id*/ <= LiveVodConfig.BlockID + 60 )
						{
							console.log( this,"淘汰到右侧边界");
							cleanUpPieceList();
							return;
						}
						
						block = this.getBlock(blockArray[j]);
						realEliminate(block,true);

						if( _streamSize >= LiveVodConfig.MEMORY_SIZE )
						{
							continue;
						}
						else
						{
							console.log( this,"淘汰后: _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
							cleanUpPieceList();
							return;
						}
					}
				}
				else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					//check left
					for( j = 0; j < blockArray.length;j++ )
					{
						block = this.getBlock(blockArray[0]);
						
						// 这里加入淘汰前判断
						if( block.id >= LiveVodConfig.BlockID-30 )
						{
							console.log( this,"左侧数据已经淘汰到边界");
							break;
						}
						
						realEliminate(block,false);
						
//						if( _streamSize >= LiveVodConfig.MEMORY_SIZE || blockArray.length > 300 )
//						{
//							continue;
//						}
//						else
//						{
							console.log( this,"淘汰后: _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")",blockArray.length);
							cleanUpPieceList();
							return;
//						}
					}
					
					//check right
					for( j = blockArray.length -1; j >= 0; j-- )
					{
						block = this.getBlock(blockArray[j]);
						
						if( block == null )
						{
							continue;
						}
						
						if( block.id <= LiveVodConfig.M3U8_MAXTIME )
						{
							console.log( this,"右侧数据已经淘汰到边界");
							cleanUpPieceList();
							break;
						}
						
						realEliminate(block,false);
						
//						if( _streamSize >= LiveVodConfig.MEMORY_SIZE || blockArray.length > 300  )
//						{
//							continue;
//						}
//						else
//						{
							
							console.log( this,"淘汰后: _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")",blockArray.length);
							cleanUpPieceList();
							var firstAbsens:Number = 0;
							block = this.getBlock(blockArray[0]);
							while( block.nextblkid != -1 )
							{
								firstAbsens = block.id;
								block = this.getBlock(block.nextblkid);
								if( null == block )
								{
									this.getBlock(firstAbsens).nextblkid = -1;
									LiveVodConfig.M3U8_MAXTIME = firstAbsens;
									return;
								}
							}
							if(block.id < LiveVodConfig.BlockID && LiveVodConfig.BlockID!=-1 )
							{
								LiveVodConfig.M3U8_MAXTIME = LiveVodConfig.BlockID;
								return;
							}
							LiveVodConfig.M3U8_MAXTIME = block.id;
							return;
//						}
					}//end for
					
				}//end vod | live
			}
		}
		
		
		
		private function cleanUpPieceList():void
		{
			for( var groupID:String in pieceList )
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
					if( pieceList[groupID]["TN"] )
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
						pieceList[groupID] = null;
						delete pieceList[groupID];
					}
				}
				else
				{
					/**如果groupID的数据为空，则删除该group*/
					pieceList[groupID] = null;
					delete pieceList[groupID];
				}
			}			
		}
		
		private function realEliminate(block:Block,isReset:Boolean=false):void
		{
			console.log( this,"eliminate block:"+block.id+ " isReset:"+isReset );
			if( isReset )
			{
				block.reset();
			}
			else if( !isReset )
			{
				if( blockArray )
				{
					var id:int = blockArray.indexOf(block.id);
					if (id != -1)
					{
						blockArray.splice(id,1);
					}
				}

				if( _blockList && block )
				{
					var index:int = LiveVodConfig.TaskCacheArray.indexOf(block.id);
					if (-1 != index)
					{
						LiveVodConfig.TaskCacheArray.splice(index, 1);
					}
					//
					block.clear();
					if( _blockList[block.id] )
					{
						_blockList[block.id] = null;
						delete _blockList[block.id];
					}
				}
				block = null;
			}
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			if(_blockList)
			{
				for(var i:String in _blockList)
				{
					_blockList[i].clear();
					_blockList[i] = null;
					delete _blockList[i];
				}
				_blockList = null;
			}
			for( var idx:int = blockArray.length-1; idx >= 0; idx-- )
			{
				blockArray[idx]=null;
				delete blockArray[idx];
			}
			blockArray = null;
			_blockList	= null;
			
			if(_pieceList)
			{
				for(var str:String in _pieceList)
				{
					if( (_pieceList[str] as Piece) )
					{
						(_pieceList[str] as Piece).clear(-1);
						_pieceList[str] = null;
						delete _pieceList[str];
					}

				}
				_pieceList = null;
			}
			_pieceList	= null;
			
			dataMgr_	= null;
			CDNIsLoadPieceArr = null;
		}
	}
}