package lee.projects.player.view.p2pInfoPanels
{
	import flash.display.MovieClip;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	
	//import org.osmf.elements.F4MElement;
	//import org.osmf.
	
	public class ServerInfoPanel extends BaseInfoPanel
	{
		protected var _setBtn:SimpleButton;
		protected var _PauseP2P:SimpleButton;
		protected var _ResumeP2P:SimpleButton;
		protected var _btnMV:MovieClip;
		public var loadVInfo:Function;
		
		public var netStream:Object;
		
		public function ServerInfoPanel(skin:Sprite)
		{
			super(skin);
			
			_setBtn = _skin.getChildByName("setBtn") as SimpleButton;
			_setBtn.addEventListener(MouseEvent.CLICK,setBtnHandler);
			
			_btnMV = _skin.getChildByName("btnMV") as MovieClip;
			//_btnMV.gotoAndStop("pf");
			_PauseP2P = _btnMV.getChildByName("PauseP2P") as SimpleButton;
			_ResumeP2P =  _btnMV.getChildByName("ResumeP2P") as SimpleButton;
			_ResumeP2P.visible = false;
			_PauseP2P.addEventListener(MouseEvent.CLICK,PauseP2PBtnHandler);
			_ResumeP2P.addEventListener(MouseEvent.CLICK,ResumeP2PBtnHandler);
			
		}
		private function PauseP2PBtnHandler(e:MouseEvent):void
		{
			if(netStream.pauseP2P())
			{
				_ResumeP2P.visible = true;
				_PauseP2P.visible  = false;
			}
			
		}
		private function ResumeP2PBtnHandler(e:MouseEvent):void
		{
			if(netStream.resumeP2P())
			{
				_ResumeP2P.visible = false;
				_PauseP2P.visible  = true;
			}			
		}
		override public function clear():void
		{
			_skin["checkSumText"].text = "";
			_skin["gatherText"].text = "";
			_skin["rtmfpText"].text = "";
			_skin["sizeText"].text = "";
			_skin["chunksText"].text = "";
			_skin["groupNameText"].text = "";
			_skin["gatherState"].gotoAndStop("init");
			_skin["rtmfpState"].gotoAndStop("init");
			_skin["vidText"].text = "1826134";// _skin["vidText"].text;//
			//1679355  1714035 1721337 1657288 1714655 1657288 1715212 1720846 1714622
			netStream = new Object();
		}
		/*public function set vid(v:String):void
		{
			_skin["vidText"].text = "";
		}*/
		public function get vid():String
		{
			return _skin["vidText"].text;
		}
		public function addInfo(obj:Object/*info:String,name:String*/):void
		{
			switch(obj.name)
			{
				case "checkSum":
					_skin["checkSumText"].text = obj.info;
					break;
				case "gather":
					_skin["gatherText"].text = obj.info;
					break;
				case "rtmfp":
					_skin["rtmfpText"].text = obj.info;
					break;
				case "size":
					_skin["sizeText"].text = obj.info;
					break;
				case "chunks":
					_skin["chunksText"].text = obj.info;
					break;
				case "groupName":
					_skin["groupNameText"].text = obj.info;
					break;
				case "gatherOk":
					_skin["gatherState"].gotoAndStop("ok");
					break;
				case "gatherFailed":
					_skin["gatherState"].gotoAndStop("failed");
					break;
				case "rtmfpOk":
					_skin["rtmfpState"].gotoAndStop("ok");
					break;
				case "rtmfpFailed":
					_skin["rtmfpState"].gotoAndStop("failed");
					break;
				
			}
		}
		protected function setBtnHandler(e:MouseEvent):void
		{
			if(_skin["vidText"].text != "")
			{
				if(loadVInfo(_skin["vidText"].text))
				{
					super.hide();
				}				
			}
		}
	}
}