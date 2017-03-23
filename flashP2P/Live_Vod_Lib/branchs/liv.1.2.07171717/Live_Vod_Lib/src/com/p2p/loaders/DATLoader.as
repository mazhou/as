package com.p2p.loaders
{
	import com.p2p.data.Block;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.Piece;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.*;
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
		
		private var timeOutTimer:Timer;
		
		public function DATLoader(_dispather:IDataManager)
		{
			P2PDebug.traceMsg(this,"DATLoader");
			this._dispather=_dispather;
			//EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			
			_downloadTaskTime = new Timer(5);
			_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timeOutTimer = new Timer(3*1000,1);
			timeOutTimer.addEventListener(TimerEvent.TIMER,timeOutHandler);
			//;
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.BINARY;
			loader.addEventListener(Event.COMPLETE, completeHandler);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);			
			loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			
			loader.addEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
			
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
				try
				{
					loader.close();
				}catch(error:Error)
				{
					P2PDebug.traceMsg(this,"close error:"+error);
				}
			}
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
			
			timeOutTimer.reset();
			
			errorCounts = 0;
		}
		//
		private function completeHandler(event:Event):void 
		{
			timeOutTimer.reset();
			
			errorCounts = 0;
			
			if(Task && Task._downLoadStat != 1)
			{
				Task = null;
				return;
			}
			
			Task.end = getTime();
			var data:ByteArray=event.target.data  as  ByteArray
			if (data.bytesAvailable == Task.size)
			{
				var pieceCount:int=Math.ceil(Task.size/LiveVodConfig.CLIP_INTERVAL);
				var pieceTime:Number=(Task.end-Task.begin)/pieceCount;
				var index:int = 0;
				
				var tempPiece:Piece;
				
				while(data.bytesAvailable > 0)
				{
					try
					{
						var pies:ByteArray = new ByteArray;
						if(data.bytesAvailable >= LiveVodConfig.CLIP_INTERVAL)
							data.readBytes(pies, 0, LiveVodConfig.CLIP_INTERVAL);
						else
							data.readBytes(pies);
						
						if(Task.pieces.length == 0)
						{
							Task = null;
							return;
						}
						
						tempPiece = Task.getPiece(index);						
						tempPiece.from  = "http";
						tempPiece.begin = Task.begin+index*pieceTime;
						tempPiece.end   = tempPiece.begin+pieceTime;
						
						Task.setPieceStream(index,pies)
						index++;
					}catch(error:Error)
					{
						P2PDebug.traceMsg(this,"load complete eorror:"+Task.name);
						Task = null;
						return;
					}
				}
				P2PDebug.traceMsg(this,"load complete:"+Task.name);
				//
				Task._downLoadStat = 3;//下载成功
				Task = null;
			}
			//
			Task = null;
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler: " + event);
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			downloadError();
		}
		private var loadByte:Number=0;		
		private function receiveDataHandler(event:ProgressEvent=null):void
		{
			linkStat="download";
			loadByte=event.bytesLoaded;
		}
		private var lastLoad:Number=0;
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"timeOutHandler: " + event);
			if(linkStat == "connect"){
				downloadError();
			}else if(linkStat == "download"){
				P2PDebug.traceMsg(this,"loadByte"+loadByte+" lastLoad:"+lastLoad+"="+(loadByte-lastLoad));
				if(loadByte-lastLoad<50000)/*106580 115340*/
				{
					downloadError();
				}else
				{
					lastLoad=loadByte;
					timeOutTimer.reset();
					timeOutTimer.start();
				}	
			}
		}
		private var errorCounts:int = 0;
		private function downloadError():void
		{
			timeOutTimer.reset();
			
			errorCounts++;
			if(errorCounts == _initData.flvURL.length)
			{
				errorCounts = 0;
				Task.isDestory = true;
			}
			
			loadURLIndex++;
			if(loadURLIndex>=_initData.flvURL.length)
			{
				loadURLIndex=0;
			}
			
			Task._downLoadStat = 0;
			Task = null;
			
			try{
				loader.close();
			}catch(err:Error)
			{
				
			}
		}
		//
		private var Task:Block = null;
		private var lastTaskName:String="";
		private var linkStat:String="connect";
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			//_downloadTaskTime.delay = 10;
			if (_dispather && null == Task)
			{
				Task = _dispather.getDataTask();
				if (Task == null)
					return;
				//
				if(lastTaskName!=Task.name)
				{
					lastTaskName=Task.name;
					this.errorCounts=0;
				}
				var url:String = getDatURL(Task.name)+"&rdm="+getTime();
				P2PDebug.traceMsg(this,"start load:"+Task.name);
				var request:URLRequest = new URLRequest(url);
				Task._downLoadStat = 1;//http调度ING
				
				timeOutTimer.reset();
				timeOutTimer.start();
				linkStat="connect";
				lastLoad=0;
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
//		protected function streamPlayHandler(evt:EventExtensions):void
//		{
//			//jsInterface();
//			_initData=evt.data as InitData;
//			P2PDebug.traceMsg(this,"调度器响应play事件"+_initData.flvURL);
//		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			loadURLIndex		=0;
			_downloadTaskTime.stop();
			_downloadTaskTime.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timeOutTimer.stop();
			timeOutTimer.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			
			try{
				loader.close();
			}catch(err:Error)
			{
				
			}
			loader.removeEventListener(Event.COMPLETE, completeHandler);
			loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			_initData			=null;
			_dispather			=null;
			_downloadTaskTime	=null;
			loader				=null;
			Task				=null;
			timeOutTimer        =null;
		}
	}
}
//		_xml=<root>
//			<header name="1364221677.header"/>
//			<clip name="2013032612/1364272625_6600_593976.dat" duration="6600ms" checksum="3485068282"/>
//			<clip name="2013032612/1364272631_7920_702171.dat" duration="7920ms" checksum="2088142328"/>
//			<clip name="2013032612/1364272639_7560_702148.dat" duration="7560ms" checksum="364880931"/>
//		</root>