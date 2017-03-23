package com.p2p.loaders
{
	import com.p2p.data.Block;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.ReceiveData;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.*;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.*;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	//import flash.net.URLRequest;
	//import flash.net.URLStream;

	/**
	 * <ul>构造函数：NETSTREAM_PROTOCOL.PLAY，获得initdata参数</ul>
	 * <ul>处理数据</ul>
	 * <ul>异常处理</ul>
	 * <ul>纠错处理：请求加载和加载过程addErrorByte</ul> 
	 * @author mazhoun
	 */
	public class DATLoader
	{
		public var isDebug:Boolean=true;
		/**初始化数据*/
		protected var _initData:InitData;
		/**声明调度器*/
		protected var _dispather:IDataManager;
		
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint=0;
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader;//new URLLoader();
		
		public function DATLoader(_dispather:IDataManager)
		{
			P2PDebug.traceMsg(this,"DATLoader");
			this._dispather=_dispather;
			//EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			
			_downloadTaskTime = new Timer(5);
			_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			//;
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			
			loader.addEventListener(Event.COMPLETE, completeHandler);
			loader.addEventListener(Event.OPEN, openHandler);
			loader.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
			loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
		//
		public function start(_initData:InitData):void
		{
			this._initData = _initData;
			//
			if (Task)
			{
				Task._downLoadStat = 0;//下载失败
				Task = null;
				loader.close();
			}
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
		}
		//
		private function completeHandler(event:Event):void 
		{
			Task.end=getTime();
			var data:ByteArray=event.target.data  as  ByteArray
			if (data.bytesAvailable == Task.size)				
			{
				var pieceCount:int=Math.ceil(Task.size/LiveVodConfig.CLIP_INTERVAL);
				var pieceTime:Number=(Task.end-Task.begin)/pieceCount;
				var index:int = 0;
				while(data.bytesAvailable > 0)
				{
					var pies:ByteArray = new ByteArray;
					if(data.bytesAvailable >= LiveVodConfig.CLIP_INTERVAL)
						data.readBytes(pies, 0, LiveVodConfig.CLIP_INTERVAL);
					else
						data.readBytes(pies);
					
					Task.getPiece(index).from="http";
					Task.getPiece(index).begin=Task.begin+index*pieceTime;
					Task.getPiece(index).end=Task.getPiece(index).begin+pieceTime;
					Task.setPieceStream(index,pies);
					index++;
				}
				P2PDebug.traceMsg(this,"load complete:"+Task.name);
				//
				Task._downLoadStat = 3;//下载成功
				Task = null;				
			}
			//
			Task = null;
		}
		
		private function openHandler(event:Event):void
		{
			P2PDebug.traceMsg(this,"openHandler: " + event);
		}
		
		private function progressHandler(event:ProgressEvent):void
		{
//			P2PDebug.traceMsg(this,"progressHandler loaded:" + event.bytesLoaded + " total: " + event.bytesTotal);
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler: " + event);
			Task._downLoadStat = 0;//下载成功
			Task = null;
		}
		
		private function httpStatusHandler(event:HTTPStatusEvent):void 
		{
			P2PDebug.traceMsg(this,"httpStatusHandler: " + event);
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			Task._downLoadStat = 0;//下载成功
			Task = null;
		}
		//
		private var Task:Block = null;
		public function handlerDownloadTask(evt:TimerEvent=null):void
		{
			//_downloadTaskTime.delay = 10;
			if (_dispather && null == Task)
			{
				Task = _dispather.getDataTask();
				if (Task == null)
					return;
				//
				var url:String = getDatURL(Task.name)+"&rdm="+getTime();
				P2PDebug.traceMsg(this,"start load:"+Task.name);
				var request:URLRequest = new URLRequest(url);
				Task._downLoadStat = 1;//http调度ING
				try
				{
					Task.begin=getTime();
					loader.load(request);
					
				} catch (error:Error)
				{
					P2PDebug.traceMsg(this,"Unable to load requested document.");
					Task._downLoadStat = 0;//
					Task = null;
				}
			}
		}
		protected function getDatURL(name:String):String
		{
			return _initData.flvURL[loadURLIndex].replace("desc.xml",name);
		}
		protected function streamPlayHandler(evt:EventExtensions):void
		{
			//jsInterface();
			_initData=evt.data as InitData;
			P2PDebug.traceMsg(this,"调度器响应play事件"+_initData.flvURL);
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}
//		_xml=<root>
//			<header name="1364221677.header"/>
//			<clip name="2013032612/1364272625_6600_593976.dat" duration="6600ms" checksum="3485068282"/>
//			<clip name="2013032612/1364272631_7920_702171.dat" duration="7920ms" checksum="2088142328"/>
//			<clip name="2013032612/1364272639_7560_702148.dat" duration="7560ms" checksum="364880931"/>
//		</root>