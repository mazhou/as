package com.p2p.events
{
	public class HttpLoaderEvent extends P2PEvent
	{
		import flash.events.Event;
		public static const HTTP_GOT_COMPLETE:String = "httpGotComplete";
		public static const HTTP_GOT_PROGRESS:String = "httpGotProgress";
		public function HttpLoaderEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,info,bubbles,cancelable);
		}
		public override function clone():Event
		{
			return new HttpLoaderEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("HttpLoaderEvent","info","type","bubbles","cancelable");
		}
	}
}