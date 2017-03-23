package com.mzStudio.component.load
{
	import com.mzStudio.event.EventExtensions;
	
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.errors.IOError;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.system.ApplicationDomain;
	import flash.system.LoaderContext;
	import flash.system.SecurityDomain;
	import flash.system.System;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	/**
	 * 资源加载器,分两类URLLoader和Loader加载器,是动态类
	 * <UL>
	 * <LI> 文本加载 </LI>
	 * <LI> 媒体加载，包含格式："swf", "png", "gif", "jpg", "jpeg" </LI>
	 * </UL>
	 * <p>
	 * 如果是URLLoader加载，将返回URLLoader的data属性；</p><p>
	 * 如果是Loader加载将返回EventExtensions的data值，其中data.dispalay是现实对象类型，data.info是LoaderInfo类型
	 * </p>
	 * @author mazhoun
	 */
	public dynamic class AssetLoader extends EventDispatcher
	{
		public static const TIME_UP:String = 'time up';
		public static const IO_ERROR:String = 'io error';
		public static const SECURITY_ERROR:String = 'security error';
		public static const DATA_ERROR:String = 'data Error';
		
		private var _loaderExtensions:Array = ["swf", "png", "gif", "jpg", "jpeg"];
		private var _loader:Loader;
		private var _urlLoader:URLLoader;
		private var _urlStreamLoader:URLStream;
		private var timer:Timer;
		private var _initError:Boolean = false;
		private var _canceled:Boolean = false;
		private var _dataFormat:String="";
		private var _readSize:uint=0;
		private var isCancelLoad:Boolean;
		
		/**加载资源地址*/
		public var url:String="";
		
		public var currentType:String;
		
		/**
		 *加载方法 
		 *URLLoaderDataFormat.TEXT，URLLoaderDataFormat.BINARY，URLLoaderDataFormat.VARIABLES其中一种
		 * 并以URLLoader加载方式，忽略文件后缀判断
		 * <listing>
		 * var assetLoader=new AssetLoader();
		 * assetLoader.addEventListener(Event.COMPLETE,completeHandler);
		 * assetLoader.addEventListener(ErrorEvent.ERROR,errorHandler);
		 * assetLoader.load(url,time,dataFormat);
		 * 
		 * protected function completeHandler(evt:EventExtensions):void
		 * {
		 * 	trace(this+evt.data);
		 * }
		 * private function errorHandler(evt:ErrorEvent):void
		 * {
		 * 	trace(this+evt.text);
		 * }
		 * </listing>
		 * 
		 * @param url为加载的地址，其中后缀名区分为那个加载器加载
		 * @param expectedTime期望返回的时间，超过时间调度错误事件	,单位精确到秒	
		 * @param dataFormat是
		 * 
		 */
		public function load(url:String,expectedTime:int = 0,_dataFormat:String=""):void{
			if(url==null){return;}
			this.url=url;
			if (expectedTime > 0) {
				timer = new Timer(expectedTime * 1000, 1);
				timer.addEventListener(TimerEvent.TIMER, timeup);
			}
			if(_dataFormat!=""){
				this._dataFormat=_dataFormat;
				useURLLoader(url);
				return;
			}
			var ext:String = url.substring(url.lastIndexOf('.') + 1, url.length);
			if (_loaderExtensions.indexOf(ext) >= 0) {
				
				useLoader(url);
			} else {
				
				useURLLoader(url);
			}
		}
		
		private function timeup(evt:TimerEvent):void
		{
			if(_canceled)return;
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, AssetLoader.TIME_UP));
			cancelLoad();
		}
		
		/**
		 *<listing>
		 * var assetLoader=new AssetLoader();
		 * assetLoader.addEventListener(Event.COMPLETE,completeHandler);
		 * assetLoader.addEventListener(ErrorEvent.ERROR,errorHandler);
		 * assetLoader.load(url,time,dataFormat);
		 * 
		 * protected function completeHandler(evt:EventExtensions):void
		 * {
		 * 	trace(this+evt.data); is byteArray
		 * }
		 * private function errorHandler(evt:ErrorEvent):void
		 * {
		 * 	trace(this+evt.text);
		 * }
		 * </listing>
		 * @param url
		 * @param expectedTime
		 * @param readSize
		 * 
		 */
		public function loadStream(url:String,expectedTime:int = 0,isCancelLoad:Boolean=true,readSize:uint=0):void {
			if(url==null){return;}
			this.url=url;
			this._readSize=readSize;
			this.isCancelLoad=isCancelLoad;
			if (expectedTime > 0) {
				if(!timer){
					timer = new Timer(expectedTime * 1000, 1);
					timer.addEventListener(TimerEvent.TIMER, timeup);
				}
			}
			
			streamLoader(url);
		}
		protected function streamLoader(url:String):void
		{
			currentType="streamload";
			urlStreamLoader.load(new URLRequest(url)); 
			if (timer) timer.start();
		}
			
		protected function useLoader(url:String):void
		{
			currentType="load";
			var context:LoaderContext;
			if(url.indexOf('http') == 0){
				context=new LoaderContext(true, ApplicationDomain.currentDomain, SecurityDomain.currentDomain);
				loader.load(new URLRequest(url), context);
			}else{
				context = new LoaderContext(false,ApplicationDomain.currentDomain,null);
				var req:URLRequest = new URLRequest(url);
				req.contentType = "";
				loader.load(req);
			}
			if (timer) timer.start();
			
		}
		
		protected function useURLLoader(url:String):void
		{
			currentType="urlload";
			urlLoader.load(new URLRequest(url)); 
			if (timer) timer.start();
		}
		
		private function get loader():Loader {
			if (!_loader) {
				_loader = new Loader();
				_loader.contentLoaderInfo.addEventListener(Event.INIT, loadInit);
				_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loadComplete);
				_loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, loadError);
				_loader.contentLoaderInfo.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loadError);
			}
			return _loader;
		}
		/**
		 * 二进制加载 
		 * @param byteArray
		 * 
		 */
		public function loadBytes(byteArray:ByteArray):void {
			var loaderContext:LoaderContext = new LoaderContext();
		  	loaderContext.allowLoadBytesCodeExecution = true; 
			loader.loadBytes(byteArray,loaderContext);
		}
		protected function get urlStreamLoader():URLStream
		{
			if (!_urlStreamLoader){
				_urlStreamLoader=new URLStream();
				_urlStreamLoader.addEventListener(Event.COMPLETE, urlStreamCompleteHandler);
				_urlStreamLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, urlStreamHttpStatusHandler);
				_urlStreamLoader.addEventListener(Event.OPEN, urlStreamOpenHandler);
				_urlStreamLoader.addEventListener(ProgressEvent.PROGRESS, urlStreamProgressHandler);
				
				_urlStreamLoader.addEventListener(IOErrorEvent.IO_ERROR, loadError);
				_urlStreamLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loadError);
			}
			return _urlStreamLoader;
		}
		protected function get urlLoader():URLLoader {
			if (!_urlLoader) {
				_urlLoader = new URLLoader();
				if(_dataFormat!=""){
					_urlLoader.dataFormat=_dataFormat;
				}
				_urlLoader.addEventListener(ProgressEvent.PROGRESS,urlLoadProgress)
				_urlLoader.addEventListener(Event.COMPLETE, urlLoadComplete);
				_urlLoader.addEventListener(IOErrorEvent.IO_ERROR, loadError);
				_urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loadError);
			}
			return _urlLoader;
		}
		
		/**
		 *取消本次加载
		 */
		public function cancelLoad():void
		{
			if(_canceled)return;
			_canceled = true;
			
			if (currentType=="load") {
				currentType="";
				loader.contentLoaderInfo.removeEventListener(Event.INIT, loadInit);
				loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, loadComplete);
				loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, loadError);
				loader.contentLoaderInfo.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loadError);	
				_loader=null
			}                                                                                              
			
			if (currentType=="urlload") {
				currentType="";
				urlLoader.removeEventListener(ProgressEvent.PROGRESS,urlLoadProgress)
				urlLoader.removeEventListener(Event.COMPLETE, urlLoadComplete);
				urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, loadError);
				urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loadError);
				_urlLoader=null;
			}                                                                               
			if (currentType=="streamload") {
				currentType="";
				_urlStreamLoader=new URLStream();
				_urlStreamLoader.removeEventListener(Event.COMPLETE, urlStreamCompleteHandler);
				_urlStreamLoader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, urlStreamHttpStatusHandler);
				_urlStreamLoader.removeEventListener(Event.OPEN, urlStreamOpenHandler);
				_urlStreamLoader.removeEventListener(ProgressEvent.PROGRESS, urlStreamProgressHandler);
				
				_urlStreamLoader.removeEventListener(IOErrorEvent.IO_ERROR, loadError);
				_urlStreamLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loadError);
				try{
					_urlStreamLoader.close();
				}catch(err:IOError){
					trace(this+err.message+err.getStackTrace());
				}
				_urlStreamLoader=null;
			}
			if (timer) {
				if (timer.running) {
					timer.stop();
				}                
				timer.removeEventListener(TimerEvent.TIMER, timeup);
			}
		}
		
		private function urlStreamCompleteHandler(evt:Event):void
		{
			try{
				var data:ByteArray = new ByteArray();
				_urlStreamLoader.readBytes(data);
				dispatchEvent(new EventExtensions(Event.COMPLETE, data));
				if(isCancelLoad){
					cancelLoad();
				}
			}catch(err:Error){
				if(_canceled){return;}
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "data Error"));
				cancelLoad();
			}
			
		}
		private function urlStreamProgressHandler(evt:Event):void
		{
			trace(this+"Progress:"+evt)
			trace(this+"bytesAvailable:"+_urlStreamLoader.bytesAvailable);
			var data:ByteArray = new ByteArray();
			_urlStreamLoader.readBytes(data);
			//if(_readSize>0){
			//}
//			dispatchEvent(new EventExtensions(ProgressEvent.PROGRESS, ));
		}
		
		private function urlStreamHttpStatusHandler(evt:HTTPStatusEvent):void
		{
			//dispatchEvent(new EventExtensions(HTTPStatusEvent.HTTP_STATUS,evt.status));			
		}
		
		private function urlStreamOpenHandler(evt:Event):void
		{
			dispatchEvent(new EventExtensions(Event.OPEN,evt));
			
			if (timer) {
				if (timer.running) {
					trace(this+"停止时间")
					timer.stop();
				}
			}
		}
		
		
		private function urlLoadProgress(evt:ProgressEvent):void{
			try
			{
				if(!(evt.target as URLLoader).data){return};
				dispatchEvent(new EventExtensions(Event.COMPLETE,(evt.target as URLLoader).data));
			} 
			catch (err:Error)
			{       
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, err.message));
			}
		}
		private function urlLoadComplete(evt:Event):void
		{    
			try
			{
				dispatchEvent(new EventExtensions(Event.COMPLETE,(evt.target as URLLoader).data));
			} 
			catch (err:Error)
			{       
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, err.message));
			}
			cancelLoad();
		}
		private function loadComplete(evt:Event):void
		{                                           
			try {
				var obj:Object=new Object();
				obj.dispalay=(evt.target as LoaderInfo).content;
				obj.info=(evt.target as LoaderInfo);
				dispatchEvent(new EventExtensions(Event.COMPLETE,obj));
			} catch (err:Error) {   
				if (!_initError)   
					dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, AssetLoader.SECURITY_ERROR));
			}
			cancelLoad();
		}
		private function loadInit(evt:Event):void
		{             
			try {
				var obj:Object=new Object();
				obj.dispalay=(evt.target as LoaderInfo).content;
				obj.info=(evt.target as LoaderInfo);
				dispatchEvent(new EventExtensions(Event.INIT,obj));
			} catch (err:Error) {
				_initError = true;
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, AssetLoader.SECURITY_ERROR));
			}                
		}
		private function loadError(evt:ErrorEvent=null):void
		{                           
			var text:String;
			if (evt is IOErrorEvent) {
				text = AssetLoader.IO_ERROR;
			} else if (evt is SecurityErrorEvent) {
				text = AssetLoader.SECURITY_ERROR;
			}   
			if(_canceled){return;}
			dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, text));			
			cancelLoad();
		}
	}
}