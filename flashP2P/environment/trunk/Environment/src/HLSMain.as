package 
{
	import flash.display.Sprite;
	import flash.utils.setTimeout;
	
	import lee.projects.player.GlobalReference;
	import lee.projects.player.controller.HLSController;	
	
	
	[SWF(backgroundColor="0x000000",frameRate="30")]  
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
		{//test()
			GlobalReference.HLSstatisticManager=new HLSStatisticManager();
			GlobalReference.type = "LIVE";
			//GlobalReference.type = "VOD";
			GlobalReference.stage = stage;
			GlobalReference.root = this;
			GlobalReference.HLScontroller=new HLSController();
			GlobalReference.HLScontroller.initialize();
		}
		private var obj:Object = {"id":1,"name":"li","age":10};
		private var obj1:Object = {"id":1,"name":"li","age":10};
		private var arr:Array  = new Array;
		private function test():void
		{
			var temp1:Object = obj1;
			
			arr.push(obj);
			var tempObj0:Object = arr[0];
			var tempObj:Object;
			for(var i:int=0 ; i<arr.length ; i++)
			{
				tempObj = arr[i];
			}
			if( tempObj0 === tempObj )
			{
				trace(true);
			}
			else
			{
				trace(false);
			}
			if( temp1 == tempObj )
			{
				trace(true);
			}
			else
			{
				trace(false);
			}
			var j:int = -2;
			j = arr.indexOf(tempObj0);
			if( j > -1)
			{
				arr.splice(j,1);
			}
			trace(arr.length)
		}
	}
}