package com.p2p.loaders
{
	
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;	
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	public class GSLBLoad extends EventDispatcher
	{
		public var isDebug:Boolean=false;
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader=null;
		private var _initData:InitData;
		private var _isLoad:Boolean=false;
		
		private var _downloadTaskTimeDelay:Number = 5*60*1000;
		
		public function start( _initData:InitData):void
		{
			this._initData = _initData;
			if (_downloadTaskTime == null)
			{
				_downloadTaskTime = new Timer( _downloadTaskTimeDelay );
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			if(!_downloadTaskTime.running)
			{
				_downloadTaskTime.start();
			}
			//TEST
			handlerDownloadTask()
		}
		/**test
		private var arr:Array = ["http://123.126.32.19:1935/Test/xml/x0.xml",
								   "http://123.126.32.19:1935/Test/xml/x1.xml",
								   "http://123.126.32.19:1935/Test/xml/x2.xml",
								   "http://123.126.32.19:1935/Test/xml/x3.xml"]
		private var arr:Array = ["http://127.126.32.19/xml/x0.xml",
			"http://127.126.32.19/xml/x1.xml",
			"http://127.126.32.19/xml/x2.xml",
			"http://127.126.32.19/xml/x3.xml"]
	    private var idx:int = 0;
		*/
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			addListener();
			if(this._initData.gslb!="")
			{
				_isLoad=true;
				loader.load(new URLRequest(_initData.gslb));
				
				/**test
				loader.load(new URLRequest(arr[idx]));
				idx++;
				if(idx>=arr.length)
				{
					idx = 0;
				}
				*/
			}else
			{
				_downloadTaskTime.reset();
			}
		}
		
		private function completeHandler(event:Event):void 
		{
			_downloadTaskTime.reset();
			try
			{
				_isLoad=false;
//				var obj:Object = JSONDOC.decode(event.target.data);	
				var xml:XML=new XML(event.target.data);
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
			
			if(xml.hasOwnProperty("forcegslb"))
			{
				var forcegslb:Number  = Number(xml.forcegslb);
				
				if(_downloadTaskTime.delay != forcegslb*1000)
				{
					_downloadTaskTime.delay = forcegslb*1000;
				}
			}
			
			if(xml.hasOwnProperty("livesfmust"))
			{
				var livesfmust:Number = Number(xml.livesfmust);
				if(livesfmust ==1)
				{
					if(xml.hasOwnProperty("livesftime"))
					{						
						Statistic.getInstance().setNetStreamOffTime(Number(xml.livesftime));						
					}
				}
			}
			
			EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.GSLB_SUCCESS,"");
			//dispatchEvent(new  EventExtensions("GSLB_SUCCESS",null));
			
			P2PDebug.traceMsg(this,"gslb"+_initData.flvURL);
						
			_downloadTaskTime.start();
			
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
			
			_downloadTaskTimeDelay = 5*60*1000;
		}
	}
}