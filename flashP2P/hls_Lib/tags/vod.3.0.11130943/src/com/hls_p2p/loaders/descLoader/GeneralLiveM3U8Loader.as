package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	internal class GeneralLiveM3U8Loader implements IDescLoader
	{
		private var _initData:InitData 			= null;
		private var _dispather:IDataManager 	= null;	
		
		public 	var isDebug:Boolean 			= true;
		private var n_desc_URLIndex:int 		= 0;
		private var timeshift_descTask:Number 	= -1;
		private var _startTime:Number 			= 0;
		private var bStart:Boolean 				= false;
		
		public var totalDuration:Number			= 0;	
		private var loader_descreq:URLLoader;
		private var timer_downloadTask:Timer;
		private var timer_timeOut:Timer;
		private var timeOutTimer:Timer;
		//local_variable

		public var groupID:String				= "";
		public var width:Number					= 0;
		public var height:Number				= 0;
		// 引入这个变量是为了当前测试直播的需要，后续直播测试环境就绪后应用timeshift替换
		public var DESC_LASTSTARTTIME:Number 	= 0;
		private var _flvURLIndex:int			= 0;
		
		public function GeneralLiveM3U8Loader(_dispather:IDataManager)
		{
			this._dispather = _dispather;
			
			timer_timeOut = new Timer(3*1000,1);
			timer_timeOut.addEventListener(TimerEvent.TIMER,timeOutHandler);
			
			addListener();
		}
		
		public function start(_initData:InitData):void
		{
			this._initData = _initData;
			
			if( timer_downloadTask == null )
			{
				timer_downloadTask = new Timer(5,1);
				timer_downloadTask.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			
			timer_downloadTask.delay = 5;
			bStart = true;
			
			if( timeshift_descTask != -1 )
			{
				try
				{
					loader_descreq.close();
				}
				catch(err:Error)
				{
					P2PDebug.traceMsg(this,err);
				}
				
				timeshift_descTask = -1; 
			}
			
			timer_downloadTask.reset();
			timer_downloadTask.start();
			
			timer_timeOut.reset();
		}
		
		public function clear():void
		{
			n_desc_URLIndex = 0;
			
			timer_downloadTask.stop();
			timer_downloadTask.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timer_timeOut.stop();
			timer_timeOut.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			
			removeListener();
			
			_dispather 			= null;
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
			timer_timeOut.reset();
			
			timeshift_descTask = -1;
			n_desc_URLIndex++;
			
			if(n_desc_URLIndex>=_initData.flvURL.length)
			{
				n_desc_URLIndex=0;
			}
			
			removeListener();
			addListener();
			
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				timer_downloadTask.delay = 5;
				timer_downloadTask.reset();
				timer_downloadTask.start();
			}
		}
		
		
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			_startTime = getTime();
	
			if (_dispather)
			{
				var url:String = "";
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					timeshift_descTask = LiveVodConfig.DESC_TIMESHIFT;
					//				if(timeshift_descTask==-1 || tmpsub_1 > LiveVodConfig.MEMORY_TIME)
					//				{
					//					return;
					//				}
					//
					//var url:String = abTimeShiftURL+this.getMiniMinute(timeshift_descTask)+"&rdm="+getTime();
					//live_vod 修改timeshift方式
					url = "http://123.126.32.19:1935/hls/ver_00_10_yyyl_test_20s_1024/live_m3u8.txt" + "?rdm=" + getTime();
					//var url:String = urltimeshift+ LiveVodConfig.DESC_TIMESHIFT + "&rdm=" + getTime();
					//var url:String = abTimeShiftURL+ LiveVodConfig.DESC_TIMESHIFT + "&rdm=" + getTime();
					//var url:String = _initData.flvURL[_flvURLIndex];
					//url = "http://123.125.89.8/m3u8/test/desc.m3u8";
				}
				else if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
				{
					url = _initData.flvURL[_flvURLIndex];
				}

				P2PDebug.traceMsg(this," url:"+ url);
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
					timeshift_descTask = -1;
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
			
			_initData.videoHeight = height;
			_initData.videoWidth  = width;
			
			_dispather.writeClipList(p_ClipVector);
			
		}
		private function completeHandler_2(event:Event):int 
		{
			// 此函数中为了调试方便，保留了一些额外的临时变量
			timer_timeOut.reset();		
			(new ParseM3U8_uniform).parseFile( String(event.target.data),_initData,callbak,this );
			
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE && timer_downloadTask )
			{
				var tmptimeshift1:Number = 0;
				var tmpsub_1:Number = LiveVodConfig.DESC_TIMESHIFT - LiveVodConfig.ADD_DATA_TIME;
				tmpsub_1 = 40;
				var tmplivetime:Number = LIVE_TIME.GetLiveTime();
				if( DESC_LASTSTARTTIME != 0 )
				{
					tmptimeshift1 = DESC_LASTSTARTTIME;
				}
				else
				{
					throw new Error("DESC_LASTSTARTTIME error")
				}
				// 时移超过缓冲时间，返回或放慢加载速度
				if( timeshift_descTask != -1 || tmpsub_1 > (LiveVodConfig.MEMORY_TIME*60) )
				{
					timer_downloadTask.delay = 1800;
				}
				else if( tmplivetime - tmptimeshift1 < 20 )
				{
					timer_downloadTask.delay = 3000;
				}
				else
				{
					timer_downloadTask.delay = 5;
				}
				
				timer_downloadTask.reset();
				timer_downloadTask.start();
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
		
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			if(_initData)
			{
				return getShiftPath_1(_initData.flvURL[n_desc_URLIndex]);
			}
			return "";
		}
		
		protected function getShiftPath(url:String):String
		{
			/*var reg:RegExp=/\/\/(\d+.\d+.\d+.\d+)\//;
			if(reg.test(url)){
			url=url.replace(url.match(reg)[1],"111.161.65.99");
			}
			var reg2:RegExp=/path=(\d+.\d+.\d+.\d+,\d+.\d+.\d+.\d+)/;
			if(reg2.test(url)){
			url=url.replace(url.match(reg2)[1],"111.161.65.99");
			}
			var reg3:RegExp=/path=(\d+.\d+.\d+.\d+)/;
			if(reg3.test(url)){
			url=url.replace(url.match(reg3)[1],"111.161.65.99");
			}*/
			
			
			
			/*if(LiveVodConfig.timeshift == 0)
			{
				url=url.replace("desc.xml","")+ "&rdm=" + getTime();
			}
			else
			{
				url=url.replace("desc.xml","")+"&abtimeshift=" + LiveVodConfig.timeshift + "&rdm=" + getTime();
			}
			
			return url;
			*/

			url=url.replace("desc.xml","")+"&abtimeshift=";
			return url;
		}
		
		protected function getShiftPath_1(url:String):String
		{
			url="http://123.125.89.8/m3u8/test/desc.m3u8?abtimeshift=";
			return url;
		}
		
		private function getMiniMinute(id:Number):Number
		{
			var date:Date  = new Date(id*1000);
			date = new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
			return Math.floor(date.time/1000);
		}
		
		
		private function urlParse_ts_1(_url:String):String
		{
			var end:int = _url.indexOf(".ts");
			var start:int = _url.lastIndexOf("/");
			_url = _url.substring(start+1,end);
			return _url;	
		}
		
		private function urlParse_ts_2(_url:String):String
		{
			var start:int = _url.indexOf(".ts?");
			var end:int = _url.length;
			
			_url = _url.substring(start+4,end);
			
			var arr_loctsInfoURL:Array;
			
			arr_loctsInfoURL = _url.split("&");
			_url = String((arr_loctsInfoURL[arr_loctsInfoURL.length-7]));
			start = _url.indexOf("geo=");
			end = _url.length;
			_url = _url.substring(start+4,end);
			
			return _url;
		}
	}
}