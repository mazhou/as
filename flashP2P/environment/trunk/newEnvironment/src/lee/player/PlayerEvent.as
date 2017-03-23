package lee.player{
	import flash.events.Event;
	public class PlayerEvent extends Event{
        public static const RESET:String = "reset";
		
		public static const MESSAGE:String = "message";
		public static const META_DATA:String = "meta_data";
		
		public static const ERROR:String = "error";
		public static const READY:String = "ready";
		public static const PLAYHEAD:String = "playhead";
		public static const PROGRESS:String = "progress";
		public static const BUFFER_UPDATE:String = "buffer_update";
		public static const STATE_CHANGE:String = "state_change";
		
		public static const CONTINUE:String = "continue";
		
		//--------------------------------------------------------------
		public var info:Object;

		public function PlayerEvent(type:String,infoObject:Object=null){
			super(type);
			info=infoObject;
		}
		public override function clone():Event{
			return new PlayerEvent(type,info);
		}
		public override function toString():String{
			return formatToString("PlayerEvent","type","bubbles","cancelable","info");
		}
	}
}