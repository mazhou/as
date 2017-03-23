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
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
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
		
		//live_vod 在调度器的set接口中设置
		public var playPosition:Number=-1;
		
		/**
		 * dataList[hour][min][blocks,isTaskFull,headid,isDestroy]
		 * _headerList[id]=bytearray
		 */
		
		/**Block总列表*/
		private var _blockList:Object = new Object;
		/**方块调用*/
		public function get blockList():Object
		{
			return _blockList;
		}
		/**保存头数据流的列表*/
		private var _headerList:Object = new Object;
		public function get headerList():Object
		{
			return _headerList;
		}
		/**保存piece的总列表*/
		private var _pieceList:Object = new Object;
		public function get pieceList():Object
		{
			return _pieceList;
		}
		/**保存每个Block单向关系的列表，用于查找下一个Block*/
		private var SeqMap:Object = new Object;
		
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
		
		/**构造*/
		public var dataMgr_:IDataManager = null;
		public function BlockList(dataMgr:IDataManager)
		{
			dataMgr_ = dataMgr;
		}
		
		public var totalBlock:int=0;
		
		/**
		 * 请求desc后处理，每次添加块时，会依具Clip的时间戳timestamp按小时分钟添加到对应的列表中，
		 * @param block 添加块
		 * 需要返回是否成功添加
		 * 先检查创建好，然后添加
		 */
		public function addBlock(clip:Clip):Boolean
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(clip.timestamp);	
			
			if( !_blockList[_tempDateObj.minutes])
			{
				_blockList[_tempDateObj.minutes] = new Object();
			}
			
			if( !_blockList[_tempDateObj.minutes]["blocks"])
			{
				_blockList[_tempDateObj.minutes]["blocks"] = new Object();
				_blockList[_tempDateObj.minutes]["isHasStreamData"] = false;
			}
			
			if(_blockList[_tempDateObj.minutes]["blocks"][clip.timestamp])
			{
				return false;
			}
			return realAddBlock(_blockList[_tempDateObj.minutes]["blocks"],clip);
		}
		/***设置block属性并添加到list中************/
		private function realAddBlock(blocks:Object, clip:Clip):Boolean
		{
			var block:Block   	 = new Block(this);
			block.id           	 = clip.timestamp;			
			block.duration       = clip.duration;
			block.width			 = clip.width;
			block.height		 = clip.height;
			block.name           = clip.name;
			block.offSize		 = clip.offsize;
			block.size           = clip.size;
			block.sequence		 = clip.sequence;
			block.groupID        = clip.groupID;
			block.pieceInfoArray = clip.pieceInfoArray;
			/**添加block*/
			blocks[clip.timestamp] = block;
			SeqMap[block.sequence] = block;
			//_count++;
//			Debug.traceMsg(this,"添加block"+block.id);
			return true;
		}
		public function getBlockBySeqID(seqID:Number):Block
		{
			if(!SeqMap[seqID])
			{
				return null;
			}
			return SeqMap[seqID];
		}
		public function getNextSeqID(seqID:Number):Block
		{
			if(!SeqMap[seqID+1])
			{
				return null;
			}
			return SeqMap[seqID+1];
		}
		
//		public function getNextblock_BySort(p_LastBufedBlockId:Number):Block
//		{
//			p_LastBufedBlockId=Math.floor(p_LastBufedBlockId*1000)/1000;
//			var _tempDateObj:Object = TimeTranslater.getHourMinObj(p_LastBufedBlockId);
//			
//			var lastblock:Block = getBlock(p_LastBufedBlockId);
//			var arr_block:Array=new Array();
//			
//			for(var i:int = 0; i<2; i++)
//			{
//				if(!_blockList[_tempDateObj.minutes+i] ||!_blockList[_tempDateObj.minutes+i]["blocks"])
//				{
//					continue;
//				}					
//				
//				var block:Block;
//				var nextBlock:Block
//				
//				for(var element:* in _blockList[_tempDateObj.minutes+i]["blocks"])
//				{
//					block=_blockList[_tempDateObj.minutes+i]["blocks"][element];
//					arr_block.push(block);
//				}
//				arr_block.sortOn("id",Array.NUMERIC);
//				
//				for(var j:int=0 ; j< arr_block.length; j++)
//				{
//					block=arr_block[j];
//					if(block.id > p_LastBufedBlockId && block.id < lastblock.id + lastblock.duration + 10 )
//					{
//						return block;
//					}	
//					else
//					{
//						continue;
//					}
//				}
//				
//			}	
//			return null;
//		}
		
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId(id:Number):Number
		{
			id=Math.floor(id*1000)/1000;
			var b_isForward:Boolean = false;
			if( id%60<=30 )
			{
				b_isForward = true;	
			}
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			var _element:*;
			var _tempBlocks:Array=new Array;
			if( b_isForward )
			{
				if(_blockList[_tempDateObj.minutes-1] 
					&& _blockList[_tempDateObj.minutes-1]["blocks"])
				{
					for(_element in _blockList[_tempDateObj.minutes-1]["blocks"])
					{
						_tempBlocks.push(_blockList[_tempDateObj.minutes-1]["blocks"][_element]);
					}
				}
			}
			else
			{
				if(_blockList[_tempDateObj.minutes+1] 
					&& _blockList[_tempDateObj.minutes+1]["blocks"])
				{
					for(_element in _blockList[_tempDateObj.minutes+1]["blocks"])
					{
						_tempBlocks.push(_blockList[_tempDateObj.minutes+1]["blocks"][_element]);
					}
				}
			}
			
			if(_blockList[_tempDateObj.minutes] 
				&& _blockList[_tempDateObj.minutes]["blocks"])
			{
				for(_element in _blockList[_tempDateObj.minutes]["blocks"])
				{
					_tempBlocks.push(_blockList[_tempDateObj.minutes]["blocks"][_element]);
				}
			}
			var block:Block;
			var nextBlock:Block;
			for each(block in _tempBlocks)
			{
				nextBlock= getNextSeqID(block.sequence);
				if(nextBlock)
				{
					if(block.id<=id && id< nextBlock.id){
						return block.id;
					}
				}else if((block.id<=id && id< block.id+block.duration)
					|| block.id==id)
				{
					return block.id;
				}
			}
			return -1;
		}
		public function getPiece(param:Object):Piece
		{
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
			if(id==-1){return null}
			
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			
			if( !_blockList[_tempDateObj.minutes] 
				|| !_blockList[_tempDateObj.minutes]["blocks"]
				|| !_blockList[_tempDateObj.minutes]["blocks"][id]
			)
			{
				return null;
			}
			return _blockList[_tempDateObj.minutes]["blocks"][id];
		}
						
		/***/
		public function getDataAfterPoint(groupID:String,id:Number):Array
		{
			/**
			 * arr数组的数据结构
			 * arr = [piece.pieceKey,..]
			 * */
			var arr:Array = new Array();
			if( pieceList[groupID] )
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
						return arr;
					}
				}
				else
				{
					/**如果groupID的数据为空，则删除该group*/
					delete pieceList[groupID];
					return arr;
				}
			}
			else
			{				
				return arr;
			}
			
			var LoadTime:Number     = Number(id);
			var intervalTime:Number = 3;			
			var lastBlockId:Number  = -1;
			var btime:Number        = LoadTime;
			
			for(LoadTime; LoadTime - btime < Math.floor(LiveVodConfig.MEMORY_TIME/2-1)*60; LoadTime += intervalTime)
			{
				var tmpTime:Number = this.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					continue;
				}
				if(lastBlockId!=tmpTime)
				{	
					var lastBlock:Block = this.getBlock(tmpTime);
					if( lastBlock )
					{
						//var pIDArr:Array  = new Array();
						for(var m:int = 0 ; m<lastBlock.pieceIdxArray.length ; m++)
						{
							var tempPiece:Piece = getPiece(lastBlock.pieceIdxArray[m]);

							if( tempPiece && tempPiece.isChecked )
							{
								//pIDArr.push(lastBlock.pieceIdxArray[m]);
								arr.push(lastBlock.pieceIdxArray[m]);
							}
						}
					}
					lastBlockId = tmpTime;
				}
			}
			return arr;			
		}
		
		/**获得id索引值之后有流的数据列表,暂时传入blockID，将来会使用blockID_pieceID */
		public function getDataAfterPoint_withoutSeqid(id:Number):Array
		{
			return null;
			/**
			 * arr数组的数据结构
			 * arr = [{bID:blockID(Number),pIDArr:Array(有数据的piece索引值)}, ... ,]
			 * */
			/*var arr:Array = new Array();
			var LoadTime:Number = Number(id);
			var intervalTime:Number=3;
			
			var lastBlockId:Number=-1;
			var btime:Number = LoadTime;
			
			//
			for(LoadTime; LoadTime - btime < Math.floor(LiveVodConfig.MEMORY_TIME/2-1)*60; LoadTime += intervalTime)
			{
				var tmpTime:Number = this.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					continue;
				}
				if(lastBlockId!=tmpTime)
				{
					var lastBlock:Block =this.getBlock(tmpTime);
					if( lastBlock )
					{
						var bIDObj:Object = new Object();
						var pIDArr:Array  = new Array();
						for(var i:int = 0 ; i<lastBlock.pieces.length ; i++)
						{
							bIDObj.bID = lastBlock.id;
							if(lastBlock.pieces[i].isChecked)
							{
								pIDArr.push(i);
							}
						}
						if(pIDArr.length>0)
						{
							bIDObj.pIDArr = pIDArr;
							arr.push(bIDObj);
						}
					}
					//
					lastBlockId = tmpTime;
				}
			}
			//
			return arr;*/
		}
		
		
		private var getWantPieceObj:Object = new Object();
		public function getWantPieceEndMinutes():Object
		{
			var startID:Number = LiveVodConfig.ADD_DATA_TIME;
			if(startID == -1){return null;}
			/**从播放点所在位置查找p2p想得到的数据*/
			var startMinutes:Number = TimeTranslater.getHourMinObj(startID).minutes;
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				var endMinutes:Number = startMinutes+Math.floor(LiveVodConfig.MEMORY_TIME/4*3-1);//dataMgr_.getNearestWantID();
				if(endMinutes>Math.floor(LiveVodConfig.DURATION/60))
				{
					endMinutes = Math.floor(LiveVodConfig.DURATION/60);
				}
				getWantPieceObj.endMinutes = endMinutes;
			}
			getWantPieceObj.startID      = startID;
			getWantPieceObj.startMinutes = startMinutes;
			
			return getWantPieceObj;
		}
		
		public function getGroupIDList():Array
		{
			var tempArray:Array=new Array;
			for(var param:String in _pieceList)
			{
				tempArray.push(param);
			}
			return tempArray;
		}
		/**
		 * 当对方节点收到本地下载数据的进度而返回的对方拥有的数据离散表remoteHaveData:Array，
		 * 该数组已经按照由左到右顺序排好，每一个元素代表一个离散区间DataRange对象,
		 * getWantPiece方法遍历区间段所包含的piece，找到本地所需的wantCount数量的piece
		 **/
		public function getWantPiece(farID:String):Array
		{
			return null;
			/*var array:Array = new Array;
			//var startID:Number = dataMgr_.getNearestWantID();
			
			getWantPieceEndMinutes();
			var startID:Number = getWantPieceObj.startID;
			var startMinutes:Number = getWantPieceObj.startMinutes;
			var endMinutes:Number = getWantPieceObj.endMinutes;//dataMgr_.getNearestWantID();
			
			
			while(true)
			{				
				if( startMinutes > endMinutes)
				{
					break;
				}
				
				var minutesObject:Object = this.getMinuteBlocks(startMinutes++);
				
				if (minutesObject == null)
					break;
				//
				var arr:Array = new Array();
				for (var id:String in minutesObject)
				{
					arr.push(Number(id));
				}
				//
				arr.sort(Array.NUMERIC);
				
				for (var i:int=0 ; i<arr.length ; i++)
				{
					var j:Number = arr[i];
					if (j >= startID)
					{
						var lastBlock:Block = minutesObject[j] as Block;
						//
						if(    lastBlock
							&& lastBlock.isChecked == false 
							&& lastBlock.downLoadStat != 1)
						{
							//var index:int = 0;
							var index:int = 0;
							while(index < lastBlock.pieces.length)
							{
								var pies:Piece = lastBlock.getPiece(index);
								index++;
								//index--;
								if ( pies )
								{
									if( pies.peerHaveData.indexOf(farID) != -1 )
									{
										//
										if ( pies.iLoadType != 3 && pies.peerID == "")
										{
											pies.begin     = getTime();
											pies.peerID    = farID;
											pies.from      = "p2p";
											pies.iLoadType = 2;
											lastBlock.downLoadStat=2;
											//pies.
											var object:Object = new Object;
											object.blockID = lastBlock.id;
											object.pieceID = pies.id;
											array.push(object);
											
											if(array.length>0)
											{
												return array;
											}
											
										}
									}									
								}
								else
								{
									break;
								}
							}
						}	
					}					
				}
			}
			return array;*/
		}			
		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void//clear:Boolean=false):void
		{
			return;
			/*var time:Number=(new Date()).time;
			var block:Block = this.getBlock(blockID);
			if(block&&!block.isChecked)
			{
				for(var i:int=0 ; i<block.pieces.length ; i++)
				{
					if(block.pieces[i].stream.bytesAvailable ==0 && block.pieces[i].peerID == farID)
					{
						block.pieces[i].reset();
					}
				}
			}*/
			//
			return;
		}		
		/**获得某一分钟段的blocks*/
		public function getMinuteBlocks(minutes:Number):Object
		{
			//var obj:Object = TimeTranslater.getHourMinObj(id);
			if( _blockList
				&& _blockList[minutes]
				&& _blockList[minutes]["blocks"]
			)
			{
				return _blockList[minutes]["blocks"];
			}
			return null;
		}
		
		/**获得最小的小时和分钟*/
		public function getMiniHourMin():Number
		{
			var miniMin:Number=int.MAX_VALUE;
			for(var min:String in _blockList)
			{
				if(miniMin > Number(min))
				{
					miniMin=Number(min);
				}
			}
			if(miniMin==int.MAX_VALUE)
			{
				return -1;
			}else
			{
				return miniMin
			}
		}
		public function setMinuteHasStreamData(i:Number):void
		{
			_blockList[i]["isHasStreamData"] = true;
		}
		
		/**获得最大的小时和分钟*/
		private var blocks:Object = new Object();
		public function getMinMaxMinute():Object
		{
			var minMin:Number = Number.MAX_VALUE;
			var maxMin:Number = -1;			
			var obj:Object = new Object();
			
			for(var minute:String in _blockList)
			{
				blocks = _blockList[minute];
				if(_blockList[minute]["isHasStreamData"])
				{
					if(Number(minute) > maxMin)
					{
						maxMin = Number(minute);
					}
					if(Number(minute) < minMin)
					{
						minMin = Number(minute);
					}
				}				
			}
			
			if( minMin != Number.MAX_VALUE && maxMin != -1)
			{
				obj.maxMin = maxMin;
				obj.minMin = minMin;
				return obj;
			}			
			
			return null;
		}
		
		public function removePeerHaveData(peerID:String,peerRemoveDataArray:Array):void
		{
			for(var i:int=0 ; i<peerRemoveDataArray.length ; i++)
			{
				/**
				 * peerRemoveDataArray及tempRemovePeerHaveDataObj数据结构：
				 * tempRemovePeerHaveDataObj = peerRemoveDataArray[n];
			 	 * tempRemovePeerHaveDataObj.minuteIdx:Number = 分钟索引值
				 * tempRemovePeerHaveDataObj.blockIdx:Number = blockID索引值，当为-1时删除全部minuteIdx分钟关于peer记录
				 * tempRemovePeerHaveDataObj.pieceIdx:Number = pieceID索引值，当为-1时删除全部block关于peer记录
				*/
				var tempRemovePeerHaveDataObj:Object = peerRemoveDataArray[i];
				var minuteIdx:Number = tempRemovePeerHaveDataObj["minuteIdx"];
				var tempBlock:Block;
				
				if(_blockList[minuteIdx] && _blockList[minuteIdx]["blocks"])
				{
					var blockIdx:Number = tempRemovePeerHaveDataObj["blockIdx"];
					if( blockIdx == -1)
					{					
						/**
						 * 删除本分钟内的所有peerID记录
						 * */
						for(var j:String in _blockList[minuteIdx]["blocks"])
						{
							tempBlock = _blockList[minuteIdx]["blocks"][j];
							realRemovePeerHaveData(peerID,tempBlock,tempRemovePeerHaveDataObj.pieceIdx);							
						}
					}
					else
					{
						/**
						 * 删除本分钟内的某一特定block的peerID记录
						 * */
						if(_blockList[minuteIdx]["blocks"][blockIdx])
						{
							tempBlock = _blockList[minuteIdx]["blocks"][blockIdx];
							realRemovePeerHaveData(peerID,tempBlock,tempRemovePeerHaveDataObj.pieceIdx);
						}
					}
				}
				tempBlock = null
			}
		}
		private function realRemovePeerHaveData(peerID:String,block:Block,pieceIdx:Number=-1):void
		{
			/*var n:int;
			if(pieceIdx == -1)
			{
				
				// 删除本分钟内的某一block里所有piece的peerID记录
				
				for(var m:int=0 ; m<block.pieces.length ; m++)
				{
					Statistic.getInstance().peerRemoveHaveData(peerID,block.id,m);
					n = block.pieces[m].peerHaveData.indexOf(peerID);					
					if(n != -1)
					{
						block.pieces[m].peerHaveData.splice(n,1);
					}
				}
			}
			else
			{
				//  删除本分钟内的某一block里pieceIdx标记的piece的peerID记录
				
				if(block.pieces[pieceIdx])
				{
					Statistic.getInstance().peerRemoveHaveData(peerID,block.id,m);
					n = block.pieces[pieceIdx].peerHaveData.indexOf(peerID);
					if(n != -1)
					{
						block.pieces[pieceIdx].peerHaveData.splice(n,1);
					}					
				}
			}*/
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
				
		/**按照分钟淘汰任务*/
		private function realEliminateTask(minute:Number,delDESC:Boolean=false):void
		{	
			if(_blockList&&	_blockList[minute])
			{
				var tempEliminateArray:Array = new Array();
				
				var beforeEliminateSize:Number = _streamSize;
				
				var blocks:Object = _blockList[minute]["blocks"];
				var block:Block;
				
				for(var n:String in blocks)
				{
					block = blocks[n] as Block;
					
					if(delDESC)
					{
						SeqMap[block.sequence] = null;
						
						delete SeqMap[block.sequence];
						
						tempEliminateArray.push(block.pieceIdxArray.concat());
						
						block.clear();	
						block = null;						
						delete blocks[n];
					}
					else
					{
						block.reset();
						block = null;	
					}			
				}
				
				if(delDESC)
				{
					_blockList[minute] = null;
					delete _blockList[minute];
				}
				
				_blockList[minute]["isHasStreamData"] = false;
				
				dataMgr_.removeHaveData(tempEliminateArray);
			}	
		}
		
		public function eliminate():void
		{
			/**判断是否饱和，如果饱和开始淘汰*/
			if(_streamSize>=LiveVodConfig.MEMORY_SIZE)
			{
				var minMaxObj:Object;
				minMaxObj = getMinMaxMinute();
				
				if(!minMaxObj || minMaxObj.maxMin == minMaxObj.minMin)return;

				var objTm:Object = TimeTranslater.getHourMinObj(LiveVodConfig.ADD_DATA_TIME);
				var beforeEliminateSize:Number = _streamSize;
				
				var tempCount:Number = 0;
				
				if(objTm.minutes - minMaxObj.minMin < 1 )
				{	
					/**淘汰播放点右侧一分钟的block数据流但保留desc和block*/
					while(true)
					{
						if( (minMaxObj.maxMin-tempCount >= objTm.minutes+LiveVodConfig.MEMORY_TIME) 
							&& _blockList[minMaxObj.maxMin-tempCount]["isHasStreamData"] == true
							)
						{
							//realEliminateTask(objTm.minutes+LiveVodConfig.MEMORY_TIME-eliminateCount);
							realEliminateTask(minMaxObj.maxMin-tempCount);
							if( /*beforeEliminateSize*/LiveVodConfig.MEMORY_SIZE > _streamSize )
							{
								/**成功淘汰数据流*/
								break;
							}
						}
						else
						{
							break;
						}
						tempCount++;
					}
				}
				else
				{
					/**淘汰播放点最左侧一分钟的desc和block*/
					while(true)
					{
						if( objTm.minutes - (minMaxObj.minMin + tempCount) >= 1
							&& _blockList[minMaxObj.minMin + tempCount]["isHasStreamData"] == true
							)
						{
							realEliminateTask(minMaxObj.minMin + tempCount/*,true*/);
							if( /*beforeEliminateSize*/LiveVodConfig.MEMORY_SIZE > _streamSize )
							{
								/**成功淘汰数据流*/
								break;
							}
						}
						else
						{
							break;
						}
						tempCount++;
					}
				}
			}
		}
		
		public function clear():void
		{
			_blockList = null;
//			_headerList = null;	
			SeqMap = null;
			dataMgr_ = null;
		}
		public function _toString():String
		{
			var str:String="";
			for(var hour:String in _blockList)
			{
				str+="hour:"+hour+" "+TimeTranslater.getTime(Number(hour)*3600)+" min:";
				for(var min:String in _blockList[hour])
				{
					str+=min+"\n";
//					str+=" blockid{";
					for(var n:String in _blockList[hour][min]["blocks"])
					{
						var block:Block = _blockList[hour][min]["blocks"][n] as Block;
//						if(block.isFull){
//							str+=block.id+" nID:"+block.nextID+" pID:"+block.preID+"\n";
//						}else{
//							str+=block._toString()+"\n";
							str+=block.sequence+"\n";
//						}
					}
//					str+="}"
				}
			}
			//str+="\ncount:"+this._count;
			//_headerList
			return str+"\n";
		}
		
		//live_vod
//		public function getDescTask():Number
//		{
//			var baseTime:Number
//			if(playPosition!=-1)
//			{
//				baseTime = playPosition;
//			}
//			else
//			{
//				baseTime =	LIVE_TIME.GetBaseTime();
//			}
//			
//			var _tempDateObj:Object = 	TimeTranslater.getHourMinObj(baseTime);
//			var _baseTimeObj:Object = 	TimeTranslater.getHourMinObj(baseTime);;
//			while(true)
//			{
//				if(_blockList&&_blockList[_tempDateObj.minutes]&&_blockList[_tempDateObj.minutes]["isMinEnd"] && LiveVodConfig.TYPE == LiveVodConfig.VOD )
//				{
//					_tempDateObj.minutes+=1;
//					if(_tempDateObj.minutes-_baseTimeObj.minutes >= LiveVodConfig.MEMORY_TIME)
//					{
//						return -1;
//					}
//				}else
//				{
//					if(LiveVodConfig.TYPE == LiveVodConfig.VOD )
//					{
//						return _tempDateObj.minutes*60;
//					}
//					/*else
//					{
//						if(LiveVodConfig.timeshift == 0)
//						{
//							LiveVodConfig.timeshift = 0
//						}
//						return LiveVodConfig.timeshift + 3;
//					}*/					
//				}
//			}
//			return -1;
//		}
	}
}