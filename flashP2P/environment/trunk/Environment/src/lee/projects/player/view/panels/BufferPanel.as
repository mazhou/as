package lee.projects.player.view.panels{
	import lee.projects.player.view.panels.BasePanel;
	import flash.display.Sprite;
	import flash.display.MovieClip;
	import flash.text.TextField;
	import flash.text.StyleSheet;
	import flash.events.TextEvent;
	public class BufferPanel extends BasePanel {
        protected var _loadingmv:MovieClip;
		public function BufferPanel(skin:Sprite) {
			addChildrenFrom(skin);
			_textField=getChildByName("msgText") as TextField;
			_textField.addEventListener(TextEvent.LINK,_textField_LINK);
			_loadingmv=getChildByName("loadingmv") as MovieClip;
			var css:String="a:link{display:inline;color:#993333;text-decoration:underline;}a:hover{color:#CC3300;text-decoration:underline;}";
			var sheet:StyleSheet=new StyleSheet();
			sheet.parseCSS(css);
			_textField.styleSheet=sheet;
			this.mouseEnabled=false;
			this.mouseChildren=false;
		}
		override public function show(info:Object=null,callback:Function=null):void{
			visible=true;
			_callback=callback;
			_loadingmv.play();
			updateInfo(info);
		}
		override public function hide():void{
			_loadingmv.stop();
			visible=false;
		}
		protected function _textField_LINK(event:TextEvent):void{
			if(_callback!=null)
			{
				_callback.call(this,event.text);
			}
		}
	}
}