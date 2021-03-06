package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class SignallingStrategy_V1
	{
		public var isDebug:Boolean=false;
		
		private var p2p_pipe:P2P_Pipe;
		
		public var remoteNearestWantID:Number = Number.MIN_VALUE;
		
		protected var _recieverTimer:Timer;
		/**P2PLoader调用的心跳接口，与节点建立索要数据的互动，将本地的下载位置发送给对方节点*/
		//		private var _NearestWantID:Number = 0;
		protected var p2pCluster:P2P_Cluster			= null;
		protected var dataManager:DataManager			= null;
		protected var remoteClientType:String 			= "PC";
		public var requestArr:Array 					= new Array;
		protected var beginTime:Number 					= 0;
		protected var isConnect:Boolean					= false;
		
		protected var remoteBirthTime:Number 			= -1;	
		//对方的播放类型，vod live
		protected var remotePlayType:String  			= "";
		
		protected var remotePNList:Array;
		protected var remoteTNList:Array;
		protected var remoteCDNTaskPieceList:Array;
		protected var readySendDataList:Array;
		
		
		
		public function SignallingStrategy_V1(p_p2p_pipe:P2P_Pipe,p2pCluster:P2P_Cluster,dataManager:DataManager)
		{
			this.p2p_pipe				= p_p2p_pipe;
			this.p2pCluster	 			= p2pCluster;
			this.dataManager 			= dataManager;
			p2p_pipe.connectSuccess		= connectSuccess;
			p2p_pipe.dataSuccess		= dataSuccess;
			beginTime = getTime();
		}
		
		public function dataSuccess(name:String,data:Object=null,type:String=null):void
		{
			beginTime = getTime();
//			var version:String = name; 
			if(data)
			{
				if(data.TNList)
				{
					remoteTNList = data.TNList;
				}
				
				if(data.PNList)
				{
					remotePNList = data.PNList;
				}
				
				if(data.playType)
				{
					remotePlayType = data.playType;
				}
				
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE
					&& remotePlayType != LiveVodConfig.VOD )
				{
					remoteBirthTime = data.birthTime;
					if( remoteBirthTime < LiveVodConfig.BirthTime )
					{
						remoteCDNTaskPieceList = data.CDNTaskPieceList;
					}
				}				
				
				if(data.requetData)
				{
					readySendDataList = getData(data.requetData);
				}
				
				if(data.sendData)
				{
					dealRemoteSendData(data.sendData);
				}
				
				if(data.clientType)
				{
					remoteClientType = data.clientType;
				}
			}
			//
			this.peerHartBeatTimer(false);
		}
		
		public function peerHartBeatTimer(isHeart:Boolean=false):void
		{			
			checkTimeout();
			
			if (p2p_pipe.canSend && p2p_pipe.canRecieved && p2p_pipe.sendNetStream)
			{
				var data:Object = new Object;
				
				data.clientType = LiveVodConfig.CLIENT_TYPE;
				
				data.playType = LiveVodConfig.TYPE;				
				
				if( true == LiveVodConfig.ifCanP2PUpload )
				{
					data.TNList	= this.dataManager.getTNRange(this.groupID);
					data.PNList	= this.dataManager.getPNRange(this.groupID);
				}
				else
				{
					data.TNList	= null;
					data.PNList	= null;
				}
				//
				if( true == LiveVodConfig.ifCanP2PDownload 
					&& requestArr.length == 0)
				{
					var piece:Piece = getTask(this.remoteTNList,this.remotePNList) as Piece;
					
					if(null == piece)
					{
						data.requetData	= null;
					}else
					{
						requestArr.push(piece);
						if(piece.type == "TN"){
							data.requetData		= [{
								"type":piece.type,
								"key":piece.pieceKey,
								"checksum":piece.checkSum
							}]
						}
						else if(piece.type == "PN")
						{
							data.requetData		= [{
								"type":piece.type,
								"key":piece.pieceKey
							}]
						}
					}
				}
				else
				{
					data.requetData	= null;
				}

				if(readySendDataList && readySendDataList.length>0)
				{
					data.sendData		= readySendDataList;
					readySendDataList 	= new Array();
				}else
				{
					data.sendData		= null;
				}
				
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE 
					&& remotePlayType != LiveVodConfig.VOD )
				{
					if( remoteBirthTime == -1 
						|| remoteBirthTime > LiveVodConfig.BirthTime )
					{
						data.CDNTaskPieceList = this.dataManager.getCDNTaskPieceList();
					}
					data.birthTime = LiveVodConfig.BirthTime;
				}
				
				if (isHeart || data.sendData != null || data.requetData	!= null)
				{
					outPutP2PState(data);
					p2p_pipe.sendData(LiveVodConfig.GET_AGREEMENT_VERSION(), data);
				}
			}
		}
		private var tempPiece:Piece;
		protected function outPutP2PState(data:Object):void
		{
			if(data.requetData)
			{
				for(var i:int=0 ; i<(data.requetData as Array).length ; i++)
				{					
					Statistic.getInstance().P2PWantData(data.requetData[i]["type"]+"_"+data.requetData[i]["key"],p2p_pipe.remoteID);
				}
			}
			if(data.sendData)
			{
				for(var j:int=0 ; j<(data.sendData as Array).length ; j++)
				{
					try
					{
						tempPiece = dataManager.getPiece({"groupID":groupID,"pieceKey":data.sendData[j]["key"],"type":data.sendData[j]["type"]});
						tempPiece.share++;
						Statistic.getInstance().P2PShareData(data.sendData[j]["type"]+"_"+data.sendData[j]["key"],p2p_pipe.remoteID);
					}catch(err:Error)
					{
						P2PDebug.traceMsg(this,"err:"+err);	
					}
				}
			}			
		}
		
		public function ifPeerHaveThisPiece( tempPiece:Piece ):Boolean
		{
			if( false == pipeConnected() )
			{
				return false;
			}
			/**与对方节点的CDNIsLoadPieceArr表进行比较去重*/
			if( null != remoteCDNTaskPieceList 
				&& remoteBirthTime < LiveVodConfig.BirthTime)
			{
				for(var i:uint = 0; i<remoteCDNTaskPieceList.length;i++)
				{
					if( remoteCDNTaskPieceList[i]["groupID"] == tempPiece.groupID
						&& remoteCDNTaskPieceList[i]["pieceKey"] == tempPiece.pieceKey
						&& remoteCDNTaskPieceList[i]["type"] == tempPiece.type )
					{
						//this.dataManager.clearIsLoaded_1( tempPiece );
						return true;
					}
				}
			}
			
			/**与对方节点的TNList表进行比较去重*/
			if( null != remotePNList)
			{
				for(var j:int = 0 ; j<remotePNList.length ; j++)
				{
					if( tempPiece.type == "PN"
						&& tempPiece.pieceKey >= remotePNList[j]["start"]
						&& tempPiece.pieceKey <= remotePNList[j]["end"])
					{
						//this.dataManager.clearIsLoaded_1( tempPiece );
						return true;
					}
				}
			}
			/**与对方节点的PNList表进行比较去重*/
			if( null != remoteTNList)
			{
				for(var p:int = 0 ; p<remoteTNList.length ; p++)
				{
					if( tempPiece.type == "TN"
						&& tempPiece.pieceKey >= remoteTNList[p]["start"]
						&& tempPiece.pieceKey <= remoteTNList[p]["end"])
					{
						//this.dataManager.clearIsLoaded_1( tempPiece );
						return true;
					}
				}
			}
			return false;
		}
		protected function getTask(TNArray:Array,PNArray:Array):Object
		{
			if(null == TNArray && null == PNArray )
			{
				return null;
			}
			var obj:Object = new Object;
			obj.groupID		= this.groupID;
			obj.TNrange		= TNArray;
			obj.PNrange		= PNArray;
			obj.remoteID	= p2p_pipe.remoteID;
			
			var callBackObj:Object = dataManager.getP2PTask(obj);
			
			return callBackObj;
		}
		
		protected function getData(arr:Array):Array
		{
			var tmpArray:Array = new Array;
			if(null == arr)
			{
				return tmpArray;
			}
			
			var tmpPiece:Piece;
			var readySendData:Object;
			
			for(var i:int=0;i<arr.length;i++)
			{
				if(arr[i])
				{
					var type:String			= arr[i]["type"];
					var key:String			= arr[i]["key"];
					if(type && key)
					{
						tmpPiece =  dataManager.getPiece(
							{
								"groupID":this.groupID,
								"type":arr[i].type,
								"pieceKey":arr[i].key
							}
						)
						
						if(!tmpPiece || false == tmpPiece.isChecked)
						{
							continue;
						}
						
						if(type == "TN" && tmpPiece.checkSum != arr[i]["checksum"])
						{
							continue;
						}
						
						readySendData = 
							{
								"type":tmpPiece.type,
								"key":tmpPiece.pieceKey,
								"data":tmpPiece.getStream()
							}
						
						tmpArray.push(readySendData);
						if(tmpArray.length>0)
						{
							break;
						}
					}else
					{
						continue;
					}
				}
			}// end for arr loop
			return tmpArray;
		}
		
		protected function dealRemoteSendData(arr:Array):void
		{
			if(null == arr)
			{
				return;
			}
			var i:int=0;
			var tmpPiece:Piece;
			for(i=0;i<arr.length;i++)
			{
				if(arr[i])
				{
					if( arr[i].hasOwnProperty("type")
						&& arr[i].hasOwnProperty("key")
						&& arr[i].hasOwnProperty("data")
						&& (arr[i].data as ByteArray).length>0 )
					{
						tmpPiece =  dataManager.getPiece(
							{
								"groupID":this.groupID,
								"type":arr[i].type,
								"pieceKey":arr[i].key
							}
						);
						
						if( tmpPiece )
						{
							if( false == tmpPiece.isChecked )
							{
								tmpPiece.setStream((arr[i].data as ByteArray),p2p_pipe.remoteID,this.remoteClientType);
							}
							requestArr.splice(requestArr.indexOf(tmpPiece), 1);
						}	
					}//end for hasOwnProperty	
				}
			}//end for
			
		}
		
		protected function checkTimeout():void
		{
			if(requestArr)
			{
				var i:int=requestArr.length;
				while(i>0)
				{
					i--;
					var tmpPiece:Piece =  dataManager.getPiece(
						{
							"groupID":this.groupID,
							"type":requestArr[i].type,
							"pieceKey":requestArr[i].pieceKey
						}
					)
					
					if(tmpPiece)
					{
						if(tmpPiece.isChecked && tmpPiece.getStream().length>0)
						{
							requestArr.splice(requestArr.indexOf(tmpPiece),1);
							continue;
						}
						if(getTime()-tmpPiece.begin>30*1000)
						{
							//tmpPiece.reset(remoteID);
							requestArr.splice(requestArr.indexOf(tmpPiece),1);
							tmpPiece = null;
						}
					}
				}
			}
		}
		
		public function isDead():Boolean
		{
			return (Math.floor((new Date()).time) - beginTime) > (13 * 1000);
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			if(requestArr && requestArr.length>0)
			{
				for each(var pieceSmp:* in requestArr)
				{
					var tmpPiece:Piece =  dataManager.getPiece(
						{
							"groupID":this.groupID,
							"type":pieceSmp.type,
							"pieceKey":pieceSmp.pieceKey
						}
					)
					
					if(tmpPiece)
					{
						//tmpPiece.reset(remoteID);
						tmpPiece = null;
					}
				}
			}
			
			requestArr 				= null;
			remotePNList 			= null;
			remoteTNList			= null;
			remoteCDNTaskPieceList  = null;
			readySendDataList		= null;
			p2p_pipe.clear();
			p2pCluster				= null;
			dataManager				= null;
			remoteClientType		= "PC";
			beginTime				= 0;
			isConnect				= false;
			
			remoteBirthTime			= -1;
			tempPiece				= null;
		}
		
		
		public function pipeConnected():Boolean
		{
			return canSend && canRecieved;
			//return isConnect;
		}
		
		public function set sendNetStream(value:NetStream):void
		{
			p2p_pipe.sendNetStream = value;
		}
		
		public function get canRecieved():Boolean
		{
			return p2p_pipe.canRecieved;
		}
		
		public function set canRecieved(value:Boolean):void
		{
			p2p_pipe.canRecieved = value;
		}
		
		public function get canSend():Boolean
		{
			return p2p_pipe.canSend;
		}
		
		public function set canSend(value:Boolean):void
		{
			p2p_pipe.canSend = value;
		}
		
		public function get remoteID():String
		{
			return p2p_pipe.remoteID;
		}
		
		public function get remoteName():String
		{
			return p2p_pipe.remoteName;
		}
		
		public function get groupID():String
		{
			return p2p_pipe.groupID;
		}
		
		public function connectSuccess(obj:Object):void
		{
			isConnect = (obj as Boolean); 
		}
		
	}
}