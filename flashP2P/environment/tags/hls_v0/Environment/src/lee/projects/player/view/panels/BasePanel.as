package lee.projects.player.view.panels{
	import lee.bases.BaseUI;
	import flash.text.TextField;
	import flash.display.Sprite;
	public class BasePanel extends Sprite {
		protected var _width:Number;
		protected var _height:Number;
		protected var _textField:TextField;
		protected var _callback:Function;
		public function BasePanel() {
		}
		public function updateInfo(info:Object=null):void{
			if(info)
			{
				if(_textField)
				{
					_textField.htmlText=String(info);
				}
			}
		}
		public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
				x=int((w-width)/2);
				y=int((h-height)/2);
			}
		}
		public function show(info:Object=null,callback:Function=null):void{
			visible=true;
			_callback=callback;
			updateInfo(info);
		}
		public function hide():void{
			visible=false;
		}
		protected function addChildrenFrom(skin:Sprite):void{
			var len:int=skin.numChildren;
			for(var i:int=0;i<len;i++)
			{
				addChild(skin.getChildAt(0));
			}
		}
	}
}