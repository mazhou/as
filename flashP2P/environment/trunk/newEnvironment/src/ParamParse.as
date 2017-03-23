package
{
	import flash.display.Loader;
	import flash.events.Event;

	public class ParamParse
	{
		[Embed(source="MMSystem.swf",mimeType="application/octet-stream")]
		private var SYSTEM:Class;
		
		//类库.
		private var lib:Object;
		//类库载入程式.
		private var libLoader:Loader;
		
		private var callBack:Function;
		public function ParamParse()
		{
			
		}
		public function strucFun(callBack:Function):void
		{
			libLoader = new Loader();
			libLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,onLibInit);
			libLoader.loadBytes(new SYSTEM());
		}
		
		private function onLibInit(event:Event):void
		{
			libLoader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onLibInit);
			libLoader = null;
			lib = event.target.content;
			
			lib.addEventListener("mmsFailed",onFailed);
			lib.addEventListener("mmsComplete",onComplete);
		}
		private function onFailed(event:Event):void
		{
//			textarea.text = "【failed】";
			lib.destroy();
		}
		
		private function onComplete(event:Event):void
		{
			var result:Object = event["dataProvider"];
			var list:Object = result.list;
//			var nextvid:Object = result.nextvid;
			callBack(list);
//			var rateItem:Object;
//			var value:String = "【下一集ID】"+nextvid+"\n";
//			for(var item:String in list)
//			{
//				value += "【码流】 "+item+"\n";
//				rateItem = list[item];
//				if(rateItem != null)
//				{
//					for(var key:String in rateItem){
//						value += key+" : "+rateItem[key]+"\n";
//					}
//				}
//			}
//			textarea.text = value;
		}
		
		public function getMsg(vid:String,callBack:Function):void
		{
			this.callBack=callBack;
			lib.load(vid);
		}
		
	}
}