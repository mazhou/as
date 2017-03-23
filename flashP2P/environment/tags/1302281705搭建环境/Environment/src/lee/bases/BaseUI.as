package lee.bases{
	import flash.display.Sprite;
	public class BaseUI extends Sprite{
		protected var _width:Number;
		protected var _height:Number;
		public function BaseUI(){
		}
		override public function get width():Number{return _width;}
		override public function set width(w:Number):void{setSize(w,height);}
		override public function get height():Number{return _height;}
		override public function set height(h:Number):void{setSize(width,h);}
		public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
			}
		}
	}
}
