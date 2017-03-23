package lee.projects.player.view.p2pInfoPanels
{
	import flash.display.Sprite;
	import flash.display.SimpleButton;
	import flash.events.MouseEvent;
	
	public class P2PInfoPanel extends BaseInfoPanel
	{
		protected var _adSkipBtn:SimpleButton;
		
		public var netStream:Object;
		
		public function P2PInfoPanel(skin:Sprite)
		{
			super(skin);
			
			_adSkipBtn = _skin.getChildByName("adSkipBtn") as SimpleButton;
			_adSkipBtn.addEventListener(MouseEvent.CLICK,adSkipBtnHandler);
		}
		override public function clear():void
		{
			_skin["bufferTimeText"].text = "";
			_skin["bufferLengthText"].text = "";
			_skin["timeText"].text = "";
			_skin["chunkIndexText"].text = "";
			_skin["P2PRateText"].text = "";
			_skin["P2PSpeedText"].text = "";
			_skin["avgSpeedText"].text = "";
			
			adTimed = false;
			netStream = new Object();
		}
		public function addInfo(obj:Object):void
		{			
			switch(obj.name)
			{
				case "bufferTime":
					_skin["bufferTimeText"].text = obj.info;
					break;
				case "bufferLength":
					_skin["bufferLengthText"].text = obj.info;
					break;
				case "time":
					_skin["timeText"].text = obj.info;
					break;
				case "chunkIndex":
					_skin["chunkIndexText"].text = obj.info;
					break;
				case "P2PRate":
					_skin["P2PRateText"].text = obj.info;
					break;
				case "P2PSpeed":
					_skin["P2PSpeedText"].text = obj.info;
					break;
				case "avgSpeed":
					_skin["avgSpeedText"].text = obj.info;
					break;	
				case "adTime":
					if(!adTimed)
					{
						_skin["adTimeText"].text = obj.info;
					}					
					break;
			}
		}
		private var adTimed:Boolean = false;
		protected function adSkipBtnHandler(e:MouseEvent):void
		{
			if(netStream)
			{
				adTimed = true;
				netStream["resume"]();
				_skin["adTimeText"].text = 0;
			}
		}
	}
}