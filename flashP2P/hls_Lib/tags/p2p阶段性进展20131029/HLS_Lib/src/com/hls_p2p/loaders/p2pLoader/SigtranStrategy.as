package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.data.vo.ReceiveData;
	import com.hls_p2p.dispatcher.IDispatcher;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	public class SigtranStrategy
	{
		public var isDebug:Boolean=false;
		
		private var p2p_pipe:P2P_Pipe;
		
		public var remoteNearestWantID:Number = Number.MIN_VALUE;
		
		protected var _recieverTimer:Timer;
		/**P2PLoader调用的心跳接口，与节点建立索要数据的互动，将本地的下载位置发送给对方节点*/
//		private var _NearestWantID:Number = 0;
		protected var p2pCluster:P2P_Cluster				= null;
		protected var dispather:IDispatcher					= null;
		protected var client_type:String 					= "PC";
		public var requestArr:Array 						= new Array;
		protected var beginTime:Number 						= 0;
		protected var isConnect:Boolean						= false;
		public function SigtranStrategy(p_p2p_pipe:P2P_Pipe,p2pCluster:P2P_Cluster,dispather:IDispatcher)
		{
			this.p2p_pipe				= p_p2p_pipe;
			this.p2pCluster	 			= p2pCluster;
			this.dispather 				= dispather;
			p2p_pipe.connectSuccess		= connectSuccess;
			p2p_pipe.dataSuccess		= dataSuccess;
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
		
		public function get groupID():String
		{
			return p2p_pipe.groupID;
		}
		
		public function connectSuccess(obj:Object):void
		{
			isConnect = (obj as Boolean); 
		}
		
		public function pipeConnected():Boolean
		{
			return canSend && canRecieved;
			//return isConnect;
		}
		public function removeHave(peiceKeyArray:Array):void
		{
			p2p_pipe.sendData("removeHave",peiceKeyArray);
		}
		public function doAddHave():void
		{
			//p2pload call
			if (remoteNearestWantID == Number.MIN_VALUE)
			{
				return;
			}
			//
			if (dispather && canSend && p2p_pipe.sendNetStream && p2p_pipe.p2pConnection && p2p_pipe.p2pConnection.connected)
			{
				/**
				 * idVector元素的数据结构
				 * obj.blockID;
				 * obj.pieceID;
				 * obj.cs;
				 * */
				var idVector:Array;
				idVector = dispather.getDataAfterPoint(groupID,remoteNearestWantID);

				if(idVector != null && idVector.length>0)
				{								
					p2p_pipe.sendData("addHave",idVector);
				}
			}
		}
		public function sendRequest(pieceList:Array):void
		{
			if(requestArr.length>0)
			{
				return;
			}
			if(pieceList && pieceList.length>0)
			{
				p2p_pipe.sendData("requestData",pieceList);
				for (var j:int = 0; j < pieceList.length; j++)
				{
					requestArr.push(pieceList[j]);
				}
			}
		}
//		public function sendRequest():void
//		{
//			if(requestArr.length>0)
//			{
//				return;
//			}/**/
//			
//			var myWantData:Array = dispather.getWantPiece(String(remoteNearestWantID));//_dispather.getWantPiece(remoteHaveData,_remoteID);
//			/**
//			 * myWantData元素的数据结构
//			 * obj.blockID;
//			 * obj.pieceID;
//			 * */
//			if(myWantData && myWantData.length>0)
//			{
//				/**
//				 * 输出面板显示，向对方节点所取数据
//				 * */
//				Statistic.getInstance().P2PWantData(myWantData,remoteID);
//				
//				p2p_pipe.sendData("requestData",myWantData);
//				
//				for (var j:int = 0; j < myWantData.length; j++)
//				{
//					requestArr.push(myWantData[j]);
//				}
//			}
//			
//		}
		
		public function DealRequestData(p_obj:Object):void
		{
			/**收到数据请求,因为远端发送请求前会检查我是否有数据,所以这里可以直接发送*/
			var remoteRequestData:Array = p_obj as Array;
			if(!remoteRequestData)
			{
				return;
			}

			for( var i:int=0 ; i<remoteRequestData.length; i++ )
			{
				Statistic.getInstance().peerWantData(remoteRequestData[i],remoteID);
				
				var tmpPiece:Piece =  dispather.getPiece(
					{
						"groupID":this.groupID,
						"type":remoteRequestData[i].type,
						"pieceKey":remoteRequestData[i].pieceKey
					}
				)
				
				if(tmpPiece && tmpPiece.iLoadType == 3 && tmpPiece.getStream().length>0)
				{
					var sendData:Object = new Object();
					sendData.type		= tmpPiece.type;
					sendData.pieceKey	= tmpPiece.pieceKey;
					sendData.data		= tmpPiece.getStream();
					p2p_pipe.sendData("sendData",sendData);
				}
			}
		}
		
		public function DealAddHaveRequest(p_obj:Object):void
		{
			/**收到远端发来通知有数据的消息*/			
			var remoteHaveData:Array = p_obj as Array;
			
			for( var m:int=0 ; m<remoteHaveData.length ; m++ )
			{
				handlerRemoteHaveData(remoteHaveData[m]);
			}
//			sendRequest();
		}
		
		private function handlerRemoteHaveData(p_obj:Object):void
		{			
			/**
			 * obj数据结构
			 * obj.bID:Number
			 * obj.pIDArr:Array = [int,int ...]
			 * */
			var tmpPiece:Piece =  dispather.getPiece(
				{
					"groupID":this.groupID,
					"type":p_obj.type,
					"pieceKey":p_obj.pieceKey
				}
			)
			if(tmpPiece.peerHaveData.indexOf(remoteID) == -1)
			{
				tmpPiece.peerHaveData.push(remoteID);
			}
		}
		
		public function DealReceiveData(p_obj:Object):void
		{
			/**接收到远端发来数据*/ 
			if(p_obj)
			{
				var sendData:Object = p_obj as Object;
				
				if(sendData && (sendData.data as ByteArray).length>0)
				{
					var tmpPiece:Piece =  dispather.getPiece(
						{
							"groupID":this.groupID,
							"type":sendData.type,
							"pieceKey":sendData.pieceKey
						}
					)
					if(tmpPiece){	
						tmpPiece.setStream((sendData.data as ByteArray));
						deleteFinishedTask(
							{
								"type":sendData.type,
								"pieceKey":sendData.pieceKey
							}
						);
					}
					//
					
				}
			}
			
//			sendRequest();
		}
		
		
		public function dataSuccess(name:String,data:Object=null,type:String=null):void
		{
			beginTime = getTime();
			P2PDebug.traceMsg(this,"dataSuccess:"+name);
			switch(name)
			{
				case "heartBeat":
//					data.maxLoadPos = maxLoadPos;
					if(data.NearestWantID>=0)
					{
						remoteNearestWantID=data.NearestWantID;
						doAddHave();
					}
//					else
//					{
//						sendMessage("respondHeartBeat",0);
//					}
					break;
				case "requestData":
					DealRequestData(data)
					break;
				case "addHave":
					DealAddHaveRequest(data);
					break;
				case "sendData":
					DealReceiveData(data);
					break;
				case "removeHave":
					
					break;
			}
		}
		
		public function peerHartBeatTimer(NearestWantID:Number, maxLoadPos:Number=-1):void
		{	
			if (p2p_pipe.canSend && p2p_pipe.canRecieved && p2p_pipe.sendNetStream)
			{
				var data:Object = new Object;
				data.NearestWantID = NearestWantID;
				data.maxLoadPos = maxLoadPos;
				p2p_pipe.sendData("heartBeat", data);
			}	
//			//
			checkTimeout();
//			sendRequest();
		}
		
		private function checkTimeout():void
		{
			if(requestArr)
			{
				var i:int=requestArr.length;
				while(i>0)
				{
					i--;

					var tmpPiece:Piece =  dispather.getPiece(
						{
							"groupID":this.groupID,
							"type":requestArr[i].type,
							"pieceKey":requestArr[i].pieceKey
						}
					)
						
					if(tmpPiece)
					{
						if(tmpPiece.getStream().length>0)
						{
							requestArr.splice(i,1);
							continue;
						}
						if(getTime()-tmpPiece.begin>5*1000)
						{
							tmpPiece.reset(remoteID);
							requestArr.splice(i,1);
						}
					}
				}
			}
		}
		//
		public function isDead():Boolean
		{return false;
			return (Math.floor((new Date()).time) - beginTime) > (13 * 1000);
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			
		}
		
		////////////////////////////////////////////////////////////////////////
		private function deleteFinishedTask(obj:Object):void
		{
			for (var i:int = 0; i < requestArr.length; i++)
			{
				if(requestArr[i].pieceKey== obj.pieceKey && 
					requestArr[i].type== obj.type)
				{
					requestArr.splice(i, 1);
					//
					return;
				}
			}
		}
		
			
		public function releaseRequestData():void
		{
			
			if(dispather)
			{
				var obj:Object;
				while(obj = requestArr.pop())
				{
					var tmpPiece:Piece =  dispather.getPiece(
						{
							"groupID":this.groupID,
							"type":obj.type,
							"pieceKey":obj.pieceKey
						}
					)
					for(var i:uint=0;i<tmpPiece.peerHaveData.length;i++)
					{
						if(tmpPiece.peerHaveData[i] == this.remoteID)
						{
							tmpPiece.peerHaveData.splice(i, 1);
						}
					}
				}
			}
		}
	}
}