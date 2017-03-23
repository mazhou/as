package com.p2p.events
{
	import flash.events.Event;

	public class P2PEvent extends Event
	{
		public static const ERROR:String = "error";

		protected var _info:Object;
		public function get info():Object
		{
			return _info;
		}
		public function P2PEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,bubbles,cancelable);
			_info = info;
		}
		public override function clone():Event
		{
			return new P2PEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("P2PEvent","info","type","bubbles","cancelable");
		}
	}
}