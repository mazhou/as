package lee.commons{
	import lee.bases.BaseEvent;
	import flash.events.MouseEvent;
	import flash.display.Sprite;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	public class DblClickSprite extends Sprite{
		public static const SINGLE_CLICK:String="single_click";
		public static const DOUBLE_CLICK:String="double_click";
		private var _firstDown:Boolean=false;
        private var _deferTime:uint=500;
		private var _intervalId:uint;
		public function DblClickSprite(){
            this.addEventListener(MouseEvent.MOUSE_DOWN,this_MOUSE_DOWN);
		}
		private function this_MOUSE_DOWN(event:MouseEvent):void {
			if(_firstDown)
			{
				_firstDown=false;
				clearTimeout(_intervalId);
				dispatchEvent(new BaseEvent(DblClickSprite.DOUBLE_CLICK));
			}
			else 
			{
				_firstDown=true;
				_intervalId=setTimeout(dispatchSingleClickEvent,_deferTime);
			}
        }
		private function dispatchSingleClickEvent():void {
			if(_firstDown)
			{
				_firstDown=false;
			    dispatchEvent(new BaseEvent(DblClickSprite.SINGLE_CLICK));
			}
        }
	}
}