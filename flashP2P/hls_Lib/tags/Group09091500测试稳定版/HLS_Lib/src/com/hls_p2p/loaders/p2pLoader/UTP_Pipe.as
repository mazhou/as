package com.hls_p2p.loaders.p2pLoader
{
	import com.p2p.utils.console;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;

	public class UTP_Pipe
	{
		public var groupID:String;
		public var remoteID:String;
		public var canSend:Boolean;
		public var canRecieved:Boolean;
		public var dataSuccess:Function = null;
		public var connectSuccess:Function = null;
		public var termid:String;
		private var host:String;
		private var port:int;		
		private var UTP_socket:Socket;
		private var receive_byteArray:ByteArray;
		
		public function UTP_Pipe(_groupID:String,_remoteID:String,_host:String,_port:int,_termid:String)
		{
			groupID = _groupID;
			remoteID = _remoteID;
			host = _host;
			port = _port;
			termid = _termid;
		}
		
		public function init():void
		{
			clear();
			receive_byteArray = new ByteArray();
			try
			{				
				UTP_socket = new Socket();
				UTP_socket.endian = Endian.BIG_ENDIAN
				UTP_socket.addEventListener(Event.CLOSE,onClose);
				UTP_socket.addEventListener(Event.CONNECT,onConnect);
				UTP_socket.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);	
				UTP_socket.addEventListener(IOErrorEvent.IO_ERROR,onError);
				UTP_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onError);
				UTP_socket.connect(host,port);
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
		
		public function sendData(type:int,temp_byteArray:ByteArray):void
		{
			var size:int = temp_byteArray.length+1;			
			if(UTP_socket)
			{
				UTP_socket.writeUnsignedInt(size);
				UTP_socket.writeByte(type);
//				trace(">>>>>>>>>\nsize:"+size.toString(16));
//				trace("type:"+type.toString(16)+"="+type.toString(10));
//				var out:String = "";
				temp_byteArray.position = 0;
//				var i:int = 0;
//				var value:String
//				while(temp_byteArray.bytesAvailable>0)
//				{
//					value = (temp_byteArray[temp_byteArray.position].toString(16))
//					out += (value.length==1?(" 0"+value):" "+value);
//					i++;
//					if(i==4){
//						out += "\n"
//						i=0;
//					}
//					temp_byteArray.position++;
//				}
//				trace("data:\n"+out+"\n<<<<<<");
				temp_byteArray.position = 0;
				UTP_socket.writeBytes(temp_byteArray);
				UTP_socket.flush();
			}
		}
		
		private function onConnect(evt:Event):void
		{
//			console.log(this,"onConnect:"+evt+" "+evt["text"]);
			canSend 	= true;
			canRecieved = true;
			connectSuccess();
		}
		
		private function onSocketData(evt:ProgressEvent):void
		{
			
			canRecieved = true;
			UTP_socket.readBytes(receive_byteArray,receive_byteArray.length);
			
			if( receive_byteArray.bytesAvailable>=4 ){
				var size:uint = receive_byteArray.readUnsignedInt();
				
				if(receive_byteArray.bytesAvailable >= size)
				{		
					var body:ByteArray = new ByteArray();
					receive_byteArray.readBytes(body,0,size);
					body.position = 0;
					dataSuccess(body);
					if(receive_byteArray.bytesAvailable>0)
					{
						var left:ByteArray = new ByteArray();
						receive_byteArray.readBytes(left);
						receive_byteArray= left;
						
					}else{
						receive_byteArray.clear();
					}
				}else
				{
					receive_byteArray.position -= 4;
				}	
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
		
		private function onError(evt:* = null):void
		{
			console.log(this,"UTP_socket error:"+evt+" "+evt["text"]);
		}
		private function onClose(evt:Event):void
		{
			console.log(this,"UTP_socket Close:"+evt);
			clear();
		}
		public function clear():void
		{
			console.log(this,"UTP_socket clear");
			try
			{
				if(UTP_socket && UTP_socket.connected)
				{
					UTP_socket.close();
				}
				
			}catch(evt:Error)
			{		
				console.log(this,"catch UTP_socket close error" + evt.message);
			}
			if(UTP_socket)
			{
				UTP_socket.removeEventListener(Event.CLOSE,onClose);
				UTP_socket.removeEventListener(Event.CONNECT,onConnect);
				UTP_socket.removeEventListener(ProgressEvent.SOCKET_DATA,onSocketData);			
				UTP_socket.removeEventListener(IOErrorEvent.IO_ERROR,onError);
				UTP_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,onError);
			}
			UTP_socket = null;
			if(receive_byteArray && receive_byteArray.length>0)
			{
				receive_byteArray.clear();
			}			
			receive_byteArray = null;
		}
	}
}