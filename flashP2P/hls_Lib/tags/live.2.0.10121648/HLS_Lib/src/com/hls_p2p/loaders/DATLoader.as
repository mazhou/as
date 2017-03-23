package com.hls_p2p.loaders
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dataManager.IDataManager;
	import com.hls_p2p.logs.P2PDebug;
	
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
		protected var _initData:InitData=null;
		/**声明调度器*/
		protected var _dispather:IDataManager;
		
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint=0;
		private var _downloadTaskTime:Timer;
		private var _mediaStream:URLStream;
		
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
			//
			addListener();
		}
		//
		public function start(_initData:InitData):void
		{
			if(!this._initData)
			{
				this._initData = _initData;
			}
			//
			if (Task)
			{
				try
				{
					if(_mediaStream.connected)
					{
						_mediaStream.close();
					}
				}catch(error:Error)
				{
					P2PDebug.traceMsg(this,"close error:"+error);
				}
				
				Task.downLoadStat = 0;//下载失败
				Task = null;
			}
			
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
			
			timeOutTimer.reset();
			
			errorCounts = 0;
			pieceTimeIdx = 1;
		}
		//
		private function completeHandler(event:Event):void 
		{
			/*if(Task._downLoadStat != 1)
			{
				Task = null;
				return;
			}*/
			timeOutTimer.reset();
			errorCounts = 0;
			readData(true);
//			if(Task)
//			{
//				P2PDebug.traceMsg(this,"load complete:"+Task.name);
//			}
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
		/**是否在读数据*/
		protected var _isRead:Boolean=false;
		private var loadByte:Number=0;		
		private function receiveDataHandler(event:ProgressEvent=null):void
		{
			linkStat="download";
			loadByte=event.bytesLoaded;
			if(!_isRead)
			{
				readData();
			}
		}
		/**统计已经下载的字节，和正在下载的字节相加可以得到下载的进度*/
		public var _countSize:Number=0;
		/** 存放分割的流*/
		protected var pies:ByteArray=new ByteArray;
		//protected var pieceIdx:int = 0;
		protected var tempPiece:Piece;
		protected var pieceTimeIdx:int = 1;
		protected function readData(isComplement:Boolean=false):void
		{
			endLoadTime = getTime();
			var pieceCount:int=Math.ceil(needDownloadBytesLength/LiveVodConfig.CLIP_INTERVAL);
			var pieceTime:Number=Math.round((endLoadTime-startLoadTime)/pieceCount);
			
			try
			{
				while(_mediaStream.bytesAvailable>=LiveVodConfig.CLIP_INTERVAL)
				{
					_isRead=true;
					pies.clear();
					_countSize+=LiveVodConfig.CLIP_INTERVAL;
					_mediaStream.readBytes(pies,0,LiveVodConfig.CLIP_INTERVAL);
					
					tempPiece = Task.getPiece(startDownloadPieceIdx);
					if(tempPiece.isChecked == false
						&& tempPiece.iLoadType != 3)
					{													
						tempPiece.from  = "http";
						tempPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
						tempPiece.end   = tempPiece.begin+pieceTime;
						Task.setPieceStream(startDownloadPieceIdx,pies);
					}
					
					pieceTimeIdx++;
					startDownloadPieceIdx++;
				}
				_isRead=false;
				if(isComplement)
				{
					if(_mediaStream.bytesAvailable>0&&_mediaStream.bytesAvailable<=LiveVodConfig.CLIP_INTERVAL)
					{
						pies.clear();
						_mediaStream.readBytes(pies);
						_countSize+=pies.length;
						
						tempPiece = Task.getPiece(startDownloadPieceIdx);
						if(tempPiece.isChecked == false
							&& tempPiece.iLoadType != 3)
						{														
							tempPiece.from  = "http";
							tempPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
							tempPiece.end   = tempPiece.begin+pieceTime;
							Task.setPieceStream(startDownloadPieceIdx,pies);
						}
						pieceTimeIdx = 1;
					}
				}
			}
			catch(err:Error)
			{
				P2PDebug.traceMsg(this,"http解析数据错误");
				downloadError();
			}
			
			
//			if(isComplement && _countSize!=Task.size)
//			{
//				P2PDebug.traceMsg(this,"解析完毕："+_countSize+" size:"+Task.size);
//			}
		}
		private var lastLoad:Number=0;
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"timeOutHandler: " + event);
			if(linkStat == "connect"){
				P2PDebug.traceMsg(this,"连接速度低于指定数据");
				downloadError();
			}else if(linkStat == "download"){
				P2PDebug.traceMsg(this,"loadByte"+(loadByte-lastLoad)/1024*8/3,LiveVodConfig.DATARATE/4);
				if((loadByte-lastLoad)/1024*8/3<LiveVodConfig.DATARATE/5)/*106580 115340*/
				{
					P2PDebug.traceMsg(this,"下载速度低于指定数据");
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
			removeListener();
			errorCounts++;
			_isRead=false;
			if(errorCounts == _initData.flvURL.length)
			{
				errorCounts = 0;
			}
			_countSize=0;
			
			if(pies){pies.clear()}
			//pieceIdx=0;
			loadURLIndex++;
			
			if(loadURLIndex>=_initData.flvURL.length)
			{
				loadURLIndex=0;
			}
			
			Task.downLoadStat = 0;
			Task = null;
			
			addListener();
		}
		//
		private var Task:Block = null;
		private var taskObj:Object=null;
		
		private var lastTaskName:String="";
		private var linkStat:String="connect";
		private var url:String ="";
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			//_downloadTaskTime.delay = 10;
			if (_dispather && null == Task)
			{
				taskObj= _dispather.getDataTask();
				if (taskObj == null)
					return;
				
				_countSize=0;
				Task=taskObj.block;
				//
				
				if(Task.name.indexOf("http://")==0){
					url=Task.name;
				}else
				{
					url=getDatURL(Task.name);
				}
				P2PDebug.traceMsg(this,"start load:"+url,Task.id,taskObj.pieceId);
				//pieceIdx=0;
				
				timeOutTimer.reset();
				var range:String = getDownloadPieceTaskRange(Task);				
				if(range != null)
				{
					var request:URLRequest = new URLRequest(url+range);
					//Task.downLoadStat = 1;//http调度ING
					
					timeOutTimer.start();
					linkStat="connect";
					lastLoad=0;
					try
					{
						startLoadTime=getTime();
						_mediaStream.load(request);
						
					} catch (error:Error)
					{
						P2PDebug.traceMsg(this,"Unable to load requested document.");
						Task.downLoadStat = 0;//
						Task = null;
					}
				}
							
			}
		}
		/**本次下载起始piece的索引*/
		private var startDownloadPieceIdx:int = -1;
		/**本次下载结束piece的索引*/
		private var endDownloadPieceIdx:int   = -1;
		/**本次下载开始的时间*/
		private var startLoadTime:Number      = -1;
		/**本次下载结束的时间*/
		private var endLoadTime:Number        = -1;
		/**本次下载需要下载的字节数*/
		private var needDownloadBytesLength:Number = -1;
		/**在Task里查找未下载数据流的piece，返回该piece或连续几个没有数据的piece在task中的起始位置的字符串*/
		
		private function getDownloadPieceTaskRange(_task:Block,pieceId:int=-1):String
		{	
			if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				startDownloadPieceIdx   = 0;
				endDownloadPieceIdx     = _task.pieces.length-1;
				needDownloadBytesLength = _task.size;
				return "";
			}
			startDownloadPieceIdx = -1;
			endDownloadPieceIdx   = -1;
			startLoadTime         = -1;
			endLoadTime           = -1;
			needDownloadBytesLength = -1;
//			if(pieceId!=-1)
//			{
//				startDownloadPieceIdx = endDownloadPieceIdx   = pieceId;
//				needDownloadBytesLength=_task.getPiece(pieceId).size;
//				if(url.indexOf("?")>0)
//				{
//					return String("&rstart="+pieceId*LiveVodConfig.CLIP_INTERVAL+"&rend="+(pieceId*LiveVodConfig.CLIP_INTERVAL+_task.getPiece(pieceId).size-1));	
//				}
//				return String("?rstart="+pieceId*LiveVodConfig.CLIP_INTERVAL+"&rend="+(pieceId*LiveVodConfig.CLIP_INTERVAL+_task.getPiece(pieceId).size-1));
//			}
			var startByte:Number = -1;
			var endByte:Number   = -1;
			for(var i:int = 0 ; i<_task.pieces.length ; i++)
			{
				if( _task.pieces[i].isChecked == false && _task.pieces[i].iLoadType != 1/* && Task.pieces[i].iLoadType != 3 */)
				{
					_task.pieces[i].iLoadType = 1;
					if( startByte == -1)
					{
						startByte = LiveVodConfig.CLIP_INTERVAL*i;
						startDownloadPieceIdx = i;
					}
					
					endDownloadPieceIdx = i;
					
					if(i != _task.pieces.length-1)
					{
						endByte = LiveVodConfig.CLIP_INTERVAL*(i+1)-1;	
						needDownloadBytesLength = endByte-startByte+1;					
					}else
					{
						//如果是最后一个piece
						endByte = _task.size - 1;
						needDownloadBytesLength = endByte-startByte+1;
						if(startByte == 0)
						{		
							//当整个Task都需要加载时
							return "";								
						}else
						{
							if(url.indexOf("?")>0)
							{
								return String("&rstart="+startByte+"&rend="+endByte);
							}
							return String("?rstart="+startByte+"&rend="+endByte);
						}						
					}					
				}
				else
				{
					if(startByte != -1 && endByte != -1)
					{
						if(url.indexOf("?")>0)
						{
							return String("&rstart="+startByte+"&rend="+endByte);
						}
						return String("?rstart="+startByte+"&rend="+endByte);
					}					
				}
			}
			return null;
		}
		protected function getDatURL(name:String):String
		{
			//http://127.0.0.1/hls/p2p-test/test.m3u8
			var offset:int;
			offset = _initData.flvURL[loadURLIndex].lastIndexOf("/");
			var fileName:String=_initData.flvURL[loadURLIndex].substr(0, offset+1)+name;
			return fileName;
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		private function addListener():void
		{
			if(_mediaStream==null)
			{
				P2PDebug.traceMsg(this,"_mediaStream:"+_mediaStream);
				_mediaStream = new URLStream();
				_mediaStream.addEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				_mediaStream.addEventListener(Event.COMPLETE,completeHandler);
				_mediaStream.addEventListener(IOErrorEvent.IO_ERROR,ioErrorHandler);
				_mediaStream.addEventListener(SecurityErrorEvent.SECURITY_ERROR,securityErrorHandler);
				
			}
		}
		private function removeListener():void
		{
			if(_mediaStream!=null)
			{
				try{
					_mediaStream.close();
				}catch(err:Error)
				{
				}
				_mediaStream.removeEventListener(Event.COMPLETE, completeHandler);
				_mediaStream.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				_mediaStream.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				_mediaStream.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				_mediaStream=null;
			}
		}
		public function clear():void
		{
			loadURLIndex		=0;
			_downloadTaskTime.stop();
			_downloadTaskTime.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			
			timeOutTimer.stop();
			timeOutTimer.removeEventListener(TimerEvent.TIMER,timeOutHandler);
			
			removeListener();
			_initData			=null;
			_dispather			=null;
			_downloadTaskTime	=null;
			
			Task				=null;
            timeOutTimer        =null;
		}
	}
}