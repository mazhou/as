package com.p2p.loaders
{
	/*
	此类负责加载验证码的xml文件功能
	*/
	import com.p2p.events.CheckLoaderEvent;
	import com.p2p.events.P2PEvent;
	
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
	import flash.net.sendToURL;
	import flash.utils.Timer;


	public class CheckLoader extends EventDispatcher
	{
		protected const RELOAD_WAITTIME:Number=5*1000;
		protected var _loadCheck:URLLoader;
		protected var _reloadCount:int;
		protected var _reloadTimer:Timer;
		protected var _url:String;
		
		protected var _startTime:Number;
			
		public function CheckLoader(){}
		
		public function startLoadCheck(url:String):void
		{
			clear();
			_url = url;
			//_url = "http://www.sina.com"
			_loadCheck = new URLLoader();
			_loadCheck.addEventListener(Event.COMPLETE,checkComplete);
			_loadCheck.addEventListener(IOErrorEvent.IO_ERROR,ioErrorHandler);
			_loadCheck.addEventListener(SecurityErrorEvent.SECURITY_ERROR,securityErrorHandler);
			_loadCheck.load(new URLRequest(_url));
			
			_reloadTimer = new Timer(RELOAD_WAITTIME,1);
			_reloadTimer.addEventListener(TimerEvent.TIMER,reLoadCheck);
			
			_startTime = getTime();
		}
		//
		public function clear():void
		{
			if(_loadCheck)
			{
				_loadCheck.removeEventListener(IOErrorEvent.IO_ERROR,ioErrorHandler);
				_loadCheck.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,securityErrorHandler);
				_loadCheck.removeEventListener(Event.COMPLETE,checkComplete);
				try
				{
					_loadCheck.close();
				}
				catch(err:Error)
				{
					//trace(this+err.message);
				}
				_loadCheck = null;
			}
			
			clearReloadTimer();
			
			_reloadCount = 0;
			_url = "";
			_startTime = 0;
		}
		private function clearReloadTimer():void
		{
			if(_reloadTimer)
			{
				if(_reloadTimer.running)
				{
					_reloadTimer.stop();
				}
				try{
					_reloadTimer.removeEventListener(TimerEvent.TIMER,reLoadCheck);
				}catch(err:Error){
					//trace(this+err.message);
				}
				_reloadTimer=null;
			}
		}
		/*private function loadCheck_HTTP_STATUS(e:HTTPStatusEvent):void
		{
			if (e.status == 404)
			{	
				clear();
				failedHandler("notFoundError");				
			}
			
		}*/
		private function checkComplete(e:Event):void
		{
			var obj:Object=new Object();
			try
			{
				obj.myXML = new XML(e.target.data);
				obj.error = 0;
				
				obj.utime = getTime()-_startTime;
				
			    var event:P2PEvent = new CheckLoaderEvent(CheckLoaderEvent.SUCCESS,obj);
				dispatchEvent(event);
				clear();
			}catch(e:Error)
			{
				failedHandler("dateError")
			}			
		}
		private function ioErrorHandler(e:IOErrorEvent):void
		{
			failedHandler("ioError");
		}
		private function securityErrorHandler(e:SecurityErrorEvent):void
		{
			failedHandler("securityError");
		}
		private function reLoadCheck(e:TimerEvent):void
		{
			_loadCheck.load(new URLRequest(_url));
		}	
		private function failedHandler(str:String):void
		{
			if(_reloadCount < 3)
			{			
				_reloadTimer.reset();
				_reloadTimer.start();
				_reloadCount++;
			}
			else
			{	
				var obj:Object = new Object();
				obj.text = str;
				obj.type = "CheckLoader";
				obj.error = 999;
				
				obj.utime = getTime()-_startTime;
				
				var event:P2PEvent = new P2PEvent(P2PEvent.ERROR,obj);
				dispatchEvent(event);
				
				clear();
			}
		}
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}