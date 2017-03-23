package com.p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * BlockList用来存放数据结构
	 */	
	
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.DataRange;
	import com.p2p.data.vo.LOAD_TYPE;
	import com.p2p.data.vo.Piece;
	import com.p2p.events.EventExtensions;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
//	import flash.external.ExternalInterface;
	import flash.utils.ByteArray;
	/**
	 * <ul>构造函数:_blockList _headerList streamRangeList</ul>
	 * <ul>_blockList增,删,handlerTimeOutWantPiece</ul>
	 * <ul>_headerList增,删(暂时不做) </ul>
	 * <ul>streamRangeList增,删,getNearestWantID,getDataAfterPoint,getWantPiece</ul>
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
		 * streamRangeList[{dataRange.start:dataRange},{dataRange.start:dataRange}...]
		 */
		
		/**总列表*/
		private var _blockList:Object;
		/**保存头数据流的列表*/
		private var _headerList:Object;
		/**保存有数据流的离散列表*/
		public var streamRangeList:RangeList;
		
		/**保存需要加载数据的列散列表
		public var needDataList:RangeList;*/
		
		private var _playHead:Number = 0;
		
		/**播放头位置，当消费数据流设置该值*/
		public function set playHead(id:Number):void
		{
			_playHead = id;
			streamRangeList.playHead = id;
		}
		public function get playHead():Number
		{
			return _playHead;
		}
		/**构造*/
		public function BlockList()
		{
//			jsDebug();
			init();
		}
		
//		private function jsDebug():void{			
//			ExternalInterface.addCallback("traceBlockList",traceBlockList);
//		}
//		public function traceBlockList():String{
//			P2PDebug.traceMsg(this,"blockList:",_toString());
//			ExternalInterface.call("trace",_toString());
//			return _toString();
//		}
		private function init():void
		{
			_blockList  = new Object();
			_headerList = new Object();
			streamRangeList = new RangeList(this);
		}
		private function delVacancyMin():void{
			if(_playHead==0){return;}
			var _playDateObj:Object = TimeTranslater.getHourMinObj(_playHead);
			var miniData:String
			for(var hourData:String in _blockList){
				if(Number(hourData)<Number(_playDateObj.hour)){
					for(miniData in _blockList[hourData]){
						if(_blockList[hourData][miniData].hasOwnProperty("isDestroy")){
							P2PDebug.traceMsg(this,hourData+":"+miniData+"delete");
							delete _blockList[hourData][miniData]["isDestroy"];
						}
					}
				}else if(Number(hourData)==Number(_playDateObj.hour)){
					for(miniData in _blockList[hourData]){
						if(Number(miniData)<Number(_playDateObj.min)){
							if(_blockList[hourData][miniData].hasOwnProperty("isDestroy")){
								P2PDebug.traceMsg(this,hourData+":"+miniData+"delete");
								delete _blockList[hourData][miniData]["isDestroy"];
							}
						}
					}
				}
			}
		}
		/**查早之前的分钟是否空缺，如果有空缺填补空缺分钟为坏记录，方便播放和下载做判断*/
		private function addVacancyMin(time:Number):void{
			if(_playHead==0){return;}
			if(time==0){return;}
			var _playDateObj:Object = TimeTranslater.getHourMinObj(_playHead);
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(time);
			while(_tempDateObj.hour>=_playDateObj.hour){
				_tempDateObj.min-=1;
				if(_tempDateObj.min==-1){
					_tempDateObj.hour-=1;
					_tempDateObj.min=59;
				}
				if(_tempDateObj.hour==_playDateObj.hour){
					if(_tempDateObj.min<=_playDateObj.min){
						break;
					}
				}
				if(!_blockList[_tempDateObj.hour]){
					_blockList[_tempDateObj.hour] = new Object();
				}
				if( !_blockList[_tempDateObj.hour][_tempDateObj.min]){
					_blockList[_tempDateObj.hour][_tempDateObj.min] = new Object();
					P2PDebug.traceMsg(this,_tempDateObj.hour+":"+_tempDateObj.min+"isDestroy");
					_blockList[_tempDateObj.hour][_tempDateObj.min]["isDestroy"] = true;
				}
			}
		}
		
		private var _lastAddBlockHour:Number=0;
		private var	_lastAddBlockMin:Number=0;
		/**
		 * 请求desc后处理，每次添加块时，会依具Clip的时间戳timestamp按小时分钟添加到对应的列表中，
		 * @param block 添加块
		 * 需要返回是否成功添加
		 * 先检查创建好，然后添加
		 */
		public function addBlock(clip:Clip,loadType:String):Boolean
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(clip.timestamp);	
			
			if(!_blockList[_tempDateObj.hour]){
				_blockList[_tempDateObj.hour] = new Object();
			}
			
			if( !_blockList[_tempDateObj.hour][_tempDateObj.min]){
				//在创建新的分钟之前查早之前的分钟是否空缺，有空缺时播放和下载无法做判断，所以补缺空
				_blockList[_tempDateObj.hour][_tempDateObj.min] = new Object();
			}
			if(_lastAddBlockHour!=_tempDateObj.hour||_lastAddBlockMin!=_tempDateObj.min){
				_lastAddBlockHour=_tempDateObj.hour;
				_lastAddBlockMin=_tempDateObj.min;
				delVacancyMin();
				addVacancyMin(clip.timestamp);
			}
			if(_blockList[_tempDateObj.hour][_tempDateObj.min].hasOwnProperty("isDestroy")){
				P2PDebug.traceMsg(this,_tempDateObj.hour+":"+_tempDateObj.min+"delete");
				delete _blockList[_tempDateObj.hour][_tempDateObj.min]["isDestroy"];
			}
			if(loadType==LOAD_TYPE.LIVESHIFT){//时移加载，每分钟都是饱和，不用判断饱和度
				_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"] = true;					
			}else{
				_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"] = false;
			}
			
			if( !_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
				_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"] = new Object();
			}
			
			if(_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][clip.timestamp])
			{
				if(clip.nextID!=0){
					_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][clip.timestamp].nextID=clip.nextID;
				}
				if(clip.preID!=0){
					_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][clip.timestamp].preID=clip.preID;
				}
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
		/**获得blockid，给定一个block所包含的时间段中任何时间戳将返回该block的id即该块的起始时间戳，没有对应值返回-1*/
		public function getBlockId(id:Number):Number
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			
			if(!_blockList[_tempDateObj.hour] 
				|| !_blockList[_tempDateObj.hour][_tempDateObj.min]
				||!_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
				return -1;
			}
			var block:Block;
			var min:Number=Number.MAX_VALUE;
			for(var element:* in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
				block=_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"][element];
				//如果大于block的id同时小于下一个block的id
				//如果大于block id同时下一个id为0，并且与block.id相差小于物理片长认为是该block
				if(min>block.id){
					min=block.id;
				}
				if((block.id<=id&&id<block.nextID)||
					(block.id<=id&&block.nextID==0&&id-block.id<=block.duration)
				){
					return block.id;
				}
			}
			if(min==Number.MAX_VALUE){
				return min;
			}else{
				return -1;
			}
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
		
		/**获得播放点之后最近的需要加载数据的索引"block_Piece"*/
		public function getNearestWantID():String
		{
			return streamRangeList.getNearestWantID();
		}
		
		/**查找该分钟，如果该分钟的一个元素存在，该元素向前和向后都能超过本分钟，则该分钟不用请求*/
		public function hasMin(id:Number):Boolean
		{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			
			if( _blockList[_tempDateObj.hour] 
				&& _blockList[_tempDateObj.hour][_tempDateObj.min] )
			{		
				if(_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"])
				{
					//Debug.traceMsg(this,id+"->分钟:"+_tempDateObj.min+"加载过");
					//分钟和分钟连接
					try{
						//前一分钟是否存在
						if(getMaxMinBlock(id-60)!=-1){
							getBlock(getMaxMinBlock(id-60)).nextID=getMiniMinBlock(id);
						}
					}catch(err:Error){}
					return true;
				}
			}
			return false;
		}
		/**设置上一分钟饱和*/
		public function setLastClipFull(time:Number):void{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(time);
			_tempDateObj.min-=1;
			if(_tempDateObj.min==-1){
				_tempDateObj.hour-=1;
				_tempDateObj.min=59;
			}
			
			if(_blockList[_tempDateObj.hour]&& _blockList[_tempDateObj.hour][_tempDateObj.min]){
				if(_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"]){return;}
				_blockList[_tempDateObj.hour][_tempDateObj.min]["isTaskFull"]=true;
			}
		}
		
		/**从小到大获得最接近参数id的block,id: block id; isHaveData：查找是否有数据的block*/		
		public function getNextNearBlock(id:Number,isHaveData:Boolean=false):Block{
			//Debug.traceMsg(this,"getNextNearBlock0:"+id);
			if(id==0){return null;}
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			var startObj:Object = TimeTranslater.getHourMinObj(id);
			var badMin:Array=new Array;
			
			while(_blockList[_tempDateObj.hour]&&_blockList[_tempDateObj.hour][_tempDateObj.min]){
				if(_blockList[_tempDateObj.hour][_tempDateObj.min].hasOwnProperty("isDestroy")&&_blockList[_tempDateObj.hour][_tempDateObj.min]["isDestroy"]){
					//记录有坏数据的索引
					badMin.push({"h":_tempDateObj.hour,"m":_tempDateObj.min});
				}else if(_blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
					var block:Block;
					var _min:Block;
					var _isFirst:Boolean=true;
					for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
						if(block.isDestroy){continue;}
						if(startObj.hour==_tempDateObj.hour&& startObj.min==_tempDateObj.min)//查找同一分钟的block
						{
							if(isHaveData){
								if(!block.isChecked){continue;}//如果是查数据，如果数据没有核查过（即没有流），将不再进行计算
							}
							if(block.id>id){
								if(_isFirst){
									_isFirst=false;
									_min=block;
									continue;
								}else{
									if(block.id<_min.id){
										_min=block;
									}
								}
							}
						}else{//查找不是同一分钟的block
							if(isHaveData){
								if(!block.isChecked){continue;}//如果是查数据，如果数据没有核查过，将不再进行计算
							}
							if(_isFirst){
								_isFirst=false;
								_min=block;
								continue;
							}else{
								if(block.id<_min.id){
									_min=block;
								}
							}
						}
					}
					if(_min){
						for(var i:int=0;i<badMin.length;i++){
							P2PDebug.traceMsg(this,badMin[i]["h"]+":"+badMin[i]["m"]+"delete");
							delete _blockList[badMin[i]["h"]][badMin[i]["m"]]["isDestroy"];
						}
						//Debug.traceMsg(this,"getNextNearBlock1:"+_min.id);
						return _min;
					}
				}else{//本分钟的blocks不存在
					return null;
				}
				_tempDateObj.min+=1;
				if(_tempDateObj.min==60){
					_tempDateObj.hour+=1;
					_tempDateObj.min=0;
				}
			}
			return null;
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
				for each(block in _blockList[_tempDateObj.hour][_tempDateObj.min]["blocks"]){
					if(block.id<id){
						if(_isFirst){
							_isFirst=false;
							_max=_min=block;
							continue;
						}else{
							if(block.id>=_max.id){
								_max=block;
							}
						}
					}else{
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
			return streamRangeList.getRangeAfterPoint(id);
		}
		
		/**
		 * 当对方节点收到本地下载数据的进度而返回的对方拥有的数据离散表remoteHaveData:Array，
		 * 该数组已经按照由左到右顺序排好，每一个元素代表一个离散区间DataRange对象,
		 * getWantPiece方法遍历区间段所包含的piece，找到本地所需的wantCount数量的piece
		 **/
		public function getWantPiece(remoteHaveData:Array,farID:String,wantCount:int=3):Array
		{
			var dataRange:Object;
			var tempWantCount:int=0;
			var tempArray:Array; 
			var startBlockID:Number;
			var startPieceID:int;
			var endBlockID:Number;
			var endPieceID:int;
			var tempHour:Number;
			var tempMinute:Number;
			var _tempDateObj:Object;
			for(var i:int=0 ; i<remoteHaveData.length ; i++)
			{
				dataRange = remoteHaveData[i];
				
				/**分别表示dataRange区域块的边界block索引和piece索引*/
				startBlockID = dataRange.startBlockID;
				startPieceID = dataRange.startPieceID;
				endBlockID = dataRange.endBlockID;
				endPieceID = dataRange.endPieceID;
				
				_tempDateObj = TimeTranslater.getHourMinObj(startBlockID);
				
				tempHour   = _tempDateObj.hour;
				tempMinute = _tempDateObj.min;
				
				
				while((tempHour*60*60+tempMinute*60 <= _playHead+LiveVodConfig.DESC_TIME)
					&&(tempHour*60*60+tempMinute*60<=endBlockID))
				{
					if(!_blockList[tempHour])
					{
						tempHour+=1;
						continue;
					}
					if(!_blockList[tempHour][tempMinute]||!_blockList[tempHour][tempMinute]["blocks"])
					{
						tempMinute+=1;
						if(tempMinute==60)
						{
							tempMinute=0;
							tempHour+=1;
						}
						continue;
					}
					if(_blockList[tempHour][tempMinute]["blocks"])
					{
						for each(var tempBlock:Block in _blockList[tempHour][tempMinute]["blocks"])
						{
							/**判断tempBlockID所代表的block是否已经填满数据，如果已经填满则跳过本次循环
							 * 或tempBlock小于startBlockID也将跳出本次循环
							 * 保证tempBlock在紧急区之外
							 * */
							if(tempBlock.id<=_playHead 
								|| tempBlock.isChecked 
								|| tempBlock.id<startBlockID 
								|| tempBlock.id>endBlockID
							)
							{															
								continue;
							}
							
							/**当存在piece,且stream为空,而且未分配给Http下载时*/
							for(var j:int=0 ; j<tempBlock.pieces.length ; j++)
							{
								if(tempBlock.id==startBlockID&&j< startPieceID){continue;}
								if(tempBlock.id==endBlockID&&j> endPieceID){continue;}								
								
								if( tempBlock.pieces[j] //存在piece
									&& tempBlock.pieces[j].stream == null //stream为空
									&& tempBlock.pieces[j].iLoadType != 1	//未分配给Http下载						 
								)
								{
									if( tempBlock.pieces[j].peerID == "" //当该piece未分配给其他节点
										|| (tempBlock.pieces[j].peerID != ""             //当该piece已经分配了P2P任务
											&& (getTime()-tempBlock.pieces[j].begin)/1000>=10 //当等待时间超过10秒时
											//&& tempBlock.pieces[j].peerID != farID           当该P2P任务未分配给farID时								
										))
									{
										tempBlock.pieces[j].begin     = getTime();
										tempBlock.pieces[j].peerID    = farID;
										tempBlock.pieces[j].from      = "p2p";
										tempBlock.pieces[j].iLoadType = 2;
										
										/**
										 * 返回的数据结构为:
										 * wantDataObj:Object
										 * wantDataObj.blockID
										 * wantDataObj.pieceID
										 * */
										var wantDataObj:Object = new Object();
										wantDataObj.blockID = tempBlock.id;
										wantDataObj.pieceID = j;
										if(!tempArray)
										{
											tempArray = new Array();
										}
										tempArray.push(wantDataObj);
										
										/**计数器累加*/
										tempWantCount++;
										
										/**当找到wantCount数量的piece时跳出所有循环，返回tempArray*/
										if(tempWantCount == wantCount)
										{								
											return tempArray;
										}
									}
									else if(tempBlock.pieces[j].peerID != "" 
										     && (getTime()-tempBlock.pieces[j].begin)/1000<10
											 && tempBlock.pieces[j].peerID == farID)
									{
										/**计数器累加*/
										tempWantCount++;
										
										/**当找到wantCount数量的piece时跳出所有循环，返回tempArray*/
										if(tempWantCount == wantCount)
										{								
											return tempArray;
										}
									}
								}
							}							
						}						
					}
					tempMinute+=1;
					if(tempMinute==60)
					{
						tempMinute=0;
						tempHour+=1;
					}
				}
			}
			return tempArray;
		}		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		public function handlerTimeOutWantPiece(farID:String,clear:Boolean=false):void
		{
			var time:Number=(new Date()).time;
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
			}
		}
		
		/**按照分钟淘汰任务（或分配空间） */
		public function eliminateTaskMinite(id:Number):void{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			realEliminateTask(String(_tempDateObj.hour),String(_tempDateObj.min),true);
		}
		/**按照分钟淘汰流（或分配的数据）*/
		public function eliminateStreamMinite(id:Number):void{
			var _tempDateObj:Object = TimeTranslater.getHourMinObj(id);
			realEliminateTask(""+_tempDateObj.hour,""+_tempDateObj.min);
		}
		/**按照分钟淘汰任务*/
		private function realEliminateTask(hour:String,min:String,isTask:Boolean=false):Array
		{
//			Debug.traceMsg(this,"淘汰"+hour,min,isTask);
//			Debug.traceMsg(this,"淘汰前",_toString());
			if(_blockList&&
				_blockList[hour]&&
				_blockList[hour][min]){
				var blocks:Object = _blockList[hour][min]["blocks"];
				var block:Block;
				for(var n:String in blocks)
				{
					block = blocks[n] as Block;
					if(isTask){//淘汰任务
						block.clear();	
						block = null;
						delete blocks[n];
					}else{//淘汰流
						block.reset();
					}
				}
			}
			if(isTask){
				//淘汰早于该分钟的任务
				for(var hourData:String in _blockList){
					if(Number(hourData)<Number(hour)){
						_blockList[hourData]=null;
						delete _blockList[hourData];
						continue;
					}
					if(Number(hourData)==Number(hour)){
						for(var minData:String in _blockList[hourData]){
							if(Number(minData)<Number(min)){
								_blockList[hour][minData]=null;
								delete _blockList[hour][minData];
								continue;
							}
						}
					}
				}
				//淘汰该一分钟任务
				_blockList[hour][min] = null;
				delete _blockList[hour][min];
				var hasMin:Boolean=false;
				for(var element:String in _blockList[hour]){
					if( _blockList[hour][element]){
						hasMin=true;
						break;
					}
				}
				if(!hasMin){
					_blockList[hour]=null;
					delete _blockList[hour];
				}
			}
//			Debug.traceMsg(this,"淘汰后",_toString());
			return null;
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
		/**获得一分钟的最小的block*/
		public function getMiniMinBlock(id:Number):Number{
			var miniBlockID:Number=int.MAX_VALUE;
			var minuteBlock:Object;
			var block:Block;
			minuteBlock=getMinuteBlocks(id);
			for each(block in minuteBlock)
			{
				if(block.id<miniBlockID){
					miniBlockID=block.id;
				}
			}
			if(miniBlockID==int.MAX_VALUE){
				return -1;
			}else{
				return miniBlockID;
			}
		}
		/**获得一分钟的最大的block*/
		public function getMaxMinBlock(id:Number):Number{
			var maxBlockID:Number=0;
			var minuteBlock:Object;
			var block:Block;
			minuteBlock=getMinuteBlocks(id);
			for each(block in minuteBlock)
			{
				if(block.id>maxBlockID){
					maxBlockID=block.id;
				}
			}
			if(maxBlockID==0){
				return -1;
			}else{
				return maxBlockID;
			}
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
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
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
						if(block.isFull){
							str+=block.id+" nID:"+block.nextID+" pID:"+block.preID+"\n";
						}else{
							str+=block._toString()+"\n";
						}
					}
//					str+="}"
				}
			}
			//_headerList
			return str+"\n";
		}
	}
}