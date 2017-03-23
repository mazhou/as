package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.statistics.Statistic;

	public class P2P_Cluster
	{
		
		protected var p2pList:Object;
		protected var initData:InitData;
		protected var manage:DataManager			=null;
		public var isStopUpload:Boolean				= false;
		public var isStopDownload:Boolean			= false;
		
		public function initialize(initData:InitData,manage:DataManager):void
		{
			if( null == this.manage )
			{
				p2pList			= new Object;
				this.initData	= initData;
				this.manage		= manage;
			}
		}
		
		public function clear():void
		{
			for( var p2p:String in p2pList )
			{
				p2pList[p2p].clear();
				p2pList[p2p] = null;
				delete p2pList[p2p];
			}
				
			p2pList				= null;
			this.initData		= null;
			this.manage			= null;	
		}
		
		public function ifGroupHasPeerConnected(groupID:String):Boolean
		{
			if( p2pList[groupID] )
			{
				return p2pList[groupID].ifPeerConnection();
			}
			
			return false;
		}
		public function createP2P(groupID:String):void
		{
			if( !hasP2P(groupID) )
			{
				p2pList[groupID] = new P2P_Loader(manage,this);
				
				p2pList[groupID].startLoadP2P(initData,groupID);
				
				Statistic.getInstance().creatStatisticByGroupID(groupID);
			}
		}
		
		public function hasP2P(groupID:String):Boolean
		{
			if( p2pList.hasOwnProperty(groupID) )
			{
				return true
			}
			
			return false;	
		}
		
		public function peerHartBeat(groupIDList:Array):void
		{
			var groupID:String = "";
			
			for( groupID in p2pList )
			{
				if( groupIDList.indexOf(groupID) != -1 )
				{
					p2pList[groupID]["peerHartBeatTimer"]();
				}
			}
		}
		
		public function handlerP2PByList(groupIDList:Array):void
		{
			var groupID:String = "";
			
			for( groupID in p2pList )
			{
				if( groupIDList.indexOf(groupID) == -1 )
				{
					p2pList[groupID].clear();
					p2pList[groupID] = null;
					delete p2pList[groupID];
					
					Statistic.getInstance().delStatisticByGroupID(groupID);
				}
			}
			
			for each( groupID in groupIDList )
			{
				if( p2pList.hasOwnProperty(groupID) )
				{
					continue;
				}
				else
				{
					createP2P(groupID);
				}
			}
		}
		
		public function removeP2P(groupID:String):void
		{
			if( hasP2P(groupID) )
			{
				p2pList[groupID].clear();
				p2pList[groupID] = null;
				delete p2pList[groupID];
			}
		}
		
		public function handlerPiece(piece:Piece):void
		{
			if( hasP2P(piece.groupID) )
			{
				p2pList[piece.groupID].handlerPiece(piece);
			}
		}
		
	}
}