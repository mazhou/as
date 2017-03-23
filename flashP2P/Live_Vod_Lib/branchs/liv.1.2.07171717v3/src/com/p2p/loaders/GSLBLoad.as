package com.p2p.loaders
{
	
	import com.p2p.data.vo.InitData;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class GSLBLoad
	{
		public var isDebug:Boolean=true;
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader=null;
		private var _initData:InitData;
		private var _isLoad:Boolean=false;
		public function start( _initData:InitData):void
		{
			this._initData = _initData;
			if (_downloadTaskTime == null)
			{
				_downloadTaskTime = new Timer(5*60*1000);
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			if(!_downloadTaskTime.running)
			{
				_downloadTaskTime.start();
			}
			//TEST
			//handlerDownloadTask()
		}
		
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			addListener();
			if(this._initData.gslb!="")
			{
				_isLoad=true;
				loader.load(new URLRequest(_initData.gslb));
			}else
			{
				_downloadTaskTime.reset();
			}
		}
		
		private function completeHandler(event:Event):void 
		{
			try
			{
				_isLoad=false;
//				var obj:Object = JSONDOC.decode(event.target.data);	
				var xml:XML=new XML(event.target.data)
			}catch(e:Error)
			{
				return;
			}
			//
			if(xml.hasOwnProperty("nodelist"))
			{
				if(xml.nodelist.child("node").length()){
					_initData.flvURL=new Array();
					for each(var tempxml:XML in xml.nodelist.children()){
						_initData.flvURL.push(tempxml.toString());
					}
				}
			}
			P2PDebug.traceMsg(this,"gslb"+_initData.flvURL)
//			if(obj.hasOwnProperty("nodelist"))
//			{
//				if(obj.nodelist.length>0)
//				{
//					_initData.flvURL=new Array;
//					for(var i:int=0;i<obj.nodelist.length;i++){
//						_initData.flvURL.push(obj.nodelist[i]["location"]);	
//					}
//				}
//			}
		}
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			_isLoad=false;
			removeListener();
		}
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			_isLoad=false;
			removeListener();
		}
		public function GSLBLoad()
		{
			
		}
		private function addListener():void
		{
			if(loader==null)
			{
				loader = new URLLoader();
				loader.dataFormat = URLLoaderDataFormat.TEXT;
				
				loader.addEventListener(Event.COMPLETE, completeHandler);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				//				loader.addEventListener(ProgressEvent.PROGRESS,receiveDataHandler);			
			}
		}
		private function removeListener():void
		{
			if(loader!=null)
			{
				try{
					loader.close();
				}catch(err:Error)
				{
				}
				loader.removeEventListener(Event.COMPLETE, completeHandler);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				//				loader.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				loader=null;
			}
		}
		public function clear():void
		{
			_isLoad=false;
			
			_downloadTaskTime.stop();
			_downloadTaskTime.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			removeListener();
			
			_downloadTaskTime=null;
			_initData=null;
		}
	}
}