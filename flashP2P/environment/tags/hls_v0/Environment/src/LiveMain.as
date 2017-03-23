package 
{
	import flash.display.Sprite;
	import flash.utils.setTimeout;
	
	import lee.projects.player.GlobalReference;
	import lee.projects.player.controller.HttpController;	
	
	
	[SWF(backgroundColor="0x3c3c3c",frameRate="30")]  
	public class LiveMain extends Sprite
	{
		public function LiveMain()
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
			GlobalReference.httpcontroller=new HttpController();
			GlobalReference.httpcontroller.initialize();
		}
	}
}