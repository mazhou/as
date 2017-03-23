package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.p2p.utils.console;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ParseUrl;
	import com.p2p.utils.sha1Encrypt;

	public class P2P_Cluster
	{
		public var isDebug:Boolean = true;
		protected var p2pList:Object;
		protected var initData:InitData;
		protected var manage:DataManager			=null;
		public var isStopUpload:Boolean				= false;
		public var isStopDownload:Boolean			= false;
		protected var _gatherName:String = "";
		protected var _gatherPort:uint;
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
			console.log(this,"clear");
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
		
		public function changeUTP( _gatherName:String, _gatherPort:uint ):void
		{
			this._gatherName = _gatherName;
			this._gatherPort = _gatherPort;
			var encryptstr:String = "";
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD  ){
				
				encryptstr = ParseUrl.getParam( initData['gslbURL'],"mmsid");
				encryptstr += "_";
				encryptstr += ParseUrl.getParam( initData['gslbURL'],"vtype");
			}else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				encryptstr = ParseUrl.getParam( initData['gslb'],"stream_id");
			}

			var enc:sha1Encrypt = new sha1Encrypt(true);
			
			var strSHA1:String  = sha1Encrypt.encrypt(encryptstr);
			LiveVodConfig.resourceID = strSHA1;//"db84ac13eb2fca817ca5f7bb863b0b596baa39ac";//sha加密
			Statistic.getInstance().gatherStart("UTP",0,groupID);
			console.log(this,"changeUTP gatherName:"+_gatherName+" ckey:"+strSHA1+ " encryptstr:"+encryptstr);
			var groupID:String = "";
			for( groupID in p2pList )
			{			
				p2pList[groupID].clear();
				p2pList[groupID] = null;
				delete p2pList[groupID];
//				Statistic.getInstance().delStatisticByGroupID(groupID);
			}
			
		}
		
		public function createP2P(groupID:String):void
		{
			if( !hasP2P(groupID) )
			{
				if( LiveVodConfig.resourceID == "" )
				{
					p2pList[groupID] = new P2P_Loader(manage,this);
					p2pList[groupID].startLoadP2P(initData,groupID);
					Statistic.getInstance().creatStatisticByGroupID(groupID);
				}
				else
				{
					p2pList[groupID] = new UTP_Loader(manage,this,_gatherName,_gatherPort);
					p2pList[groupID].startLoadP2P(initData,groupID,LiveVodConfig.resourceID);
					Statistic.getInstance().creatStatisticByGroupID( groupID );
					
					Statistic.getInstance().rtmfpStart("UTP",0,groupID);
				}
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
					//删除group
					/*p2pList[groupID].clear();
					p2pList[groupID] = null;
					delete p2pList[groupID];*/
					
					removeP2P(groupID);
					
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
					//创建group
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