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
		/**保存piece的总列表*/
		private var _pieceList:Object = new Object;
		
		/**构造*/
		public var dataMgr_:IDataManager = null;
		
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
		
		public function addTNRange(groupID:String,index:uint):void
		{
			if (index <= -1) return;
			//
			if(null == this.pieceList || null == this.pieceList[groupID]){return;}
			
			if(null == this.pieceList[groupID]["TNRange"])
			{
				this.pieceList[groupID]["TNRange"] =new Array;
			}
			
			var _TNRange:Array = (this.pieceList[groupID]["TNRange"] as Array);
			
			if (_TNRange[index] == null)
			{
				_TNRange[index] = new Object();
				_TNRange[index].start = index;
				_TNRange[index].end = index;
			}
			//
			for each(var rg:* in _TNRange)
			{
				if (_TNRange[rg.end+1])
				{
					rg.end = _TNRange[rg.end+1].end;
					delete _TNRange[rg.end];
				}				
			}
		}
		
		public function deleteTNRange(groupID:String,index:uint):void
		{
			if (index <= -1) return;
			if(
				null == this.pieceList || 
				null == this.pieceList[groupID] || 
				null == this.pieceList[groupID]["TNRange"]
			){return;}
			
			var _TNRange:Array = (this.pieceList[groupID]["TNRange"] as Array);
			
			//range 起点包含的数据
			if (_TNRange[index])
			{
				//range 是一个元素情况
				if (_TNRange[index].start == _TNRange[index].end)
				{
					delete _TNRange[index];
					return;
				}else
				{
					//range 是多个元素情况
					_TNRange[index+1] = new Object();
					_TNRange[index+1].start = index+1;
					_TNRange[index+1].end   = _TNRange[index].end;
					//
					delete _TNRange[index];
					return;
				}
			}
			//
			for each(var rg:* in _TNRange)
			{
				if (rg.start < index && rg.end >= index)
				{
					_TNRange[index+1] = new Object();
					_TNRange[index+1].start = index+1;
					_TNRange[index+1].end   = rg.end;
					//
					rg.end = index -1;
					//
					return ;
					//break;
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
		
		public function addPNRange(groupID:String,index:uint):void
		{
			if (index <= -1) return;
			//
			if(null == this.pieceList || null == this.pieceList[groupID]){return;}
			
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
			//
			for each(var rg:* in _PNRange)
			{
				if (_PNRange[rg.end+1])
				{
					rg.end = _PNRange[rg.end+1].end;
					delete _PNRange[rg.end];
				}				
			}
		}
		
		public function deletePNRange(groupID:String,index:uint):void
		{
			if (index <= -1) return;
			//range 起点包含的数据
			if(
				null == this.pieceList || 
				null == this.pieceList[groupID] || 
				null == this.pieceList[groupID]["PNRange"]
			){return;}
			
			var _PNRange:Array = (this.pieceList[groupID]["PNRange"] as Array);
			
			if (_PNRange[index])
			{
				if (_PNRange[index].start == _PNRange[index].end)
				{
					delete _PNRange[index];
					return;
				}else
				{
					_PNRange[index+1] = new Object();
					_PNRange[index+1].start = index+1;
					_PNRange[index+1].end   = _PNRange[index].end;
					//
					delete _PNRange[index];
					return;
				}
			}
			//
			for each(var rg:* in _PNRange)
			{
				if (rg.start < index && rg.end >= index)
				{
					_PNRange[index+1] = new Object();
					_PNRange[index+1].start = index+1;
					_PNRange[index+1].end   = rg.end;
					//
					rg.end = index -1;
					//
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
				block.groupID        = clip.groupID;
				block.pieceInfoArray = clip.pieceInfoArray;
				_fileMap[clip.name] = block;
			}else
			{
				block = _fileMap[clip.name];
				block.id = clip.timestamp;
			}
			
			blocks[clip.timestamp] = block;
			return true;
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
		
		public function getGroupIDList():Array
		{
			var tempArray:Array=new Array;
			for(var param:String in _pieceList)
			{
				tempArray.push(param);
			}
			return tempArray;
		}		
		
		public function eliminate():void
		{
			if(_streamSize>=LiveVodConfig.MEMORY_SIZE)
			{
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
								/**直播淘汰数据右侧数据*/
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
		
		private function realEliminate(block:Block,isRight:Boolean=false):void
		{
			_fileMap[block.name] = null;
			delete _fileMap[block.name];
			_blockList[block.id] = null;
			delete _blockList[block.id];
			
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
					block.clear();
				}
				else
				{
					/**直播淘汰数据右侧数据*/
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
			dataMgr_	= null;			
		}
	}
}