package com.p2p.events
{
	import flash.events.Event;
	
	public class SelectorEvent extends Event
	{
		public static const ERROR:String = "error";
		
		public static const SELECTOR_SUCCESS:String="selectorSuccess";
		
		protected var _info:Object;
		public function get info():Object
		{
			return _info;
		}
		public function SelectorEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,bubbles,cancelable);
			_info = info;
		}
		public override function clone():Event
		{
			return new SelectorEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("SelectorEvent","info","type","bubbles","cancelable");
		}
	}
}