package com.p2p.loaders
{
	import com.p2p.data.Head;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.*;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.net.*;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import com.p2p.data.LIVE_TIME;
	
	/**
	 *等同于dat加载 
	 * @author mazhoun
	 */
	public class HeadLoader //extends DATLoader
	{
		public var isDebug:Boolean=true;
		private var _dispather:IDataManager = null;
		
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader;//new URLLoader();
		private var _initData:InitData;
		public function HeadLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			//
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			
			loader.addEventListener(Event.COMPLETE, completeHandler);
			loader.addEventListener(Event.OPEN, openHandler);
			loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
			loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
		public function start( _initData:InitData):void
		{
			this._initData = _initData;
			if (_downloadTaskTime == null)
			{
				_downloadTaskTime = new Timer(5);
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			//
			if (Task)
			{
				Task = null;
				loader.close();
			}
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
			
		}
		//
		private function completeHandler(event:Event):void 
		{
			P2PDebug.traceMsg(this,"load complete:"+Task.id);
			//var loader:URLLoader = URLLoader(event.target);
			var data:ByteArray=event.target.data  as  ByteArray
			
			Task.setHeadStream(data);
			//
			if (Task)
			{
				Task = null;
			}
		}
		
		private function openHandler(event:Event):void
		{
			P2PDebug.traceMsg(this,"openHandler: " + event);
		}
		
		private function progressHandler(event:ProgressEvent):void
		{
//			P2PDebug.traceMsg(this,"progressHandler loaded:" + event.bytesLoaded + " total: " + event.bytesTotal);
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler: " + event);
			Task = null;
		}
		
		private function httpStatusHandler(event:HTTPStatusEvent):void 
		{
			P2PDebug.traceMsg(this,"httpStatusHandler: " + event);
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			Task = null;
		}
		//
		private var Task:Head = null;
		public function handlerDownloadTask(evt:TimerEvent=null):void
		{
			
			if (_dispather && null == Task)
			{
				Task = _dispather.getHeadTask();//(LIVE_TIME.GetBaseTime());
				if (Task == null)
					return;
				//
				var url:String = getDatURL(Task.id + ".header")+"&rdm="+getTime();
				P2PDebug.traceMsg(this,"start load:"+url);
				var request:URLRequest = new URLRequest(url);
				try
				{
					loader.load(request);
					
				} catch (error:Error)
				{
					P2PDebug.traceMsg(this,"Unable to load requested document.");
					Task = null;
				}
			}
		}
		protected function getDatURL(name:String):String
		{
			return _initData.flvURL[0].replace("desc.xml",name);
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}
