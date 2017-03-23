package com.hls_p2p.loaders
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.loaders.cdnLoader.CDNLoad;
	import com.hls_p2p.loaders.p2pLoader.P2P_Cluster;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class LoadManager
	{
		protected var getTaskListTime:Timer;
		protected var manager:IDataManager;
		protected var cdnLoad:CDNLoad;
		protected var p2pCluster:P2P_Cluster;
		protected var CacheLen:Number 							= LiveVodConfig.DAT_BUFFER_TIME;
		protected var TaskCacheNode:Object 						= new Object;
		
		public function LoadManager( manager:IDataManager )
		{
			this.manager = manager;
			cdnLoad = new CDNLoad( manager, this );
			p2pCluster = new P2P_Cluster();
		}
		
		public function start( _initData:InitData ):void
		{
			TaskCacheNode = null;
			TaskCacheNode = new Object;
			
			handlerGetTaskList();
			cdnLoad.start(_initData);
			
			p2pCluster.initialize( _initData,manager );
		}
		
		protected function handlerGetTaskList():void
		{
			CheckCompleteTaskInCacheNode();
			//
			if( TaskCacheNode
				&& TaskCacheNode.task )
			{
				if(TaskCacheNode.task.length > 5)
				{
					return;
				}				
			}
			
			TaskCacheNode = manager.getDataTaskList();
			handerGroupList(TaskCacheNode.groupList);
			//stopDownLoad
			if( CacheLen == LiveVodConfig.DAT_BUFFER_TIME )
			{
				if( TaskCacheNode
					&& TaskCacheNode.task
					&& TaskCacheNode.task[0] 
					&& (TaskCacheNode.task[0] as Block).id - LiveVodConfig.ADD_DATA_TIME > LiveVodConfig.DAT_BUFFER_TIME )
				{
					CacheLen = LiveVodConfig.DAT_BUFFER_TIME / 2;
				}
			}
			else if( TaskCacheNode
					  && TaskCacheNode.task
					  && TaskCacheNode.task[0]
					  && (TaskCacheNode.task[0] as Block).id - LiveVodConfig.ADD_DATA_TIME < LiveVodConfig.DAT_BUFFER_TIME / 2 )
			{
				CacheLen = LiveVodConfig.DAT_BUFFER_TIME;
			}
		}
		
		public function CheckCompleteTaskInCacheNode():void
		{
			if( TaskCacheNode && TaskCacheNode.task)
			{
				var flag:int = 0;
				for( var i:int = 0; i< TaskCacheNode.task.length; i++ )
				{
					var tmpblock:Block = TaskCacheNode.task[i] as Block;
					if( tmpblock.isChecked == true )
					{
						TaskCacheNode.task.splice(i,1);
						if (0 == flag)
						{
							LiveVodConfig.NEAREST_WANT_ID = tmpblock.id;
						}
						
					}
					//
					flag++;
				}
			}
			
		}

		public function getCDNTask():Block
		{
			handlerGetTaskList();
			//
			if( TaskCacheNode == null
				|| TaskCacheNode.task == null)
			{
				return null;				
			}
			
			var i:int = 0;
			var arr:Array = TaskCacheNode.task;

			for( i = 0 ; i<arr.length; i++ )
			{
				var temp:Number = this.manager.getBlockId( LiveVodConfig.ADD_DATA_TIME );
				if( -1 == temp )
				{
					return null;
				}
				if( (arr[i] as Block).id >= temp )
				{
					var block:Block = arr[i] as Block;
					
					if( block && block.id - LiveVodConfig.ADD_DATA_TIME <= CacheLen )
					{							
						if( false == block.isChecked && block.downLoadStat != 1 )
						{
							block.downLoadStat = 1;
							return block;
						}
					}
					
					// 紧急区之外缓冲区的一半
					if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
					{
						if( block	
							&& block.id - LiveVodConfig.ADD_DATA_TIME > CacheLen 
							&& block.id - LiveVodConfig.ADD_DATA_TIME < Math.floor(LiveVodConfig.MEMORY_TIME/2-1)*60)
						{
							return block;
						}	
					}
				}
			}

			return null;
		}
		
		public function getP2PTask( getP2PTask:Object ):Object
		{
					
			handlerGetTaskList();
			//
			if( TaskCacheNode == null
				|| TaskCacheNode.task == null)
			{
				return null;				
			}
			//
			var i:uint = 0;
			var j:uint = 0;
			var arr:Array = TaskCacheNode.task;
			var piece:Piece;
			
			
			for( i = 0; i<arr.length-1;i++ )
			{
				var block:Block = arr[i] as Block;
				if( block.groupID != getP2PTask.groupID )
				{
					continue;
				}
				
				if( block 
					&& block.id - LiveVodConfig.ADD_DATA_TIME <= CacheLen
					&& (!block.isChecked) )
				{
					return null;
				}
				
				if( block	&& block.id - LiveVodConfig.ADD_DATA_TIME > CacheLen )
				{
					if( false == block.isChecked && block.downLoadStat != 1 )
					{
						for( j = 0; j < block.pieceIdxArray.length; j++ )
						{
							piece=block.getPiece(j);
							if( !piece.isChecked
								&& piece.iLoadType != 3 
								&& piece.peerID == "" )
							{
								var rangeArray:Array = getP2PTask.TNrange;;
								if("PN" == piece.type)
								{
									rangeArray = getP2PTask.PNrange;
								}
								//search TN
								var p_data:*;
								for each( p_data in rangeArray )
								{
									if(	p_data.start<=int(piece.pieceKey)
										&& int(piece.pieceKey)<=p_data.end )
									{										
										piece.iLoadType = 2;
										piece.peerID    = getP2PTask.remoteID;
										return piece;
									}
								}
								
							}//end for piece
						}
					}
				}
			}
			return null;
		}
		
		protected function handerGroupList( data:Object ):void
		{
			if( data && data is Array && (data as Array).length>0 )
			{
				p2pCluster.handlerP2PByList(data as Array);
			}
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			if( cdnLoad )
			{
				cdnLoad.clear();
				cdnLoad = null;
			}
			
			if( p2pCluster )
			{
				p2pCluster.clear();
				p2pCluster = null;
			}
			
			CacheLen      = LiveVodConfig.DAT_BUFFER_TIME;
			TaskCacheNode = null;
		}
	}
}