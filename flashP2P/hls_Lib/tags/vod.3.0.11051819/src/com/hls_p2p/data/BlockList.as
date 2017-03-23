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
		
		private var getWantPieceObj:Object = new Object();
		
		/**Block总列表*/
		private var _blockList:Object = new Object;
		
		private var _fileMap:Object = new Object;
		/**方块调用*/
		public function get blockList():Object
		{
			return _blockList;
		}
		
		/**保存piece的总列表*/
		private var _pieceList:Object = new Object;
		
		/**构造*/
		public var dataMgr_:IDataManager = null;
		
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
			if(_blockList == null)
			{
				_blockList = new Object;
			}
			if(_blockList.hasOwnProperty(clip.timestamp))
			{
				return true;
			}
			return realAddBlock(_blockList,clip);
		}
		/***设置block属性并添加到list中************/
		private function realAddBlock(blocks:Object, clip:Clip):Boolean
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
				block.offSize		 = clip.offsize;
				block.size           = clip.size;
//				block.sequence		 = clip.sequence;
				block.groupID        = clip.groupID;
				block.pieceInfoArray = clip.pieceInfoArray;
				_fileMap[clip.name] = block;
			}else
			{
				block = _fileMap[clip.name];
				block.id = clip.timestamp;
			}
			
			blocks[clip.timestamp] = block;
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
		
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId(id:Number):Number
		{
			if (null == _blockList) return -1;
			var block:Block;
			var maxId:Number = 0;
			for each(block in this._blockList)
			{
				if (block.id > maxId)
					maxId = block.id;
				//
				if(block)
				{
					if(block.id<=id && id< block.id+block.duration)
					{
						return block.id;
					}
				}
			}
			//
			if (maxId > id)
				return getBlockId(id+1);
			else 
				return maxId;
			return -1;
		}
		public function getPiece(param:Object):Piece
		{
			if (null == pieceList) return null;
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
			if (null == _blockList) return null;
			if(id==-1){return null}
			return _blockList[id];
		}
						
		/***/
		public function getDataAfterPoint(groupID:String,id:Number):Array
		{
			/**
			 * arr数组的数据结构
			 * arr = [piece.pieceKey,..]
			 * */
			if (null == pieceList) return null;
			var arr:Array = new Array();
			if( !pieceList[groupID] )
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
		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void//clear:Boolean=false):void
		{
			return;
		}		
		
		public function eliminate():void
		{
			if(_streamSize>=LiveVodConfig.MEMORY_SIZE)
			{
				//tempEliminatePieceIdxArr = new Array();
				
				var i:uint,j:uint;
				var arr:Array = new Array();
				//-60表示淘汰时，不淘汰播放点左侧一分钟之内的数据
				var playID:Number = this.getBlockId(LIVE_TIME.GetBaseTime()-60);
				var block:Block = null;
				for (var id:String in _blockList)
				{
					arr.push(Number(id));
				}
				arr.sort(Array.NUMERIC);
				
				for(j=0;j<arr.length;j++)
				{
					if(arr[j]<playID)
					{
						/**淘汰播放点左侧数据*/
						block = this.getBlock(arr[j]);
						//fileMap的block是按照最大的id标识
						if(block.id != arr[j])
						{
							_blockList[arr[j]] = null;
							delete _blockList[arr[j]];
							continue;
						}else
						{
							_blockList[arr[j]] = null;
							delete _blockList[arr[j]];
							
							this._fileMap[block.name] = null;
							delete this._fileMap[block.name];
							
							realEliminate(block);
							
							if(_streamSize >= LiveVodConfig.MEMORY_SIZE)
							{
								continue;
							}else
							{
								break;
							}
						}
					}
				}
				//
				if(_streamSize >= LiveVodConfig.MEMORY_SIZE)
				{
					for(j=arr.length-1;j>=0;j--)
					{
						if(arr[j]>playID+5*60)
						{
							block = this.getBlock(arr[j]);
							//fileMap的block是按照最大的id标识
							if(block.id != arr[j])
							{
								_blockList[arr[j]] = null;
								delete _blockList[arr[j]];
								continue;
							}else
							{
								/**直播淘汰数据右侧数据,需要淘汰策略！！！！！！！！*/
								/*if(arr[j]<get)
								{
									
								}*/
								_blockList[arr[j]] = null;
								delete _blockList[arr[j]];
								
								this._fileMap[block.name] = null;
								delete this._fileMap[block.name];
								
								realEliminate(block,true);
								
								if(_streamSize >= LiveVodConfig.MEMORY_SIZE)
								{
									continue;
								}else
								{
									break;
								}
							}
						}
					}
				}
				cleanUpPieceList();
				//dataMgr_.removeHaveData(tempEliminatePieceIdxArr);
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
		
		private var tempEliminatePieceIdxArr:Array;
		private function realEliminate(block:Block,isRight:Boolean=false):void
		{
			
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				/**点播淘汰数据*/
				//tempEliminatePieceIdxArr.concat(block.pieceIdxArray);
				block.reset();
			}
			else
			{
				if(	false == isRight )
				{
					/**直播淘汰数据左侧数据*/
					//tempEliminatePieceIdxArr.concat(block.pieceIdxArray);
					block.clear();
				}
				else
				{
					/**直播淘汰数据右侧数据,需要淘汰策略！！！！！！！！*/
					//tempEliminatePieceIdxArr.concat(block.pieceIdxArray);
					block.reset();
				}
			}
			block = null;
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

			_blockList	= null;
			getWantPieceObj = null;
			_pieceList	= null;
			SeqMap		= null;
			dataMgr_	= null;

			tempEliminatePieceIdxArr = null;			
		}
	}
}