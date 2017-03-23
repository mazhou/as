package com.p2p.events
{
	import flash.events.Event;

	public class EventExtensions extends Event
	{
		public var data:Object;
		public function get info():Object
		{
			return data;
		}
		public function EventExtensions(type:String, data:Object,bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			if(data!=null){
				this.data=data;
			}
		}
		public override function clone():Event {
			return new EventExtensions(this.type, this.data);
		}
		public override function toString():String {
			return '[PlayerEvent type="' + type + '"' 				
				+ ' message="' + data + '"'
				+ "]";
		}
	}
}