package analysisURL
{	
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	public class ContinuityAnalysisURL extends EventDispatcher
	{
		[Embed(source="MMSystem.swf",mimeType="application/octet-stream")]
		private var SYSTEM:Class;
		
		//类库.
		private var lib:Object;
		//类库载入程式.
		private var libLoader:Loader;
		
		private var isRunning:Boolean = false;
		
		private var perID:String  = "";
		
		private var nextID:String = "";
		
		private var voidInfoObj:Object;
		
		public function ContinuityAnalysisURL()
		{
			libLoader = new Loader();
			libLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,onLibInit);			
		}
		
		public function start( id:String ):void
		{
			if( perID == id )
			{
				return;
			}
			voidInfoObj = new Object();
			perID = id;
			nextID= "";
			libLoader.loadBytes(new SYSTEM());
		}
		
		private function onLibInit(event:Event):void
		{
			libLoader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onLibInit);
			libLoader = null;
			lib = event.target.content;
			lib.addEventListener("mmsFailed",onFailed);
			lib.addEventListener("mmsComplete",onComplete);
			lib.load( perID );
		}
		
		private function onFailed(event:Event):void
		{
			trace("ContinuityAnalysisURL Error");
			lib.destroy();
		}
		
		private function onComplete(event:Event):void
		{
			var result:Object = event["dataProvider"];
			var list:Object = result.list;
			var nextvid:Object = result.nextvid;
			
			if( nextID == "" )
			{
				if( nextvid != null )
				{
					start( nextID );
				}
				dispatchG3SuccessEvent();
			}
			else
			{
				dispatchG3SuccessEvent();
			}
		}
		protected function dispatchG3FailedEvent():void
		{
		/*	obj.code = "URLAnalysisFailed";
			
			dispatchEvent(new AnalysisEvent(AnalysisEvent.ERROR,obj));*/
			
		}
		protected function dispatchG3SuccessEvent():void
		{
			dispatchEvent(new AnalysisEvent(AnalysisEvent.STATUS,voidInfoObj));
		}
		public function clear():void
		{
			
		}
	}
}