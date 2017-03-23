package com.p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * BlockList用来存放数据结构
	 */	
	
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.DataRange;
	import com.p2p.data.vo.LOAD_TYPE;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.Piece;
	import com.p2p.events.EventExtensions;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	import flash.external.ExternalInterface;
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
		private var _blockList:Object;
		/**保存头数据流的列表*/
		private var _headerList:Object;
		
		private var _count:Number=0;
		
		private var _isEliminate:Boolean=false;
		
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
			jsDebug();
			init();
		}
		private function jsDebug():void{
			ExternalInterface.addCallback("traceBlockList",traceBlockList);
		}
		public function traceBlockList():String{
			_isEliminate=true;
//			P2PDebug.traceMsg(this,"blockList:",_toString());
//			ExternalInterface.call("trace",_toString());
			return _toString();
		}
		private function init():void
		{
			_blockList  = new Object();
			_headerList = new Object();
		}
	
		private var _lastAddBlockHour:Number=0;
		private var	_lastAddBlockMin:Number=0;
		/**
		 * 请求desc后处理，每次添加块时，会依具Clip的时间戳timestamp按小时分钟添加到对应的列表中，
		 * @param block 添加块
		 * 需要返回是否成功添加
		 * 先检查创建好，然后添加
		 */
		public function addBlock(clip:Clip,loadType:String=""):Boolean
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(clip.timestamp);	
			
			if(!_blockList[_tempDateObj.hour])
			{
				_blockList[_tempDateObj.hour] = new Object();
			}
			
			if( !_blockList[_tempDateObj.hour][_tempDateObj.min])
			{
				//在创建新的分钟之前查早之前的分钟是否空缺，有空缺时播放和下载无法做判断，所以补缺空
				_blockList[_tempDateObj.hour][_tempDateObj.min] = new Object();
			}
			/*if(_lastAddBlockHour!=_tempDateObj.hour||_lastAddBlockMin!=_tempDateObj.min)
			{
				_lastAddBlockHour=_tempDateObj.hour;
				_lastAddBlockMin=_tempDateObj.min;
			}*/
			
			if( !_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"] = new Object();
			}
			
			if(_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][clip.timestamp])
			{
				/*if(clip.nextID!=0)
				{
					_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][clip.timestamp].nextID=clip.nextID;
				}
				if(clip.preID!=0){
					_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][clip.timestamp].preID=clip.preID;
				}*/
				/**该block已经存在，不需要添加*/
				return false;
			}
			return realAddBlock(_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"],clip);
		}
		
		/**每次cliplist填充后，修复衔接的双向链表*/
		public function repairNextBlockId(blockId:Number,nextBlockId:Number):void{
			if(getBlock(blockId)){
				getBlock(blockId).nextID=nextBlockId;
			}
		}
		/***设置block属性并添加到list中************/
		private function realAddBlock(blocks:Object,clip:Clip):Boolean
		{
			var block:Block   = new Block(this);
			block.id           = clip.timestamp;
			block.head         = clip.head;
			block.checkSum     = clip.checkSum;
			block.duration     = clip.duration;
			block.name         = clip.name;
			block.size         = clip.size;
			block.sunCheckSum  = clip.sunCheckSum;
			block.preID        = clip.preID;
			block.nextID       = clip.nextID;
			block.sequence     = clip.sequence;
			/**添加block*/
			blocks[clip.timestamp] = block;
			
			/**添加head*/
			addHeader(clip.head);
//			Debug.traceMsg(this,"添加block"+block.id);
			return true;
		}
		
		/**添加头,确保头的时间戳是head id*/
		private function addHeader(timestamp:Number):void
		{
			if(!_headerList[timestamp])
			{
				_headerList[timestamp] = new Head();
				_headerList[timestamp].id = timestamp;
				P2PDebug.traceMsg(this,"headerList["+timestamp+"] = "+_headerList[timestamp]);
			}
		}
		//
		public function getData(blockId:Number, seq:Number):Block
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(blockId);
			
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
				||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				return null;
			}
			//
			var block:Block;
			var seqMin:Number = Number.MAX_VALUE;
			var tmpBlock:Block;
			for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				
				if ( seq+1 == block.sequence )
				{
					return block;
				}
				//
				if (seqMin > block.sequence)
				{
					seqMin = block.sequence;
					tmpBlock = block;
				}
			}
			//
			_tempDateObj = TimeTranslater.getHourMinObj(blockId-60);
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
				||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				return null;
			}
			//
			for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				
				if ( seq+1 == block.sequence )
				{
					return block;
				}
			}
			//
			return tmpBlock;
		}
		public function getMinSeq(tm:Number):Block
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(tm);
			
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
				||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				return null;
			}
			//
			var block:Block;
			var seq:Number = Number.MAX_VALUE;
			var tmpBlock:Block;
			for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				
				if (block.isChecked == false && seq > block.sequence )
				{
					tmpBlock = block;
					seq = block.sequence;
					//return block;
				}
			}
			//
			if (tmpBlock && tmpBlock.isChecked == false)
				return tmpBlock;
			//
			return null;
		}
		public function getTask(tm:Number, pseq:Number=0):Block
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(tm);
			
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
				||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				return null;
			}
			//
			var block:Block;
			var seq:Number = Number.MAX_VALUE;
			var tmpBlock:Block;
			for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				
				if (block.isChecked == false && seq > block.sequence )
				{
					//return block;
					tmpBlock = block;
					seq = block.sequence;
					//return block;
				}
			}
			//
			if (tmpBlock && tmpBlock.isChecked == false)
				return tmpBlock;
			//
			return null;
			
		}
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId(id:Number):Number
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
				||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				return -1;
			}
			var block:Block;
			var min:Number=Number.MAX_VALUE;
			for(var element:* in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
			{
				block=_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][element];
				
				if(((block.id<=id)  && (id<block.nextID)) ||
					((block.id<=id) && (id<block.id+block.duration/1000))
				)
				{
					return block.id;
				}
			}
			//
			{
				_tempDateObj = TimeTranslater.getHourMinObj(id-id%60);
				
				if(!_blockList[_tempDateObj.hour] 
					|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
					||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
					return -1;
				}
				
				for(var _element:* in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
				{
					block=_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][_element];
					
					if(((block.id<=id)  && (id<block.nextID)) ||
						((block.id<=id) && (id<block.id+block.duration/1000))
					){
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
			
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][id]
			)
			{
				return null;
			}
			return _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][id];
		}
		
		public function getHead(id:Number):Head
		{
			return _headerList[id];
		}
		
		/**查找该分钟，如果该分钟的一个元素存在，该元素向前和向后都能超过本分钟，则该分钟不用请求*/
		public function hasMin(id:Number):Boolean
		{
			var block:Block;
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			var seq1:Number = Number.MAX_VALUE;
			if( _blockList[_tempDateObj.hour] 
				&& _blockList[_tempDateObj.hour][_tempDateObj.min+1] )
			{	
				for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min+1]["blocks"])
				{
					
					if (block.sequence < seq1)
					{
						seq1 = block.sequence;
						//tmpBlock = block;
					}
				}
				//
			}
			//
			//_tempDateObj = TimeTranslater.getHourMinObj(id-60);
			var seq2:Number = Number.MIN_VALUE;
			if( _blockList[_tempDateObj.hour] 
				&& _blockList[_tempDateObj.hour][_tempDateObj.min] )
			{	
				for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
				{
					
					if (block.sequence > seq2)
					{
						seq2 = block.sequence;
						//tmpBlock = block;
					}
				}
				//
			}
			//
			
			if (seq2 == Number.MIN_VALUE)
				return false;
			if (seq1 == Number.MAX_VALUE)
				return true;
			//
			if (seq2+1 == seq1)
				return true;
			return false;
		}
		/**设置上一分钟饱和*/
		public function setLastClipFull(time:Number):void
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(time);
			if(_blockList[_tempDateObj.hour]&& _blockList[_tempDateObj.hour][_tempDateObj.min])
			{
				if(_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"]){return;}
				_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"]=true;
			}
		}
		
		/**获的衔接的前一个块，没有数据或不衔接返回0,datamange在连接nextid调用*/
		public function getLastBlock(id:Number):Number{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			var _min:Block;
			var _max:Block;
			var _isFirst:Boolean=true;
			var block:Block;
			//查找当前的分钟
			if(_blockList[_tempDateObj.hour] 
				&& _blockList[_tempDateObj.hour][_tempDateObj.min] )
			{
				for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"])
				{
					if(block.id<id)
					{
						if(_isFirst)
						{
							_isFirst=false;
							_max=_min=block;
							continue;
						}else
						{
							if(block.id>=_max.id)
							{
								_max=block;
							}
						}
					}else
					{
						continue;
					}
				}
				if(_max&&_max.id<id&&id<_max.id+(_max.duration/1000)+6){
//				if(_max&&_max.id<id&&(Math.abs(_max.id+(_max.duration/1000)-id)<=8)){
					return _max.id;
				}
			}
			_isFirst=true;
			_min=null;
			_max=null;
			//如果当前分钟不存在，查找前一份 
			var _tempDateObj2:Object = TimeTranslater.getHourMinObj(id-60);
			if( _blockList[_tempDateObj2.hour] 
				&& _blockList[_tempDateObj2.hour][_tempDateObj2.min]){
				for each(block in _blockList[_tempDateObj2.hour][_tempDateObj2.min]["blocks"]){
					//向前查找是否有小于该分钟的时间
					if(_isFirst){
						_isFirst=false;
						_max=_min=block;
						continue;
					}else{
						if(block.id>_max.id){
							_max=block;
						}
						if(block.id<_min.id){
							_min=block;
						}
					}
				}
				if(_max&&Math.abs(_max.id+(_max.duration/1000)-id)<=8){
					return _max.id;
				}
			}
			return 0;
		}
		
		/**获得id索引值之后有流的数据列表,暂时传入blockID，将来会使用blockID_pieceID */
		public function getDataAfterPoint(id:String):Array
		{
			var arr:Array = new Array();
			var LoadTime:Number = Number(id);//id.split("_")[0];
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
					if(tmpTime<LIVE_TIME.GetLiveTime()){
						continue;
					}
					break;
					//return null;
				}
				if(lastBlockId!=tmpTime)
				{
					var lastBlock:Block =this.getBlock(tmpTime);
					if(lastBlock&&lastBlock.isChecked)
					{
						arr.push(lastBlock.id);
						//return lastBlock;	
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
		public function getWantPiece(remoteHaveData:Array,farID:String,wantCount:int=3):Array
		{
			var arr:Array = new Array;
			for(var j:int=0 ; j<remoteHaveData.length ; j++)
			{
				var blID:Number = Number(remoteHaveData[j]);
				var lastBlock:Block =this.getBlock(blID);
				if(lastBlock&&lastBlock.isChecked == false)
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
							if (pies.iLoadType != 1 && pies.iLoadType != 3 && pies.peerID == "")
							{
								pies.begin     = getTime();
								pies.peerID    = farID;
								pies.from      = "p2p";
								pies.iLoadType = 2;
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
						//
						if (arr.length > 3)
						{
							return arr;
						}
					}
				}
			}
			//
			return arr;
		}		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void//clear:Boolean=false):void
		{
			var time:Number=(new Date()).time;
			var block:Block = this.getBlock(blockID);
			if(!block.isChecked)
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
			
			/*var time:Number=(new Date()).time;
			for each(var hour:Object in _blockList)
			{
				for each(var min:Object in hour)
				{
					for each(var block:Block in min["blocks"])
					{
						if(!block.isChecked)
						{
							for(var i:int=0 ; i<block.pieces.length ; i++)
							{
								if(block.pieces[i].stream == null && block.pieces[i].peerID == farID)
								{
									block.pieces[i].reset();
								}
							}
						}
					}
				}
			}*/
		}
		
		/**按照分钟淘汰任务*/
		private function realEliminateTask(hour:String,min:String,isClear:Boolean=false):Boolean
		{
			var SumPiece:Number = this._count;
			if(Number(hour)*60*60+Number(min)*60>LIVE_TIME.GetLiveTime())
			{
				return true;
			}
			if(_blockList&&
				_blockList[hour]&&
				_blockList[hour][min])
			{
				var blocks:Object = _blockList[hour][min]["blocks"];
				var block:Block;
				for(var n:String in blocks)
				{
					block = blocks[n] as Block;
					if(isClear)
					{//淘汰任务
						block.clear();	
						block = null;
						delete blocks[n];
						delete _blockList[hour][min];
					}else
					{//淘汰流
						block.reset();
					}
				}
			}
			//
			if (SumPiece - this._count >= 1)
				return true;
			//
			
			return false;
			//
		}
		
		/**获得某一分钟段的blocks*/
		public function getMinuteBlocks(id:Number):Object
		{
			var obj:Object = TimeTranslater.getHourMinObj(id);
			if( _blockList
				&& _blockList[obj.hour]
				&& _blockList[obj.hour][obj.min]
				&& _blockList[obj.hour][obj.min]["blocks"]
			)
			{
				return _blockList[obj.hour][obj.min]["blocks"];
			}
			return null;
		}
		
		/**获得最小的小时和分钟*/
		public function getMiniHourMin():Object{
			var miniHour:Number=Number.MAX_VALUE;
			var miniMin:Number=int.MAX_VALUE;
			var obj:Object = new Object();
			for(var hourData:String in _blockList){
				if(Number(hourData)<miniHour){
					miniHour=Number(hourData)
				}
			}
			
			if(miniHour!=Number.MAX_VALUE){
				for(var miniData:String in _blockList[String(miniHour)]){
					if(Number(miniData)<miniMin){
						miniMin=Number(miniData)
					}
				}				
				if(miniMin!=int.MAX_VALUE){
					obj.hour =miniHour;
					obj.min  = miniMin;
					return obj;
				}
			}
			return null;
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
		private function minHasData(hour:Number,min:Number):Boolean{
			var bool:Boolean=false;
			if( _blockList
				&& _blockList[hour]
				&& _blockList[hour][min]
				&& _blockList[hour][min]["blocks"]
			)
			{
				for each (var block:Block in _blockList[hour][min]["blocks"]){
					if(block.isChecked){
						return true;
					}
				}
			}
			return bool;
		}
		public function eliminate():void
		{
			/**判断是否饱和，如果饱和开始淘汰，不饱和不做淘汰*/
			if(_count>=LiveVodConfig.MEMORY_SIZE/LiveVodConfig.CLIP_INTERVAL||_isEliminate)
			{
				_isEliminate=false;
				var _miniObj:Object=getMiniHourMin();
				if(!_miniObj)return;
				P2PDebug.traceMsg(this,"淘汰前:",_toString());
				if (LIVE_TIME.GetBaseTime() < (_miniObj.hour*60*60 + _miniObj.min * 60))
				{//right
					var tm:Number = LIVE_TIME.GetBaseTime();
					var tmpTm:Object = TimeTranslater.getHourMinObj(tm+60*40);
					while(!realEliminateTask(String(tmpTm.hour),String(tmpTm.min),false))
					{
						tm += 60;
						tmpTm = TimeTranslater.getHourMinObj(tm+60*40);
					}
				}else//left
				{
					var miniTm:Number = _miniObj.hour * 60 *60 + _miniObj.min * 60;
					var Tm:Object = TimeTranslater.getHourMinObj(miniTm);
					while(!realEliminateTask(String(Tm.hour),String(Tm.min),true))
					{
						miniTm += 60;
						Tm = TimeTranslater.getHourMinObj(miniTm);
					}
					
				}
				P2PDebug.traceMsg(this,"淘汰后:",_toString());
				//
				return;
			}
		}
		
		public function clear():void
		{
			init();
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