package com.p2p.kernelReport
{
	import flash.net.URLRequest;
	import flash.net.sendToURL;
	
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	
	public class KernelReport
	{
		//private static var stagePath:String   = "http://123.126.32.18:3020/ClientStageInfo?"
		//private static var trafficPath:String = "http://123.126.32.18:3020/ClientTrafficInfo?"
		private static var stagePath:String   = "http://s.webp2p.letv.com/ClientStageInfo?"
		private static var trafficPath:String = "http://s.webp2p.letv.com/ClientTrafficInfo?"
		//
		private static var rIP:String = "0";
		private static var gIP:String = "0";
		private static var rPort:uint = 0;
		private static var gPort:uint = 0;
		//
		private static var _ver:String;
		private static var _type:String;
		private static var _gID:String;
		//	
		public static var gID:String = "0";
		//
		public function KernelReport()
		{
		}
		public static function SET_INFO(ver:String,type:String):void
		{
			_ver  = ver;
			_type = type;
		}
		public static function PROGRESS(obj:Object):void
		{
			var act:int = -1;
			var err:int = 0;
			
			switch(obj.code)
			{
				case "P2PNetStream_success":
					act = 0;
					break;
				case "checksum_success":
					act = 1;
					break;
				case "checksum_failed":
					act = 1;
					err = 1;
					break;
				case "selector_success":
					act = 2;
					break;	
				case "rtmfp_success":
					act = 3;
					rIP = obj.ip;
					rPort = obj.port;
					break;
				case "gather_success":
					act = 4;
					gIP = obj.ip;
					gPort = obj.port;
					break;
				case "load_success":
					act = 5;
					break;
					
			}
			
			if(act != -1)
			{
				var str:String = String(stagePath+"act="+act+"&err="+err+"&utime="+obj.utime+"&ip="+obj.ip+"&port="+obj.port+"&gID="+gID+"&ver="+_ver+"&type="+_type);						
				sendToURL(new URLRequest(str));
				//MZDebugger.trace(KernelReport,str,"",0xff0000);
			}
			
			obj = null;
		}
		public static function HEART(obj:Object):void
		{
			var str:String = String(trafficPath+"csize="+obj.csize+"&dsize="+obj.dsize+"&dnode="+obj.dnode+"&lnode="+obj.lnode+"&gip="+obj.gip+"&gport="+obj.gport+"&rip="+obj.rip+"&rport="+obj.rport+"&gID="+gID+"&ver="+_ver+"&type="+_type);			
			sendToURL(new URLRequest(str));
			//MZDebugger.trace(KernelReport,str,"",0xff0000);
			obj = null;
		}
	}
}