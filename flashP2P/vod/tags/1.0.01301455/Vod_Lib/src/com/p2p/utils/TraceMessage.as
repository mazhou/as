package com.p2p.utils
{
	public class TraceMessage
	{
		protected static var canTrace:Boolean=true;
		
		public function TraceMessage()
		{
		}
		public static function tracer(str:String):void
		{
			if(canTrace)
			{
				trace(str);
			}
			
		}
	}
}