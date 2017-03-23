// ActionScript file
package com.p2p.utils.httpSocket
{
	import flash.events.Event;
	
	public class HttpSocketEvent extends Event
	{
		public static const CONNECT:String = "connect";			//已经通过Socket连接上目标服务器
		
		public static const OPEN:String = "open";					//已经收到目标服务器的httpHeader信息
		
		public static const CLOSE:String = "close";				//socket断开
		
		public static const PROGRESS:String = "progress";		//加载过程
		
		public static const COMPLETE:String = "complete";		//文件加载完毕
		
		public static const ERROR:String = "error";				//加载出错
		
		
		public var data:Object;
		
		public var msg:Object;
		
		
		public function HttpSocketEvent(type:String,bubbles:Boolean = false,cancelable:Boolean = false)
		{
			super(type,bubbles,cancelable);
		}
	}
}