package lee.commons{
	import lee.bases.BaseEvent;
	import flash.events.EventDispatcher;
	import flash.events.Event;
	import flash.events.ErrorEvent;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	public class DataLoader extends EventDispatcher {
		public static const COMPLETE:String = "complete";
		public static const ERROR:String = "error";
		private var loader:URLLoader;
		private var _type:String;
		public function DataLoader() {
			
		}
		
		public function load(url:String,type:String=null):void{
			clear();
			_type=type;
			loader = new URLLoader();
			loader.addEventListener(Event.COMPLETE,loader_COMPLETE);
			loader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
			loader.load(new URLRequest(url));
		}
		public function clear():void{
			_type=null;
			if(loader)
			{
			    loader.removeEventListener(Event.COMPLETE,loader_COMPLETE);
			    loader.removeEventListener(IOErrorEvent.IO_ERROR,loader_ERROR);
			    loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,loader_ERROR);
			    loader=null;
			}
		}
		private function loader_COMPLETE(evt:Event):void{
			var obj:Object=new Object();
			obj.data=evt.target.data;
			obj.type=_type;
			clear();
			dispatchEvent(new BaseEvent(DataLoader.COMPLETE,obj));
		}
		private function loader_ERROR(evt:ErrorEvent):void{
			var obj:Object=new Object();
			obj.text=evt.text;
			obj.type=_type;
			clear();
			dispatchEvent(new BaseEvent(DataLoader.ERROR,obj));
		}
    }
}