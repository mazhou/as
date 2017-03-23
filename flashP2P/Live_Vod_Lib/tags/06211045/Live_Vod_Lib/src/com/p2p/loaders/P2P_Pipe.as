package com.p2p.loaders
{
	import com.p2p.data.Block;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.Piece;
	import com.p2p.data.vo.ReceiveData;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventWithData;
	import com.p2p.logs.P2PDebug;
	import com.p2p.utils.CRC32;
	import com.p2p.statistics.Statistic;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	public class P2P_Pipe extends EventDispatcher
	{
		public var canRecieved:Boolean = false;
		public var canSend:Boolean = false;
		public var remotePlayHead:String;
		/**对方的用户名*/
		public var remoteName:String;
		/**发送器*/
		public var sendNetStream:NetStream = null;
		/**接收器*/
		protected var _receiveNetStream:NetStream = null;
		
		private var _p2pConnection:NetConnection;
		/**播放器传递的参数*/
		private var _initData:InitData
		/**声明调度器*/
		private var _dispather:IDataManager;
		
		protected var _remoteID:String;
		protected var _recieverTimer:Timer;
		
		protected var beginTime:Number = 0;
		private   var _gName:String;
		
		public function P2P_Pipe(p2pConn:NetConnection,dispather:IDataManager,gName:String) :void
		{
			_p2pConnection = p2pConn;
			_dispather     = dispather;
			beginTime      = Math.floor((new Date()).time);
			_gName         = gName;
		}
		public function isDead():Boolean
		{
			return (Math.floor((new Date()).time) - beginTime) > (13 * 1000);
		}
		public function clear():void
		{
			canRecieved = false;
			canSend     = false;
			
			if(_dispather)
			{
				_dispather.handlerTimeOutWantPiece(_remoteID);	
				_dispather = null;
			}
			/**原来版本需要清理userName列表，目前无userName列表,不用清理
			 * 
			 * 输出面板需要peer信息：
			 * 用户名：  remoteName；
			 * 连接状态：pipeConnected()；
			 * 
			 * */
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

		public function initPipe(farID:String):void
		{
			_remoteID = remoteName = farID;
			_recieverTimer = new Timer(0);
			_recieverTimer.addEventListener(TimerEvent.TIMER, recieverTimer );
			_recieverTimer.start();
		}
		//
		public function pipeConnected():Boolean
		{			
			return canRecieved && canSend;			
		}
		private function recieverTimer(event:TimerEvent):void
		{
			_recieverTimer.delay = 7*1000;
			//
			if (_p2pConnection && _p2pConnection.connected)
			{
				if (canRecieved == false)
				{
					if (null == _receiveNetStream)
					{
						try
						{
							_receiveNetStream = new NetStream(_p2pConnection, _remoteID);
						}
						catch(err:Error)
						{
							P2PDebug.traceMsg(this,err.getStackTrace());
						}
						
						_receiveNetStream["dataReliable"] = true;
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
		}
		
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
		*/
		public function pipeprocess(obj:Object):void
		{
			canRecieved = true;
			
			var bty:ByteArray = obj.obj;
			try
			{
				bty.uncompress();
				obj = bty.readObject() as Object;
			}
			catch(e:Error)
			{
				P2PDebug.traceMsg(this,"pipeprocess解压出错！！");
				return;
			}
			
			var chunkID:uint = 0; //用于过程处理的局部循环变量,为避免编译器警告,提前声明			
			/**接受对方名称*/
			remoteName = obj.userName;
			
			if( obj.mstype=="requestData" )
			{
				/**收到数据请求,因为远端发送请求前会检查我是否有数据,所以这里可以直接发送*/
				var remoteRequestData:Array = obj.msdata as Array;
				if(!remoteRequestData)
				{
					return;
				}
				for( var i:int=0 ; i<remoteRequestData.length ; i++ )
				{					
					/**
					 *输出面板显示 
					*/
					Statistic.getInstance().peerWantData(remoteRequestData[i],remoteName);
					
				    sendData(remoteRequestData[i]);
					
					//Debug.traceMsg(this,"对方请求 pieceID= "+remoteRequestData[i].blockID+"_"+remoteRequestData[i].pieceID);					
				}
			}
			else if( obj.mstype == "sendData" )
			{
				/**接收到远端发来数据*/ 
				if(obj.msdata)
				{
					var sendDataor:Object = obj.msdata as Object;
				
					if(sendDataor)
					{
						//_dispather.addByte(sendDataor.blockID,sendDataor.pieceID,sendDataor.data,0,0,"p2p",remoteName);
						var data:ReceiveData = new ReceiveData();
						data.blockID = sendDataor.blockID;
						data.pieceID = sendDataor.pieceID;
						data.data    = sendDataor.data as ByteArray;
						data.begin   = 0;
						data.end     = 0;
						data.from    = "p2p";
						data.remoteName = remoteName;
						_dispather.addByte(data);
						P2PDebug.traceMsg("收到数据  pieceID= "+sendDataor.blockID+"_"+sendDataor.pieceID);
					}
				}
				
				peerHartBeatTimer();				
			}
			else if( obj.mstype == "addHave" )
			{
				/**收到远端发来通知有数据的消息*/			
				if(obj.msdata is Array)
				{
					var remoteHaveData:Array = obj.msdata as Array;
				}
				else
				{
					return;
				}
				if(remoteHaveData && remoteHaveData.length>0)
				{					
					var myWantData:Array = _dispather.getWantPiece(remoteHaveData,_remoteID);
					/**
					 * myWantData元素的数据结构
					 * obj.blockID;
					 * obj.pieceID;
					 * */
					if(myWantData && myWantData.length>0)
					{
						/**当sendMessage()返回false时，需要将刚分配的
					    * getWantPiece列表设置成未分配状态···，暂时没有解决。
						*/
						var str:String="";
/*
						for(var m:int=0 ; m<myWantDataVector.length ; m++)
						{
							str+=("本地请求 pieceID= "+myWantDataVector[m].blockID+"_"+myWantDataVector[m].pieceID+"\n");
						}
						Debug.traceMsg(str);
*/						
						/**
						 * 输出面板显示，向对方节点所取数据
						 * */
						Statistic.getInstance().P2PWantData(myWantData,remoteName);
						
						sendMessage("requestData",0,myWantData);
					}
				}
			}
			else if( obj.mstype == "removeHave" )
			{
				_dispather.handlerTimeOutWantPiece(obj.userName);				 
			}
			else if( obj.mstype == "heartBeat" )
			{
				if( obj.msidID != "0" )
				{
					doAddHave(obj.msidID);
				}
				else
				{
					sendMessage("respondHeartBeat",0);
				}
			}
		}
		/**P2PLoader调用的心跳接口，与节点建立索要数据的互动，将本地的下载位置发送给对方节点*/
		public function peerHartBeatTimer(/*event:* = null*/rg:Object=null):void
		{	
			if (canSend && sendNetStream)
			{
				sendMessage("heartBeat",_dispather.getNearestWantID());								
			}			
			//_dispather.handlerTimeOutWantPiece(_remoteID);			
		}
		/**根据远方节点心跳发送的piece索引，进行查找该索引之后拥有数据的离散数组*/
		private function doAddHave(iRHead:String):void
		{
			if (_dispather && canSend && sendNetStream && _p2pConnection && _p2pConnection.connected)
			{
				/**
				 * idVector元素的数据结构
				 * obj.blockID;
				 * obj.pieceID;
				 * obj.cs;
				 * */
				var idVector:Array = _dispather.getDataAfterPoint(iRHead);
				if(idVector != null && idVector.length>0)
				{					
					sendMessage("addHave",0,idVector);					
				}
				remotePlayHead = iRHead;
			}
		}
		//
		private function sendMessage(mstype:String, chunkStart:*,messagedata:* = null/*messagedata:ByteArray=null*/):Boolean 
		{
			var obj:Object = new Object;
			obj.mstype     = mstype;
			obj.msidID     = chunkStart;
			/**
			obj.userName   = _dispather.myName;	
			 * */
			obj.userName   = LiveVodConfig.MY_NAME;
			obj.msdata     = messagedata;
			//------------------------------
			if (canSend && sendNetStream && _p2pConnection && _p2pConnection.connected)
			{
				var bty:ByteArray = new ByteArray();
				bty.writeObject(obj);
				bty.compress();
				var send:Object = new Object();
				send.obj = bty;
				sendNetStream.send("pipeprocess", send);
				return true;
			}
			//
			return false;
		}
		//为远程发送数据调用的方法	
		private function sendData(wantData:Object):void
		{
			/**
			 * wantData的数据结构为：
			 * wantData:Object
			 * wantData.blockID
			 * wantData.pieceID
			 * */
			
			var bl:Block = _dispather.getBlock(wantData.blockID);
			
			if(bl && bl.isChecked)
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
					sendDataor.checkSum = bl.checkSum;
					P2PDebug.traceMsg(this,"p2pSendDate  blockID = "+bl.id+"; pieceID = "+piece.id);
					sendMessage("sendData", 0, sendDataor );
					/**
					 * 将分享piece的消息公布出去，便于显示面板调试
					 * 输出面板上报*/
					Statistic.getInstance().P2PShareData(String(bl.id+"_"+piece.id),remoteName);
					/**增加piece的share值*/
					piece.share++;
					//Debug.traceMsg("share = "+bl.id+"_"+piece.id+" ;count = "+piece.share+" ;to = "+String(remoteName).substr(0,5));
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
					canRecieved = true;
					//Debug.traceMsg("--------------time Success= "+(Math.floor((new Date()).time)-tempTime));
					break;
				case "NetStream.Connect.Closed":
					canRecieved = false;
					//Debug.traceMsg("--------------time Closed= "+(Math.floor((new Date()).time)-tempTime));
					break;
				default : 
					break;
			}
		}
		
	}
}