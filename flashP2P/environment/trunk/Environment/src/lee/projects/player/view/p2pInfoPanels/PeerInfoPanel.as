package lee.projects.player.view.p2pInfoPanels
{
	import com.p2p.data.vo.LiveVodConfig;
	
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
			dataManager = new Object();
		}
		public function addInfo(obj:Object/*info:String,name:String*/):void
		{
			switch(obj.name)
			{
				case "peerID":
					
					clearPeerText();									
					
					disPlayPeer(obj);
					
					break;
				
				case "myPeerID":
					
					if(obj.info)
					{
						_skin["myPeerText"].text = obj.info/*obj.info.substr(0,10)*/;
					}
					
					break;
				
				case "peerState":
					
					disPlayPeerState(obj.data);
					break;/**/
			}
		}
		private function disPlayPeer(obj:Object):void
		{
			/**用obj.info属性区别新版与旧版，obj.info != undefined为旧版*/
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
						
					}else
					{
						continue;
					}					
					j++;
				}					
			}
			else if(obj.data != undefined)
			{
				for each(var p:Object in obj.data)
				{
					/**
					 * p:Object的数据结构
					 * p.name:对方的名称
					 * p.farID:对方farID
					 * p.state:连接状态"notConnect","connect","halfConnect","signalling"
					 * */
					if(p["name"] && _skin["peerText"+j])
					{
						_skin["peerText"+j].text = p["name"];
						_skin["peerState"+j].farID = p["farID"];
						
						if(p["state"] == "connect")
						{
							_skin["peerState"+j].gotoAndStop("ok");
						}
						else if(p["state"] == "halfConnect")
						{
							_skin["peerState"+j].gotoAndStop("half");
						}
						else if(p["state"] == "notConnect")
						{
							_skin["peerState"+j].gotoAndStop("init");
						}
					}
					j++;
				}
			}
		}
		private function disPlayPeerState(obj:Object):void
		{			
			/**
			 * obj:Object的数据结构
			 * obj.farID:对方farID
			 * obj.state:连接状态"notConnect","connect","halfConnect","signalling"
			 * */
			for(var j:int = 0 ; j<11 ; j++)
			{
				if(_skin["peerState"+j] 
					&& _skin["peerState"+j].hasOwnProperty("farID") 
					&& _skin["peerState"+j]["farID"] == obj.farID)
				{
					switch(obj.state)
					{
						case "notConnect":
							_skin["peerState"+j].gotoAndStop("init");
							return;
						case "connect":
							_skin["peerState"+j].gotoAndStop("ok");
							return;
						case "halfConnect":
							_skin["peerState"+j].gotoAndStop("half");
							return;
						case "signalling":
							_skin["peerState"+j].gotoAndPlay("signalling");
							return;							
					}
				}
			}
		}
		protected function setBtnHandler(e:MouseEvent):void
		{
			if(_skin["myPeerText"].text != "")
			{
				//dataManager.test_userID = _skin["myPeerText"].text;
				if(dataManager && dataManager.userName && dataManager.userName["myName"])
				{
					dataManager.userName["myName"] = _skin["myPeerText"].text;
				}
				else if(LiveVodConfig && LiveVodConfig.MY_NAME)
				{
					LiveVodConfig.MY_NAME = _skin["myPeerText"].text;
				}
				
			}
		}
		protected function clearPeerText():void
		{
			for(var i:int = 1  ; i <= 11  ; i++)
			{						
				_skin["peerText"+i].text = "";
				_skin["peerState"+i].gotoAndStop("init");
			}
		}
	}
}