package com.p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * BlockList用来存放数据结构
	 */	
	
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.Piece;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
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
		
		/**
		 * dataList[hour][min][blocks,isTaskFull,headid,isDestroy]
		 * _headerList[id]=bytearray
		 */
		
		/**总列表*/
		private var _blockList:Object = new Object;
		/**保存头数据流的列表*/
		private var _headerList:Object = new Object;		
		private var SeqMap:Object = new Object;
		/*private var _count:Number=0;

		public function get count():Number
		{
			return _count;
		}

		public function set count(value:Number):void
		{
			_count = value;			
		}
		*/
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
		/**
		 * 请求desc后处理，每次添加块时，会依具Clip的时间戳timestamp按小时分钟添加到对应的列表中，
		 * @param block 添加块
		 * 需要返回是否成功添加
		 * 先检查创建好，然后添加
		 */
		
		public function addBlock(clip:Clip,isMinEnd:Boolean):Boolean
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(clip.timestamp);	
			
			if( !_blockList[_tempDateObj.minutes])
			{
				//在创建新的分钟之前查早之前的分钟是否空缺，有空缺时播放和下载无法做判断，所以补缺空
				_blockList[_tempDateObj.minutes] = new Object();
			}
			
			if( !_blockList[_tempDateObj.minutes]["blocks"])
			{
				_blockList[_tempDateObj.minutes]["blocks"] = new Object();
			}
			
			_blockList[_tempDateObj.minutes]["isMinEnd"]=isMinEnd;
			
			if(_blockList[_tempDateObj.minutes]["blocks"][clip.timestamp])
			{
				/**该block已经存在，不需要添加*/
				return false;
			}
			return realAddBlock(_blockList[_tempDateObj.minutes]["blocks"],clip);
		}
		/***设置block属性并添加到list中************/
		private function realAddBlock(blocks:Object, clip:Clip):Boolean
		{
			var block:Block   = new Block(this);
			block.id           = clip.timestamp;
			block.head         = clip.head;
			block.checkSum     = clip.checkSum;
			block.duration     = clip.duration;
			block.name         = clip.name;
			block.size         = clip.size;
			block.sequence     = clip.sequence;
			/**添加block*/
			blocks[clip.timestamp] = block;
			SeqMap[block.sequence] = block;
			//_count++;
			
			/**添加head*/
			addHeader(clip.head);
//			Debug.traceMsg(this,"添加block"+block.id);
			return true;
		}
		
		/**添加头,确保头的时间戳是head id*/
		private function addHeader(hdID:Number):void
		{
			if(!_headerList[hdID])
			{
				_headerList[hdID] = new Head();
				_headerList[hdID].id = hdID;
				P2PDebug.traceMsg(this,"headerList["+hdID);
			}
		}
		
		public function getDescTask():Number
		{
			var baseTime:Number		=	LIVE_TIME.GetBaseTime();
			var _tempDateObj:Object = 	TimeTranslater.getHourMinObj(baseTime);
			var _baseTimeObj:Object = 	TimeTranslater.getHourMinObj(baseTime);;
			while(true)
			{
				if(_blockList&&_blockList[_tempDateObj.minutes]&&_blockList[_tempDateObj.minutes]["isMinEnd"])
				{
					_tempDateObj.minutes+=1;
					if(_tempDateObj.minutes-_baseTimeObj.minutes
						>=
						LiveVodConfig.MEMORY_TIME)
					{
						return -1;
					}
				}else
				{
					return _tempDateObj.minutes*60;
				}
			}
			return -1;
		}
		
		public function getNextIDBlock(currentID:Number):Block
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(currentID);
			
			if(!_blockList[_tempDateObj.minutes]
				||!_blockList[_tempDateObj.minutes]["blocks"])
			{
				return null;
			}
			
			var arr:Array=new Array;
			for(var element:* in _blockList[_tempDateObj.minutes]["blocks"])
			{
				arr.push(_blockList[_tempDateObj.minutes]["blocks"][element].id);
			}
			
			if(_blockList[_tempDateObj.minutes+1]
				&&_blockList[_tempDateObj.minutes+1]["blocks"])
			{
				for( element in _blockList[_tempDateObj.minutes+1]["blocks"])
				{
					arr.push(_blockList[_tempDateObj.minutes+1]["blocks"][element].id);
				}
			}
			
			arr.sort(Array.NUMERIC);
			for(var i:int=0;i<arr.length;i++)
			{
				if(arr[i]>currentID)
				{
					return getBlock(arr[i]);
				}
			}
			
			return null;
		}
		
		public function getNextSeqID(seqID:Number):Block
		{
			if(!SeqMap[seqID+1])
			{
				return null;
			}
			return SeqMap[seqID+1];
		}
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId(id:Number):Number
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			
			if(!_blockList[_tempDateObj.minutes]
				||!_blockList[_tempDateObj.minutes]["blocks"])
			{
				return -1;
			}
			var block:Block;
			var minBlock:Block=null;
			for(var element:* in _blockList[_tempDateObj.minutes]["blocks"])
			{
				block=_blockList[_tempDateObj.minutes]["blocks"][element];
				if(minBlock==null)
				{
					minBlock=block;
				}else
				{
					if(minBlock.id>block.id)
					{
						minBlock=block;
					}
				}
				if(((block.id<=id) && (id<block.id+block.duration/1000))
				)
				{
					return block.id;
				}
			}
			//
			{
				//_tempDateObj = TimeTranslater.getHourMinObj(id-60);
				
				if(!_blockList[_tempDateObj.minutes-1]
					||!_blockList[_tempDateObj.minutes-1]["blocks"])
				{
					if(minBlock)
					{
						return minBlock.id;
					}
					return -1;
				}
				
				for(var _element:* in _blockList[_tempDateObj.minutes-1]["blocks"])
				{
					block=_blockList[_tempDateObj.minutes-1]["blocks"][_element];
					
					if(((block.id<=id) && (id<block.id+block.duration/1000)))
					{
						return block.id;
					}
				}
			}
			
			return -1;
		}
		/**确保getBlock的时间戳是block id，如果不能确保id,调用getBlockId*/
		public function getBlock(id:Number):Block
		{
			if(id==0){return null}
			
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
		public function getHeadTask():Head
		{
			for (var id:String in _headerList)
			{
				if (_headerList[id])
				{
					var hd:Head = _headerList[id] as Head ;
					if (hd.getHeadStream().bytesAvailable == 0)
						return hd;
				}
			}
			//
			return null;
		}
		public function getHead(id:Number):Head
		{
			return _headerList[id];
		}
		//
						
		/**获得id索引值之后有流的数据列表,暂时传入blockID，将来会使用blockID_pieceID */
		public function getDataAfterPoint(id:Number):Array
		{
			/**
			 * arr数组的数据结构
			 * arr = [{bID:blockID(Number),pIDArr:Array(有数据的piece索引值)}, ... ,]
			 * */
			var arr:Array = new Array();
			var LoadTime:Number = Number(id);
			var intervalTime:Number=3;
			
			var lastBlockId:Number=-1;
			var btime:Number = LoadTime;
			if (LoadTime == 0)
				return arr;
			//
			for(LoadTime; LoadTime - btime < Math.floor(LiveVodConfig.MEMORY_TIME/2-1)*60/*60*20*/; LoadTime += intervalTime)
			{
				var tmpTime:Number = this.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					continue;
				}
				if(lastBlockId!=tmpTime)
				{
					var lastBlock:Block =this.getBlock(tmpTime);
					if( lastBlock /*&& lastBlock.isChecked*/ )
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
			return arr;
		}
		
		/**
		 * 当对方节点收到本地下载数据的进度而返回的对方拥有的数据离散表remoteHaveData:Array，
		 * 该数组已经按照由左到右顺序排好，每一个元素代表一个离散区间DataRange对象,
		 * getWantPiece方法遍历区间段所包含的piece，找到本地所需的wantCount数量的piece
		 **/
		public function getWantPiece(farID:String):Array
		{
			var array:Array = new Array;
			var startID:Number = dataMgr_.getPlayingBlockID();
			//var startBlock:Block = this.getBlock(startID);
			/**从播放点所在位置查找p2p想得到的数据*/
			var startMinutes:Number = TimeTranslater.getHourMinObj(startID).minutes;
			
			
			/**从直播点的方向查找p2p想得到的数据*/
			
			var MaxMinMinuteObj:Object = getMinMaxMinute();
			if(MaxMinMinuteObj == null)
			{
				return null;
			}
			var endMinutes:Number = MaxMinMinuteObj.maxMin;
			if(endMinutes-startMinutes>= Math.floor(LiveVodConfig.MEMORY_TIME/2-1))
			{
				endMinutes=TimeTranslater.getHourMinObj(startMinutes+Math.floor(LiveVodConfig.MEMORY_TIME/2-1)).minutes;
			}
			/********************************/
			
			while(true)
			{
				/**var minutesObject:Object = this.getMinuteBlocks(obj.minutes++);*/
				var minutesObject:Object = this.getMinuteBlocks(endMinutes--);
				
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
				//for each(var i:Number in arr)
				for (var i:int=arr.length-1 ; i>=0 ; i--)
				{
					var j:Number = arr[i];
					if (j >= startID)
					{
						var lastBlock:Block = minutesObject[j] as Block;
						//
//						if(lastBlock.id<= this.dataMgr_["httpDownLoadPos"])
//						{
//							return null;
//						}
						if(    lastBlock
							&& lastBlock.isChecked == false 							
							&& (lastBlock.id - LIVE_TIME.GetBaseTime()) > LiveVodConfig.DAT_BUFFER_TIME //假定紧急区为30秒
							/*&& lastBlock.peersHaveData.indexOf(farID) != -1*/)
						{
							//var index:int = 0;
							var index:int = lastBlock.pieces.length-1;
							while(index>=0)
							{
								var pies:Piece = lastBlock.getPiece(index);
								//index++;
								index--;
								if ( pies )
								{
									if( pies.peerHaveData.indexOf(farID) != -1 )
									{
										/*if (   pies.iLoadType == 2                      //如果该任务已分配给p2p下载
											&& pies.peerID != ""                        //用该条件判断piece是否为未分配任务的初始状态
											&& pies.peerID != farID                     //不是同一个Peer
											&& (getTime() - pies.begin) > 17*1000)      //等待时间超过30秒
										{
											pies.reset();
										}*/
										//
										if ( pies.iLoadType != 3 && pies.peerID == "")
										{
//											pies.begin     = getTime();
//											pies.peerID    = farID;
//											pies.from      = "p2p";
//											pies.iLoadType = 2;
//											lastBlock.downLoadStat=2;
											//pies.
											var object:Object = new Object;
											object.blockID = lastBlock.id;
											object.pieceID = pies.id;
											array.push(object);
											
//											if(array.length==1)
//											{
//												/**每次只分配一个piece*/
//												return array;
//											}
											
										}
									}									
								}
								else
								{
									break;
								}
							}
							
							//
//							if(array.length > 0)
//							{
//								return array;
//							}
						}	
					}					
				}
			}
			if(array.length > 0)
			{
				var obj2:Object=array[Math.floor(array.length*Math.random())];
				var pies2:Piece=this.getBlock(obj2.blockID).getPiece(obj2.pieceID);
				pies2.begin     = getTime();
				pies2.peerID    = farID;
				pies2.from      = "p2p";
				pies2.iLoadType = 2;
				lastBlock.downLoadStat=2;
				return [obj2];
			}
			return array;
		}			
		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void//clear:Boolean=false):void
		{
			return;
			var time:Number=(new Date()).time;
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
			}
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
		/**获得最大的小时和分钟*/
		public function getMinMaxMinute():Object
		{
			var minMin:Number = Number.MAX_VALUE;
			var maxMin:Number = -1;
			var obj:Object = new Object();
			
			for(var minute:String in _blockList)
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
			
			if( minMin != Number.MAX_VALUE && maxMin != -1)
			{
				obj.maxMin = maxMin;
				obj.minMin = minMin;
				return obj;
			}			
			
			return null;
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
				
				var objTm:Object = TimeTranslater.getHourMinObj(LIVE_TIME.GetBaseTime());
				
				var beforeEliminateSize:Number = _streamSize;
				
				var tempCount:Number = 0;
				
				if(objTm.minutes - minMaxObj.minMin < 1 )
				{	
					/**淘汰播放点右侧一分钟的block数据流但保留desc和block*/
					while(true)
					{
						if( minMaxObj.maxMin-tempCount >= objTm.minutes+LiveVodConfig.MEMORY_TIME )
						{
							//realEliminateTask(objTm.minutes+LiveVodConfig.MEMORY_TIME-eliminateCount);
							realEliminateTask(minMaxObj.maxMin-tempCount);
							if( beforeEliminateSize > _streamSize )
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
						if(objTm.minutes - (minMaxObj.minMin + tempCount) >= 1)
						{
							realEliminateTask(minMaxObj.minMin,true);
							if( beforeEliminateSize > _streamSize )
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
			_headerList = null;	
			SeqMap = null;
			dataMgr_ = null;
		}
		public function _toString():String{
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
	}
}