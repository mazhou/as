package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.loaders.Gslbloader.Gslbloader;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.Timer;
	
	internal class GeneralLiveM3U8Loader implements IDescLoader
	{
		private var _initData:InitData 			= null;
		private var _dataManager:IDataManager 	= null;	
		
		public 	var isDebug:Boolean 			= true;
		private var n_desc_URLIndex:int 		= 0;
		
		//private var m_bLastError:Boolean		= false;
		//private var m_strLastUrl:String			= "";
		
		private var loader_descreq:URLLoader;
		private var timer_downloadTask:Timer;
		private var timer_timeOut:Timer;
		
		public var totalDuration:Number			= 0;	
		//local_variable
		
		public function GeneralLiveM3U8Loader(_dataManager:IDataManager)
		{
			this._dataManager = _dataManager;
			
			timer_timeOut = new Timer(3*1000,1);
			timer_timeOut.addEventListener(TimerEvent.TIMER,timeOutHandler);
			
			addListener();
		}
		
		public function start(_initData:InitData):void
		{
			this._initData = _initData;
			
			if( timer_downloadTask == null )
			{
				timer_downloadTask = new Timer(5);
				timer_downloadTask.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			
			timer_downloadTask.delay = 5;
			
			timer_downloadTask.reset();
			timer_downloadTask.start();
			
			timer_timeOut.reset();
		}
		
		public function clear():void
		{		
			timer_downloadTask.stop();
			timer_downloadTask.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timer_timeOut.stop();
			timer_timeOut.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			
			removeListener();
			
			_dataManager 			= null;
			timer_downloadTask  = null;
			_initData 			= null;
			timer_timeOut 		= null;	
		}
		
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"timeOutHandler: " + event);
			
			downloadError();
		}
		
		private function downloadError():void
		{
			if( _initData.g_nM3U8Idx >= _initData.flvURL.length-1 )
			{
				_initData.g_nM3U8Idx = 0;
			}
			else
			{
				++_initData.g_nM3U8Idx;
			}
			
			LoadManager.g_bsticLastM3U8Error = true;
			timer_timeOut.reset();
				
			removeListener();
			addListener();
			
			//if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				timer_downloadTask.delay = 5;
				timer_downloadTask.reset();
				timer_downloadTask.start();
			}
			
			timer_downloadTask.reset();
			timer_downloadTask.start();
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				_initData.g_bVodLoaded = false;
			}
		}

		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			if( _dataManager )
			{
				LoadManager.g_bsticLastM3U8Error = false;
				
				var url:String = "";
				var tmpobj:Object = _dataManager.getM3U8Task();
				url = tmpobj.url;
				
				timer_downloadTask.delay = tmpobj.delaytime;
				
				if( LiveVodConfig.TYPE == LiveVodConfig.VOD && _initData.g_bVodLoaded == true )
				{
					return;
				}
				
				if(url == "")
				{
					return;
				}

				try
				{
					removeListener();
				}
				catch(error:Error)
				{
					P2PDebug.traceMsg(this,"close error:"+error);
				}
				
				addListener();
				
				LoadManager.g_strsticLastUrl = url;
				P2PDebug.traceMsg(this," GeneralLiveM3u8_url:"+ url);
				var request:URLRequest = new URLRequest(url);
				
				timer_timeOut.reset();
				timer_timeOut.start();
				
				try
				{
					loader_descreq.load(request);
				}
				catch (error:Error)
				{
					trace("Unable to load requested document.");
				}
			}
		}
		
		private function addListener():void
		{
			if(loader_descreq==null)
			{
				loader_descreq = new URLLoader();
				loader_descreq.dataFormat = URLLoaderDataFormat.TEXT;
				
				loader_descreq.addEventListener(Event.COMPLETE, completeHandler_2);
				loader_descreq.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader_descreq.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				loader_descreq.addEventListener(ProgressEvent.PROGRESS,receiveDataHandler);			
			}
		}
		
		private function removeListener():void
		{
			if(loader_descreq!=null)
			{
				try
				{
					loader_descreq.close();
				}
				catch(err:Error)
				{
				}
				loader_descreq.removeEventListener(Event.COMPLETE, completeHandler_2);
				loader_descreq.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader_descreq.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				loader_descreq.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				loader_descreq=null;
			}
		}
	
		public function callbak( p_ClipVector:Vector.<Clip>):void
		{
			//Statistic.getInstance().loadXMLSuccess(groupID);
			
//			_initData.videoHeight = height;
//			_initData.videoWidth  = width;
			
			_dataManager.writeClipList(p_ClipVector);
			
		}
		
		private function completeHandler_2(event:Event):int 
		{
			// 此函数中为了调试方便，保留了一些额外的临时变量
			timer_timeOut.reset();		
			(new ParseM3U8_uniform).parseFile( String(event.target.data),_initData,callbak );
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				_initData.g_bVodLoaded = true;
			}
			return 0;
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler"+event);
			
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler"+event);
			
			downloadError();
		}
		
		private function receiveDataHandler(event:ProgressEvent=null):void
		{
			timer_timeOut.reset();
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
//		protected function getShiftPath(url:String):String
//		{
//			/*var reg:RegExp=/\/\/(\d+.\d+.\d+.\d+)\//;
//			if(reg.test(url)){
//			url=url.replace(url.match(reg)[1],"111.161.65.99");
//			}
//			var reg2:RegExp=/path=(\d+.\d+.\d+.\d+,\d+.\d+.\d+.\d+)/;
//			if(reg2.test(url)){
//			url=url.replace(url.match(reg2)[1],"111.161.65.99");
//			}
//			var reg3:RegExp=/path=(\d+.\d+.\d+.\d+)/;
//			if(reg3.test(url)){
//			url=url.replace(url.match(reg3)[1],"111.161.65.99");
//			}*/
//			
//			
//			
////			if(LiveVodConfig.M3U8_MAXTIME == 0)
////			{
////				url=url.replace("desc.xml","")+ "&rdm=" + getTime();
////			}
////			else
////			{
////				url=url.replace("desc.xml","")+"&abtimeshift=" + LiveVodConfig.M3U8_MAXTIME + "&rdm=" + getTime();
////			}
//			
////			return url;
//			/**/
//
//			url=url.replace("desc.xml","")+"&abtimeshift=";
//			return url;
//		}
		
		private function getMiniMinute(id:Number):Number
		{
			var date:Date  = new Date(id*1000);
			date = new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
			return Math.floor(date.time/1000);
		}

	}
}