package lee.projects.player.view.p2pInfoPanels
{
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	
	import lee.bases.BaseUI;
	
	import mx.core.FlexTextField;
	
	public class BaseInfoPanel extends Sprite
	{
		
		private var _dragBtn:SimpleButton;
		private var _closeBtn:SimpleButton;
		protected var _skin:Sprite;
		
		public function BaseInfoPanel(skin:Sprite)
		{
			_skin = skin;
			addChild(_skin);
			
			clear();
			
			_closeBtn = skin.getChildByName("closeBtn") as SimpleButton;
			_closeBtn.addEventListener(MouseEvent.CLICK,hide);
			
			_dragBtn = skin.getChildByName("dragBtn") as SimpleButton;
			_dragBtn.addEventListener(MouseEvent.MOUSE_DOWN,stratDarg);
			_dragBtn.addEventListener(MouseEvent.MOUSE_UP,stopDarg);
		}
		public function show():void{
			visible=true;
			getTop();
		}
		public function hide(e:*=null):void{
			visible=false;
		}
		public function getTop():void
		{
			if(this.parent && 
			   this.parent.numChildren > 1)
			{
				//trace("this.parent.numChildren  "+this.parent.numChildren)
				this.parent.addChildAt(this,(this.parent.numChildren-1));
			}
			
		}
		protected function stratDarg(e:MouseEvent):void
		{
			//x = mouseX;
			//y = mouseY;
			getTop();
			_skin.startDrag();

		}
		protected function stopDarg(e:MouseEvent):void
		{
			_skin.stopDrag();
		}
		public function clear():void
		{
			
			/*trace("_skin  =  "+(typeof _skin))
			if(_skin is SeverInfoPanel)
			{
				trace("checkSumText----------------")
				_skin["checkSumText"].text = "";
			}
			for(var i:String in _skin)
			{
				trace("i  "+i)
				if(i is TextField)
				{
					_skin[i].text = "";
				}
			}*/
		}
		
	}
}