package com.p2p.log
{
	import com.p2p.utils.GetLocationParam;
	import com.p2p.utils.ParseUrl;
	import com.p2p.utils.json.JSONEncoder;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;

	public class ConsoleDebug
	{
		private static var _date:Date = null;
		private static var _browserParams:Object = null;
		private static var _allowOutputMsg:int = -1;
		private static var _preparedSocketStr:String = "";
		private static var _sendStr:String = "";
		private static var sket:Socket = new Socket;
		private static var _connectSuccess:Boolean = false;
		private static var _debugUser:String = "";
		
		public function ConsoleDebug()
		{
			
		}
		

			
		public static function info():void
		{
			
		}
		
		public static function log(...arg):void
		{
			var isAllowDebug:Boolean = false;
			if( arg[0] && arg[0].hasOwnProperty("isDebug") && arg[0].isDebug ){
				isAllowDebug = true;
			}
			else
			{
				return;
			}
			
			if(isAllowDebug){
				arg[0] = arg[0].toString().replace("object " ,"");
			}
			
			if( _browserParams == null )
			{
				_browserParams = GetLocationParam.GetBrowseLocationParams();
				if( _browserParams == null )
				{
					_browserParams = {};
					return;
				}
			}
			
			if( 1 == _allowOutputMsg  )
			{
				_sendStr = "";
				_sendStr += arg[0]+" ";
				for(var i:int = 1;i<arg.length;i++)
				{
					_sendStr += (new JSONEncoder(arg[i])).getString();
				}
				
				sendMessage( _sendStr );
				return;
			}else if( 0 == _allowOutputMsg ){	
				socket();
				return;
			}else if( -1 == _allowOutputMsg )
			{
				_sendStr = "";
				_sendStr += arg[0]+" ";
				for(var j:int = 1;j<arg.length;j++)
				{
					_sendStr += (new JSONEncoder(arg[j])).getString();
				}
				
				sendMessage( _sendStr );
			}
			
			if( _browserParams && _browserParams.hasOwnProperty("location"))
			{
				if(ParseUrl.getParam(_browserParams.location,"webp2pDebug") == "true" || ParseUrl.getParam(_browserParams.location,"debug") == "true")
				{
					_allowOutputMsg = 1;
				}else{
					_allowOutputMsg = 0;
					_preparedSocketStr = "";
				}
				
				_debugUser = ParseUrl.getParam(_browserParams.location,"debugUser");
				_sendStr = "";
				_sendStr += arg[0]+" ";
				for( i = 1;i<arg.length;i++)
				{
					_sendStr += (new JSONEncoder(arg[i])).getString();
				}
				
				socket();
				sendMessage( _sendStr );
			}else
			{
				return;
			}
			
		}
		private static var count:int = 0;
		protected static function sendMessage(msg:String):void//发送数据对应按钮click事件   
		{
			if( _connectSuccess == false )
			{
				_preparedSocketStr += msg+"\n";
				if( _preparedSocketStr.length > 10000 ){
					_preparedSocketStr = _preparedSocketStr.substr(_preparedSocketStr.length-10000); 
					trace("_preparedSocketStr:"+_preparedSocketStr)
				}
				return;
			}
			
			try{
				_date = new Date();
				
				msg = "["+_date.getHours()+":"+_date.getMinutes()+":"+_date.getSeconds()+"."+_date.milliseconds+"] "+msg;
				trace(" msg:"+msg);
				sket.writeObject({"log":(msg),"fileName":_debugUser+_browserParams.title+_browserParams.type});				
				sket.flush();
			}catch(err:Error)
			{
				_connectSuccess = false;
				try{
					sket.close();
				}catch(err:IOError)
				{
					
				}
			}			
		}
		
		protected static function socket():void
		{
			if(_connectSuccess)return;
			if( !sket.hasEventListener(Event.CLOSE) )
			{
				sket.addEventListener(Event.CLOSE, closeHandler);  
				sket.addEventListener(Event.CONNECT, connectHandler);  
				sket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);  
				sket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);  
				sket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);  
			}
			sket.connect("localhost",23456);
		}
		
		protected static function connectHandler(event:Event):void
		{  
			//			trace("连接成功22"); 
			_connectSuccess = true;
			_allowOutputMsg = 1;
			if( _preparedSocketStr != "" )
			{
				sendMessage( _browserParams.location+"\n"+_preparedSocketStr);
				_preparedSocketStr = "";
			}
		} 
		
		protected static function closeHandler(event:Event):void
		{ 
			_connectSuccess = false;
			_allowOutputMsg = 0;
			//socket();
		}
		
		protected static function ioErrorHandler(event:IOErrorEvent):void
		{  
			_connectSuccess = false;
			_allowOutputMsg = 0;
			//socket();
		}
		
		protected static function securityErrorHandler(event:SecurityErrorEvent):void
		{  
			_connectSuccess = false;
			_allowOutputMsg = 0;
			//socket();
		}
		
		protected static function socketDataHandler(event:ProgressEvent):void
		{  
			//trace("接收数据");
		}
		
		
		//		logger.debug("Start of the main() in TestLog4j");
		//		logger.info("Just testing a log message with priority set to INFO");
		//		logger.warn("Just testing a log message with priority set to WARN");
		//		logger.error("Just testing a log message with priority set to ERROR");
		//		logger.fatal("Just testing a log message with priority set to FATAL");
		//		logger.log(Priority.WARN, "Testing a log message use a alternate form");
		//		logger.debug(TestLog4j.class.getName());
		
	}
}