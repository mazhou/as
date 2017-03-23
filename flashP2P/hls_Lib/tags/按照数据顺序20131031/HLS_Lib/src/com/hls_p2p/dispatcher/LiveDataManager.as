package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.Head;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.PlayData;
	import com.hls_p2p.data.vo.ReceiveData;
	
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.loaders.cdnLoader.FactoryCdnLoadStream;
	import com.hls_p2p.loaders.cdnLoader.IStreamLoader;
	import com.hls_p2p.loaders.descLoader.FactoryDesc;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.loaders.p2pLoader.P2P_Loader;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	import com.hls_p2p.data.Piece;
	
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	/**
	 * <ul>构造函数：监听NETSTREAM_PROTOCOL.PLAY，NETSTREAM_PROTOCOL.SEEK;
	 * 创建_blockList _descLoad _datLoad _headLoad _p2pLoad _p2pLoad</ul>
	 * <ul>接口功能解释参见接口类</ul>
	 * <ul>http和p2p调度策略handlerDownloadTask</ul>
	 * @author mazhoun
	 */
	public class LiveDataManager extends DataManager
	{
		
		
		public function LiveDataManager()
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
			
			if(LoadTime == -1){return 0}
			LoadLoopRangeTime = LoadTime+(LiveVodConfig.MEMORY_TIME-1)*60;
			if(LoadLoopRangeTime > LIVE_TIME.GetLiveTime())
			{
				LoadLoopRangeTime = LIVE_TIME.GetLiveTime();
			}
			
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
			return 0;
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
			}
			//DO
			var obj:Object = new Object();
			Statistic.getInstance().callBackMateData(obj);
		}

		
		//public var earliestStartTimeAllPeer:Number = 0;
		
		override public function getDataTask():Object
		{

			if(_initData.ifP2PFirst())
			{
//				P2PDebug.traceMsg(this,"ad：=>"+_initData.getAdRemainingTime());
				return null;
			}
			
			var _PlayingBlockID:Number = _blockList.getBlockId(LiveVodConfig.ADD_DATA_TIME);
			
			if(_PlayingBlockID == -1)
			{
				return null;
			}
			//
			var obj:Object = TimeTranslater.getHourMinObj(_PlayingBlockID);
			while(1)
			{
				var minutesObject:Object =  _blockList.getMinuteBlocks(obj.minutes++);
				if (minutesObject == null)
					return null;
				//
				var arr:Array = new Array();
				for (var id:String in minutesObject)
				{
					arr.push(Number(id));
				}
				//
				arr.sort(Array.NUMERIC);
				var playTime:Number=LiveVodConfig.PLAY_TIME;
				if(playTime==-1)
				{
					playTime=_PlayingBlockID;
				}
				for each(var i:Number in arr)
				{
					if (i >= _PlayingBlockID)
					{
						var block:Block = minutesObject[i] as Block;
						//
						if (block)
						{
							//trace((LiveVodConfig.MEMORY_TIME-1)*60);
							if ((block.id - _PlayingBlockID) > (LiveVodConfig.MEMORY_TIME-1)*60)
							{
								return null;
							}
							//
							if (block.id - playTime <= LiveVodConfig.DAT_BUFFER_TIME)
							{
								/**在紧急区之内的block，目前为播放点之后的紧急区秒数，
								 如果没有下载到数据或下载的数据有问题，则强行将该任务分配给
								 http下载*/
								if (false == block.isChecked )
								{
									block.downLoadStat = 1;
									return {"block":block,"pieceId":-1};
								}else{
									continue;
								}
							}
							// 修改了p2p连接的判断位置
//							if (this._p2pLoad.ifPeerConnection() == false)//如果没有成功连接节点
//							{
//								return null;
//							}
							
							if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
							{
								if(loadManager.ifGroupHasPeerConnected(block.groupID) == false)
								{
									continue;
								}
								/**紧急区之外的http任务*/
								if (block.id - playTime> LiveVodConfig.DAT_BUFFER_TIME)
								{
									var tempPiece:Piece;
									for(var j:int=0 ; j<block.pieceIdxArray.length ; j++)
									{					
										//					tempPiece = getPieceByPieceIdxArray(i);
										tempPiece = _blockList.getPiece(block.pieceIdxArray[j]);
										if( tempPiece.peerHaveData.length==0   //邻居节点没有下载到该piece数据
										//&& block.pieces[j].getStream().length==0 //本地没有下载到该piece数据
										&& tempPiece.isLoad                //该piece已经按概率分配给http下载
										&& tempPiece.iLoadType != 1        //未分配给http  
										&& tempPiece.isChecked  == false   //未通过验证 
																				)
										{
											block.downLoadStat = 1;
											//httpDownLoadPos = block.id;
											P2PDebug.traceMsg(this,"emg:"+ block.id + " pieceID:" + j);
											//											
											return {"block":block,"pieceId":j};
										}					
									}
								}	
							}
						}
					}
				}
			}
			//
			return null;
		}
	}
}