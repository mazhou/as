package com.p2p.loaders
{
	import com.p2p.data.Head;
	import com.p2p.data.LIVE_TIME;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.dataManager.IDataManager;
//	import com.p2p.events.EventExtensions;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.*;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.net.*;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	/**
	 *等同于dat加载 
	 * @author mazhoun
	 */
	public class HeadLoader //extends DATLoader
	{
		public var isDebug:Boolean=false;
		private var _dispather:IDataManager = null;
		
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader=null;//new URLLoader();
		private var _initData:InitData;
		
		private var _flvURLIndex:int=0;
		
		private var timeOutTimer:Timer;
		
		public function HeadLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			//
			addListener();
			
			timeOutTimer = new Timer(3*1000,1);
			timeOutTimer.addEventListener(TimerEvent.TIMER,timeOutHandler);
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
				try{
					loader.close();
				}catch(err:Error)
				{
					P2PDebug.traceMsg(this,err);
				}
			}
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
			
			timeOutTimer.reset();
			
		}
		//
		private function completeHandler(event:Event):void 
		{
			timeOutTimer.reset();
			//var loader:URLLoader = URLLoader(event.target);
			var data:ByteArray=event.target.data  as  ByteArray;
			
			//
			if (Task)
			{
				Task.setHeadStream(data);
				P2PDebug.traceMsg(this,"load complete:"+Task.id);
				Task = null;
			}
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler: " + event);
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			downloadError();
		}
		
		private function receiveDataHandler(event:ProgressEvent=null):void
		{
			timeOutTimer.reset();
		}
		
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"timeOutHandler: " + event);
			downloadError();
		}
		
		private function downloadError():void
		{
			timeOutTimer.reset();
			Task = null;
			_flvURLIndex++;
			if(_flvURLIndex>=_initData.flvURL.length)
			{
				_flvURLIndex=0;
			}
			removeListener();
			addListener();
		}
		//
		private var Task:Head = null;
		private function handlerDownloadTask(evt:TimerEvent=null):void
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
				
				timeOutTimer.reset();
				timeOutTimer.start();
				
				
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
			return _initData.flvURL[_flvURLIndex].replace("desc.xml",name);
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		private function addListener():void
		{
			if(loader==null)
			{
				loader = new URLLoader();
				loader.dataFormat = URLLoaderDataFormat.BINARY;
				
				loader.addEventListener(Event.COMPLETE, completeHandler);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				loader.addEventListener(ProgressEvent.PROGRESS,receiveDataHandler);			
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
				loader.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				loader=null;
			}
		}
		public function clear():void
		{
			_flvURLIndex=0;
			_downloadTaskTime.stop();
			_downloadTaskTime.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timeOutTimer.stop();
			timeOutTimer.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			
			removeListener();
			
			_dispather=null;
			_downloadTaskTime=null;
			_initData=null;
			timeOutTimer = null;
		}
	}
}
