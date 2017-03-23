package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.ReceiveData;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	public class VodDataManager extends DataManager
	{
		public function VodDataManager()
		{
			super();
		}
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		override public function getNearestWantID(isPiece:Boolean=false):Number
		{
			if (null == _blockList)
				return -1;
			//---------------------------------------------------------
			if(LiveVodConfig.ADD_DATA_TIME == -1)
			{
				return -1;
			}
			var LoadTime:Number = LiveVodConfig.ADD_DATA_TIME;
			var LoadLoopRangeTime:Number = 0;
			var intervalTime:Number=3;
			var lastBlock:Block;
			var lastBlockId:Number=-1;
			var piece:Piece;
			LoadLoopRangeTime = LiveVodConfig.LAST_TS_ID;
			
			for(LoadTime ; LoadTime < LoadLoopRangeTime ; LoadTime+=intervalTime)
			{
				//var tmpTime:Number= 0;
				var tmpTime:Number = _blockList.getBlockId(LoadTime);
				
				if(tmpTime==-1)
				{
					continue;
				}
				
				lastBlock=_blockList.getBlock(tmpTime);
				if(lastBlock && lastBlock.isChecked == false)
				{
					if(isPiece)
					{
						for(var j:uint = 0;j<lastBlock.pieceIdxArray.length;j++)
						{
							piece = this.getPiece(lastBlock.pieceIdxArray[j]);
							if(piece && !piece.isChecked && piece.from != "")
							{
								return Number(piece.pieceKey);
							}
						}
					}else
					{
						return (lastBlock.id);
					}
				}
			}
			//
			if(LiveVodConfig.LAST_TS_ID >= 0)
			{
				//trace(this,"getNearestWantID LAST_TS_ID pid "+LiveVodConfig.LAST_TS_ID);
				if(isPiece)
				{
					return -1;
				}else
				{
					return LiveVodConfig.LAST_TS_ID;
				}
			}
			//trace(this,"getNearestWantID noFound pid "+PlayingBlockID);
			return -1;
		}
		
		override public function getBytesLoaded():Block
		{
			var _tempBlock:Block = _blockList.getBlock(getNearestWantID());/**/
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
			
			var retObj:Object = new Object;
			var iCount:uint = 0;
			
			retObj.groupList = this._blockList.getGroupIDList();
			retObj.task = new Object;
			
			var i:uint,j:uint;
			var piece:Piece;
				
			var arr:Array = new Array();
			for (var id:String in this._blockList.blockList)
			{
				arr.push(Number(id));
			}
			arr.sort(Array.NUMERIC);				
			for (i = 0 ; i<arr.length; i++)
			{
				var temp:Number = this.getBlockId(LiveVodConfig.ADD_DATA_TIME);//LIVE_TIME.GetBaseTime();
				if(-1 == temp){return retObj;}

				if (arr[i] >= temp)
				{	
					var block:Block = _blockList.getBlock(arr[i]) as Block;
					if (false == block.isChecked )
					{
						retObj.task[arr[i]] = block;
						iCount++;
						if (iCount > 20)
						{
							return retObj;
						}
					}
				}				
			}
			//
			return retObj;
		}
	}
}