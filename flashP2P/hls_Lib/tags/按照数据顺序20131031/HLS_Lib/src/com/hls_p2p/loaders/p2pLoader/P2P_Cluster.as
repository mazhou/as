package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.dispatcher.IDataManager;

	public class P2P_Cluster
	{
		public function P2P_Cluster()
		{
		}
		
		public function initialize(initData:InitData,dispatcher:IDataManager):void
		{
			if(!isInint)
			{
				p2pList			= new Object;
				this.initData	= initData;
				this.dispatcher	= dispatcher;
				isInint			= true;
			}
		}
		
		public function clear():void
		{
			if(isInint)
			{
				for(var p2p:String in p2pList)
				{
					p2pList[p2p].clear();
				}
				p2pList				= null;
				this.initData		= null
				this.dispatcher		= dispatcher;
				isInint				= false;
			}
		}
		
//		public function getWantPiece():void
//		{
//			var myWantData:Array = dispather.getWantPiece(_remoteID);
//		}
		public function ifGroupHasPeerConnected(groupID:String):Boolean
		{
			if(p2pList[groupID])
			{
				return p2pList[groupID].ifPeerConnection();
			}
			return false;
		}
		public function createP2P(groupID:String):void
		{
			if(!hasP2P(groupID))
			{
				p2pList[groupID]	= new P2P_Loader(dispatcher,this);
				p2pList[groupID].startLoadP2P(initData,groupID);
			}
		}
		
		public function hasP2P(groupID:String):Boolean
		{
			if(p2pList.hasOwnProperty(groupID))
			{
				return true
			}
			return false;	
		}
		
		public function handlerP2PByList(groupIDList:Array):void
		{
			var groupID:String
			//
			for (groupID in p2pList)
			{
				if(groupIDList.indexOf(groupID) == -1)
				{
					p2pList[groupID].clear();
					p2pList[groupID] = null;
					delete p2pList[groupID];
				}
			}
			//
			for each(groupID in groupIDList)
			{
				if(p2pList.hasOwnProperty(groupID))
				{
					continue;
				}else
				{
					createP2P(groupID);
				}
			}
		}
		
		public function removeP2P(groupID:String):void
		{
			if(hasP2P(groupID))
			{
				p2pList[groupID].clear();
				p2pList[groupID] = null;
				delete p2pList[groupID];
			}
		}
		public function removeHaveData(simplyPieceList:Array):void
		{
			/**
			 * simplyPieceList的数据结构为
			 * simplyPieceList = [
			 * 						[
			 * 							{"groupID":String,"pieceKey":Number,"type":String},
			 * 							{"groupID":String,"pieceKey":Number,"type":String},
			 * 							{"groupID":String,"pieceKey":Number,"type":String}
			 * 						],
			 *						[
			 * 							{"groupID":String,"pieceKey":Number,"type":String},
			 * 							{"groupID":String,"pieceKey":Number,"type":String}
			 * 						],
			 * 					 ]
			 * */
			var i:uint = 0;
			var obj:Object = new Object;
			for(i=0;i<simplyPieceList.length;i++)
			{
				for(var m:int=0 ; m<simplyPieceList[i].length ; m++)
				{
					if(obj[simplyPieceList[i][m].groupID])
					{
						obj[simplyPieceList[i][m].groupID].push( 
							{
								"pieceKey":simplyPieceList[i][m].pieceKey,
								"type":simplyPieceList[i][m].type
							} 
						);
					}
					else 
					{
						obj[simplyPieceList[i][m].groupID] = [ {
							"pieceKey":simplyPieceList[i][m].pieceKey,
							"type":simplyPieceList[i][m].type
						}  ];
					}
				}				
			}
			/**
			 * obj = {groupID:[{"pieceKey":Number,"type":String},{"pieceKey":Number,"type":String}],
			 *        groupID:[{"pieceKey":Number,"type":String},{"pieceKey":Number,"type":String}]..}
			 * */
			for( var param:String in obj)
			{
				if(hasP2P(param))
				{
					p2pList[param].removeHaveData(obj[param]);
				}
			}
		}
		public function handlerPiece(piece:Piece):void
		{
			if(hasP2P(piece.groupID))
			{
				p2pList[piece.groupID].handlerPiece(piece);
			}
		}
		public function doAddHave(groupID:String):void
		{
			if(p2pList && p2pList[groupID])
			{
				p2pList[groupID].doAddHave();
			}
		}
		//执行p2p任务
//		protected function executeP2P(groupID:String):void
//		{
//			createP2P(groupID);
//			p2pList[groupID].
////			executeSendP2P(groupID);
////			executeSendP2P(groupID);
//		}
//		public function executeSendP2P(groupID:String):void
//		{
//			
//		}
//		
//		public function executeRecieveP2P(groupID:String):void
//		{
//			
//		}
		
		public function stopP2P(groupID:String):void
		{
//			stopSendP2P(groupID);
//			stopRecieveP2P(groupID);
		}
		
//		public function stopSendP2P(groupID:String):void
//		{
//			
//		}
//		
//		public function stopRecieveP2P(groupID:String):void
//		{
//			
//		}
		
		protected var isInint:Boolean				=false;
		protected var p2pList:Object;
		protected var initData:InitData;
		protected var dispatcher:IDataManager;
	}
}