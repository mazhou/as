package com.p2p.data
{
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.DataRange;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;

	/**
	 *　对有流的离散列表维护，内存中存放的流早晚相差Config.DAT_TIME(40分钟)
	 * @author mazhoun
	 */
	public class RangeList
	{
		public var isDebug:Boolean = false;
		/**有流的离散列表*/
		private var _rangeList:Object = new Object();
		/**对blocklist的引用*/
		private var _blockList:BlockList;
		/**有流的piece总数*/
		private var _count:Number = 0;
		/**播放头*/
		private var _playHead:Number = 0;
		
		public function RangeList(blockList:BlockList)
		{
			_blockList = blockList;
		}
		
		public function set playHead(id:Number):void
		{
			_playHead = id;
		}
		
		/**每添加一个piece，创建DataRange类型对象，并添加该对象，维护一个range表*/
		public function addDataRange(dataRange:DataRange):void
		{
			if(_rangeList[dataRange.startBlockID+"_"+dataRange.startPieceID])
			{
				return;
			}
			if(!_blockList.getBlock(dataRange.startBlockID)){
				return;
			}
//			Debug.traceMsg(this,"s:"+dataRange.startBlockID+"_"+dataRange.startPieceID,
//				"e:"+dataRange.endBlockID+"_"+dataRange.endPieceID,
//				"n:"+dataRange.nextConnectBlockID+"_"+dataRange.nextConnectPieceID);
			_rangeList[dataRange.startBlockID+"_"+dataRange.startPieceID] = dataRange;
			//在block中已经做了判断，不会添加重复的dataRange
			_count++;
			if(_count>650){
				P2PDebug.traceMsg(this,"_count = "+_count);
			}
			var blockID:Number;
			var block:Block;
			var pieceID:int 
			var nextConnectID:String;
			//Debug.traceMsg(this,"合并前:",_toString());
			for each(var tempDataRange:DataRange in _rangeList)
			{
				if(tempDataRange.nextConnectBlockID == 0&&tempDataRange.nextConnectPieceID==0)
				{
					/**说明该DataRange块的最后一个piece没有后续连接的block.piece,
					 * 可能该piece为直播点的最后一个piece
					 * 需要等待下一个block的出现，所以应该再次计算，以便等待最新的block出现*/
					
					blockID= tempDataRange.endBlockID;
					block= _blockList.getBlock(blockID);
					
					pieceID=tempDataRange.endPieceID;
					
					if(block&&pieceID == block.pieces.length-1 && block.nextID != 0)
					{
						tempDataRange.nextConnectBlockID=block.nextID;
						tempDataRange.nextConnectPieceID=0;
					}
				}
				var connectID:String = tempDataRange.nextConnectBlockID+"_"+tempDataRange.nextConnectPieceID;
				var connectID2:String ="";
				if(_rangeList[connectID] )
				{
					tempDataRange.endBlockID           = _rangeList[connectID].endBlockID;
					tempDataRange.endPieceID           = _rangeList[connectID].endPieceID;
					
					tempDataRange.nextConnectBlockID           = _rangeList[connectID].nextConnectBlockID;
					tempDataRange.nextConnectPieceID           = _rangeList[connectID].nextConnectPieceID;
					
					connectID2 =tempDataRange.nextConnectBlockID+"_"+tempDataRange.nextConnectPieceID;
					_rangeList[connectID]=null;
					delete _rangeList[connectID];
					//当添加的数据是{123:(2,2)},原有基础是{123:(1,1)}，{123:(1,3)}，要连续淘汰
					if(_rangeList[connectID2])
					{
						tempDataRange.endBlockID           = _rangeList[connectID2].endBlockID;
						tempDataRange.endPieceID           = _rangeList[connectID2].endPieceID;
						tempDataRange.nextConnectBlockID = _rangeList[connectID2].nextConnectBlockID;
						tempDataRange.nextConnectPieceID = _rangeList[connectID2].nextConnectPieceID;
						_rangeList[connectID2] = null;
						delete _rangeList[connectID2];
					}
				}
			}
			//Debug.traceMsg(this,"合并后:",_toString());
			eliminate();			
		}
		/**按照block删除，idx是block的id值*/
		public function deleteBlockRange(idx:Number):Boolean
		{
			var blockID:Number ;
			var block:Block= _blockList.getBlock(idx);
			var startBlockID:Number;
			var endBlockID:Number;
			for each(var tempDataRange:DataRange in _rangeList)
			{
				startBlockID=tempDataRange.startBlockID;
				endBlockID=tempDataRange.endBlockID;
				
				if( startBlockID==idx
					&& startBlockID==endBlockID)
				{
//					Debug.traceMsg(this,"dlt:"+Debug.getTime(tempDataRange.startBlockID)+" "+
//						tempDataRange.startBlockID+"_"+tempDataRange.startPieceID);
					/**同属一个block*/
					delete _rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID];
					return true;
				}
				else if(startBlockID==idx)
				{
					/**Range左边界同属一个block*/
					_rangeList[block.nextID+"_0"]=new DataRange;
					_rangeList[block.nextID+"_0"].startBlockID=block.nextID;
					_rangeList[block.nextID+"_0"].startPieceID=0;
					
					_rangeList[block.nextID+"_0"].endBlockID=tempDataRange.endBlockID;
					_rangeList[block.nextID+"_0"].endPieceID=tempDataRange.endPieceID;
					
					_rangeList[block.nextID+"_0"].nextConnectBlockID=tempDataRange.nextConnectBlockID;
					_rangeList[block.nextID+"_0"].nextConnectPieceID=tempDataRange.nextConnectPieceID;
//					Debug.traceMsg(this,"beg:"+Debug.getTime(_rangeList[block.nextID+"_0"].startBlockID)+" "+
//						_rangeList[block.nextID+"_0"].startBlockID+"_"+_rangeList[block.nextID+"_0"].startPieceID,
//						"dlt:"+
//						tempDataRange.startBlockID+"_"+tempDataRange.startPieceID
//					);
					delete _rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID];
					return true;
				}
				else if(endBlockID==idx)
				{
					/**Range右边界同属一个block*/
					tempDataRange.endBlockID=block.preID
					tempDataRange.endPieceID=(_blockList.getBlock(block.preID).pieces.length-1);
//					Debug.traceMsg(this,"end:"+tempDataRange.endBlockID+"_"+tempDataRange.endPieceID);
					return true;
				}
				else if( idx>startBlockID&&idx<endBlockID)
				{
					/**block在左右边界之间*/
					_rangeList[block.nextID+"_0"]=new DataRange;
					_rangeList[block.nextID+"_0"].startBlockID=block.nextID;
					_rangeList[block.nextID+"_0"].startPieceID=0;
					
					_rangeList[block.nextID+"_0"].endBlockID=_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].endBlockID;
					_rangeList[block.nextID+"_0"].endPieceID=_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].endPieceID;
					
					_rangeList[block.nextID+"_0"].nextConnectBlockID=_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].nextConnectBlockID;
					_rangeList[block.nextID+"_0"].nextConnectPieceID=_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].nextConnectPieceID;
					
					_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].endBlockID = block.preID;
					_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].endPieceID = _blockList.getBlock(block.preID).pieces.length-1;
					_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].nextConnectBlockID=idx;
					_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].nextConnectPieceID=0;
//					Debug.traceMsg(this,"mid:"+
//						_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].endBlockID+
//						"_"+
//						_rangeList[tempDataRange.startBlockID+"_"+tempDataRange.startPieceID].endPieceID+
//						"<>"+
//						Debug.getTime(_rangeList[block.nextID+"_0"].startBlockID)+" "+
//						_rangeList[block.nextID+"_0"].startBlockID+"_0");
					return true;
				}
			}
			return false;
		}
		/**id是block的id值*/
		private function doCount(tempBlock:Block):void
		{
			if(tempBlock)
			{
				for(var i:int=0 ; i<tempBlock.pieces.length ; i++)
				{
					if(tempBlock.pieces[0].stream&&tempBlock.pieces[0].stream.length>0)
					{
						_count--;
						/**输出面板测试*/
						if(i == 0)
						{	
							Statistic.getInstance().removeData(tempBlock.id+"_"+i+"  _count="+_count+""+TimeTranslater.getTime(tempBlock.id));
						}else{
							Statistic.getInstance().removeData(tempBlock.id+"_"+i+"  _count="+_count);
						}
					}
				}
			}
		}
		/**在RangeList中截取blockID_pieceID之后的离散列表，且将该离散列表排序后返回
		 * 暂时用blockID
		 * 
		 * */
		public function getRangeAfterPoint(str:String):Array
		{
			var id:Number = str.split("_")[0];
			var arr:Array = new Array();
			var tempDataRange:Object;
			
			for(var i:String in _rangeList)
			{
				if( Number(i.split("_")[0]) > id )
				{
					/**当该离散片段大于该id索引时*/
					tempDataRange = new Object();
					tempDataRange.startBlockID = (_rangeList[i] as DataRange).startBlockID;
					tempDataRange.startPieceID = (_rangeList[i] as DataRange).startPieceID;
					tempDataRange.endBlockID   = (_rangeList[i] as DataRange).endBlockID;
					tempDataRange.endPieceID   = (_rangeList[i] as DataRange).endPieceID;
					//tempDataRange.next  = (_rangeList[i] as DataRange).nextConnectID;
					//arr.push(tempDataRange);
				}
				else if( Number(i.split("_")[0]) <= id && Number(_rangeList[i].endBlockID) >= id)
				{
					/**当该离散片段包含该id索引时*/
					tempDataRange = new Object();
					if(Number(i.split("_")[0]) < id)
					{
						tempDataRange.startBlockID = Number(str.split("_")[0]);
						tempDataRange.startPieceID = Number(str.split("_")[1]);
					}
					else
					{
						/**不够精确，需要进行性piece判断，返回大的piece,同时考虑end的piece的大小*/
						tempDataRange.startBlockID = Number(i.split("_")[0]);
						tempDataRange.startPieceID = Number(i.split("_")[1]);
					}
					
					tempDataRange.endBlockID = (_rangeList[i] as DataRange).endBlockID;
					tempDataRange.endPieceID = (_rangeList[i] as DataRange).endPieceID;
					//arr.push(tempDataRange);
				}
				/**将arr数组中的元素按照DataRange.start进行从小到大的排序*/
				if(tempDataRange)
				{				
					var tempDataRangeBID:Number = tempDataRange.startBlockID;
					var tempDataRangePID:Number = tempDataRange.startPieceID;
					var isFound:Boolean=false;//为找到比tempDataRangeBID小的
					
					for(var j:int=0 ; j<arr.length ; j++)
					{
						var tempBID:Number = Number(arr[j].startBlockID);
						var tempPID:Number = Number(arr[j].startPieceID);
						
						if( tempDataRangeBID < tempBID //当blockID小于数组元素的blockID时
							|| (tempDataRangeBID == tempBID && tempDataRangePID < tempPID)//当blockID相等，但pieceID小于数组元素的pieceID时
						   )
						{
							arr.splice(j,0,tempDataRange);
							isFound = true;
							break;
						}
					}
					if(arr.length == 0 || !isFound)
					{
						/**当对arr一次填充时*/
						arr.push(tempDataRange);
					}
				}
				tempDataRange = null;
			}
			
			//testGetRangeAfterPoint(arr)
			
			return arr;
		}
		
		
		/**获得播放点之后最近的空数据索引,当找到边界值但未能找到空数据的索引时，则返回该边界值的索引。
		 * 当未找到时，说明 1：直播点之后的block没有数据，即紧急区不满，应停止p2p下载，此时返回0_0
		 * check 了一半，后续check
		 * */
		public function getNearestWantID():String
		{
			var nearestWantID:String = "0_0";
			var startBlockID:Number;
			var endBlockID:Number;
			var endPieceID:Number;
			var tempBlock:Block;
			
			for(var i:String in _rangeList)
			{
				startBlockID = _rangeList[i].startBlockID;
				endBlockID   = _rangeList[i].endBlockID;
				endPieceID   = _rangeList[i].endPieceID;
				
				if( Number(startBlockID) <= _playHead 
					&& Number(endBlockID) > _playHead )
				{
					tempBlock = _blockList.getBlock(endBlockID);
					
					if(tempBlock)
					{
						if( endPieceID < tempBlock.pieces.length-1)
						{
							/**当边界值的piece不是所在Block.pieces的最后一个元素时*/
							nearestWantID = endBlockID+"_"+(endPieceID+1);							 
						}
						else
						{
							if(tempBlock.nextID != 0)
							{
								/**当边界值的piece是tempBlock.pieces的最后一个元素，且可以找到下一个block时，取下一块block的第一个piece*/
								nearestWantID = tempBlock.nextID+"_"+0;
							}
							else
							{
								/**当边界值的piece是tempBlock.pieces的最后一个元素，但找不到下一个block时，则取边界值返回*/
								nearestWantID = _rangeList[i].endBlockID+"_"+_rangeList[i].endPieceID;
							}
						}
						break;
					}
				}
			}
			/**当未找到时，说明直播点之后的block没有数据，即紧急区不满，应停止p2p下载，此时返回0_0*/
			
			return nearestWantID;
		}
		
		/**获得较早数据的边界*/
		public function getForwardConfine():Number
		{
			return getConfine()["forwardBorder"];
		}
		/**获得较晚数据的边界*/
		public function getForbackConfine():Number
		{
			return getConfine()["forbackBorder"];
		}
		/**获得边界*/
		private function getConfine():Object
		{
			var forwardBorder:Number=Number.MAX_VALUE;
			var forbackBorder:Number=0;
			for(var i:String in _rangeList)
			{
				if(forwardBorder>Number(i.split("_")[0])){
					forwardBorder=Number(i.split("_")[0]);
				}
				if(forbackBorder<_rangeList[i].endBlockID){
					forbackBorder=_rangeList[i].endBlockID;
				}
			}
			return {"forwardBorder":forwardBorder,"forbackBorder":forbackBorder}
		}
		/**淘汰最早方向最远的数据*/
		private function eliminateForward(border:Object):void
		{
			eliminateRangelist(border["forwardBorder"]);
			//同时border["forwardBorder"]点向最早方向的desc统统淘汰
			_blockList.eliminateTaskMinite(border["forwardBorder"]);
		}
		/**淘汰最晚方向最远的数据*/
		private function eliminateForback(border:Object):void
		{
			eliminateRangelist(border["forbackBorder"]);
			_blockList.eliminateStreamMinite(border["forbackBorder"]);
		}
		
		private function eliminateRangelist(blockID:Number):void{
			var minuteBlock:Object;
			var block:Block;
			minuteBlock=_blockList.getMinuteBlocks(blockID);
			for each(block in minuteBlock)
			{
				doCount(block);
				deleteBlockRange(block.id);
			}
		}
		
		/**
		 * 淘汰算法，判断是否饱和，如果饱和开始淘汰，不饱和不做淘汰
		 * 先淘汰播放点最早（时间戳最小）的数据直到淘汰到播放点同时淘汰desc，然后淘汰播放点最晚（时间戳最大）的数据
		 * 每淘汰一次淘汰一分钟
		 */
		private function eliminate():void
		{
			/**判断是否饱和，如果饱和开始淘汰，不饱和不做淘汰*/
			if(_count>=LiveVodConfig.MEMORY_SIZE/LiveVodConfig.CLIP_INTERVAL)
			{
				P2PDebug.traceMsg(this,"_count = "+_count);
				P2PDebug.traceMsg(this,"_playHead = "+_playHead+" "+TimeTranslater.getTime(_playHead));
				P2PDebug.traceMsg(this,"淘汰前:",_toString());
				
				//找到边界值
				var border:Object=getConfine();
				var minuteBlock:Object
				var block:Block
				//判断边界值和播放头的关系
				//最早边界小于播放头，淘汰最早边界所在的一分钟同时这一分钟最早的淘汰desc
				//播放头同在一分钟
				
				var playHeadHourMin:Object=TimeTranslater.getHourMinObj(_playHead);
				var forwardHourMin:Object=TimeTranslater.getHourMinObj(border["forwardBorder"]);
				//判断播放点小时 是否小于最早流所在的小时
				if(playHeadHourMin.hour<forwardHourMin.hour)
				{//播放点所在的小时小于最早流所在的小时
					P2PDebug.traceMsg(this,"eliminateForback0:"+border["forwardBorder"],TimeTranslater.getTime(border["forwardBorder"]));
					eliminateForback(border);//淘汰最晚方向的一分钟
				}
				else if(playHeadHourMin.hour==forwardHourMin.hour)
				{//播放点小时 等于最早流所在的小时的情况
					
					if(playHeadHourMin.min<=forwardHourMin.min){//播放点所在的分钟小于最早流所在的分钟
						P2PDebug.traceMsg(this,"eliminateForback0:"+border["forbackBorder"],TimeTranslater.getTime(border["forbackBorder"]));
						eliminateForback(border);//淘汰最晚方向的一分钟
					}
					else if(playHeadHourMin.min>forwardHourMin.min)
					{
						P2PDebug.traceMsg(this,"eliminateForward1:"+border["forwardBorder"],TimeTranslater.getTime(border["forwardBorder"]));
						eliminateForward(border);//淘汰最早方向的一分钟
					}
				}
				else if(playHeadHourMin.hour>forwardHourMin.hour)
				{//播放点小时 大于最早流所在的小时的情况
					P2PDebug.traceMsg(this,"eliminateForward2:"+border["forwardBorder"],TimeTranslater.getTime(border["forwardBorder"]));
					eliminateForward(border);//淘汰最早方向的一分钟
				}
				P2PDebug.traceMsg(this,"_count = "+_count);
				P2PDebug.traceMsg(this,"淘汰后:",_toString());
				
				if(_count>640){
					P2PDebug.traceMsg(this,"_count = "+_count);
					repaireEliminate();
					P2PDebug.traceMsg(this,"淘汰后2:",_toString());
				}
			}
		}
		
		private function repaireEliminate():void{
			var miniHour:Object=_blockList.getMiniHourMin();
			var startBlockID:Number;
			var startPieceID:Number;
			var endBlockID:Number;
			for each(var tempDataRange:DataRange in _rangeList)
			{
				startBlockID=tempDataRange.startBlockID;
				startPieceID=tempDataRange.startPieceID
				endBlockID=tempDataRange.endBlockID;
				
				if(TimeTranslater.getHourMinObj(endBlockID).hour<miniHour.hour){
					_rangeList[startBlockID+"_"+startPieceID]=null;
					delete _rangeList[startBlockID+"_"+startPieceID];
				}
				
				if(TimeTranslater.getHourMinObj(endBlockID).hour==miniHour.hour){
					if(TimeTranslater.getHourMinObj(endBlockID).min<miniHour.min){
						_rangeList[startBlockID+"_"+startPieceID]=null;
						delete _rangeList[startBlockID+"_"+startPieceID];
					}					
				}
			}
		}
		
		public function _toString():String{
			var str:String="\n";
			for (var dataRange:String in _rangeList)
			{
				str+=dataRange+"->"+_rangeList[dataRange]._toString()+"\n";
			}
			return str;
		}
	}
}