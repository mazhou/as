package com.p2p.utils
{
	import com.p2p.utils.GetLocationParam;
	import com.p2p.utils.ParseUrl;
	import com.p2p.utils.json.JSONEncoder;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.net.Socket;

	public class console
	{
		private static var _date:Date = null;
		private static var _browserParams:Object = null;
		private static var _allowOutputMsg:int = -1;
		private static var _preparedSocketStr:String = "";
		private static var _sendStr:String = "";
		private static var sket:Socket = new Socket;
		private static var _connectSuccess:Boolean = false;
		private static var _debugUser:String = "";
		private static var _title:String = "";
		private static var _log:Boolean;
		private static var _trc:Boolean; 
		private static var _csl:Boolean;
		public static function info():void
		{
		}
		
		public static function log(...arg):void
		{
			if( 0 == _allowOutputMsg ){return;}
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
					_allowOutputMsg = 0;
					_preparedSocketStr = "";
					return;
				}
				_title = _browserParams.title;
				if(_title.length > 10)
				{
					_title = _title.substr(0,10);	
				}
			}
			
			if( 1 == _allowOutputMsg  )
			{
				_sendStr = "";
				_sendStr += arg[0]+" ";
				for(var i:int = 1;i<arg.length;i++)
				{
					if(arg[i])
					{
						_sendStr += (new JSONEncoder(arg[i])).getString();
					}
				}
				sendMessage( _sendStr );
				return;
			}else if( -1 == _allowOutputMsg )
			{
				
				if( _browserParams && _browserParams.hasOwnProperty("location"))
				{
					_log = (ParseUrl.getParam(_browserParams.location,"debug") == "log" || ParseUrl.getParam(_browserParams.location,"debug") == "true");
					_trc = ParseUrl.getParam(_browserParams.location,"debug") == "trace";
					_csl = ParseUrl.getParam(_browserParams.location,"debug") == "console";
					
					if( _log || _trc || _csl )
					{
						_allowOutputMsg = 1;
						_debugUser = ParseUrl.getParam(_browserParams.location,"debugUser");
						_sendStr = "";
						_sendStr += arg[0]+" ";
						for( i = 1;i<arg.length;i++)
						{
							_sendStr += (new JSONEncoder(arg[i])).getString();
						}
						
						socket();
						sendMessage( _sendStr );
					}else{
						_allowOutputMsg = 0//-1;//
						_preparedSocketStr = "";
					}
				}
			}
		}
		
		private static var count:int = 0;
		protected static function sendMessage(msg:String):void//发送数据对应按钮click事件   
		{
			if(_log)
			{
				if( _connectSuccess == false )
				{
					_preparedSocketStr += msg+"\n";
					if( _preparedSocketStr.length > 10000 ){
						_preparedSocketStr = _preparedSocketStr.substr(_preparedSocketStr.length-10000); 
					}
					return;
				}
				try{
					_date = new Date();
					
					msg = "["+formatDate(_date)+"] "+msg;
					sket.writeObject({"log":(msg),"fileName":_debugUser+_title+_browserParams.type});				
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
			}else if(_trc)
			{
				try{
					_date = new Date();
					msg = "["+formatDate(_date)+"] "+msg;
					trace(msg);
				}catch(err:Error)
				{
					
				}
			}else if(_csl)
			{
				try{
					_date = new Date();
					msg = "["+formatDate(_date)+"] "+msg;
					ExternalInterface.call("console.log",msg);
				}catch(err:Error)
				{
					
				}
			}			
		}
		protected static function formatDate(_data:Date):String
		{
			var _dateF:String = "";
			_dateF += String(_date.getHours()).length==1?("0"+_date.getHours()):String(_date.getHours());
			_dateF += ":";
			_dateF += String(_date.getMinutes()).length==1?("0"+_date.getMinutes()):String(_date.getMinutes());
			_dateF += ":";
			_dateF += String(_date.getSeconds()).length==1?("0"+_date.getSeconds()):String(_date.getSeconds());
			_dateF += ":";
			var milliseconds:String = String(_date.milliseconds);
			while(milliseconds.length<3)
			{
				milliseconds = "0"+milliseconds;
			}
			_dateF += milliseconds;
			
			return _dateF;	
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