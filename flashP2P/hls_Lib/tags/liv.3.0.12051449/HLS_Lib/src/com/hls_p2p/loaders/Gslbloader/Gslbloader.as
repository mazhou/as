package com.hls_p2p.loaders.Gslbloader
{
	import cmodule.keygen.CLibInit;
	
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.p2p.utils.ParseUrl;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class Gslbloader extends EventDispatcher
	{
		public var isDebug:Boolean			 	   = true;
		
		private var _isLoad:Boolean			 	   = false;
		private var loader:URLLoader		 	   = null;
		
		private var _initData:InitData;
		private var _downloadTaskTime:Timer;
		
		protected var m_DataManager:DataManager   = null;
		
		public function Gslbloader( p_DataManager:DataManager )
		{
			m_DataManager = p_DataManager;
			if( _downloadTaskTime == null )
			{
				_downloadTaskTime = new Timer( 0,1 );
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			addListener();
		}
		
		public function start( _initData:InitData ):void
		{
			this._initData = _initData;
			if( !_downloadTaskTime.running )
			{
				_downloadTaskTime.start();
			}
		}
		
		private function GetsecurityKey_1( p_gslbUrl:String ):String
		{
			if( _initData.keyCreater )
			{
				try{
					var tmpobj:Object = _initData.keyCreater.getKey();
					
					if(tmpobj)
					{
						P2PDebug.traceMsg(this,"tm: "+tmpobj.tm+" key:"+tmpobj.key);
						p_gslbUrl = ParseUrl.replaceParam(p_gslbUrl,"tm",tmpobj.tm);
						p_gslbUrl = ParseUrl.replaceParam(p_gslbUrl,"key",tmpobj.key);
					}
				}
				catch(error:Error)
				{
					P2PDebug.traceMsg(this,"_initData.keyCreater is null ");
				}
			}
			return p_gslbUrl;
		}
		
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE )
			{
				_downloadTaskTime.stop();
			}
			if( this._initData.gslbURL != "" )
			{
				try{
					_isLoad = true;
					var strurl:String = _initData.gslbURL;
					P2PDebug.traceMsg(this,"gslb: "+ strurl);
					strurl = GetsecurityKey_1( strurl );
					P2PDebug.traceMsg(this,"new gslb: "+strurl);
					loader.load( new URLRequest(strurl) );
				}catch(err:Error)
				{
					_downloadTaskTime.delay = 1000;
					_downloadTaskTime.reset();
					_downloadTaskTime.start();
				}
			}
//			else
//			{
//				_downloadTaskTime.delay = 1000;
//				_downloadTaskTime.reset();
//				_downloadTaskTime.start();
//			}
		}
		
		private function completeHandler(event:Event):void 
		{
			_isLoad = false;
			var tmpxml:XML = new XML(event.target.data);

			if( tmpxml.hasOwnProperty("nodelist") )
			{
				if( tmpxml.nodelist.child("node").length() )
				{
					_initData.flvURL = new Array();
					_initData.setIndex(0);
					for each( var tempxml:XML in tmpxml.nodelist.children() )
					{
						P2PDebug.traceMsg(this,"gslb xml_node"+ tempxml.toString());
						_initData.flvURL.push(tempxml.toString());
					}
					_initData.g_bGslbComplete = true;
				}
			}
			
			if( tmpxml.hasOwnProperty("forcegslb") )
			{
				_downloadTaskTime.delay =  Number(tmpxml.forcegslb)*1000;
				_downloadTaskTime.reset();
				_downloadTaskTime.start();
			}else
			{
				_downloadTaskTime.delay =  3000;
				_downloadTaskTime.reset();
				_downloadTaskTime.start();
			}
		}

		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			_isLoad=false;
//			removeListener();
			_downloadTaskTime.delay =  3000;
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
		}
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			_isLoad=false;
			_downloadTaskTime.delay =  3000;
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
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
			}
		}
		
		private function removeListener():void
		{
			if( loader!=null )
			{
				try
				{
					loader.close();
				}
				catch(err:Error)
				{
				}
				
				loader.removeEventListener(Event.COMPLETE, completeHandler);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				
				loader=null;
			}
		}
		
		public function clear():void
		{
			_isLoad=false;
			_downloadTaskTime.stop();
			_downloadTaskTime.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			removeListener();
			_downloadTaskTime 		= null;
			//_initData.g_bGslbComplete = false;
			_initData				=null;
		}
		
	}
}