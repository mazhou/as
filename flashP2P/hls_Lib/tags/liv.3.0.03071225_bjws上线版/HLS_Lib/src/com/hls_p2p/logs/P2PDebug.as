package com.hls_p2p.logs
{
	import com.p2p.utils.GetLocationParam;
	import com.p2p.utils.ParseUrl;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;

	public class P2PDebug
	{
		private static var _isDebug:Boolean=false;
		public static var _tempString:String="";
		protected static var sket:Socket = new Socket;
		protected static var sketIsSuccess:Boolean = false;
		protected static var playerType:String = "";
		protected static var fileTitle:String = "";
		protected static var fileLocation:String = "";
		protected static var webp2pUser:String = "";
		public static function get isDebug():Boolean
		{
			return _isDebug;
		}

		public static function set isDebug(value:Boolean):void
		{
			_isDebug = value;
		}
		
		public static function traceMsg(...arg):void{
			var isAllowDebug:Boolean = false;
			if(arg[0]&&arg[0].hasOwnProperty("isDebug")&&arg[0].isDebug){
				isAllowDebug = true;
			}
			
			var date:Date = null;
			
			if(isDebug){
				if(isAllowDebug){
					arg[0] = arg[0].toString().replace("object " ,"");
					date = new Date();
					trace("["+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds+"]",
						arg);
				}
			}
			
			if( playerType == "" )
			{
				var browseParams:Object = GetLocationParam.GetBrowseLocationParams();
				if(browseParams!=null)
				{
					playerType = browseParams.type;
					fileLocation = browseParams.location;
					fileTitle = browseParams.title;
					webp2pUser = ParseUrl.getParam( fileLocation,"webp2pUser" );//"debug"
				}else
				{
					playerType = "no type";
				}
			}
			
			if( playerType == "no type" )
			{
				return;
			}
			
			if(isAllowDebug)
			{
				if(_tempString!=String(arg[1])){
					_tempString=String(arg[1]);	
					if( date == null )
					{
						date = new Date();
					}
					if(sketIsSuccess){
						var str:String="";
						for(var i:int = 0;i<arg.length;i++)
						{
							if(arg[i] is Array)
							{
								for(var j:int = 0; j<arg[i].length; j++)
								{
									str+=arg[i][j];
								}
							}else
							{
								str+=arg[i];
							}
						}
						sendMessage("["+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds+"]"+str);
						return;
					}
					
					if(ParseUrl.getParam(fileLocation,"webp2pDebug") == "true" || ParseUrl.getParam(fileLocation,"debug") == "true")
					{
						sketIsSuccess = true;
						socket();
					}else
					{
						playerType = "no type";
					}
				}
			}
		}
		

		public static function socket():void
		{
			sket.addEventListener(Event.CLOSE, closeHandler);  
			sket.addEventListener(Event.CONNECT, connectHandler);  
			sket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);  
			sket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);  
			sket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);  
			sket.connect("localhost",23456); 
//			addEventListener("recieved",recievedData);  
		}
		protected static function closeHandler(event:Event):void
		{  
//			trace("连接关闭");
		}  
		protected static var connectSuccess:Boolean = false;
		protected static function connectHandler(event:Event):void
		{  
//			trace("连接成功22"); 
			connectSuccess = true;
			if(tempString!="")
			{
				sendMessage(fileLocation+"\n"+tempString);
				tempString="";
			}
		} 
		protected static var tempString:String = "";
		internal static function sendMessage(msg:String):void//发送数据对应按钮click事件   
		{
			if( connectSuccess == false )
			{
				tempString += msg+"\n";
				return;
			}
			try{
//				sket.writeBytes(
				sket.writeObject({"log":(msg),"fileName":webp2pUser+fileTitle+playerType});				
				sket.flush();
			}catch(err:Error)
			{
				sketIsSuccess = false;
				try{
					sket.close();
				}catch(err:IOError)
				{
					
				}
			}
		} 
		protected static function ioErrorHandler(event:IOErrorEvent):void
		{  
//			trace("ioErrorHandler信息： " + event);  
			sketIsSuccess = false;
		}  
		
		protected static function securityErrorHandler(event:SecurityErrorEvent):void
		{  
//			trace("securityErrorHandler信息: " + event);  
			sketIsSuccess = false;
		}  
		
		protected static function socketDataHandler(event:ProgressEvent):void
		{  
//			trace("接收数据");
		}
		
	}
}