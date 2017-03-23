package lee.managers
{
    import lee.projects.player.view.P2PInfoArea;
	
	public class P2PInfoManager
	{
		static public var p2pInfoArea:P2PInfoArea;
		static public var dataManager:Object;
		
		public function P2PInfoManager()
		{
		}
		
		static public function clear():void
		{
			p2pInfoArea.clear();
			dataManager = new Object();
		}
	}
}