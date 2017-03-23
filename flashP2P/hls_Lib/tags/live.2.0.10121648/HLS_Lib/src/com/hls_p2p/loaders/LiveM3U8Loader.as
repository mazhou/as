package com.hls_p2p.loaders
{
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.IDataManager;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
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
	
	internal class LiveM3U8Loader implements IDescLoader
	{
		
		private var _initData:InitData = null;
		private var _dispather:IDataManager = null;	
		
		public 	var isDebug:Boolean = true;
		private var n_desc_URLIndex:int = 0;
		private var loader_descreq:URLLoader;//new URLLoader();
		
		//public var  timestamp_NextReq:Number = 0;
		//public var  b_DealingRequest:Boolean = false;
		
		private var timer_downloadTask:Timer;
		private var timer_timeOut:Timer;
		
		//local_variable
		private var timeshift_descTask:Number = -1;
		private var _startTime:Number = 0;
		
		private var bStart:Boolean = false;
		
		public function LiveM3U8Loader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			
			timer_timeOut = new Timer(3*1000,1);
			timer_timeOut.addEventListener(TimerEvent.TIMER,timeOutHandler);
			
			addListener();
			
		}
		
		public function start(_initData:InitData):void
		{
			this._initData = _initData;
			if (timer_downloadTask == null)
			{
				timer_downloadTask = new Timer(5);
				timer_downloadTask.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			timer_downloadTask.delay=5;
			bStart = true;
			//
			if (timeshift_descTask != -1)
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
			n_desc_URLIndex=0;
			timer_downloadTask.stop();
			timer_downloadTask.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timer_timeOut.stop();
			timer_timeOut.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			
			removeListener();
			
			_dispather=null;
			timer_downloadTask=null;
			_initData=null;
			timer_timeOut = null;
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
		}
		
		
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			/*if( b_DealingRequest )
			{
				return;
			}
			else
			{
				b_DealingRequest = true;
			}*/
			if(timeshift_descTask != -1)
			{
				return;
			}
			_startTime = getTime();
			timer_downloadTask.delay = 3000;
			
			if (_dispather)
			{
				timeshift_descTask = LiveVodConfig.DESC_TIMESHIFT;
				if(timeshift_descTask==-1)
				{
					return;
				}
				//
				//var url:String = abTimeShiftURL+this.getMiniMinute(timeshift_descTask)+"&rdm="+getTime();
				//live_vod 修改timeshift方式
				var url:String = abTimeShiftURL+ LiveVodConfig.DESC_TIMESHIFT + "&rdm=" + getTime();
				P2PDebug.traceMsg(this," url:"+ url);
				var request:URLRequest = new URLRequest(url);
				
				timer_timeOut.reset();
				timer_timeOut.start();
				
				try
				{
					loader_descreq.load(request);
					
				} catch (error:Error)
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
				
				loader_descreq.addEventListener(Event.COMPLETE, completeHandler);
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
				loader_descreq.removeEventListener(Event.COMPLETE, completeHandler);
				loader_descreq.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader_descreq.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				loader_descreq.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				loader_descreq=null;
			}
		}
		
		
		private function completeHandler(event:Event):void 
		{
			
			/*
			samples:
			#EXTM3U
			#EXT-X-TARGETDURATION:10
			#EXT-X-MEDIA-SEQUENCE:1381158538
			#EXTINF:6,
			#EXT-LETV-M3U8-SEQ:1381158536
			#EXT-LETV-SEGMENT-CKS:2428282017
			2013101009/1381368772_6200_590696.ts
			#EXTINF:8,
			#EXT-LETV-M3U8-SEQ:1381158537
			#EXT-LETV-SEGMENT-CKS:2793328756
			2013101009/1381368779_7520_827388.ts
			#EXTINF:6,
			#EXT-LETV-M3U8-SEQ:1381158538
			#EXT-LETV-SEGMENT-CKS:4059025459
			2013101009/1381368787_6400_746548.ts
			
			*/
			timer_timeOut.reset();
			timeshift_descTask = -1;
			//			P2PDebug.traceMsg(this,"data:"+event.target.data);
			var lines:Array = String(event.target.data).split("\n");
			//
			if(lines.length<=1)
			{
				downloadError();
				return;
			}
			lines[0]=lines[0].replace("\r","");
			if(lines[0] != "#EXTM3U")
			{
				//throw new Error("Extended M3U files must start with #EXTM3U");
				P2PDebug.traceMsg(this,"first line wasn't #EXTM3U was instead "+lines[0]); // have some files with weird data here
			}
			var i:int;
			var _clipList:Vector.<Clip>;
			var _clip:Clip=new Clip;
			_clipList = new Vector.<Clip>;
			var pieceTotal:int=0;
			var checksums:Array;
			
			var arr_tsInfoURL:Array;
			
			var _totalTime:Number=0;
			var debugStr:String="";
			
			var numtargetduration:Number = 0;		
			var numMediaSeq:Number = 0;
			//var reg:RegExp = /\s*$/;
			i=1;
			while(lines[i])
			{	
				lines[i]=lines[i].replace("\r","");
				if(String(lines[i]).indexOf("#") == 0)
				{
					if(String(lines[i]).indexOf("#EXTINF:") == 0)
					{
						if(_clip){
							_clip.duration = 1000*parseFloat(String(lines[i]).substr(8));
						}
					}else if(String(lines[i]).indexOf("#EXT-LETV-M3U8-SEQ:") == 0)
					{
						if(_clip)
						{
							_clip.sequence=int(String(lines[i]).replace("#EXT-LETV-M3U8-SEQ:",""));
						}
						
					}else if(String(lines[i]).indexOf("#EXT-LETV-SEGMENT-CKS:") == 0)
					{
//						_initData.videoWidth = int(String(lines[i]).replace("#EXT-LETV-PIC-WIDTH:",""));
						if(_clip)
						{
							_clip.block_checkSum = String(lines[i]).replace("#EXT-LETV-SEGMENT-CKS:","");
						}
						
					}else if(String(lines[i]).indexOf("#EXT-X-TARGETDURATION:") == 0)
					{
						//P2PDebug.traceMsg(this,"最大时长："+String(lines[i]).replace("#EXT-X-TARGETDURATION:",""));
						
					}else if(String(lines[i]).indexOf("#EXT-X-MEDIA-SEQUENCE:") == 0)
					{
						//P2PDebug.traceMsg(this,"MEDIA-SEQUENCE："+String(lines[i]).replace("#EXT-X-MEDIA-SEQUENCE:",""));
						
					}
				}else if(String(lines[i]).indexOf("#") == -1)
				{
					
					if(_clip)
					{
						_clip.name= String(lines[i]);
						arr_tsInfoURL = urlParse_ts_1(_clip.name).split("_");
						_clip.timestamp = int((arr_tsInfoURL[arr_tsInfoURL.length-3]));
						LiveVodConfig.DESC_TIMESHIFT = _clip.timestamp;
						_clip.size = Number(arr_tsInfoURL[arr_tsInfoURL.length-1]);
						
						if(bStart)
						{
							LiveVodConfig.ADD_DATA_TIME = _clip.timestamp;
							bStart = false;
						}
					}
					if(_clip){
						debugStr+="id:"+_clip.timestamp+" drtion:"+_clip.duration+ " seq:"+_clip.sequence+" s:"+_clip.size+" offs:"+_clip.offsize+" ck:"+_clip.checkSums+" "+_clip.name+"\n"
						_clipList.push(_clip);
					}
					_clip=new Clip();
				}
				i++;
			}
			P2PDebug.traceMsg(this,"m3u8:"+debugStr);
			try
			{
				Statistic.getInstance().loadXMLSuccess(getTime()-_startTime);
			}catch(err:Error)
			{
				return;
			}
			//
			//_initData.totalDuration=_totalTime;
			_dispather.writeClipList(_clipList,false,true);
			
			//b_DealingRequest = false;
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
				return getShiftPath(_initData.flvURL[n_desc_URLIndex]);
			}
			//
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
		
		private function getMiniMinute(id:Number):Number
		{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
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