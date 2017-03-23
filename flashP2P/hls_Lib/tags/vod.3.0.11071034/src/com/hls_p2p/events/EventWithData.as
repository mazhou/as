package com.hls_p2p.events
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import com.hls_p2p.events.EventExtensions;

	public class EventWithData extends EventDispatcher
	{
		private static var instance:EventWithData=null;
//		public var data:Object;
		
		public function doAction(type:String,data:Object=null, bubbles:Boolean=false, cancelable:Boolean=false):void
		{
//			if(data!=null){
//				this.data=data;
//			}
			trace(this,"type");
			dispatchEvent(new EventExtensions(type,data,bubbles, cancelable));
		}
		
		public function EventWithData(single:Singleton):void
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