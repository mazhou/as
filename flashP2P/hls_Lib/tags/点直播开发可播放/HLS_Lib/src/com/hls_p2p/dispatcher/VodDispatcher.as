package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.data.vo.ReceiveData;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	public class VodDispatcher extends Dispatcher
	{
		public function VodDispatcher()
		{
			super();
		}
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		override public function getNearestWantID():Number
		{
			//---------------------------------------------------------
			if(LiveVodConfig.ADD_DATA_TIME == -1)
			{
				return 0;
			}
			var LoadTime:Number = LiveVodConfig.ADD_DATA_TIME;
			var LoadLoopRangeTime:Number = 0;
			var intervalTime:Number=3;
			var lastBlock:Block;
			var lastBlockId:Number=-1;
			
			LoadLoopRangeTime = LiveVodConfig.LAST_TS_ID;
			
			for(LoadTime ; LoadTime < LoadLoopRangeTime ; LoadTime+=intervalTime)
			{
				var tmpTime:Number= 0;
//				tmpTime = _blockList.getBlockId(LoadTime);
				
				if(tmpTime==-1)
				{
					continue;
				}
				
//				lastBlock=_blockList.getBlock(tmpTime);
				if(lastBlock && lastBlock.isChecked == false)
				{
					return (lastBlock.id);
				}
			}
			//
			if(LiveVodConfig.LAST_TS_ID >= 0)
			{
				//trace(this,"getNearestWantID LAST_TS_ID pid "+LiveVodConfig.LAST_TS_ID);
				return LiveVodConfig.LAST_TS_ID;
			}
			//trace(this,"getNearestWantID noFound pid "+PlayingBlockID);
			return 0;
		}
		
		override public function getBytesLoaded():Block
		{
			var _tempBlock:Block /*= _blockList.getBlock(getNearestWantID());*/
			return _tempBlock; 
			
		}
		
		/**添加任务数据desc*/
		override public function  writeClipList(clipList:Vector.<Clip>):void
		{
			if(clipList.length>0)
			{
				for(var i:int=0;i<clipList.length;i++)
				{
					_blockList.addBlock(clipList[i]);
				}
				LiveVodConfig.LAST_TS_ID = clipList[clipList.length-1].timestamp;
			}
			//DO
			var obj:Object = new Object();
			Statistic.getInstance().callBackMateData(obj);
		}
		
		override public function getDataTask():Object
		{
			/**
			 * 返回数据类型
			 * 
			 * */
			var data:Object=
			{
				"cdn":null,
				"p2p":new Array,
				"groupList":this._blockList.getGroupIDList()
			};
			
			var i:uint,j:uint;
			var piece:Piece;
			
			var _PlayingBlockID:Number = _blockList.getBlockId(LiveVodConfig.ADD_DATA_TIME);
			if(_PlayingBlockID == -1)
			{
				return null;
			}
			var obj:Object = TimeTranslater.getHourMinObj(_PlayingBlockID);
			var tempMinute:Number = obj.minutes;
			var startMinute:Number = tempMinute;
			while(1)
			{				
				if( tempMinute-startMinute>=(LiveVodConfig.MEMORY_TIME-1) 
					|| tempMinute - this._initData.totalDuration>0
					)
				{
					break;
				}
				
				var minutesObject:Object =  _blockList.getMinuteBlocks(tempMinute++);
				
				if ( !minutesObject )
				{
					break;
//					return null;
				}
				var arr:Array = new Array();
				for (var id:String in minutesObject)
				{
					arr.push(Number(id));
				}
				arr.sort(Array.NUMERIC);				
				for (i = 0 ; i<arr.length ; i++)
				{
					if (arr[i] >= _PlayingBlockID)
					{
						var block:Block = _blockList.getBlock(arr[i]) as Block;
						
						if ( block
							  && block.id - _PlayingBlockID <= LiveVodConfig.DAT_BUFFER_TIME
							  && _initData.ifP2PFirst() == false
						)
						{							
							if (false == block.isChecked )
							{
								if(data["cdn"] == null)
								{
									data["cdn"] = block;
								}else 
								{
									continue;
								}								
							}
							else
							{
								continue;
							}
						}else
						{
							//p2p task
							if (false == block.isChecked )
							{
								
								for(j=0;j<block.pieceIdxArray.length;j++)
								{
									piece=this.getPiece(block.pieceIdxArray[j]);
									if(
										!piece.isChecked
										&&
										piece.iLoadType != 3 
										&&
										piece.peerID == ""
										&&
										piece.peerHaveData.length>0
									)
									{
										data.p2p.push(piece);	
									}
								}
							}
						}
					}
				}
			}
			return data;
		}
	}
}