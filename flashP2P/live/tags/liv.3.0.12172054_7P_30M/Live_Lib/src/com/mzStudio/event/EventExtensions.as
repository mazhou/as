package com.mzStudio.event
{
	import flash.events.Event;

	public class EventExtensions extends Event
	{
		public var data:Object;
		public function EventExtensions(type:String, data:Object)
		{
			super(type, false, false);
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