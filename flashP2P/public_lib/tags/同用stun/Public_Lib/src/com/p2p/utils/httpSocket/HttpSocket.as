// ActionScript file

package com.p2p.utils.httpSocket
{	
	import flash.display.Sprite;
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.system.Security;
	import flash.utils.ByteArray;
	
	public class HttpSocket extends EventDispatcher
	{
		private var _host:String;				//host地址		
		private var _port:int = 80;			//默认访问端口
		private var _src:String;				//加载的文件地址
		private var _method:String = "GET";	//加载模式默认是GET
		
		private var _backHead:ByteArray;		//接收到的httpHead
		private var _file:ByteArray;			//拿来存文件数据的
		
		private var _wait:Boolean = true;		//一个标志，是否处于文件头的等待状态下
		private var _len:int = 0;				//加载中的文件总长度
				
		private var $postData:Object;			//post的数据源
		private var $httpHeaders:Object;		//socket模拟Http访问的头对象
		
		private var _socket:Socket = null;			//核心对象		
		private var clipInterval:uint;      //chunk 大小
		private var sumlen:uint = 0;            //接收到总的数据量
		public static const VERSION:String = "1.0.5";		
		
		public function HttpSocket(_clipSize:uint)
		{
			clipInterval = _clipSize;						
			
			$httpHeaders = {"Accept":"*/*","Connection":"keep-alive"};	
			
			gc();
		}
		
		//----外部调用启动http访问----
		public function load(request:URLRequest):Boolean
		{						
			//URLRequest访问源
			if(request == null)
			{
				//sendError("Invalid URLRequest");
				return false;
			}
			//url地址
			var url:String = request.url;
			if(!analyseUrl(url) || request==null)
			{
				//sendError("Error Url");
				return false;
			}
			//post数据对象
			$postData = request.data;
			//method
			var method:String = request.method;
			if(method == URLRequestMethod.POST || method == HttpSocketMethod.POST)
			{
				_method = HttpSocketMethod.POST;
			}else
			{
				_method = HttpSocketMethod.GET;
			}
			//
			try
			{				
				_socket = new Socket();
				_socket.addEventListener(Event.CLOSE,onClose);
				_socket.addEventListener(Event.CONNECT,onConnect);
				_socket.addEventListener(ProgressEvent.SOCKET_DATA,onSocketData);	
				_socket.addEventListener(IOErrorEvent.IO_ERROR,onError);
				_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onError);
				_socket.connect(_host,_port);
				//
				return true;
			}catch(e:IOError)
			{
				onError(new IOErrorEvent(IOErrorEvent.IO_ERROR));
			}catch(e:SecurityError)
			{
				onError(new SecurityErrorEvent(SecurityErrorEvent.SECURITY_ERROR));
			}catch(e:Error)
			{
				onError();
			}
			//
			return false;
		}
		public function isEnough(chunkSize:uint):Boolean
		{
			return chunkSize <= (_file.length + _socket.bytesAvailable);
		}
		public function readBytes(bytes:ByteArray,start:int,isFinalChunk:Boolean):Boolean
		{
			var boo:Boolean=false;
			if(_file.length > 0)
			{
				bytes.writeBytes(_file);
				_file.clear();
				boo=true;
			}
			//
			if(_socket.bytesAvailable > 0)
			{
				if(isFinalChunk)
				{
					_socket.readBytes(bytes, bytes.length );
				}else
				{
					_socket.readBytes(bytes, bytes.length, clipInterval - bytes.length );
				}
				//
				boo=true;
			}
			//
			sumlen += bytes.length;
			return boo;
		}
		
		//----分析URL地址----
		private function analyseUrl(url:String):Boolean
		{
			try
			{
				if(url == null) return false;
				
				if(url.indexOf("http://") == -1)return false;
				
				var arr:Array = url.split("/");
				if(arr==null || arr.length<=2)return false;
				
				var hostValue:String = arr[2];
				if(hostValue==null || hostValue=="")return false;
				
				var portValue:int = _port;
				if(hostValue.indexOf(":") != -1)
				{//地址中存在端口号
					var hostArr:Array = hostValue.split(":");
					if(hostArr == null)return false;
					hostValue = hostArr[0];
					if(hostValue==null || hostValue=="")return false;
					portValue = hostArr[1];
				}
				const httpLen:int = 7;//http://7个字节的长度
				_host = hostValue;
				_port = portValue;
				_src = url.substr(7 + _host.length);	
				
			}catch(e:Error)
			{
				sendError("exception");
				return false;
			}
			return true;
		}
		//----socket已经断开----
		private function onClose(event:Event):void
		{			
			//dispatchEvent(new HttpSocketEvent(HttpSocketEvent.CLOSE));
			sendError("onClose");
		}
		//----socket已经连接----
		private function onConnect(event:Event):void
		{
			var requestStr:String = _method + " " + _src + " HTTP/1.1\r\n";        
			requestStr += "Host:" + _host + ":" + _port +"\r\n";
			for(var str:String in $httpHeaders){
				requestStr += str + ":" + $httpHeaders[str] + "\r\n";
			}						
			//----进行POST参数追加----
			var postStr:String = "";
			if(_method == HttpSocketMethod.POST){	
				if($postData){
					var counter:int = 0;
					for(var s:String in $postData){
						if(counter == 0){
							postStr += str + "=" + $postData[s];
						}else{
							postStr += "&" + str + "=" + $postData[s];
						}
					}
				}
				requestStr += "Content-Length: " + postStr.length + "\r\n";				
				requestStr += "Content-Type: application/x-www-form-urlencoded\r\n";		
				requestStr += "\r\n";
				
				_socket.writeUTFBytes(requestStr);  
				_socket.writeUTFBytes(postStr);
			}else{
				requestStr += "\r\n";
				_socket.writeUTFBytes(requestStr);  
			}
			//trace("requestStr  =====================  "+requestStr)
			_socket.flush();
			//sendConnect(requestStr);
		}		
		//----接收到数据----
		private function onSocketData(event:ProgressEvent):void
		{					
			//if(_wait)
			if (0 == _len)
			{	
				var b:ByteArray = new ByteArray();	
				_socket.readBytes(b);
				_backHead.position = _backHead.length;
				_backHead.writeBytes(b);                
				var arCheck:Array = analyseHead();
				if(arCheck == null)
				{
					
					return; 
				}				
				_backHead = arCheck[0];
				_backHead.position = 0;
				var strInfo:String = _backHead.toString();//b.readUTFBytes(_backHead.bytesAvailable);
				var arInfo:Array = strInfo.split("\r\n");
				for each(var strData:String in arInfo)
				{					
					var arData:Array = strData.split(":");
					if(arData[0].toString().toLowerCase() == "content-length")
					{
						//获取信息头中关于文件长度的描述						
						_len = int(StringUtil.replace(String(arData[1])," ",""));
						break;
					}
				}
				//_wait = false;
				//把从信息头中读余下的数据写到文件数据中去     
				//trace("1")
				getFile(arCheck[1]);
			} else
			{				
				
				if (_socket.bytesAvailable + _file.length >= clipInterval//够一块数据
					|| _len <= _socket.bytesAvailable+sumlen+_file.length)//
				{					
					var e:HttpSocketEvent;	
					e = new HttpSocketEvent(HttpSocketEvent.PROGRESS);
					dispatchEvent(e);
				}
			}
				
		}		
		
		private function getFile(b:ByteArray):void
		{
			
			_file.writeBytes(b);	
			
			if((_len != 0 &&  _len <= _file.length) || (_file.length >= clipInterval))
			{				
				var e:HttpSocketEvent;	
				e = new HttpSocketEvent(HttpSocketEvent.PROGRESS);
				dispatchEvent(e);
				
			}				
			
		}	
		
		//----分析返回的视频头信息----
		private function analyseHead():Array
		{
			try
			{
				const strEnd:String="\r\n\r\n";        
				var headNew:ByteArray = new ByteArray();
				var file:ByteArray = new ByteArray();
				_backHead.position = 0;
				var l:int = 4;
				var len:int = _backHead.length - l > 1024 ? 1024 : _backHead.length - l;        
				while(_backHead.position < len)
				{
					var nPos:int = _backHead.position;
					var btaEnd:ByteArray = new ByteArray();
					_backHead.readBytes(btaEnd,0,l);
					_backHead.position = 0;
					var strGet:String = btaEnd.readUTFBytes(l);
					btaEnd.position=0;
					if(strGet == strEnd)
					{
						//找到头文件结束符了,返回头文件和余下的文件内容
						_backHead.position = 0;
						_backHead.readBytes(headNew,0,nPos + l);
						_backHead.readBytes(file,0,_backHead.bytesAvailable);
						//发送OPEN开始事件
						//sendOpen(headNew.toString());
						return [headNew,file];
					}
					_backHead.position = nPos + 1;
				}
			}catch(e:Error)
			{
				sendError("exception");
				return null;
			}
			return null;
		}
		//----所有的错误监听----
		private function onError(event:* = null):void
		{
			if(event && event.type)
			{
				sendError(event.type);
			}else
			{
				sendError("Unknow Error");
			}
		}
		//----向外部发送错误信息----
		private function sendError(value:String):void
		{
			try
			{
				var e:HttpSocketEvent = new HttpSocketEvent(HttpSocketEvent.ERROR);
				e.msg = value;
				dispatchEvent(e);
			}catch(e:Error)
			{
				//trace("--x sendError",e.message);
			}
		}
		
		public function get host():String
		{
			return _host;
		}
		
		public function get port():int
		{
			return _port;
		}
		
		public function get bytesTotal():Number
		{
			return _len;
		}
		
		public function get bytesLoaded():Number
		{
			return sumlen + _socket.bytesAvailable + _file.length;
		}
		
		//----加入Http头选项----
		public function addHeadItem(type:String,value:String):Boolean
		{
			if(HttpSocketUtil.checkAddItem(type,value)){
				$httpHeaders[type] = value;
				return true;
			}
			return false;
		}
		
		public function close():void
		{
			gc();
		}
		
		private function gc():void
		{
			_len = 0;			
			_wait = true;
			if(_file)
				_file.clear();
			_file = new ByteArray();
			if(_backHead)
				_backHead.clear();
			_backHead = new ByteArray();
			
			//_socket gc
			try
			{
				//trace("_socket```````````")
				if(_socket)
				{
					_socket.close();
				}
				
			}catch(e:Error)
			{		
				//trace("_socket.error" + e.message)
				//for(var i;String in e)
			}
			if(_socket)
			{
				_socket.removeEventListener(Event.CLOSE,onClose);
				_socket.removeEventListener(Event.CONNECT,onConnect);
				_socket.removeEventListener(ProgressEvent.SOCKET_DATA,onSocketData);			
				_socket.removeEventListener(IOErrorEvent.IO_ERROR,onError);
				_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,onError);
			}
			_socket = null;
		}
	}	
}