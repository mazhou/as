package demo
{
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	
	public class SimpleDemo extends Sprite
	{
		public function SimpleDemo()
		{
			if(stage){
				init();
			}else{
				addEventListener(Event.ADDED_TO_STAGE,init);
			}
		}
		private function init(event:Event = null):void
		{
			removeEventListener(Event.ADDED_TO_STAGE,init);
			
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			connect = new NetConnection();
			connect.connect(null);
			
			video1 = new Video(320,180);
			video1.smoothing = true;
			video1.x = video1.y = 50;
			addChild(video1);
			
			tf1 = new TextField();
			tf1.x = 50;
			tf1.y = video1.y - 20;
			tf1.width = 320;
			tf1.height = 20;
			tf1.text = "正常导入   Time: 0";
			tf1.type=TextFieldType.INPUT;
			addChild(tf1);
			
			btn.graphics.beginFill(0xf0,1);
			btn.graphics.drawRect(0,0,80,20);
			btn.graphics.endFill();
			btn.addEventListener(MouseEvent.CLICK,clickHandler);
			btn.x=200;
			btn.y= video1.y - 20;
			addChild(btn);
			stream1 = new HTTPNetStream(connect);
			stream1.bufferTime = 1;
			video1.attachNetStream(stream1);
			stream1.addEventListener(NetStatusEvent.NET_STATUS,onNetStatus);
			
			stream1.client=new ClientObject_HLS;
			stream1.play(streamName, startTime, len);
			
			setLoop(true);
		}
		private function clickHandler(evt:MouseEvent):void
		{
			stream1.seek(Number(tf1.text));
		}
		private var inter:int;
		private function setLoop(flag:Boolean):void
		{
			clearInterval(inter);
			if(flag){
				inter = setInterval(onLoop,30);
			}
		}
		private function onLoop():void
		{
			tf1.text = "正常导入    Time: "+stream1.time;
		}
		
		private function onNetStatus(event:NetStatusEvent):void
		{
			//trace(event.info.code);
		}
		
		private var connect:NetConnection;
		private var video1:Video;
		private var tf1:TextField;
		private var btn:Sprite=new Sprite;
		private var stream1:HTTPNetStream;
		private var streamName:String="http://127.0.0.1/hls/group/a.m3u8";
		private var startTime:int=0;
		private var len:int=-1;
	}
}