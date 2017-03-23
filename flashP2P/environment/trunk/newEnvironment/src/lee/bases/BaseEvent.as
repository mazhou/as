package lee.bases{
	import flash.events.Event;
	public class BaseEvent extends Event {
		
		public var info:Object;
		
		public function BaseEvent(type:String,infoObject:Object=null,bubbles:Boolean=false,cancelable:Boolean=false) {
			super(type,bubbles,cancelable);
			info=infoObject;
		}
		public override function clone():Event {
			return new BaseEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String {
			return formatToString("BaseEvent","type","bubbles","cancelable","info");
		}
	}
}