package com.p2p_live.events
{
	import flash.events.Event;
	public class DataManagerEvent extends P2PEvent
	{
		
		
		public static const STATUS:String="STATUS"
		
		public static const ERROR:String = "error";
		

		public function DataManagerEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,info,bubbles,cancelable);
		}
		public override function clone():Event
		{
			return new DataManagerEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("DataManagerEvent","info","type","bubbles","cancelable");
		}
	}
}