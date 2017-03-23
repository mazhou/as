package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.console;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class Selector extends EventDispatcher
	{
		public var groupID:String;
		public var gatherName:String;
		public var gatherPort:uint;
		public var rtmfpName:String;
		public var rtmfpPort:uint;
		public var maxQPeers:uint = 0;
		public var hbInterval:uint = 11;
		
		private var _selectorTimer:Timer;
		private var _selector:Selector_Loader;
		private var _selectorName:String = "selector.webp2p.letv.com";
		private var _selectorPort:uint   = 80;
		private var selectorCount:uint =0;
		
		
		public function Selector(groupID:String)
		{
			this.groupID = groupID;
		}
		public function load():void
		{
			if(!_selectorTimer)
			{
				_selectorTimer = new Timer(0);
				_selectorTimer.addEventListener(TimerEvent.TIMER, selectorInit );
				_selectorTimer.start();
			}
		}
		public function reload():void
		{
			_selectorTimer.start();
		}
		public function clear():void
		{
			if(_selectorTimer)
			{
				_selectorTimer.stop();
				_selectorTimer.removeEventListener(TimerEvent.TIMER,selectorInit);
				_selectorTimer = null;
			}
		}
		private function selectorInit(event:* = null):void
		{	
			if( _selector )
			{
				if( _selector.isConnecting == true )
				{
					return;
				}
				
				if( true == _selector.noRequest )
				{
					_selectorTimer.stop();
					return;
				}
				
				trace("selectorInit"+this.groupID);
				_selectorTimer.delay = 100;
				if( _selector.error )
				{
					if( selectorCount <= 3 )
					{
						++selectorCount;
						//trace("selectorCount = "+selectorCount+" , delay = "+_selectorTimer.delay+" , startTime = "+(new Date).time);
					}
					
					//
					if( _selector )
					{
						_selector.clear();
						_selector = null;
					}
					//_selector.error = false;
					_selectorTimer.reset();
					_selectorTimer.delay = selectorCount*8*1000;
					_selectorTimer.start();
					
					return;
				}
				
				//
				if( _selector.isOK )
				{	
					rtmfpPort 	= _selector.rtmfpPort;
					rtmfpName 	= _selector.rtmfpIp;
					
					gatherName = _selector.proxyIp;
					gatherPort = _selector.proxyPort;
					//					_startPublishNetStreamTime =this.getTime();
					if( true == _selector.sharePeers )
					{
						LiveVodConfig.IS_SHARE_PEERS = _selector.sharePeers;
					}
					if( _selector.maxQPeers > 0 )
					{
						maxQPeers = _selector.maxQPeers;
					}
					if( _selector.hbInterval > 0 )
					{
						hbInterval = _selector.hbInterval;
					}
					console.log(this,"gather = "+gatherName+":"+gatherPort);
					/**过程上报*/
					Statistic.getInstance().selectorSuccess(groupID);
					_selectorTimer.stop();					
					_selector.clear();
					_selector = null;
					dispatchEvent(new Event(Event.COMPLETE));
					return;
				}
				else if ( _selector.redirectSelector )
				{
					_selectorName = _selector.selectorIP;
					_selectorPort = _selector.selectorPort;
					
					_selector.init(groupID, _selectorName, _selectorPort);
					return;
				}
			}
			
			_selector = new Selector_Loader();
			_selector.init(groupID, _selectorName, _selectorPort);
		}
	}
}