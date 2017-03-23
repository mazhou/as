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
		private var _count:Number=0;

		public function get count():Number
		{
			return _count;
		}

		public function set count(value:Number):void
		{
			_count = value;
			
		}
		/**构造*/
		public function BlockList()
		{
		}
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
				//在创建新的分钟之前查早之前的分钟是否空缺，有空缺时播放和下载无法做判断，所以补缺空
				_blockList[_tempDateObj.minutes] = new Object();
			}
						
			if( !_blockList[_tempDateObj.minutes]["blocks"])
			{
				_blockList[_tempDateObj.minutes]["blocks"] = new Object();
			}
			
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
			_count++;
			
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
		
		private var descTask:Number = -1;
		public function getDescTask():Number
		{
			if (descTask != -1)
			{
				var desc:Number = descTask;
				descTask = -1;
				return desc;
			}
			var block:Block;
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(LIVE_TIME.GetBaseTime());
			var seq1:Number = Number.MAX_VALUE;
			if( _blockList[_tempDateObj.minutes] )
			{	
				for each(block in _blockList[_tempDateObj.minutes]["blocks"])
				{
					
					if (block.sequence < seq1)
					{
						seq1 = block.sequence;
						break;
					}
				}
				//
			}
			//
			if (seq1 == Number.MAX_VALUE)
				return LIVE_TIME.GetBaseTime();
			//
			while(1)
			{
				if (SeqMap[seq1])
				{
					seq1 +=1;
				}else
				{
					break;
				}
			}
			//
			block = SeqMap[seq1 - 1] as Block;
			descTask = block.id + 60;
			
			//
			return block.id;// + block.duration/1000;// + 20;
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
			for(var element:* in _blockList[_tempDateObj.minutes]["blocks"])
			{
				block=_blockList[_tempDateObj.minutes]["blocks"][element];
				
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
		public function getDataAfterPoint(id:String):Array
		{
			var arr:Array = new Array();
			var LoadTime:Number = Number(id);
			var intervalTime:Number=3;
			
			var lastBlockId:Number=-1;
			var btime:Number = LoadTime;
			if (LoadTime == 0)
				return arr;
			//
			for(LoadTime; LoadTime - btime < 60*20; LoadTime += intervalTime)
			{
				var tmpTime:Number = this.getBlockId(LoadTime);
				if(tmpTime==-1)
				{
					continue;
				}
				if(lastBlockId!=tmpTime)
				{
					var lastBlock:Block =this.getBlock(tmpTime);
					if(lastBlock&&lastBlock.isChecked)
					{
						arr.push(lastBlock.id);
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
		public function getWantPiece(remoteHaveData:Array, farID:String, wantCount:int=3):Array
		{
			var arr:Array = new Array;
			for(var j:int=0 ; j<remoteHaveData.length ; j++)
			{
				var blID:Number = Number(remoteHaveData[j]);
				var lastBlock:Block = this.getBlock(blID);
				if(    lastBlock
					&& lastBlock.isChecked == false 
					&& lastBlock._downLoadStat != 1 
					&& (blID - LIVE_TIME.GetBaseTime()) >LiveVodConfig.DAT_BUFFER_TIME)//假定紧急区为30秒
				{
					var index:int = 0;
					while(1)
					{
						var pies:Piece = lastBlock.getPiece(index);
						index++;
						if (pies)
						{
							if (pies.iLoadType == 2 && pies.peerID != farID && (getTime() - pies.begin) > 30*1000)
							{
								pies.reset();
							}
							//
							if ( pies.iLoadType != 3 && pies.peerID == "")
							{
								pies.begin     = getTime();
								pies.peerID    = farID;
								pies.from      = "p2p";
								pies.iLoadType = 2;
								lastBlock._downLoadStat=2;
								//pies.
								var obj:Object = new Object;
								obj.blockID = blID;
								obj.pieceID = pies.id;
								arr.push(obj);
							}
						}
						else
						{
							break;
						}
					}
					//
					if(index>0)
					{
						return arr;
					}
				}
			}
			//
			return arr;
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
					if(block.pieces[i].stream == null && block.pieces[i].peerID == farID)
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
		public function getMaxHourMin():Object{
			var maxHour:Number=0;
			var maxMin:Number=0;
			var obj:Object = new Object();
			for(var hourData:String in _blockList){
				if(Number(hourData)>maxHour){
					maxHour=Number(hourData)
				}
			}
			
			if(maxHour!=0){
				for(var maxData:String in _blockList[String(maxHour)]){
					if(Number(maxData)>maxMin){
						maxMin=Number(maxData)
					}
				}				
				if(maxMin!=0){
					obj.hour =maxHour;
					obj.min  = maxMin;
					return obj;
				}
			}
			return null;
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		/**按照分钟淘汰任务*/
		private function realEliminateTask(min:Number):void
		{
			if(_blockList&&	_blockList[min])
			{
				var blocks:Object = _blockList[min]["blocks"];
				var block:Block;
				
				for(var n:String in blocks)
				{
					block = blocks[n] as Block;
					SeqMap[block.sequence] = null;
					delete SeqMap[block.sequence];
	
					block.clear();	
					block = null;						
					delete blocks[n];
					//
					_count--;
				}
				//
				_blockList[min] = null;
				delete _blockList[min];
				//
			}
				
			return ;
			//
		}
		//
		public function eliminate():void
		{
			/**判断是否饱和，如果饱和开始淘汰，不饱和不做淘汰*/
			if(_count>=LiveVodConfig.MEMORY_SIZE/(LiveVodConfig.CLIP_INTERVAL * 5))
			{
				var _miniObj:Number=getMiniHourMin();
				if(_miniObj==-1)return;
				//
				var objTm:Object = TimeTranslater.getHourMinObj(LIVE_TIME.GetBaseTime());
				if(objTm.minutes - _miniObj < 10 )
				{
					realEliminateTask(objTm.minutes+30);
				}else
				{
					realEliminateTask(_miniObj);
				}
				//
				return;
			}
		}
		
		public function clear():void
		{
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
			str+="\ncount:"+this._count;
			//_headerList
			return str+"\n";
		}
	}
}