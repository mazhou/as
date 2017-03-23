package lee.commons{
	import flash.events.EventDispatcher;
	import flash.display.MovieClip;
	import flash.text.TextField;
	import flash.events.MouseEvent;
	public class StateButton extends EventDispatcher{
		protected var _skin:MovieClip;
		protected var _textField:TextField;
		
		protected var _state:String;

		protected var _labelColors:Object;
		public function StateButton(skin:MovieClip) {
			_skin=skin;
			_skin.buttonMode=true;
			_textField=_skin.getChildByName("labelText") as TextField;
			if(_textField)
			{
			    _textField.mouseEnabled=false;
			}
			_skin.addEventListener(MouseEvent.ROLL_OUT,_skin_ROLL_OUT);
			_skin.addEventListener(MouseEvent.ROLL_OVER,_skin_ROLL_OVER);
			_skin.addEventListener(MouseEvent.MOUSE_DOWN,_skin_MOUSE_DOWN);
			_skin.addEventListener(MouseEvent.MOUSE_UP,_skin_MOUSE_UP);
			_skin.addEventListener(MouseEvent.CLICK,_skin_CLICK);
			state="up";
		}
		public function get skin():MovieClip{
			return _skin;
		}
		public function set labelColors(obj:Object):void{
			_labelColors=obj;
			setState(state);
		}
		public function get label():String{
			return _textField.text;
		}
		public function set label(lab:String):void{
			_textField.text=lab;
		}
		public function get state():String{
			return _state;
		}
		public function set state(sta:String):void{
			if(state!=sta)
			{
				setState(sta);
			}
		}
		protected function setState(sta:String):void{
			_state=sta;
			if(_textField&&_labelColors)
			{
				_textField.textColor=uint(_labelColors[sta])
			}
			switch (sta)
			{
				case "up" :
					_skin.gotoAndStop(1);
					setEnabled(true);
					break;
				case "over" :
					_skin.gotoAndStop(2);
					setEnabled(true);
					break;
			    case "down" :
					_skin.gotoAndStop(3);
					setEnabled(true);
					break;
				case "selected" :
					_skin.gotoAndStop(4);
					setEnabled(false);
					break;
				case "disabled" :
					_skin.gotoAndStop(5);
					setEnabled(false);
					break;
				default:
					throw new Error(sta+"不是有效值");
			}
		}
		protected function setEnabled(boo:Boolean):void{
			_skin.mouseEnabled=_skin.mouseChildren=_skin.tabEnabled=_skin.tabChildren=boo;
		}
		protected function _skin_ROLL_OUT(event:MouseEvent):void {
			if(state!="selected"&&state!="disabled"){state="up";}
		}
		protected function _skin_ROLL_OVER(event:MouseEvent):void {
			if(state!="selected"&&state!="disabled"){state="over";}
		}
		protected function _skin_MOUSE_DOWN(event:MouseEvent):void {
			if(state!="selected"&&state!="disabled"){state="down";}
		}
		protected function _skin_MOUSE_UP(event:MouseEvent):void {
			if(state!="selected"&&state!="disabled"){state="over";}
		}
		protected function _skin_CLICK(event:MouseEvent):void {
			if(state!="selected"&&state!="disabled"){dispatchEvent(event);}
		}
	}
}