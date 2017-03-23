package com.p2p.logs
{
	public class P2PDebug
	{
		public static var isDebug:Boolean=false;
		public static var _tempString:String="";
		public static function traceMsg(...arg):void{
			if(isDebug){
				if(arg[0]&&arg[0].hasOwnProperty("isDebug")&&arg[0].isDebug){
					if(_tempString!=String(arg[1])){
						_tempString=String(arg[1]);
						var date:Date=new Date();
						trace("["+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds+"]",
						arg);
					}
				}
			}
		}
		public function activeListenrKey():void
		{
			
		}
	}
}