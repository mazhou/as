package lee.projects.player.utils
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	import cmodule.keygen.CLibInit;

	public class LiveKey extends EventDispatcher
	{
		private var _streamid:String="";
		private var _serverurl:String="";
		private var _time:Number=0;
		private var _useTime:Number=24;
		private var _key:String="";
		private var _loader:URLLoader;
		private var _timeout:Number=3000;
		private var _retry:uint=1;
		private var _md5:Object;
		private var _difftime:Number=0;
		private static var _instance:LiveKey;
		
		public function LiveKey()
		{
			if(_instance!=null)
			{
				throw(new Error("This is a singlon!"));
			}
		}
		public static function getInstance():LiveKey
		{
			if(!_instance)
			{
				_instance=new LiveKey();
			}
			return _instance;
		}
		public function init(obj:Object):void
		{
			_streamid=obj.streamid;
			_serverurl=obj.serverurl;
			_useTime=obj.usetime;
			if(!_md5)
			{
				var loader:CLibInit=new CLibInit();
				_md5=loader.init();
			}
		}
		public function load(flag:Boolean=false):void
		{
			if(flag)
			{
				errorHandler();
				return;
			}
			var url:String =_serverurl+"?r="+Math.random();
			_loader = new URLLoader();
			_loader.addEventListener(Event.COMPLETE,overHandler);
			_loader.addEventListener(ErrorEvent.ERROR,errorHandler);
			_loader.load(new URLRequest(url));
		}
		public function get tm():String
		{
			return String(_time+_useTime*60*60);
		}
		public function get key():String
		{
			return _key;
		}
		public function get time():Number
		{
			return _time;
		}
		public function reFreshTime():void
		{
			_time =  int(new Date().time/1000+_difftime)
			_key=_md5["calcLiveKey"](_streamid,tm);
		}
		public function getNewKey(value:Object):String
		{
			return _md5["calcLiveKey"](value.streamid,String(value.time+_useTime*60*60));
		}
		private function overHandler(evt:Event):void
		{
			var data:Object=JSON.parse(evt.target.data);
			_time=Number(data["stime"]);
			_difftime = int(_time - new Date().time/1000);
			processData();
		}
		private function errorHandler(evt:Event=null):void
		{
			/**返回错误使用本地时间*/
			_time=Math.round(new Date().time/1000);
			processData();
		}
		private function processData():void
		{
			_key=_md5["calcLiveKey"](_streamid,tm);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
	}
}