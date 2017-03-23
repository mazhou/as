package com.hls_p2p.loaders
{
	import com.p2p.utils.TimeTranslater;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.IDataManager;
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
	
	
	/**
	 * <ul>构造函数：NETSTREAM_PROTOCOL.PLAY，获得initdata参数</ul>
	 * <ul>处理数据</ul>
	 * <ul>异常处理</ul>
	 * <ul>纠错处理：请求加载和加载过程addErrorByte</ul> 
	 * @author mazhoun
	 */
	public class DescLoader implements IDescLoader
	{
		public var isDebug:Boolean=true;
		private var _dispather:IDataManager = null;	
//		private var _downloadTaskTime:Timer;
		private var loader:URLLoader;//new URLLoader();
		private var _initData:InitData=null;
		private var _flvURLIndex:int=0;
		
		private var timeOutTimer:Timer;
		
		public function DescLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			//
			timeOutTimer = new Timer(3*1000,1);
			timeOutTimer.addEventListener(TimerEvent.TIMER,timeOutHandler);
			//
			addListener();
		}
		public function start( _initData:InitData):void
		{
			if(!this._initData)
			{
				this._initData = _initData;
				handlerDownloadTask();
				timeOutTimer.reset();
			}
		}
		//
		private var _startTime:Number = 0;
		private function completeHandler(event:Event):void 
		{
			timeOutTimer.reset();
//			P2PDebug.traceMsg(this,"data:"+event.target.data);
			var lines:Array = String(event.target.data).split("\n");
			//
			if(lines.length<=1)
			{
				downloadError();
				return;
			}
			if(lines[0] != "#EXTM3U")
			{
				//throw new Error("Extended M3U files must start with #EXTM3U");
				P2PDebug.traceMsg(this,"first line wasn't #EXTM3U was instead "+lines[0]); // have some files with weird data here
			}
			var i:int;
			var _clipList:Vector.<Clip>;
			var _clip:Clip;
			_clipList = new Vector.<Clip>;
			var pieceTotal:int=0;
			var checksums:Array;
			var elements:Array;
			var halfOfEndURL:Array;
			var sequence:int=0;
			var _totalTime:Number=0;
			var debugStr:String="";
			for(i=1; i<lines.length; i++)
			{
				lines[i]=lines[i].replace("\r","");
				if(String(lines[i]).indexOf("#EXTINF:") == 0)
				{
					_clip=new Clip();
					_clip.duration= parseFloat(String(lines[i]).substr(8));	// 8 is length of "#EXTINF:"
					_totalTime+=Number(_clip.duration);
					++i;
					if(i > lines.length)
						throw new Error("processIndexData: improperly terminated M3U8 file (2)");
					lines[i]=lines[i].replace("\r","");
					_clip.name= String(lines[i]);
					/*本地测试*/
					/*halfOfEndURL=urlParse(_clip.name,false,".ts").split("_");
					_clip.sequence=int((halfOfEndURL[1]));
					_clip.size=Number(halfOfEndURL[2]);
					_clip.offsize=Number(halfOfEndURL[3]);*/
					
					/*线上测试*/
					halfOfEndURL=urlParse1(_clip.name).split("_");
					_clip.sequence=int((halfOfEndURL[halfOfEndURL.length-3]));
					_clip.size=Number(halfOfEndURL[halfOfEndURL.length-2]);
					_clip.offsize=Number(halfOfEndURL[halfOfEndURL.length-1]);
					
					++i;
					lines[i]=lines[i].replace("\r","");
					_clip.timestamp=Number(String(lines[i]).replace("#EXT-LETV-START-TIME:",""));
					++i;
					lines[i]=lines[i].replace("\r","");
					
					pieceTotal=int(String(lines[i]).replace("#EXT-LETV-P2P-PIECE-NUMBER:",""));
					_clip.pieceTotal = pieceTotal;
					checksums=new Array;
					//pieceTotal长度已经改过，226上还没有更新
					for(var j:int=0;j<pieceTotal;j++){
						++i;
						lines[i]=lines[i].replace("\r","");
						elements=String(lines[i]).split("&");
						checksums.push(elements[elements.length-1]);
					}
					_clip.checkSums=checksums;
					
					_clipList.push(_clip);
					debugStr+="id:"+_clip.timestamp+" drtion:"+_clip.duration+" s:"+_clip.size+" offs:"+_clip.offsize+" ck:"+_clip.checkSums+" "+_clip.name+"\n"
				}
				
				if(String(lines[i]).indexOf("#EXT-X-TARGETDURATION:") == 0)
				{
					P2PDebug.traceMsg(this,"最大时长："+lines[i]);
				}
				if(String(lines[i]).indexOf("#EXT-LETV-P2P-TARGET-LENGTH:") == 0)
				{
					LiveVodConfig.CLIP_INTERVAL=int(String(lines[i]).replace("#EXT-LETV-P2P-TARGET-LENGTH:",""));
					P2PDebug.traceMsg(this,"peice长度："+LiveVodConfig.CLIP_INTERVAL);
				}
				if(String(lines[i]).indexOf("#EXT-LETV-TOTAL-SEGMENT:") == 0)
				{
					P2PDebug.traceMsg(this,"总块数："+String(lines[i]));
				}
				
				if(String(lines[i]).indexOf("#EXT-LETV-TOTAL-LENGTH:") == 0)
				{					
					_initData.totalSize = int(String(lines[i]).replace("#EXT-LETV-TOTAL-LENGTH:",""));
					//trace(_initData.totalSize);
					P2PDebug.traceMsg(this,int(String(lines[i]).replace("#EXT-LETV-TOTAL-LENGTH:","")));
				}
				/*#EXT-LETV-PIC-WIDTH:640
					#EXT-LETV-PIC-HEIGHT:352*/
				if(String(lines[i]).indexOf("#EXT-LETV-PIC-WIDTH:") == 0)
				{
					_initData.videoWidth = int(String(lines[i]).replace("#EXT-LETV-PIC-WIDTH:",""));
				}
				if(String(lines[i]).indexOf("#EXT-LETV-PIC-HEIGHT:") == 0)
				{
					_initData.videoHeight = int(String(lines[i]).replace("#EXT-LETV-PIC-HEIGHT:",""));
				}
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
			_initData.totalDuration=_totalTime;
			_dispather.writeClipList(_clipList,true);
			return;
		}
		private function urlParse(_url:String,isHalOfBegin:Boolean=true,endLetter:String=""):String
		{
			var offset:int;
			offset = _url.lastIndexOf("/");
			if(isHalOfBegin){
				_url=_url.substr(0, offset+1);
			}else
			{
				_url=_url.substr( offset+1);
			}
			offset=_url.indexOf(endLetter);
			_url=_url.substr(0, offset);
			return _url;
		}
		private function urlParse1(_url:String):String
		{
			var end:int = _url.indexOf(".ts");
			var start:int = _url.lastIndexOf("/");
			_url = _url.substring(start,end);
			return _url;
		}
		private function receiveDataHandler(event:ProgressEvent=null):void
		{
			timeOutTimer.reset();
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			downloadError();
		}
		
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"DESCtimeOutHandler: " + event);
			downloadError();
		}
		
		private function downloadError():void
		{
			timeOutTimer.reset();
			_flvURLIndex++;
			if(_flvURLIndex>=_initData.flvURL.length)
			{
				_flvURLIndex=0;
			}
			removeListener();
			addListener();
			handlerDownloadTask();
		}
		//
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			_startTime = getTime();
			if (_dispather)
			{
				//
				var url:String = _initData.flvURL[_flvURLIndex];
				var request:URLRequest = new URLRequest(url);
				P2PDebug.traceMsg(this,"url:"+url);
				timeOutTimer.reset();
				timeOutTimer.start();
				
				try
				{
					loader.load(request);
					
				} catch (error:Error)
				{
					//trace("Unable to load requested document.");
				}
			}
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
				loader.dataFormat = URLLoaderDataFormat.TEXT;
				
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
			timeOutTimer.stop();
			timeOutTimer.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			removeListener();
			_dispather=null;
			_initData=null;
			timeOutTimer = null;
		}
	}
}