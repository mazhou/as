package com.mzStudio.event
{
	import flash.events.EventDispatcher;
	import flash.events.Event;
	public class EventWithData extends EventDispatcher
	{
		private static var instance:EventWithData=null;
		public var state:String;
		public var data:Object;
		
		public function doAction(type:String="", bubbles:Boolean=false, cancelable:Boolean=false,data:Object=null):void
		{
			if(data!=null){
				this.data=data;
			}
			dispatchEvent(new Event(type, bubbles, cancelable));
		}
		
		public function EventWithData(single:Singleton=null):void
		{}
		public static function getInstance():EventWithData
		{
			if(instance==null){
				instance=new EventWithData(new Singleton());
			}
			return instance;
		}
	}
}
class Singleton{}