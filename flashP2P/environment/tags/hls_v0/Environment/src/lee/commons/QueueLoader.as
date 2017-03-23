package lee.commons{
	import lee.utils.ArrayUtil;
	import lee.bases.BaseEvent;
	
	import flash.events.EventDispatcher;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.ErrorEvent;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;

	import flash.display.Loader;
	import flash.display.LoaderInfo;
	
	import flash.net.URLRequest;
	import flash.net.URLLoader;
	import flash.net.URLStream;
	
	import flash.media.Sound;
	import flash.media.SoundLoaderContext;
	
    import flash.system.LoaderContext;
	public class QueueLoader extends EventDispatcher {

		public static const ITEM_START:String="itemStart";
		public static const ITEM_ERROR:String="itemError";
		public static const ITEM_PROGRESS:String="itemProgress";
		public static const ITEM_COMPLETE:String="itemComplete";
		public static const QUEUE_START:String="queueStart";
		public static const QUEUE_COMPLETE:String="queueComplete";
		
		private var _loaderTypes:Array = ["URLLoader","Loader","Sound","URLStream"];

		private var _itemArray:Array;
		private var _loader:Object;
		private var _loadingItem:Object;
		
		public function QueueLoader() {
		}
		public function addItem(type:String,name:String,url:String,context:*=null):void{
			var obj:Object=new Object();
			obj.type=type;
			obj.name=name;
			obj.url=url;
			obj.context=context;
			obj.state="initial";
			obj.data=null;
			if(!_itemArray)
			{
				_itemArray=new Array();
			}
			_itemArray.push(obj);
		}
		public function start():void{
			dispatchEvent(new BaseEvent(QueueLoader.QUEUE_START,null));
			startLoad(_itemArray[0]);
		}
		public function resume():void{
			var index:int=ArrayUtil.indexByField(_itemArray,"state","initial");
			if(index!=-1)
			{
				startLoad(_itemArray[index]);
			}
			else
			{
				dispatchEvent(new BaseEvent(QueueLoader.QUEUE_COMPLETE,null));
			}
		}
		public function close():void{
			if(_loader)
			{
				try
				{
					_loader.close();
				}
				catch(error:Error)
				{}
			}
		}
		public function clear():void{
			close();
			_itemArray=null;
			_loader=null;
			_loadingItem=null;
		}
		//-----------------------------------------------------------------------------
		public function get numItems():uint{
			return _itemArray.length;
		}
		public function get loadingItem():Object{
			return _loadingItem;
		}
		public function getDataByIndex(index:uint):*{
			return (index<numItems)?_itemArray[index].data:null;
		}
		public function getDataByName(name:String):*{
			var index:int=ArrayUtil.indexByField(_itemArray,"name",name);
			return (index!=-1)?_itemArray[index].data:null;
		}
		public function getItemByIndex(index:uint):Object{
			return (index<numItems)?_itemArray[index]:null;
		}
		public function getItemByName(name:String):Object{
			var index:int=ArrayUtil.indexByField(_itemArray,"name",name);
			return (index!=-1)?_itemArray[index]:null;
		}
		//==============================================================================
		private function startLoad(item:Object):void{
			_loadingItem=item;
			switch (item.type)
			{
				case _loaderTypes[0]:
				    _loader=new URLLoader();
					addLoaderListener(_loader as EventDispatcher);
					_loader.load(new URLRequest(item.url));
					break;
				case _loaderTypes[1]:
				    _loader=new Loader();
					addLoaderListener(_loader.contentLoaderInfo as EventDispatcher);
					_loader.load(new URLRequest(item.url),(item.context as LoaderContext));
					break;
				case _loaderTypes[2]:
				    _loader=new Sound();
					addLoaderListener(_loader as EventDispatcher);
					_loader.load(new URLRequest(item.url),(item.context as SoundLoaderContext));
					break;
				case _loaderTypes[3]:
				    _loader=new URLStream();
					addLoaderListener(_loader as EventDispatcher);
				    _loader.load(new URLRequest(item.url));
					break;
				default:
				    throw new Error(item.type+"不是有效值！");
			}
			dispatchEvent(new BaseEvent(QueueLoader.ITEM_START,item));
		}
		private function getLoaderData(type:String):* {
			if(!_loader)
			{
				return;
			}
			switch (type)
			{
				case _loaderTypes[0]:
				    return _loader.data;
					break;
				case _loaderTypes[1]:
				    var ret:*=_loader.content;
				    _loader.unload();
					return ret;
					break;
				case _loaderTypes[2]:
					return _loader;
					break;
				case _loaderTypes[3]:
				    return _loader;
					break;
				default:
				    throw new Error("不是有效的AssetLoader类型！");
			}
		}
		private function addLoaderListener(loader:EventDispatcher):void{
			loader.addEventListener(Event.COMPLETE,_loaderComplete);
		    loader.addEventListener(ProgressEvent.PROGRESS,_loaderProgress);
			loader.addEventListener(IOErrorEvent.IO_ERROR,_loaderError);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,_loaderError);
		}
		private function removeLoaderListener(loader:EventDispatcher):void{
			loader.removeEventListener(Event.COMPLETE,_loaderComplete);
		    loader.removeEventListener(ProgressEvent.PROGRESS,_loaderProgress);
			loader.removeEventListener(IOErrorEvent.IO_ERROR,_loaderError);
			loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,_loaderError);
		}
		//===============================================================================
		private function _loaderComplete(event:Event):void {
			var item:Object=_loadingItem;
			item.state="complete";
			item.data=getLoaderData(item.type);
			removeLoaderListener(event.currentTarget as EventDispatcher);
			_loadingItem=null;
			_loader=null;
			dispatchEvent(new BaseEvent(QueueLoader.ITEM_COMPLETE,item));
			resume();
		}
		private function _loaderError(event:ErrorEvent):void {
			var item:Object=_loadingItem;
			item.state="error";
			removeLoaderListener(event.currentTarget as EventDispatcher);
			_loadingItem=null;
			_loader=null;
			dispatchEvent(new BaseEvent(QueueLoader.ITEM_ERROR,item));
		}
		private function _loaderProgress(event:ProgressEvent):void {
			var obj:Object=new Object();
			obj.name=_loadingItem.name;
			obj.bytesLoaded=event.bytesLoaded;
			obj.bytesTotal=event.bytesTotal;
			obj.percentLoaded=(event.bytesTotal!=0)?(event.bytesLoaded/event.bytesTotal):0;
			dispatchEvent(new BaseEvent(QueueLoader.ITEM_PROGRESS,obj));
		}
    }
}