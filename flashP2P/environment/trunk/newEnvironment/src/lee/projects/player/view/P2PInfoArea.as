package lee.projects.player.view
{
//	import flash.events.MouseEvent;
	
	import lee.bases.BaseUI;
	import lee.projects.player.view.p2pInfoPanels.P2PInfoPanel;
	import lee.projects.player.view.p2pInfoPanels.PeerInfoPanel;
	import lee.projects.player.view.p2pInfoPanels.ServerInfoPanel;
	
	
	public class P2PInfoArea extends BaseUI
	{
		public var serverInfoPanel:ServerInfoPanel;
		public var p2pInfoPanel:P2PInfoPanel;
		public var peerInfoPanel:PeerInfoPanel;
		public var wspeerInfoPannel:PeerInfoPanel
		
		public function P2PInfoArea()
		{
			peerInfoPanel=new PeerInfoPanel(new PeerInfoPanelSkin());
			peerInfoPanel.Title="RTMFP节点";
			peerInfoPanel.x = 10;
			peerInfoPanel.y = 30;
			//peerInfoPanel.hide();
			addChild(peerInfoPanel);/**/
			
			wspeerInfoPannel = new PeerInfoPanel(new PeerInfoPanelSkin());
			wspeerInfoPannel.Title="WebSocket节点";
			wspeerInfoPannel.x = 240;
			wspeerInfoPannel.y =30;
			addChild(wspeerInfoPannel);/**/
			
			serverInfoPanel=new ServerInfoPanel(new ServerInfoPanelSkin());
			serverInfoPanel.x = 580//30;
			serverInfoPanel.y = 355//40;
			//serverInfoPanel.hide();
			addChild(serverInfoPanel);
			
			p2pInfoPanel=new P2PInfoPanel(new P2PInfoPanelSkin());
			p2pInfoPanel.x = 580//50;
			p2pInfoPanel.y = 30//50;
			//p2pInfoPanel.hide();
			addChild(p2pInfoPanel);/**/			
			
		}
		public function clear():void
		{
			serverInfoPanel.clear();
			p2pInfoPanel.clear();
			peerInfoPanel.clear();
		}
		public function serverInfo(obj:Object):void
		{
			serverInfoPanel.addInfo(obj);
		}
		public function p2pInfo(obj:Object):void
		{
			p2pInfoPanel.addInfo(obj);
		}
		public function peerInfo(obj:Object):void
		{
			if(obj.name.indexOf("_ws")>-1)
			{
				//trace("------------------"+obj.name)
				wspeerInfoPannel.addInfo(obj);
			}
			else
			{
				peerInfoPanel.addInfo(obj);
			}
		}
		public function set dataManager(obj:Object):void
		{
			peerInfoPanel.dataManager = obj;			
		}
		public function set loadVInfo(f:Function):void
		{
			serverInfoPanel.loadVInfo = f;
		}
		public function set netStream(obj:Object):void
		{
			serverInfoPanel.netStream = obj;
			p2pInfoPanel.netStream    = obj;
		}
		public function clearAll():void
		{
			peerInfoPanel.clear();
			serverInfoPanel.clear();
			p2pInfoPanel.clear();
		}
	}
}