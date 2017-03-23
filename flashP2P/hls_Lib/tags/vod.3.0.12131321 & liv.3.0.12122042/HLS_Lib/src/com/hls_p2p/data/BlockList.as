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
		//private var _fileMap:Object 		= new Object;
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
		/*public function addRange(range:Array,index:Number):void
		{
			if(index <= -1)
			{
				return;
			}
			
			if( range.length == 0 )
			{
				range.push({"start":index,"end":index});
				return;
			}
			
			for(var idx:int = 0;idx < range.length-1;idx++)
			{
				if( 0 == idx && index < range[idx]["start"] )
				{
					if( index+1 == range[idx]["start"])
					{
						range[idx]["start"]--; 
					}
					else
					{
						range.unshift({"start":index,"end":index});
					}
					return;
				}
				
				if( index >= range[idx]["start"] && index <= range[idx]["end"] )
				{
					return;
				}
				
				if( index > range[idx]["end"] && index < range[idx+1]["start"] )
				{
					var merge:int = 0;
					if( index+1 == range[idx+1]["start"] )
					{
						range[idx+1]["start"]--; 
						merge++;
					}
					
					if( index-1 == range[idx]["end"] )
					{
						if( merge==1 )
						{
							range[idx]["end"]=range[idx+1]["end"];
							range.splice(idx+1,1);
							return;
						}else
						{
							range[idx]["end"]++;
							merge++;
						}
						
					}
					//
					if( merge == 0 )
					{
						range.splice(idx+1,0,{"start":index,"end":index});
					}
					return;
				}
			}
			//yikuai
			if( range.length == 1 && index < range[0]["start"])
			{
				if( index+1 == range[0]["start"])
				{
					range[idx]["start"]--;
				}
				else
				{
					range.unshift({"start":index,"end":index});
				}
				return;
			}
			//zuihou 
			if( index >= range[idx]["start"] && index <= range[idx]["end"] )
			{
				return;
			}
			
			if(  index > range[idx]["end"] )
			{
				if( index-1 == range[idx]["end"])
				{
					range[idx]["end"]++; 
				}
				else
				{
					range.push({"start":index,"end":index});
				}
				return;
			}
		}*/

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
						P2PDebug.traceMsg( this, "超出警戒" );
					}
					if(_PNRange[i]["end"]>=_PNRange[i+1]["start"])
					{
						P2PDebug.traceMsg( this, "超出警戒" );
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
			/*var i:int = CDNIsLoadPieceArr.indexOf(piec);
			if( i != -1 )
			{
				CDNIsLoadPieceArr.splice(i,1);
			}*/
		}

		public function clearIsLoaded(p_groupID:String,p_aCDNTaskPieceList:Array,p_remoteTNList:Array=null,p_remotePNList:Array=null):void
		{
			var peerPiece:Piece;
			for each(var myPiece:Piece in CDNIsLoadPieceArr)
			{
				/**与对方节点的CDNIsLoadPieceArr表进行比较去重*/
				for(var i:uint = 0; i<p_aCDNTaskPieceList.length;i++)
				{
					peerPiece = getPiece(p_aCDNTaskPieceList[i]);
					if( peerPiece 
						&& myPiece == peerPiece 
						&& p_groupID == myPiece.groupID)
					{
						myPiece.isLoad = false;
						deleteCDNIsLoadPiece( myPiece );
					}
				}
				/**与对方节点的TNList表进行比较去重*/
				if( null != p_remoteTNList)
				{
					for(var j:int = 0 ; j<p_remoteTNList.length ; j++)
					{
						if( myPiece.type == "PN"
							&& myPiece.id >= p_remoteTNList[j]["start"]
							&& myPiece.id <= p_remoteTNList[j]["end"]
							&& p_groupID == myPiece.groupID)
						{
							myPiece.isLoad = false;
							deleteCDNIsLoadPiece( myPiece );
						}
					}
				}
				/**与对方节点的PNList表进行比较去重*/
				if( null != p_remotePNList)
				{
					for(var p:int = 0 ; p<p_remoteTNList.length ; p++)
					{
						if( myPiece.type == "TN"
							&& myPiece.id >= p_remoteTNList[j]["start"]
							&& myPiece.id <= p_remoteTNList[j]["end"]
							&& p_groupID == myPiece.groupID)
						{
							myPiece.isLoad = false;
							deleteCDNIsLoadPiece( myPiece );
						}
					}
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
					block.dodurationHandler();
				}
			
			_blockList[clip.timestamp] = block;
			blockArray.push(block.id);
			blockArray.sort(Array.NUMERIC);
			
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
			return getBlockIdLoop( id,id );
			//return getNextBlockIdLoop( id,id );
		}
		
		public function getNextBlockId( p_curid:Number,p_id:Number ):Number
		{
			return getNextBlockIdLoop( p_curid,p_id );
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
			/*else 
			{
				return maxId;
			}*/
			
			return -1;
		}
		
		public function getNextBlockIdLoop( orgID:Number,p_id:Number ):Number
		{
			if( null == _blockList )
			{ 
				return -1;
			}
			
//			P2PDebug.traceMsg( this,"getNextBlockIdLoop para para_orgID:" + orgID + " para_p_id: " + p_id );
			
			var block:Block = null;
			var maxId:Number = 0;
			for each( block in this._blockList )
			{
				if( block.id > maxId )
				{
					maxId = block.id;
				}
				
				if( block )
				{
					if( block.id <= p_id && p_id< Math.round((block.id+block.duration)*100)/100 )
					{
						if( block.id == orgID )
						{
							if( Math.abs(orgID-p_id)>23 )
							{
								P2PDebug.traceMsg( this,"if( block.id == orgID ) not finded block Math.abs(orgID-p_id)>23 orgID:" + orgID + " p_id: " + p_id + "block.id: " + block.id );
								return -1;
							}
							
							P2PDebug.traceMsg( this,"reccall block if( block.id == orgID ) orgID:" + orgID + " p_id: " + (p_id+1) + "block.id: " + block.id );
							return getNextBlockIdLoop( orgID,p_id+1 );
						}
						else
						{
							return block.id;
						}
					}
				}
			}
			
			if( Math.abs(orgID-p_id)>23 )
			{
				P2PDebug.traceMsg( this,"not finded block Math.abs(orgID-p_id)>23 orgID:" + orgID + " p_id: " + p_id + "block.id: " + block.id );
				return -1;
			}
			
			if( maxId > p_id )
			{
				P2PDebug.traceMsg( this,"reccall block maxId > p_id orgID:" + orgID + " p_id: " + (p_id+1) + "block.id: " + block.id );
				return getNextBlockIdLoop(orgID,p_id+1);
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
			if( _streamSize >= LiveVodConfig.MEMORY_SIZE+1024*1024 )
			{
				var i:int = 0;
				var j:int = 0;
				
				P2PDebug.traceMsg( this,"淘汰前 set memorySize:"+LiveVodConfig.MEMORY_SIZE+" _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
				var block:Block = null;
				if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
				{
					//check left
					for(j = 0; j < blockArray.length;j++)
					{
						if( blockArray[j] >= LiveVodConfig.ADD_DATA_TIME-60 )
						{
							P2PDebug.traceMsg( this,"左侧数据已经淘汰");
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
							P2PDebug.traceMsg( this,"淘汰后 set memorySize:"+LiveVodConfig.MEMORY_SIZE+" _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
							cleanUpPieceList();
							return;
						}
					}

					//check right
					for(j = blockArray.length -1; j >= 0;j--)
					{
						block = this.getBlock(blockArray[j]);
						
						if( block.id <= LiveVodConfig.ADD_DATA_TIME + 60 )
						{
							P2PDebug.traceMsg( this,"淘汰到右侧边界");
							cleanUpPieceList();
							return;
						}
						
						realEliminate(block,true);

						if( _streamSize >= LiveVodConfig.MEMORY_SIZE )
						{
							continue;
						}
						else
						{
							P2PDebug.traceMsg( this,"淘汰后: _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
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
						if( block.id >= LiveVodConfig.ADD_DATA_TIME-60 )
						{
							P2PDebug.traceMsg( this,"左侧数据已经淘汰到边界");
							break;
						}
						
						realEliminate(block,false);
						
//						if( _streamSize >= LiveVodConfig.MEMORY_SIZE )
//						{
//							continue;
//						}
//						else
						{
							P2PDebug.traceMsg( this,"淘汰后: _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
							cleanUpPieceList();
							return;
						}
					}
					
					//check right
					for( j = blockArray.length -1; j >= 0; j-- )
					{
						block = this.getBlock(blockArray[j]);
						
						if( block == null )
						{
							continue;
						}
						
						if( block.id <= LiveVodConfig.ADD_DATA_TIME + 60 || block.id <= LiveVodConfig.M3U8_MAXTIME )
						{
							P2PDebug.traceMsg( this,"右侧数据已经淘汰到边界");
							cleanUpPieceList();
							break;
						}
						
						realEliminate(block,false);
						
//						if( _streamSize >= LiveVodConfig.MEMORY_SIZE )
//						{
//							continue;
//						}
//						else
						{
							P2PDebug.traceMsg( this,"淘汰后: _streamSize:"+_streamSize+"("+int(_streamSize/1024/1024)+")");
							cleanUpPieceList();
							return;
						}
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
		
		private function realEliminate(block:Block,isReset:Boolean=false):void
		{
			P2PDebug.traceMsg( this,"eliminate block:"+block.id+ " isReset:"+isReset );
			if( isReset )
			{
				block.reset();
			}
			else if( !isReset )
			{
				var iTmpid:int = blockArray.indexOf(block.id);
				blockArray.splice(iTmpid,1);
				
				block.clear();
				if( _blockList[block.id] )
				{
					_blockList[block.id] = null;
					delete _blockList[block.id];
				}
				
				block = null;
			}
		}
		
//		private function ShowEliminateDetailInfo( p_block:Block, p_strInfo:String ):void
//		{
//			var piece:Piece  = null;
//			if( p_block )
//			{
//				for(var i:int = 0 ; i<p_block.pieceIdxArray.length ; i++)
//				{
//					piece = getPiece(p_block.pieceIdxArray[i]);
//					if( piece )
//					{
//						P2PDebug.traceMsg( this, " p_strInfo: " + p_strInfo + " p_block.id:" + p_block.id + " piece.id: " 
//							+ piece.id + " piece.pieceKey: " 
//							+ piece.pieceKey + " piece.size:" + piece.size 
//							+ " piece.isChecked: " + piece.isChecked );
//					}
//				}
//			}
//			else
//			{
//				P2PDebug.traceMsg( this, " p_block is null");
//			}
//		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			/*if(_fileMap)
			{
				for(var i:String in _fileMap)
				{
					_fileMap[i].clear();
					_fileMap[i] = null;
					delete _fileMap[i];
				}
				_fileMap = null;
			}
			*/
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

			blockArray = null;
			//_blockList	= null;
			_pieceList	= null;
			dataMgr_	= null;
			CDNIsLoadPieceArr = null;
		}
	}
}