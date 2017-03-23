package com.hls_p2p.loaders.p2pLoader
{
	
	import com.p2p.utils.console;
	
	import flash.errors.IOError;
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLRequest;
	import flash.net.sendToURL;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	public class P2P_Pipe extends EventDispatcher
	{
		public var isDebug:Boolean = true;
		public var isConnect:Boolean = false;
		
		public var canSend:Boolean = false;
		public var canRecieved:Boolean = false;
		
		public var XNetStream:NetStream = null;
		public var  p2pConnection:NetConnection;
		private   var _groupID:String;
		protected var _remoteID:String;
		protected var _recieverTimer:Timer;
		
		public var connectSuccess:Function = null;
		public var dataSuccess:Function = null;
		
		private var _remoteName:String;
		
		private var _isReportError:Boolean = false;
		
		private var _startTime:Number = 0;
		
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
			_groupID      = groupID;
		}
		//
		public function clear():void
		{
			console.log(this,"clear");
			isConnect 	= false;
			canSend		= false;
			canRecieved	= false;
			p2pConnection = null;
			
			
			connectSuccess 	= null;
			dataSuccess 	= null;
			
			_isReportError	= false;
			
			if(_recieverTimer)
			{
				_recieverTimer.stop();
				_recieverTimer.removeEventListener(TimerEvent.TIMER, recieverTimer );
				_recieverTimer = null;
			}
			//
			if (XNetStream)
			{
				try
				{
					XNetStream.close();
					//trace("XNetStream.close() = "+remoteID);
					if (XNetStream.hasEventListener(NetStatusEvent.NET_STATUS))
					{	
						XNetStream.removeEventListener(NetStatusEvent.NET_STATUS,StatusHandler);
					}
					//
					if (XNetStream.hasEventListener(AsyncErrorEvent.ASYNC_ERROR))
					{
						XNetStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
					}
				}
				catch(e:Error)
				{
					
				}
				XNetStream = null;
				//trace("XNetStream.remoteID = "+XNetStream);
			}
			
			_groupID	= null;
			_remoteID 	= null;
			_remoteName	= null;

		}
		//
		public function initPipe(farID:String):void
		{
			_remoteID 		= farID;
			_remoteName		= farID;
			if (XNetStream)
			{
				//trace(this,"XNetStream = "+XNetStream+" ,farID = "+farID);
				canRecieved = true;
				canSend = true;
				XNetStream.client = this;
				return ;
			}
			
			
			if (_recieverTimer == null)
			{
				_recieverTimer 	= new Timer(200);
				_recieverTimer.addEventListener(TimerEvent.TIMER, recieverTimer );
				_recieverTimer.start();
			}
			
		}
		
		//
		private function recieverTimer(event:TimerEvent):void
		{
			if(_recieverTimer)
			{
				_recieverTimer.delay = 7*1000;
			}
			
			//
			if (p2pConnection && p2pConnection.connected)
			{
				if (canRecieved == false)
				{
					if (null == XNetStream)
					{
						try
						{
							XNetStream = new NetStream(p2pConnection, _remoteID);
							XNetStream["dataReliable"] = true;//true;//
							XNetStream.addEventListener(NetStatusEvent.NET_STATUS, StatusHandler);
							XNetStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
							XNetStream.client = this;
							XNetStream.play(_groupID);
							//trace("XNetStream.play("+_groupID+")");
						}
						catch(err:Error)
						{
							canRecieved = false;
							console.log(this,err.getStackTrace());
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
					}else
					{
						XNetStream.play(_groupID);
					}
				}else
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
			//
			try
			{
				XNetStream.send("pipeprocess", obj);
				
			}catch(err:Error)
			{
				console.log(this,"sendData err:"+err+err.getStackTrace());
			}
			obj = null;
		}
		//
		
		public function closeStream(obj:Object):void
		{
			
		}
		
		public function pipeprocess(...arg/*obj:Object*/):void
		{
			if(dataSuccess!=null)
			{
				canRecieved     = true;
				canSend   = true;
				var obj:Object = arg[0];
				
				try
				{
					var bty:ByteArray = obj.data;
					obj.data = bty.readObject() as Object;
					dataSuccess(obj.name,obj.data,obj.type);
					
					if( false == _isReportError )
					{
						var stagePath:String = "http://s.webp2p.letv.com/ClientTrafficInfo?";
						var str:String = "";
						if(arg.length!= 1 )
						{
							str = String(stagePath+"clientType="+obj.data.clientType+"&remoteID="+remoteID+"&groupID="+groupID+"&r="+Math.floor(Math.random()*100000));
							sendToURL(new URLRequest(str));
						}
						else if( !obj.data )
						{
							str = String(stagePath+"clientType=no data"+"&remoteID="+remoteID+"&groupID="+groupID+"&r="+Math.floor(Math.random()*100000));
							sendToURL(new URLRequest(str));
						}
						else if( !obj.data.clientType )
						{
							str = String(stagePath+"clientType=no data.clientType"+"&remoteID="+remoteID+"&groupID="+groupID+"&r="+Math.floor(Math.random()*100000));
							sendToURL(new URLRequest(str));
						}
					}
					
					obj = null;
				}catch(err:Error)
				{
					console.log(this,"pipeprocess"+err+err.getStackTrace());	
				}
			}
		}
		//
		private function asyncErrorHandler(evt:AsyncErrorEvent):void{}
		private function StatusHandler(event:NetStatusEvent = null):void
		{//trace("remoteID "+event.info.code);
			switch (event.info.code)
			{
				
				case "NetStream.Play.Start":
					canRecieved     = true;
					canSend   = true;
					//trace("NetStream.Play.Start "+remoteID)
					break;
				case "NetStream.Play.Reset":
					canRecieved     = false;
					canSend   = false;
					//trace("NetStream.Play.Reset "+remoteID)
					break;
				case "NetStream.Play.Stop":
					canRecieved     = false;
					canSend   = false;
					//trace("NetStream.Play.Stop "+remoteID)
//					if (XNetStream && null != _groupID)
//					{
//						XNetStream.play(_groupID);
//					}
					//
					break;
					
//				case "NetStream.Connect.Success":
//					isConnect = true;
//					if(connectSuccess != null)
//					{
//						connectSuccess(true);
//					}
//					break;
//				case "NetStream.Connect.Closed":
//					isConnect = false;
//					if(connectSuccess != null)
//					{
//						connectSuccess(false);
//					}
//					break;
				default : 
					break;
			}
		}
	}
}
