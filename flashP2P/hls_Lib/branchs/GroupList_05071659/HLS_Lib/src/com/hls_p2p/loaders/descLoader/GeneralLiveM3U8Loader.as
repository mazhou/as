package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.loaders.Gslbloader.Gslbloader;
	import com.hls_p2p.loaders.LoadManager;
	import com.p2p.utils.console;
	
	import flash.external.ExternalInterface;
	
	import com.p2p.utils.ParseUrl;
	
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
		public var isDebug:Boolean 				= true;
		private var _initData:InitData 			= null;
		private var _dataManager:DataManager 	= null;	
		private var m_bAssumeQuery:Boolean		= true;
		
		private var isLoading:Boolean			= false;
		
		private var n_desc_URLIndex:int 		= 0;
		
		//private var m_bLastError:Boolean		= false;
		//private var m_strLastUrl:String			= "";
		
		private var loader_descreq:URLLoader;
		private var timer_downloadTask:Timer;
		private var timer_timeOut:Timer;
		
		public var totalDuration:Number			= 0;
		

		//local_variable
		
		public function GeneralLiveM3U8Loader(_dataManager:DataManager)
		{
			this._dataManager = _dataManager;
			
			timer_timeOut = new Timer(3*1000,1);
			timer_timeOut.addEventListener(TimerEvent.TIMER,timeOutHandler);
			
			addListener();
		}
		
		public function start(_initData:InitData):void
		{
			this._initData = _initData;
			isLoading		= false;
			try
			{
				removeListener();
			}
			catch(error:Error)
			{
				console.log(this,"remove error:"+error);
			}
			addListener();
			
			if( timer_downloadTask == null )
			{
				//TTT
				timer_downloadTask = new Timer(5);
				//timer_downloadTask = new Timer(0,1);
				timer_downloadTask.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			//TTT
			timer_downloadTask.delay = 5;
			//timer_downloadTask.delay = 0;
			
			timer_downloadTask.reset();
			timer_downloadTask.start();
			
			timer_timeOut.reset();
		}
		
		public function clear():void
		{		
			console.log(this,"clear");
			if( timer_downloadTask )
			{
				timer_downloadTask.stop();
				timer_downloadTask.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			
			if( timer_timeOut )
			{
				timer_timeOut.stop();
				timer_timeOut.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			}
			
			
			removeListener();
			
			_dataManager 		= null;
			timer_downloadTask  = null;
			_initData 			= null;
			timer_timeOut 		= null;	
		}
		
		private function timeOutHandler(event:TimerEvent):void 
		{
			console.log(this,"timeOutHandler: " + event);
			
			downloadError();
		}
		
		private function downloadError():void
		{
			m_bAssumeQuery = true;
			
			if( ! ( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD 
					&& true ==  _initData.g_bVodLoaded
					&& true ==  _initData.g_bNextVodLoaded ) )
			{
				++_initData.g_nM3U8Idx;
				if( _initData.g_nM3U8Idx >= _initData.flvURL.length )
				{
					_initData.g_nM3U8Idx = 0;
				}
			}
			else
			{
				if( _initData.nextFlvURL )
				{
					++_initData.g_next_nM3U8Idx;
					if( _initData.g_next_nM3U8Idx >= _initData.nextFlvURL.length )
					{
						_initData.g_next_nM3U8Idx = 0;
					}
				}
			}
			
			isLoading = false;
			
			timer_timeOut.reset();
				
			removeListener();
			addListener();
			
			timer_downloadTask.delay = 1000;
			timer_downloadTask.reset();
			timer_downloadTask.start();
			
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE )
			{
				if( false == _initData.g_bVodLoaded )
				{
					//联播加载 下 一集的m3u8时不上报
					_dataManager.downloadM3U8Failed();
				}
			}
		}

		private function getPureUrl( p_strUrl:String ):String
		{
			var strTmpUrl:String = p_strUrl;
			
			var iPos:int = strTmpUrl.indexOf("&rdm=");
			
			strTmpUrl = strTmpUrl.substr(0,iPos);
			
			return strTmpUrl;
		}
		
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			if( _dataManager )
			{
				if ( isLoading == true ){return; } 
				
				if( (false == _initData.g_bVodLoaded 
						|| ( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD && false == _initData.g_bNextVodLoaded ) )
				 )
				{
					
					_dataManager.startDownloadM3U8();
				}
				else
				{
					return;
				}
				
				var tmpobj:Object = _dataManager.getM3U8Task();
				if( null == tmpobj )
				{
					return;
				}
				else
				{
					timer_downloadTask.delay = tmpobj.delaytime;
					if( !tmpobj.url || ""==tmpobj.url  )
					{
						return;
					}
				}		
				
				if( ( LiveVodConfig.TYPE == LiveVodConfig.VOD && _initData.g_bVodLoaded == true ) 
					|| (  LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD && _initData.g_bNextVodLoaded == true  ) )
				{
					return;
				}
				
				var url:String = tmpobj.url;	
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					url = ParseUrl.replaceParam(url,"ext","m3u8");
				}
				
				try
				{
					//trace("new task")
					removeListener();
				}
				catch(error:Error)
				{
					console.log(this,"close error:"+error);
				}
				
				addListener();
				
				m_bAssumeQuery = false;
				
				LoadManager.g_strsticLastUrl = url;
				console.log(this,"LiveVodConfig.ADD_DATA_TIME: " + LiveVodConfig.ADD_DATA_TIME + "LiveVodConfig.M3U8_MAXTIME: " + LiveVodConfig.M3U8_MAXTIME );
				console.log(this," GeneralLiveM3u8_url : "+ url);
				var request:URLRequest = new URLRequest(url);
				//trace(this,"------------------- GeneralLiveM3u8_url:"+ url);
				timer_timeOut.reset();
				timer_timeOut.start();
				
				try
				{
					isLoading = true;
					loader_descreq.load(request);
				}
				catch (error:Error)
				{
					//trace("Unable to load requested document.");
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
					//trace("loader_descreq.close()")
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
	
		public function callbak( p_ClipVector:Vector.<Clip>,kbps:Number=0):void
		{
			//Statistic.getInstance().loadXMLSuccess(groupID);
			
//			_initData.videoHeight = height;
//			_initData.videoWidth  = width;
			
			_dataManager.writeClipList(p_ClipVector,kbps);
			
		}
		
		private function completeHandler_2(event:Event):int 
		{
			// 此函数中为了调试方便，保留了一些额外的临时变量
			//trace("completeHandler_2")
			timer_timeOut.reset();		
			(new ParseM3U8_uniform).parseFile( String(event.target.data),_initData,callbak );
			
			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				_initData.g_bVodLoaded = true;
			}
			if( LiveVodConfig.TYPE == LiveVodConfig.CONTINUITY_VOD )
			{
				if( false == _initData.g_bVodLoaded )
				{
					_initData.g_bVodLoaded = true;
				}
				else if(  false == _initData.g_bNextVodLoaded  )
				{
					_initData.g_bNextVodLoaded = true;
				}
			}
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				//var tmp:Number = timer_downloadTask.delay;
				//timer_downloadTask.reset();
				//timer_downloadTask.start();
				LiveVodConfig.IS_SEEKING = false;
			}
			isLoading = false;
			m_bAssumeQuery = true;
			return 0;
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			console.log(this,"securityErrorHandler"+event);
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			console.log(this,"ioErrorHandler"+event);
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