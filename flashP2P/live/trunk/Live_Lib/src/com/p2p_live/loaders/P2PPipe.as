package com.p2p_live.loaders
{

	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p_live.data.Block;
	import com.p2p_live.data.Chunk;
	import com.p2p_live.data.Piece;
	import com.p2p_live.data.SendData;
	import com.p2p_live.data.WantData;
	import com.p2p_live.events.P2PEvent;
	import com.p2p_live.events.P2PLoaderEvent;
	
	import com.p2p_live.managers.DataManager;
	import com.p2p.utils.CRC32;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.*;
	import flash.net.NetGroup;
	import flash.net.NetStream;
	import flash.sampler.Sample;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	public class P2PPipe extends EventDispatcher
	{
		/////////////////////////////////////////
		// 需要外部传入的参数
		private var _p2pConnection:NetConnection;
		private var _dataManager:DataManager;
		private var _p2pWaitTaskList:Object;
		public var _canRecieved:Boolean = false;
		public var _canSend:Boolean = false;
		public var remotePlayHead:uint;
		/////////////////////////////////////////
		// 管道内部参数
		public var _sendNetStream:NetStream    = null;
		protected var _receiveNetStream:NetStream = null;
		protected var _remoteID:String;
		protected var _recieverTimer:Timer;
		
		protected var beginTime:Number = 0;
		private   var _gName:String;
		
		public function P2PPipe(p2pConn:NetConnection, dataMgr:DataManager, p2pwait:Object, gName:String) :void
		{
			_p2pConnection    = p2pConn;
			_dataManager      = dataMgr;
			_p2pWaitTaskList  = p2pwait;
			//
			beginTime         = Math.floor((new Date()).time);
			_gName            = gName;
		}
		public function isDead():Boolean
		{
			return (Math.floor((new Date()).time) - beginTime) > (13 * 1000);
		}
		public function clear():void
		{
			_canRecieved = false;
			_canSend     = false;
//--------------------------------------------------------------------------------------------------
			//************************************************************
			if(_dataManager&&_dataManager.blockList){
				_dataManager.blockList.handlerTimeOutWantPiece(_remoteID,true);
			}
			//************************************************************
			/*for each( var task:* in _p2pWaitTaskList )
			{
				if( task.status == _remoteID )
				{
					task.status = "wait";
				}
			}*/
//--------------------------------------------------------------------------------------------------
			if(_dataManager.userName[_remoteID])
			{
				delete _dataManager.userName[_remoteID];
			}
			if(_dataManager.userName[_remoteID+"state"])
			{
				delete _dataManager.userName[_remoteID+"state"];
			}
			
			if(_recieverTimer)
			{
				_recieverTimer.removeEventListener(TimerEvent.TIMER, recieverTimer );
				_recieverTimer.stop();
				_recieverTimer = null
			}
			//
			if (_receiveNetStream)
			{
				_receiveNetStream.removeEventListener(NetStatusEvent.NET_STATUS,StatusHandler);
				_receiveNetStream.close();
				_receiveNetStream = null;
			}
		}
		//
		//private var _peerHartBeatTimer:Timer;
		public function initPipe(nearID:String, farID:String):void
		{
			_remoteID  = farID;
			_recieverTimer = new Timer(0);
			_recieverTimer.addEventListener(TimerEvent.TIMER, recieverTimer );
			_recieverTimer.start();
			
			_dataManager.userName[_remoteID] = _remoteID;
		}
		//
		public function pipeConnected():Boolean
		{
			
			return _canRecieved && _canSend;			
		}
		private function recieverTimer(event:TimerEvent):void
		{
			_recieverTimer.delay = 7*1000;
			//
			if (_p2pConnection && _p2pConnection.connected)
			{
				if (_canRecieved == false)
				{
					if (null == _receiveNetStream)
					{
						_receiveNetStream = new NetStream(_p2pConnection, _remoteID);
						_receiveNetStream.dataReliable = true;
						_receiveNetStream.addEventListener(NetStatusEvent.NET_STATUS, StatusHandler);
						_receiveNetStream.client = this;
					}
					//
					_receiveNetStream.play(_gName/*_remoteID*/);
					//
					return;
				}
				else
				{
					_recieverTimer.stop();
				}
			}
			//
			
			
		}
		/*private function getPeerRequstCount():uint
		{
			var iCount:uint = 0;
			for each(var task:* in _p2pWaitTaskList)
			{
				if (task.status == _remoteID)
				{
					iCount ++;
					if (iCount > 3)
						return iCount;
				}
			}
			//
			return iCount;
		}*/
		
		private function getWaitCount():uint
		{
			var iCount:uint = 0;
			for each(var peerWait:* in _p2pWaitTaskList)
			{
				if (peerWait.status == "wait")
				{
					iCount ++;
					return iCount;
				}
			}
			//
			return iCount;
		}
		
		public function pipeprocess(obj:Object):void
		{
			_canRecieved = true;
			
			var bty:ByteArray = obj.obj;
			try
			{
				bty.uncompress();
				obj = bty.readObject() as Object;
			}
			catch(e:Error)
			{
				trace("解压出错");
				return;
			}
			
			var chunkID:uint = 0; //用于过程处理的局部循环变量,为避免编译器警告,提前声明			
			_dataManager.userName[_remoteID] = obj.userName;
			
			if( obj.mstype=="requestData" )
			{
				// 收到数据请求,因为远端发送请求前会检查我是否有数据,所以这里可以直接发送
				var remoteRequestDataVector:Vector.<Object> = obj.msdata as Vector.<Object>;
				for( var i:int=0 ; i<remoteRequestDataVector.length ; i++ )
				{
				    sendData(remoteRequestDataVector[i]);
					
					//trace("对方请求 pieceID= "+remoteRequestDataVector[i].blockID+"_"+remoteRequestDataVector[i].pieceID);					
				}
			}
			else if( obj.mstype == "sendData" )
			{
				// 接收到远端发来数据
				//************************************************************				
				var sendDataor:Object = obj.msdata as Object;
				var _object:Object = new Object();
				
				_object.type       = "DataResult";
				_object.from       = "p2p";
				_object.peerID     = obj.userName;
				_object.id         = sendDataor.blockID;
				_object.pieceID    = sendDataor.pieceID;				
				_object.data       = sendDataor.data;
				_object.checksum   = sendDataor.checksum;				
				_dataManager.writeData(new P2PLoaderEvent(P2PLoaderEvent.CHANGE_SITUATION,_object));
				//
				
				trace("收到数据  pieceID= "+sendDataor.blockID+"_"+sendDataor.pieceID);
				
				//
				_object = null;
				//
				peerHartBeatTimer();
				//************************************************************
			}
			else if( obj.mstype == "addHave" )
			{
				// 收到远端发来通知有数据的消息				
				//************************************************************
				if(obj.msdata is Vector.<Object>)
				{
					var remoteHaveDataVector:Vector.<Object> = obj.msdata as Vector.<Object>;
				}
				else
				{
					return;
				}
				if(remoteHaveDataVector && remoteHaveDataVector.length>0)
				{
					var myWantDataVector:Vector.<Object> = _dataManager.blockList.getWantPiece(remoteHaveDataVector,_remoteID);
					/**
					 * myWantDataVector元素的数据结构
					 * obj.blockID;
					 * obj.pieceID;
					 * obj.cs;
					 * */
					if(myWantDataVector && myWantDataVector.length>0)
					{
						/**当sendMessage()返回false时，需要将刚分配的
					    * getWantPiece列表设置成未分配状态···，暂时不解决。
						*/
						var str:String="";
/*
						for(var m:int=0 ; m<myWantDataVector.length ; m++)
						{
							str+=("本地请求 pieceID= "+myWantDataVector[m].blockID+"_"+myWantDataVector[m].pieceID+"\n");
						}
						trace(str);
*/
						sendMessage("requestData",0,myWantDataVector);
					}
				}
				//************************************************************
			}
			else if( obj.mstype == "removeHave" )
			{
				//************************************************************
				_dataManager.blockList.handlerTimeOutWantPiece(obj.userName,false,obj.msidID);
				//************************************************************
			}
			else if( obj.mstype == "heartBeat" )
			{
				if( obj.msidID > 0 )
				{
					//************************************************************
					doAddHave(obj.msidID);
					//************************************************************
					//stupid(obj.msidID);
				}
				else
				{
					sendMessage("respondHeartBeat",0);
				}
			}
		}
		
		public function peerHartBeatTimer(/*event:* = null*/rg:Object=null):void
		{	
			if (_canSend && _sendNetStream)
			{
				//sendMessage("heartBeat", _dataManager.httpDownloadingTask/*, getWaitCount()*/);
				sendMessage("heartBeat", _dataManager.playHead);
			}
			//***********************************************************************
			_dataManager.blockList.handlerTimeOutWantPiece(_remoteID);
			//***********************************************************************
		}
		//
		private function doAddHave(iRHead:uint):void
		{
			if (_dataManager && _canSend && _sendNetStream && _p2pConnection && _p2pConnection.connected)
			{
				var idVector:Vector.<Object> = _dataManager.blockList.getPlayHeadAfterData(iRHead);
				/**
				 * idVector元素的数据结构
				 * obj.blockID;
				 * obj.pieceID;
				 * obj.cs;
				 * */
				if(idVector != null && idVector.length>0)
				{					
					sendMessage("addHave",0,idVector);					
				}
				remotePlayHead = iRHead;
			}
		}
		//
		private function sendMessage(mstype:String, chunkStart:uint,messagedata:* = null/*messagedata:ByteArray=null*/):Boolean 
		{
			var obj:Object = new Object;
			obj.mstype     = mstype;
			obj.msidID     = chunkStart;
			obj.userName   = _dataManager.userName["myName"];			
			obj.msdata     = messagedata;
			//------------------------------
			if (_canSend && _sendNetStream && _p2pConnection && _p2pConnection.connected)
			{
				var bty:ByteArray = new ByteArray();
				bty.writeObject(obj);
				bty.compress();
				var send:Object = new Object();
				send.obj = bty;
				_sendNetStream.send("pipeprocess", send);
				return true;
			}
			//
			return false;
		}
		//		
		private function sendData(wantData:Object):void
		{
			//***********************************************************************
			var bl:Block = _dataManager.blockList.getBlock(wantData.blockID);
			if(bl)
			{
				var piece:Piece = bl.pieces[wantData.pieceID];
				if(piece && piece.iLoadType == 3 && piece.stream != null/*sendDataor.data != null*/)
				{
					var sendDataor:Object = new Object();
					//sendDataor.blockID = wantData.blockID;
					//sendDataor.pieceID = wantData.pieceID;
					sendDataor.blockID = bl.id;
					sendDataor.pieceID = piece.id;
					sendDataor.data    = piece.stream;
					sendDataor.checksum = bl.checksum;
					MZDebugger.rectTrace({"type":"p2pGetDate","blockID":bl.id,"pieceID":piece.id});
					sendMessage("sendData", 0, sendDataor );
					
					_dataManager.weightPlus(bl.id,piece.id,String(_dataManager.userName[_remoteID]).substr(0,10));
					
					piece.share++;
					//trace("share = "+bl.id+"_"+piece.id+" ;count = "+piece.share+" ;to = "+String(_dataManager.userName[_remoteID]).substr(0,5));
					
					return;
				}
			}			
			sendMessage("sendData", 0, null );
			
		}
		//
		public function removeHave(chunkStart:uint, chunkEnd:uint):void
		{
			sendMessage("removeHave", chunkStart/*, chunkEnd*/ );
		}
		//
		private function StatusHandler(event:NetStatusEvent = null):void
		{
			switch (event.info.code)
			{
				case "NetStream.Connect.Success":
					_canRecieved = true;
					//trace("--------------time Success= "+(Math.floor((new Date()).time)-tempTime));
					break;
				case "NetStream.Connect.Closed":
					_canRecieved = false;
					//trace("--------------time Closed= "+(Math.floor((new Date()).time)-tempTime));
					break;
				default : 
					break;
			}
		}
		
	}
}