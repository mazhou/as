package com.p2p_live.events
{
	import flash.events.Event;

	public class P2PLoaderEvent extends P2PEvent
	{
		
		public static const CHANGE_SITUATION:String = "changeSituation";
		
		
		public static const STATUS:String="STATUS";
			
		public function P2PLoaderEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,info,bubbles,cancelable);
		}
		public override function clone():Event
		{
			return new P2PLoaderEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("P2PLoaderEvent","info","type","bubbles","cancelable");
		}
	}
}