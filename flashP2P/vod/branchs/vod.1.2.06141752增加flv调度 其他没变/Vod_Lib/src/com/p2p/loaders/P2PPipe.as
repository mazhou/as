package com.p2p.loaders
{

	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.data.Chunk;
	import com.p2p.data.Chunks;
	import com.p2p.events.P2PEvent;
	import com.p2p.events.P2PLoaderEvent;
	import com.p2p.managers.DataManager;
	import com.p2p.utils.CRC32;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;	
	import flash.events.AsyncErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.*;
	//import flash.net.NetGroup;;
	import flash.net.NetStream;
	import flash.sampler.Sample;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;

	public class P2PPipe extends EventDispatcher
	{
		//////////////////////////////////////////
		// 需要外部传入的参数
		private var _p2pConnection:NetConnection;
		private var _dataManager:DataManager;
		private var _p2pWaitTaskList:Object;
		public var _canRecieved:Boolean = false;
		public var _canSend:Boolean = false;
		
		/////////////////////////////////////////
		// 管道内部参数
		//public var _sendNetStream:NetStream    = null;
		//protected var _receiveNetStream:NetStream = null;
		public var XNetStream:NetStream     = null;
		public var ExtraNetStream:NetStream = null;
		protected var _remoteID:String;
		protected var _recieverTimer:Timer;
		
		protected var beginTime:Number = 0;
		private   var _gName:String;
		private   var _p2PLoader:P2PLoader; 
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
			
			for each( var task:* in _p2pWaitTaskList )
			{
				if( task.status == _remoteID )
				{
					task.status = "wait";
				}
			}
			
			if( _dataManager && _dataManager.userName && _dataManager.userName[_remoteID])
			{
				delete _dataManager.userName[_remoteID];
			}
			if( _dataManager && _dataManager.userName && _dataManager.userName[_remoteID+"state"])
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
			if (XNetStream)
			{		
				try
				{
					XNetStream.close();
					XNetStream.removeEventListener(NetStatusEvent.NET_STATUS,StatusHandler);
				}catch(e:Error)
				{
					//trace(e);
				}

				XNetStream = null;
			}
			if( ExtraNetStream )
			{
				try
				{
					ExtraNetStream.close();
				}
				catch(e:Error)
				{
					
				}
				ExtraNetStream = null;
			}
			//			
			_p2pConnection    = null;
			_dataManager      = null;
			_p2pWaitTaskList  = null;
			_p2PLoader        = null;
			/**/
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
			//trace("&&&&&  "+(_canRecieved && _canSend))
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
					if (null == XNetStream)
					{
						try
						{
							XNetStream = new NetStream(_p2pConnection, _remoteID);
							XNetStream["dataReliable"] = true;
							XNetStream.addEventListener(NetStatusEvent.NET_STATUS, StatusHandler);
							XNetStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
							XNetStream.client = this;
						}
						catch(err:Error)
						{
							_canRecieved = false;												
							if( XNetStream.hasEventListener(NetStatusEvent.NET_STATUS) )
							{
								XNetStream.removeEventListener(NetStatusEvent.NET_STATUS, StatusHandler);
							}
							if( XNetStream.hasEventListener(AsyncErrorEvent.ASYNC_ERROR) )
							{
								XNetStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
							}
							XNetStream = null;
							return;
						}
					}
					
					//
					XNetStream.play(_gName/*_remoteID*/);
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
		private function getPeerRequstCount():uint
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
				
		public function pipeprocess(obj:Object):void
		{
			var bty:ByteArray = obj.obj;
			try
			{
				bty.uncompress();
			    obj = bty.readObject() as Object;
			}
			catch(e:Error)
			{
				return;
			}
			
			_canRecieved = true;
			_canSend   	 = true;
			beginTime    = Math.floor((new Date()).time);
			
			//trace("obj = "+obj.mstype)
			
			var chunkID:uint = 0; //用于过程处理的局部循环变量,为避免编译器警告,提前声明			
			_dataManager.userName[_remoteID] = obj.userName;
			if( obj.mstype=="requestData" )
			{
				// 收到数据请求,因为远端发送请求前会检查我是否有数据,所以这里可以直接发送
				for( chunkID =obj.msidstart; chunkID<=obj.msidend; chunkID++ )
				{
					sendData(chunkID);
				}
			}
			else if( obj.mstype == "sendData" )
			{
				// 接收到远端发来数据
				var _object:Object = new Object();
				_object.type       = "DataResult"	;
				_object.id         = uint(obj.msidstart);
				_object.from       = "p2p";
				_object.peerID     = obj.userName;
				_object.data       = obj.msdata;
				
				//trace("receive = "+_object.id);
				
				var ch:Chunk = _dataManager.chunks.getChunk( _object.id );
				if(_p2pWaitTaskList[_object.id] && ch != null && ch.iLoadType != 3)
				{
					_object["begin"] = _p2pWaitTaskList[_object.id]["beginTime"];
				}
				
				if (_object.data != null && _dataManager.writeData(new P2PLoaderEvent(P2PLoaderEvent.CHANGE_SITUATION,_object)))
				{
					if (_p2pWaitTaskList[_object.id])
						delete _p2pWaitTaskList[_object.id];
				}else
				{
					if (_p2pWaitTaskList[_object.id])
						_p2pWaitTaskList[_object.id].status = "wait";
				}
				//
				_object = null;
				//
				peerHartBeatTimer();
			}
			else if( obj.mstype == "removeHave" )
			{
				for( chunkID = obj.msidstart; chunkID <= obj.msidend;chunkID++ )
				{
					if( _p2pWaitTaskList[chunkID] && _p2pWaitTaskList[chunkID].status == _remoteID )
					{
						_p2pWaitTaskList[chunkID].status = "wait";
					}
				}
			}
			else if( obj.mstype == "heartBeat" )
			{
				//trace("peer heart________________________!!!")
				if( obj.msidend >= 0 )
				{					
					stupid(obj.msidstart);
				}
				else
				{
					sendMessage("respondHeartBeat",0,0);
				}				
			}
			else if( obj.mstype == "noCheckSum" )
			{
				/**先判断checkSum是否成功加载 lz 0613 add*/
				//trace("obj.mstype")
			}
		}
		
		public function startPeerHaveList(_p2PLoader:P2PLoader):void{
			this._p2PLoader=_p2PLoader;
			if (_dataManager && _canSend && XNetStream && _p2pConnection && _p2pConnection.connected)
			{
				XNetStream.send("getPeerList");
			}
		}
		//获得临近节点的临近节点列表请求
		public function getPeerList():void
		{
			if (_dataManager && _canSend && XNetStream && _p2pConnection && _p2pConnection.connected&&_p2PLoader)
			{
				var bty:ByteArray = new ByteArray();
				bty.writeObject(_p2PLoader.getPeerList())
				bty.compress();
				var obj:Object = new Object();
				obj.obj = bty;
				XNetStream.send("peerListHandler",obj);
			}
		}
		//获得临近节点的临近节点列表
		public function peerListHandler(obj:Object):void
		{
			var bty:ByteArray = obj.obj;
			
			try
			{
				bty.uncompress();
				obj = bty.readObject() as Object;
			}
			catch(e:Error)
			{
				//trace("peerListHandler 解压出错");
				return;
			}
			
			if(_p2PLoader){
				_p2PLoader.setPeerList(obj);
			}
		}
		
		public function addHave(obj:Object):void
		{
			var bty:ByteArray = obj.obj;
			//trace("i want ");
			try
			{
				bty.uncompress();
				obj = bty.readObject() as Object;
			}
			catch(e:Error)
			{
				//trace("解压addHave出错");
				return;
			}
			
			//
			for (var i:String in obj)
			{
				for( var chunkID:uint = obj[i].start; chunkID <= obj[i].end; chunkID++ )
				{
					if(_p2pWaitTaskList[chunkID] &&  _p2pWaitTaskList[chunkID].status == "wait" )
					{
						if (getPeerRequstCount() < 3)
						{
							if (sendMessage("requestData", chunkID, chunkID))
							{
								//trace("want "+chunkID);
								_p2pWaitTaskList[chunkID].status    = _remoteID;
								_p2pWaitTaskList[chunkID].beginTime = Math.floor((new Date()).time);
							}
						}else return;
					}
				}
			}
		}
		//
		public function peerHartBeatTimer(rg:Object=null):void
		{	
			//trace("_canSend       = "+_canSend)
			//trace("_sendNetStream = "+_sendNetStream)
			//trace("getWaitCount()       = "+getWaitCount())
			//trace("getPeerRequstCount() = "+getPeerRequstCount())
			if (_canSend && XNetStream)
			{
				/**先判断checkSum是否成功加载 lz 0613 add*/
				if(_dataManager.isCheckSumSuccess)
				{
					if (getWaitCount() > 0 && getPeerRequstCount() <3)
					{
					 	sendMessage("heartBeat", _dataManager.playHead, getWaitCount());
					}
				}
				else
				{
					sendMessage("noCheckSum", _dataManager.playHead, 0);
				}
			}
			//
			for each(var task:* in _p2pWaitTaskList)
			{
				if (task.status == _remoteID)
				{
					if (Math.floor(( Math.floor((new Date()).time) - task.beginTime) / 1000) > 10)
					{
						task.status = "wait";
					}
				}
			}
		}
		//
		private function stupid(iRHead:uint):void
		{
			if (_dataManager && _canSend && XNetStream && _p2pConnection && _p2pConnection.connected)
			{
				var dataRange:Object = new Object();//_dataManager.getDataRange(iRHead);
				var idx:uint = 0;
				//_dataManager._dataRange.sortOn("start", 16); 
				var range:Array = new Array();// = _dataManager._dataRange;
				for each(var r:* in _dataManager.dataRange)
				{
					range.push(r);
				}
				range.sortOn("start", 16);
				for each(var rg:* in range)
				{
					if (rg.end >= iRHead)
					{
						dataRange[idx] = rg;
						idx++;
					}
				}
				//
				if( dataRange )
				{
					var bty:ByteArray = new ByteArray();
					bty.writeObject(dataRange);
					bty.compress();
					var obj:Object = new Object();
					obj.obj = bty;
					XNetStream.send("addHave", obj);
				}
			}
		}
		//
		private function sendMessage(mstype:String, chunkStart:uint, chunkEnd:uint,messagedata:ByteArray = null):Boolean 
		{
			var obj:Object = new Object;
			obj.mstype     = mstype;
			obj.msidstart  = chunkStart;
			obj.msidend    = chunkEnd;
			obj.msdata     = messagedata;
			obj.userName   = _dataManager.userName["myName"];
			//trace("myName ====== "+String(_dataManager.userName["myName"]).substr(0,10))
			//------------------------------
			if (_canSend && XNetStream && _p2pConnection && _p2pConnection.connected)
			{
		        var bty:ByteArray = new ByteArray();
				bty.writeObject(obj);
				bty.compress();
				var send:Object = new Object();
				send.obj = bty;
				XNetStream.send("pipeprocess", send);
				return true;
			}
			//
			return false;
		}
		//		
		private function sendData(chunkID:uint):void
		{
			var sendDataChunk:Chunk = _dataManager.chunks.getChunk( chunkID )			
			if( sendDataChunk != null && sendDataChunk.iLoadType == 3 && sendDataChunk.data != null)
			{
				_dataManager.weightPlus(chunkID);
				sendMessage("sendData", chunkID, chunkID, sendDataChunk.data );
			}else
			{
				sendMessage("sendData", chunkID, chunkID, null );
			}
		}
		//
		public function removeHave(chunkStart:uint, chunkEnd:uint):void
		{
			sendMessage("removeHave", chunkStart, chunkEnd );
		}
		//
		private function asyncErrorHandler(evt:AsyncErrorEvent):void{}
		private function StatusHandler(event:NetStatusEvent = null):void
		{
			switch (event.info.code)
			{
				case "NetStream.Play.Start":
					_canRecieved     = true;
					_canSend   		 = true;
					break;
				case "NetStream.Play.Reset":
					_canRecieved     = false;
					_canSend  		 = false;
					break;
				case "NetStream.Play.Stop":
					_canRecieved     = false;
					_canSend  		 = false;
//					if (XNetStream && null != _groupID)
//					{
//						XNetStream.play(_groupID);
//					}
					break;
				default : 
					break;
			}
		}
		
	}
}