package com.hls_p2p.loaders
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.loaders.cdnLoader.CDNLoad;
	import com.hls_p2p.loaders.p2pLoader.P2P_Cluster;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class LoadManager
	{
		protected var getTaskListTime:Timer;
		protected var dispather:IDataManager;
		protected var cdnLoad:CDNLoad;
		protected var p2pCluster:P2P_Cluster;
		
		public function LoadManager(dispather:IDataManager)
		{
			this.dispather=dispather;
			cdnLoad = new CDNLoad(dispather);
			p2pCluster = new P2P_Cluster();
			if(getTaskListTime == null)
			{
				getTaskListTime = new Timer(50);
				getTaskListTime.addEventListener(TimerEvent.TIMER, handlerGetTaskList);
			}
		}
		
		public function start(_initData:InitData):void
		{
			if(getTaskListTime)
			{
				getTaskListTime.reset();
				getTaskListTime.start();
				cdnLoad.start(_initData);
			}
			
			p2pCluster.initialize(_initData,dispather);
		}
		
		public function ifGroupHasPeerConnected(groupID:String):Boolean
		{
			if(p2pCluster)
			{
				return p2pCluster.ifGroupHasPeerConnected(groupID);
			}
			return false;
		}
		
		protected function handlerGetTaskList(evt:TimerEvent=null):void
		{
			var data:Object=dispather.getDataTaskList();
			if(data)
			{
				handerCDN(data.cdn);
				handerGroupList(data.groupList);
				handerP2P(data.p2p);
			}
		}
		
		protected function handerGroupList(data:Object):void
		{
			if((data as Array).length>0)
			{
				p2pCluster.handlerP2PByList(data as Array);
			}
		}
		
		protected function handerCDN(data:Object):void
		{
			if(data && !cdnLoad.isLoad)
			{
				cdnLoad.loadTask(data as Block);
			}
		}
		
		protected function handerP2P(data:Object):void
		{
			if(data is Array)
			{
				if((data as Array).length>0)
				{
					var i:uint = 0;
					for(i=0;i<(data as Array).length;i++)
					{
						p2pCluster.handlerPiece((data as Array)[i]);
					}
				}
			}
		}
		
		public function doAddHave(groupID:String):void
		{
			p2pCluster.doAddHave(groupID);
		}
		
		public function removeHaveData(eliminateArray:Array):void
		{
			if((eliminateArray as Array).length>0)
			{
				p2pCluster.removeHaveData(eliminateArray);
			}
		}
		
		public function clear():void
		{
			if(getTaskListTime)
			{
				getTaskListTime.stop();
				getTaskListTime.removeEventListener(TimerEvent.TIMER, handlerGetTaskList);
			}
		}
	}
}