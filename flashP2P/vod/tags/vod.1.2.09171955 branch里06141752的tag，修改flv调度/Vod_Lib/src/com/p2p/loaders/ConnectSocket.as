package com.p2p.loaders
{
	import com.p2p.events.DataManagerEvent;
	
	import flash.events.*;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.net.Socket;
	import flash.utils.Timer;
	
	import org.osmf.events.TimeEvent;
	
	public class ConnectSocket extends EventDispatcher
	{
		private var _socket:Socket;
		
		private var _FLVURL:String; 
		
		
		public function ConnectSocket(target:IEventDispatcher=null)
		{
			super(target);
			
		}
		public function start(FLVURL:String):void
		{
			
			_FLVURL = doRegExp(FLVURL);
			_socket = new Socket();
			_socket.timeout = 1*1000;
			_socket.addEventListener(Event.CONNECT,onSocketConnect);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onSecurityError);
			
			_socket.addEventListener(IOErrorEvent.IO_ERROR,onIOError);
			_socket.addEventListener(Event.CLOSE,onSocketClose);
			_socket.connect(_FLVURL,843);
			//trace("_FLVURL  ----  "+_FLVURL);
			//_socket.connect("123.126.32.18",8080);
			//_socket.connect("123.125.89.88",843);
			//_socket.connect("123.126.32.135",8080);
			
		}
		public function clear():void
		{
			clearListener();
			_socket = null;
			_FLVURL = "";
		}
		//
		private function doRegExp(str:String):String
		{
			var regExp:RegExp = /\d+\.\d+\.\d+\.\d+/g;
			regExp.lastIndex = 7;
			var obj:Object = regExp.exec(str);
			if (obj)
			{
				return String(obj["0"]);
			}
			else
			{
				return "";
			}
		}
		protected function onSocketConnect(e:Event):void
		{
			var obj:Object = new Object();
			obj.code       = "P2P.connectSocket.Success";
			obj.level      = "status";
			obj.url        = _FLVURL;
			dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
			//
			if(_socket)
			{
				_socket.close();
				
			}	
			
			clearListener();
			
		}
		protected function onSecurityError(e:SecurityErrorEvent):void
		{
			var obj:Object = new Object();
			obj.code       = "P2P.connectSocket.Failed";
			obj.level      = "error";
			obj.url        = _FLVURL;
			obj.type       = "SecurityError";
			obj.error        = 506;
			dispatchEvent(new DataManagerEvent(DataManagerEvent.ERROR,obj));
			//
			//clearListener();
		}
		protected function onIOError(e:IOErrorEvent):void
		{
			var obj:Object = new Object();
			obj.code       = "P2P.connectSocket.Failed";
			obj.level      = "error";
			obj.url        = _FLVURL;
			obj.type       = "IOError";
			obj.error      = 505;
			dispatchEvent(new DataManagerEvent(DataManagerEvent.ERROR,obj));
			//
			//clearListener();
		}
		protected function onSocketClose(e:Event):void
		{
			if(_socket)
			{
				_socket.close();
				
			}		
			clearListener();
				
		}
		
		protected function clearListener():void
		{
			if(_socket)
			{
				_socket.removeEventListener(Event.CONNECT,onSocketConnect);
				_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,onSecurityError);
				_socket.removeEventListener(IOErrorEvent.IO_ERROR,onIOError);
				_socket = null;
			}
			
		}
		
	}
}