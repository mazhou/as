package lee.projects.player.view.p2pInfoPanels
{
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	
	public class PeerInfoPanel extends BaseInfoPanel
	{
		protected var _setBtn:SimpleButton;
		
		protected var _peerStateObj:Object;
		
		public var dataManager:Object;
		
		public function PeerInfoPanel(skin:Sprite)
		{
			super(skin);
			
			_setBtn = _skin.getChildByName("setBtn") as SimpleButton;
			_setBtn.addEventListener(MouseEvent.CLICK,setBtnHandler);
		}
		override public function clear():void
		{
			_skin["peerText1"].text = "";
			_skin["peerText2"].text = "";
			_skin["peerText3"].text = "";
			_skin["peerText4"].text = "";
			_skin["peerText5"].text = "";
			_skin["peerText6"].text = "";
			_skin["peerText7"].text = "";
			
			_skin["peerState1"].gotoAndStop("init");
			_skin["peerState2"].gotoAndStop("init");
			_skin["peerState3"].gotoAndStop("init");
			_skin["peerState4"].gotoAndStop("init");
			_skin["peerState5"].gotoAndStop("init");
			_skin["peerState6"].gotoAndStop("init");
			_skin["peerState7"].gotoAndStop("init");
			/**lz 1212 add*/
			_skin["peerText8"].text = "";
			_skin["peerText9"].text = "";
			_skin["peerText10"].text = "";
			_skin["peerText11"].text = "";			
			_skin["peerState8"].gotoAndStop("init");
			_skin["peerState9"].gotoAndStop("init");
			_skin["peerState10"].gotoAndStop("init");
			_skin["peerState11"].gotoAndStop("init");
			/**************/
			_skin["myPeerText"].text = "";
			
			_peerStateObj = new Object();
		}
		public function addInfo(obj:Object/*info:String,name:String*/):void
		{
			switch(obj.name)
			{
				case "peerID":
					
					clearPeerText();
					var j:int = 1;					
					
					if(obj.info != undefined)
					{
						for(var i:String in obj.info)
						{	
							if(i == "myName")
							{
								continue;
							}
							
							if(_skin["peerText"+j] && 
								obj.info[i] && 
								(i.search("state") == -1))
							{
								_skin["peerText"+j].text = obj.info[i];
								
								if(obj.info[i+"state"] && (obj.info[i+"state"] == "ok"))
								{
									_skin["peerState"+j].gotoAndStop("ok");
								}
								else
								{
									_skin["peerState"+j].gotoAndStop("init");
								}
								//trace("obj.info  ------ "+obj.info[i]);
								
							}else
							{
								continue;
							}
							
							//trace("j = "+j)
							j++;
						}					
					}
					break;
				
				case "myPeerID":
					
					if(obj.info)
					{
						_skin["myPeerText"].text = obj.info.substr(0,10);
					}
					
					break;
				
				/*case "peerState":
					
					for(var p:int = 1 ; p<=7 ; p++)
					{
						if(_skin["peerText"+p].text == obj.peerID)
						{
							_skin["peerState"+p].gotoAndStop(obj.state);
						}
					}
					break;*/
			}
		}
		protected function setBtnHandler(e:MouseEvent):void
		{
			if(_skin["myPeerText"].text != "")
			{
				//dataManager.test_userID = _skin["myPeerText"].text;
				dataManager.userName["myName"] = _skin["myPeerText"].text;
			}
		}
		protected function clearPeerText():void
		{
			for(var i:int = 1  ; i <= 7  ; i++)
			{						
				_skin["peerText"+i].text = "";
				_skin["peerState"+i].gotoAndStop("init");
			}
		}
	}
}