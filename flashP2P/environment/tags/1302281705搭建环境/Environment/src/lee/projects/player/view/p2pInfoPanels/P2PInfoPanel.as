package lee.projects.player.view.p2pInfoPanels
{
	import flash.display.Sprite;
	
	public class P2PInfoPanel extends BaseInfoPanel
	{
		public function P2PInfoPanel(skin:Sprite)
		{
			super(skin);
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
			}
		}
	}
}