package com.p2p.lib
{
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Timer;
	
	public class STUNConnecter extends EventDispatcher
	{
		/**连接rtmfp通道*/
		private var _netConnection:NetConnection;
		/**加载STUN服务的http请求*/
		private var _urlLoader:URLLoader;
		/**连接rtmfp的ip和端口*/
		private var _stunRtmfpURL:String;
		/**连接STUN服务器的ip和端口*/
		private var _stunReqURL:String;
		/**本地nearID*/
		private var _peerID:String;
		/**当加载失败时，进行重新加载的计时器*/
		private var _myTimer:Timer
		/**当失败时，保存加载rtmfp的加载方法startNetConnection()或连接STUN服务器的方法startURLLoader()*/
		private var _progressFunction:Function
		
		/**本类生成对象的最终结果将保存在natType中，默认值为-1，表示未接收到数据；
		 * 如果请求调度成功，natType中的值为：0、1或2 
		 * 0：节点位于公网上 
		 * 1：节点所在的NAT设备为对称型 
		 * 2：节点所在的NAT设备为锥型
		 * */
		public var kindOfNat:int = -1;
		/**允许连接失败的次数*/
		private var _errorCount:int=0;
		
		public function STUNConnecter(stunRtmfpURL:String,stunReqURL:String)
		{
			init(stunRtmfpURL,stunReqURL)
		}
		private function init(stunRtmfpURL:String,stunReqURL:String):void
		{
			clear();
			
			_stunRtmfpURL = stunRtmfpURL;
			_stunReqURL   = stunReqURL;
			
			_netConnection = new NetConnection();
			_netConnection.addEventListener(NetStatusEvent.NET_STATUS,netStatusHandler);
			_netConnection.addEventListener(IOErrorEvent.IO_ERROR,netErrorHandler);			
			startNetConnection();
			
			_urlLoader = new URLLoader();
			_urlLoader.addEventListener(Event.COMPLETE,urlLoadHandler);
			_urlLoader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
			_urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
			
			_myTimer = new Timer(3*1000,1);
			_myTimer.addEventListener(TimerEvent.TIMER,myTimerHandler);
		}
		public function clear():void
		{
			_stunRtmfpURL     = null;
			_stunReqURL       = null;			
			_progressFunction = null;
			kindOfNat           = -1;
			_peerID           = null;
			
			clearNetConnection();
			
			clearURLLoader();
			
			clearMyTimer();
		}
		private function startNetConnection():void
		{
			//MZDebugger.trace(this,"rtmfp://"+_stunRtmfpURL);
			_netConnection.connect( "rtmfp://"+_stunRtmfpURL+"/");
		}
		private function clearNetConnection():void
		{
			if (_netConnection)
			{
				_netConnection.removeEventListener(NetStatusEvent.NET_STATUS,netStatusHandler);
				_netConnection.removeEventListener(IOErrorEvent.IO_ERROR,netErrorHandler);
				try{
					_netConnection.close();
				}
				catch(err:Error)
				{
					//MZDebugger.trace(this,err.message);
				}
				_netConnection = null;
			}
		}
		private function clearURLLoader():void
		{
			if(_urlLoader)
			{
				_urlLoader.removeEventListener(Event.COMPLETE,urlLoadHandler);
				_urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
				_urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
				_urlLoader = null;
			}
		}
		private function clearMyTimer():void
		{
			if(_myTimer)
			{
				_myTimer.stop();
				_myTimer.removeEventListener(TimerEvent.TIMER,myTimerHandler);
				_myTimer = null;
			}			
		}
		private function netErrorHandler(event:* = null):void
		{			
			_progressFunction = startNetConnection;
			_myTimer.reset();
			_myTimer.start();
		}
		private function netStatusHandler(e:NetStatusEvent):void
		{						
			switch (e.info.code)
			{
				case "NetConnection.Connect.Success" :
					_peerID = _netConnection.nearID;
					clearNetConnection();
					startURLLoader();					
					break;
				case "NetConnection.Connect.Closed" :
				case "NetConnection.Connect.Failed" :
				case "NetConnection.Connect.Rejected" :
				case "NetConnection.Connect.AppShutdown" :
				case "NetConnection.Connect.InvalidApp" :
				case "NetConnection.Call.Prohibited" :
				case "NetConnection.Call.BadVersion" : 
				case "NetConnection.Call.Failed":
				case "NetConnection.Call.Prohibited":
				case "NetConnection.Connect.IdleTimeout":  					
					netErrorHandler();
					break;
			}	
		}
		private function startURLLoader():void
		{
			//trace("http://"+_stunReqURL+"/query?peerId="+_peerID);
			_urlLoader.load(new URLRequest("http://"+_stunReqURL+"/query?peerId="+_peerID));
		}
		private function urlLoadHandler(e:Event):void
		{
			/**
			 *  JOSN结构：
			 * {“result”:”success”,”value”:{”natType”:0}}
			 * */
			try
			{	
				var obj:Object = JSONDOC.decode(String(_urlLoader.data));
				if(obj["result"] == "success")
				{
					kindOfNat = obj["value"]["natType"];
					dispatchEvent(new Event(Event.COMPLETE));
				}
				else
				{
					loader_ERROR(null);
				}
			}
			catch(e:Error)
			{
				loader_ERROR(null);
				return;
			}
		}
		
		private function loader_ERROR(e:* = null):void
		{
			_progressFunction = startURLLoader;
			_myTimer.reset();
			_myTimer.start();
		}
		
		private function myTimerHandler(e:TimerEvent):void
		{
			if(_errorCount<3)
			{
				_errorCount++;
				_progressFunction();
			}
			else
			{
				dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
			}
		}
	}
}