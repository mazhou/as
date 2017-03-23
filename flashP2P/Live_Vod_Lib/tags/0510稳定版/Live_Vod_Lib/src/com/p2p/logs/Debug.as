package com.p2p.logs
{
	public class Debug
	{
		public static var isDebug:Boolean=false;
		
		public static function traceMsg(...arg):void{
			if(isDebug){
				if(arg[0]&&arg[0].hasOwnProperty("isDebug")&&arg[0].isDebug){
					var date:Date=new Date();
					trace("["+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds+"]",
					arg);
				}
			}
		}
		public function activeListenrKey():void
		{
			
		}
		/**参数单位是秒*/
		public static function getTime(dateTime:Number):String{
			var date:Date=new Date(dateTime*1000);
			return date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds;
		}
	}
}