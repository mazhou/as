package 
{
	import flash.display.Sprite;
	import flash.utils.setTimeout;
	
	import lee.projects.player.GlobalReference;
	import lee.projects.player.controller.M3u8Controller;	
	
	
	[SWF(backgroundColor="0x3c3c3c",frameRate="30")]  
	public class M3u8Main extends Sprite
	{
		public function M3u8Main()
		{
			trace(this,"M3u8Main");
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
			GlobalReference.m3u8statisticManager=new M3u8StatisticManager();
			GlobalReference.stage = stage;
			GlobalReference.root = this;
			GlobalReference.m3u8controller=new M3u8Controller();
			GlobalReference.m3u8controller.initialize();
		}
	}
}