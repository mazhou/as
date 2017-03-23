package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.p2p.utils.console;
	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketErrorEvent;
	import com.worlize.websocket.WebSocketEvent;
	import com.worlize.websocket.WebSocketMessage;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;

//	import flash.utils.Endian;

	public class WS_Pipe
	{
		public var groupID:String;
		public var remoteID:String;
		public var canSend:Boolean;
		public var canRecieved:Boolean;
		public var dataSuccess:Function = null;
		public var connectSuccess:Function = null;
		public var termid:String;
		public var uir:String;
		private var host:String;
		private var port:int;		
		private var ws_socket:WebSocket;
		private var receive_byteArray:ByteArray;
		///;
		public var origin:String = "*";
		public var timeout:uint=30000;
		public var protocols:*;
		public var handleExtensions:Object;
		
		public function WS_Pipe(_groupID:String,_remoteID:String,_host:String,_port:int,_termid:String)
		{
			groupID = _groupID;
			remoteID = _remoteID;
			//remoteID="1234566";
			host = _host;
			port = _port;
			termid = _termid;
			//request握手信息头
			var os:String = (Capabilities.os).split(" ")[0];
			var ver:String = "ver_"+(Capabilities.version).split(" ")[1].split(",").join("_");
			handleExtensions={
				"X-MTEP-Client-Id":LiveVodConfig.uuid,
				"X-MTEP-Client-Module":"flash",
				"X-MTEP-Client-Version":ver,
				"X-MTEP-Protocol-Version":"1.0",
				"X-MTEP-Business-Params":"playType="+LiveVodConfig.TYPE+"&p2pGroupId="+groupID,
				"X-MTEP-OS-Platform":os,
				"X-MTEP-Hardware-Platform":"pc"
			};
		}
		public function init():void
		{
			clear();
			receive_byteArray = new ByteArray();
			try
			{	
				uir="ws://"+host+":"+port;
				trace(uir);
				ws_socket = new WebSocket(uir, origin, protocols, timeout,handleExtensions);
				ws_socket.debug = true;
				ws_socket.addEventListener(WebSocketEvent.CLOSED, handleWebSocket);
				ws_socket.addEventListener(WebSocketEvent.OPEN, handleWebSocket);
				ws_socket.addEventListener(WebSocketEvent.MESSAGE, handleWebSocket);
				ws_socket.addEventListener(WebSocketEvent.PONG, handleWebSocket);
				ws_socket.addEventListener(IOErrorEvent.IO_ERROR, handleError);
				ws_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleError);
				ws_socket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, handleError);
				ws_socket.connect();
			}
			catch(e:IOError)
			{
				onError(new IOErrorEvent(IOErrorEvent.IO_ERROR));
			}
			catch(e:SecurityError)
			{
				onError(new SecurityErrorEvent(SecurityErrorEvent.SECURITY_ERROR));
			}
			catch(e:Error)
			{
				onError();
			}
		}
		private function handleWebSocket(evt:WebSocketEvent):void
		{
			var type:String = evt.type;
			switch(type)
			{
				case WebSocketEvent.CLOSED:
					WebSocket.logger("===Websocket closed.");
					break;
				case WebSocketEvent.OPEN:
					var response:String = String(evt.dataProvider);
					WebSocket.logger("===Websocket OPen");
					//握手信息返回
//					if(response == null)
//					{	
//						break;
//					}
//					var lines:Array = response.split(/\r?\n/);
//					var responseLine:String;
//					while (lines.length > 0) {
//						responseLine = lines.shift();
//						var header:Object = parseHTTPHeader(responseLine);
//						if(header == null)
//						{
//							continue;
//						}
//						var lcName:String= header.name.toLocaleLowerCase();;
//						var lcValue:String= header.value.toLocaleLowerCase();
//						switch(lcName)
//						{
//							case "x-mtep-client-id":
//								break;
//							case "x-mtep-client-module":
//								break;
//							case "x-mtep-client-version":
//								break;
//							case "x-mtep-protocol-version":
//								break;
//							case "x-mtep-business-tags":
//								break;
//							case "x-mtep-os-platform":
//								break;
//							case "x-mtep-hardware-platform":
//								break;
//						}
//						WebSocket.logger(lcName+":"+lcValue);
//					}
					onConnect(response);
					break;
				case WebSocketEvent.MESSAGE:
					//信息接受
					WebSocket.logger("Websocket Message");
					canRecieved = true;
					var message:WebSocketMessage =evt.message;
					switch(message.type)
					{
						case WebSocketMessage.TYPE_BINARY:
							if( dataSuccess!= null)
							{
								dataSuccess(message.binaryData);
							}
							break;
						case WebSocketMessage.TYPE_UTF8:
							break;
					}
					break;
				case WebSocketEvent.PONG:
					break;
			}
		}
		
		private function toHexString(bytes:ByteArray, length:int):String
		{
			var result:String = new String();
			while(length-- > 0){
				var v:int = bytes.readByte() & 0xff;
				if(v < 0x10){
					result += "0"
				}
				result += v.toString(16);
			}
			return result;
		}
		private function handleError(evt:Event):void
		{
			var type:String= evt.type;
			switch(type)
			{
				case IOErrorEvent.IO_ERROR:
					break;
				case SecurityErrorEvent.SECURITY_ERROR:
					break;
				case WebSocketErrorEvent.CONNECTION_FAIL:
					WebSocket.logger("Connection Failure: " + evt["text"]);
					break;
			}
		}
		public function sendData(type:String,temp_byteArray:ByteArray):void
		{
			if(ws_socket)
			{
				ws_socket[type](temp_byteArray);
			}
		}
		private function onConnect(value:String):void
		{
			//			console.log(this,"onConnect:"+evt+" "+evt["text"]);
			canSend 	= true;
			canRecieved = true;
			connectSuccess(value);
		}
		private function onError(evt:* = null):void
		{
			console.log(this,"web_socket error:"+evt+" "+evt["text"]);
		}
		private function onClose(evt:Event):void
		{
			console.log(this,"web_socket Close:"+evt);
			clear();
		}
		public function clear():void
		{
			console.log(this,"web_socket clear");
			try
			{
				if(ws_socket && ws_socket.connected)
				{
					ws_socket.close();
				}
				
			}catch(evt:Error)
			{		
				console.log(this,"catch UTP_socket close erro!r" + evt.message);
			}
			if(ws_socket)
			{
				ws_socket.removeEventListener(WebSocketEvent.CLOSED, handleWebSocket);
				ws_socket.removeEventListener(WebSocketEvent.OPEN, handleWebSocket);
				ws_socket.removeEventListener(WebSocketEvent.MESSAGE, handleWebSocket);
				ws_socket.removeEventListener(WebSocketEvent.PONG, handleWebSocket);
				ws_socket.removeEventListener(IOErrorEvent.IO_ERROR, handleError);
				ws_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, handleError);
				ws_socket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, handleError);
				ws_socket.close(true);
			}
			ws_socket = null;
			if(receive_byteArray && receive_byteArray.length>0)
			{
				receive_byteArray.clear();
			}			
			receive_byteArray = null;
		}
	}
}