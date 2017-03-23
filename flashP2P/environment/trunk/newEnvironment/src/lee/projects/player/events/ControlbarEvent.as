package lee.projects.player.events{
	import flash.events.Event;
	public class ControlbarEvent extends Event{
        public static const VOLUME_CHANGE:String = "volume_change";
		public static const FULLSCREENBTN_CLICK:String = "fullscreenbtn_click";
		public static const NORMALSCREENBTN_CLICK:String = "normalscreen_click";
		//--------------------------------------------------------------
		public var info:Object;
		public var expa:Object;

		public function ControlbarEvent(type:String,infoObject:Object=null,expaObject:Object=null){
			super(type);
			info=infoObject;
			expa=expaObject;
		}
		public override function clone():Event{
			return new ControlbarEvent(type,info,expa);
		}
		public override function toString():String{
			return formatToString("ControlbarEvent","type","bubbles","cancelable","info","expa");
		}
	}
}