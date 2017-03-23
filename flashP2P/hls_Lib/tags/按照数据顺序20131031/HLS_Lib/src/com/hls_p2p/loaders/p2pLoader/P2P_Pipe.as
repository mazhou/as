package com.hls_p2p.loaders.p2pLoader
{
	
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
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
		public var isDebug:Boolean=true;
		public var isConnect:Boolean = false;
		
		public var canSend:Boolean = false;
		public var canRecieved:Boolean = false;
		
		/**发送器*/
		public var sendNetStream:NetStream = null;
		/**接收器*/
		protected var _receiveNetStream:NetStream = null;
		public var  p2pConnection:NetConnection;
		private   var _groupID:String;
		protected var _remoteID:String;
		protected var _recieverTimer:Timer;
		
		public var connectSuccess:Function = null;
		public var dataSuccess:Function = null;
		
		private var _remoteName:String;
		
		public function get groupID():String
		{
			return _groupID;
		}
		
		public function get remoteID():String
		{
			return _remoteID;
		}
		
		public function get remoteName():String
		{
			return _remoteName;
		}
		
		public function set remoteName(str:String):void
		{
			_remoteName = str;
		}
		
		//
		public function P2P_Pipe(p2pConn:NetConnection,groupID:String) :void
		{
			p2pConnection = p2pConn;
			_groupID         = groupID;
		}
		//
		public function clear():void
		{
			isConnect = false;
			
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
		public function initPipe(farID:String):void
		{
			_remoteID 		= farID;
			_remoteName		= farID;
			_recieverTimer 	= new Timer(0);
			_recieverTimer.addEventListener(TimerEvent.TIMER, recieverTimer );
			_recieverTimer.start();
		}
		
		//
		private function recieverTimer(event:TimerEvent):void
		{
			_recieverTimer.delay = 7*1000;
			//
			if (p2pConnection && p2pConnection.connected)
			{
				if (canRecieved == false)
				{
					if (null == _receiveNetStream)
					{
						try
						{
							_receiveNetStream = new NetStream(p2pConnection, _remoteID);
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
					_receiveNetStream.play(_groupID);
					return;
				}
				else
				{
					_recieverTimer.stop();
				}
			}
		}
		//
		public function sendData(name:String,data:Object=null,type:String=null):void
		{
			var obj:Object = new Object;
			obj.name=name;
			obj.type=type;
			if(data)
			{
				var bty:ByteArray = new ByteArray();
				bty.writeObject(data);
				obj.data=bty;
			}else
			{
				obj.data=new Object;
			}
			try{
				sendNetStream.send("pipeprocess", obj);
			}catch(err:Error)
			{
				P2PDebug.traceMsg(this,"sendData err:"+err);
			}
		}
		//
		public function pipeprocess(obj:Object):void
		{
			canRecieved = true;
			if(dataSuccess!=null)
			{
				var bty:ByteArray = obj.data;
				obj.data = bty.readObject() as Object;
				dataSuccess(obj.name,obj.data,obj.type);
			}
		}
		//
		private function StatusHandler(event:NetStatusEvent = null):void
		{
			switch (event.info.code)
			{
				case "NetStream.Connect.Success":
					isConnect = true;
					if(connectSuccess != null)
					{
						connectSuccess(true);
					}
					break;
				case "NetStream.Connect.Closed":
					isConnect = false;
					if(connectSuccess != null)
					{
						connectSuccess(false);
					}
					break;
				default : 
					break;
			}
		}
	}
}
