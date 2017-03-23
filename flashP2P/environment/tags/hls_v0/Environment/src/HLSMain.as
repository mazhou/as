package 
{
	import flash.display.Sprite;
	import flash.utils.setTimeout;
	
	import lee.projects.player.GlobalReference;
	import lee.projects.player.controller.HLSController;	
	
	
	[SWF(backgroundColor="0x3c3c3c",frameRate="30")]  
	public class HLSMain extends Sprite
	{
		public function HLSMain()
		{
			trace(this,"HLSMain");
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
			GlobalReference.HLSstatisticManager=new HLSStatisticManager();
			GlobalReference.stage = stage;
			GlobalReference.root = this;
			GlobalReference.HLScontroller=new HLSController();
			GlobalReference.HLScontroller.initialize();
		}
	}
}