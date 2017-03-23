package com.p2p.events
{
	import flash.events.Event;
	public class CheckLoaderEvent extends P2PEvent
	{
		public static const SUCCESS:String = "checkSuccess";

		public function CheckLoaderEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,info,bubbles,cancelable);
		}
		public override function clone():Event
		{
			return new CheckLoaderEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("CheckLoaderEvent","info","type","bubbles","cancelable");
		}
	}
}