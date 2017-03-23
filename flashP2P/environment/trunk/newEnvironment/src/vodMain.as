package 
{
	import flash.display.Sprite;
	import flash.utils.setTimeout;
	
	import lee.projects.player.GlobalReference;
	import lee.projects.player.controller.Controller;

	
//	[SWF(width="688",height="387",backgroundColor="0xffffff",frameRate="30")]
	[SWF(backgroundColor="0x333333",frameRate="12")]
	public class vodMain extends Sprite
	{
		public function vodMain()
		{
			init();
		}
		protected function init():void
		{
			if (stage.stageWidth > 0)
			{
				realInit();
			}
			else
			{
				setTimeout(init,200);
			}
		}
		protected function realInit():void
		{
			GlobalReference.statisticManager=new StatisticManager();
			GlobalReference.stage = stage;
			GlobalReference.root = this;
			GlobalReference.controller=new Controller();
			GlobalReference.controller.initialize();
		}
	}
}