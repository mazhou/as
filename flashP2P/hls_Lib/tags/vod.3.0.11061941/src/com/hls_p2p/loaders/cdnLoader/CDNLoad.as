package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ParseUrl;
	
	import flash.events.*;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.*;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	public class CDNLoad implements IStreamLoader
	{
		public var isDebug:Boolean			=true;
		/**初始化数据 */
		protected var _initData:InitData	=null;
		/**声明调度器*/
		protected var dispatcher:IDataManager;
		
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint		=0;
		protected var getTaskListTime:Timer;
		protected var _mediaStream:URLStream;
				
		protected var Task:Block 			= null;
		protected var url:String 			="";
		private   var arrPieceidx:Array     = new Array;
		
			
		/**统计已经下载的字节，和正在下载的字节相加可以得到下载的进度*/
		public var _countSize:Number		=0;
		/** 存放分割的流*/
		protected var arrByteBuf:ByteArray		= new ByteArray;
		protected var tempPiece:Piece;
		protected var pieceTimeIdx:int 		= 1;
		protected var loadMgr:LoadManager 	= null;
		private   var nPieceIdx_idx:Number  = 0;
		
		
		public function CDNLoad(dispatcher:IDataManager, LDMGR:LoadManager)
		{
			this.dispatcher=dispatcher;
			loadMgr = LDMGR;
			P2PDebug.traceMsg(this,"CDNLoad");
			addListener();
			//
			if(getTaskListTime == null)
			{
				getTaskListTime = new Timer(0, 1);
				getTaskListTime.addEventListener(TimerEvent.TIMER, handlerGetTaskList);
			}
		}
		
		protected function handlerGetTaskList(evt:TimerEvent=null):void
		{
			if (Task == null)
			{
				Task = loadMgr.getCDNTask();
				loadTask();
			}else
			{
				if(getTaskListTime)
				{
					getTaskListTime.reset();
					getTaskListTime.delay = 20;
					getTaskListTime.start();
				}
			}
			//
			
		}
		
		public function start( _initData:InitData):void
		{	
			if( !this._initData )
			{
				this._initData = _initData;
			}
			//
			if( Task )
			{
				try
				{
					if(_mediaStream.connected)
					{
						_mediaStream.close();
					}
				}
				catch(error:Error)
				{
					P2PDebug.traceMsg(this,"close error:"+error);
				}
				
				Task.downLoadStat = 0;
				Task = null;
			}			
			
			errorCounts = 0;
			pieceTimeIdx = 1;
			//
			if(getTaskListTime)
			{
				getTaskListTime.reset();
				getTaskListTime.start();
			}
		}
		
		
		protected var m_vecDownloadingPieces:Array;
		
		public function loadTask():void
		{
				
			if (Task == null)
			{
				if(getTaskListTime)
				{
					getTaskListTime.reset();
					getTaskListTime.delay = 20;
					getTaskListTime.start();
				}
				return ;
			}
	
			_countSize=0;
			
			
			if(Task.name.indexOf("http://")==0)
			{
				url=Task.name;
			}
			else
			{
				if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
				{
					url=getDatURL_1(Task.name);
				}
				else
				{
					url=getDatURL(Task.name);
				}
				
			}
			
			//timeOutTimer.reset();
			m_vecDownloadingPieces = new Array;
			var range:String = getDownloadPieceContentTask(m_vecDownloadingPieces,-1);	
			if(range != null)
			{
				//url=ParseUrl.replaceParam(url+range,"rd",""+getTime());
				url=ParseUrl.replaceParam(url+"","rd",""+getTime());
				var request:URLRequest = new URLRequest(url);
				P2PDebug.traceMsg(this,"******start load:"+url);
				
				P2PDebug.traceMsg(this,"******start load_blockid:"+Task.id + " PieceType:" + m_vecDownloadingPieces[0].type + " Pieceid:" + m_vecDownloadingPieces[0].id);
				//
				try
				{
					startLoadTime=getTime();
					_mediaStream.load(request);
				}
				catch (error:Error)
				{
					P2PDebug.traceMsg(this,"Unable to load requested document.");
					Task.downLoadStat = 0;//
					Task = null;
				}
			}
			
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		protected function getDatURL(name:String):String
		{
			//http://127.0.0.1/hls/p2p-test/test.m3u8
			var offset:int;
			offset = _initData.flvURL[loadURLIndex].lastIndexOf("/");
			var fileName:String=_initData.flvURL[loadURLIndex].substr(0, offset+1)+name;
			return fileName;
		}
		
		protected function getDatURL_1(name:String):String
		{
			//http://127.0.0.1/hls/p2p-test/test.m3u8
			//var offset:int;
			//offset = _initData.flvURL[loadURLIndex].lastIndexOf("/");
			//var fileName:String=_initData.flvURL[loadURLIndex].substr(0, offset+1)+name;
			var fileName:String="http://123.125.89.8/m3u8/test/"+name;
			return fileName;
		}
		
		
		/**本次下载起始piece的索引*/
		protected var startDownloadPieceIdx:int = -1;
		/**本次下载结束piece的索引*/
		protected var endDownloadPieceIdx:int   = -1;
		/**本次下载开始的时间*/
		protected var startLoadTime:Number      = -1;
		/**本次下载结束的时间*/
		protected var endLoadTime:Number        = -1;
		/**本次下载需要下载的字节数*/
		protected var needDownloadBytesLength:Number = -1;
		protected function getDownloadPieceContentTask(p_arrPieces:Array,pieceId:int=-1):String
		{
			startDownloadPieceIdx 		= -1;
			endDownloadPieceIdx   		= -1;
			startLoadTime         		= -1;
			endLoadTime           		= -1;
			needDownloadBytesLength 	= -1;
			
			var startByte:Number 		= -1;
			var endByte:Number   		= -1;
			var piece:Piece   			= null;
			for(var i:int = 0 ; i<Task.pieceIdxArray.length ; i++)
			{
				piece = dispatcher.getPiece(Task.pieceIdxArray[i]);
				
				if(piece && piece.isChecked == false && piece.iLoadType != 1)
				{
					piece.iLoadType = 1;
					if( startByte == -1)
					{
						startByte = CalculatePieceStart(Task,i);
						startDownloadPieceIdx = i;
					}
					
					endDownloadPieceIdx = i;
					endByte = CalculatePieceEnd(Task,i);	
					needDownloadBytesLength = endByte-startByte+1;	
					arrPieceidx.push(i);
					p_arrPieces.push(piece);
					
					if( i== Task.pieceIdxArray.length-1)
					{
						//如果是最后一个piece
						if(startByte == 0)
						{		
							//当整个Task都需要加载时
							return "";								
						}
						else
						{
							if(url.indexOf("?")>0)
							{
								return String("&rstart="+startByte+"&rend="+endByte);
							}
							else
							{
								return String("?rstart="+startByte+"&rend="+endByte);
							}
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
						else
						{
							return String("?rstart="+startByte+"&rend="+endByte);
						}
					}					
				}
			}
			return null;
		}
		
		private function CalculatePieceStart(p_block:Block,p_nIdx:Number):Number
		{
			var nStartPos:Number = 0;
			for(var i:int = 0 ; i< p_nIdx; i++)
			{
				nStartPos += dispatcher.getPiece(p_block.pieceIdxArray[i]).size;
			}
			return nStartPos;
		}
		
		private function CalculatePieceEnd(p_block:Block,p_nIdx:Number):Number
		{
			var nEndPos:Number = 0;
			
			for(var i:int = 0 ; i<= p_nIdx; i++)
			{
				nEndPos += dispatcher.getPiece(p_block.pieceIdxArray[i]).size;
			}
			nEndPos -= 1;
			return nEndPos;
		}	
		
		protected function addListener():void
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
		
		protected function removeListener():void
		{
			if(_mediaStream!=null)
			{
				try
				{
					_mediaStream.close();
				}
				catch(err:Error)
				{
				}
				_mediaStream.removeEventListener(Event.COMPLETE, completeHandler);
				_mediaStream.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				_mediaStream.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				_mediaStream.removeEventListener(ProgressEvent.PROGRESS,receiveDataHandler);
				_mediaStream=null;
			}
		}
		
		protected var errorCounts:int = 0;
		protected function downloadError():void
		{
			//timeOutTimer.reset();
			removeListener();
			errorCounts++;
			_isRead=false;
			if(errorCounts == _initData.flvURL.length)
			{
				errorCounts = 0;
			}
			_countSize=0;
			
			if(arrByteBuf){arrByteBuf.clear()}
			//pieceIdx=0;
			loadURLIndex++;
			
			if(loadURLIndex>=_initData.flvURL.length)
			{
				loadURLIndex=0;
			}
			
			if(Task)
			{
				Task.downLoadStat = 0;
				Task = null;
			}
			
			addListener();
			//
			if(getTaskListTime)
			{
				getTaskListTime.reset();
				getTaskListTime.start();
			}
		}
		
		protected function readData_1(isComplement:Boolean=false):void
		{
			endLoadTime = getTime();
			var pieceCount:int= m_vecDownloadingPieces.length;
			var pieceTime:Number=Math.round((endLoadTime-startLoadTime)/pieceCount);
			
			var nReadSize:Number = 0;
			
			try
			{
				while( m_vecDownloadingPieces.length > 0
					&& m_vecDownloadingPieces[0]
					&& _mediaStream 
					&& _mediaStream.bytesAvailable >= m_vecDownloadingPieces[0].size )
				{
					_isRead=true;
					arrByteBuf.clear();
					
					nReadSize = m_vecDownloadingPieces[0].size;
					_countSize += nReadSize;
					
					_mediaStream.readBytes(arrByteBuf,0,nReadSize);
					//Task.pieceIdxArray[i]
					//{"groupID":Task.groupID,"pieceKey":Task.pieceIdxArray[i].pieceKey}
					tempPiece = m_vecDownloadingPieces[0];//Task.getPiece(Task.pieceIdxArray[startDownloadPieceIdx]);
					if(tempPiece && tempPiece.isChecked == false && tempPiece.iLoadType != 3)
					{													
						tempPiece.from  = "http";
						tempPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
						tempPiece.end   = tempPiece.begin+pieceTime;
						tempPiece.setStream(arrByteBuf);
					}
					
					//pieceTimeIdx++;
					//startDownloadPieceIdx++;
					m_vecDownloadingPieces.shift();
				}
				_isRead=false;
				if(isComplement)
				{
					if(m_vecDownloadingPieces[0] && _mediaStream.bytesAvailable>0 && _mediaStream.bytesAvailable <= m_vecDownloadingPieces[0].size)
					{
						arrByteBuf.clear();
						_mediaStream.readBytes(arrByteBuf);
						nReadSize = m_vecDownloadingPieces[0].size;
						_countSize+=arrByteBuf.length;
						
						tempPiece = m_vecDownloadingPieces[0];//Task.getPiece(Task.pieceIdxArray[startDownloadPieceIdx]);
						if(tempPiece && tempPiece.isChecked == false && tempPiece.iLoadType != 3)
						{													
							tempPiece.from  = "http";
							tempPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
							tempPiece.end   = tempPiece.begin+pieceTime;
							P2PDebug.traceMsg(this,"****** Receive_blockid:"+Task.id + " PieceType:" + m_vecDownloadingPieces[0].type + " Pieceid:" + m_vecDownloadingPieces[0].id);
							tempPiece.setStream(arrByteBuf);
						}
						//pieceTimeIdx++;
						//startDownloadPieceIdx++;
						m_vecDownloadingPieces.shift();
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
		
		/**是否在读数据*/
		protected var _isRead:Boolean=false;
		protected var loadByte:Number=0;		
		protected function receiveDataHandler(event:ProgressEvent=null):void
		{
			loadByte=event.bytesLoaded;
			if(!_isRead)
			{
				readData_1();
			}
		}
		
		protected function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"securityErrorHandler: " + event);
			downloadError();
			//
		}
		
		protected function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			downloadError();
			//
		}
		
		protected function completeHandler(event:Event):void
		{
			errorCounts = 0;
			Task.downLoadStat = 0;
			readData_1(true);
			
			Task = null;
			m_vecDownloadingPieces = null;
			//
			if(getTaskListTime)
			{
				getTaskListTime.reset();
				getTaskListTime.start();
			}
		}
		
		public function clear():void
		{
			loadURLIndex			=0;
			errorCounts				=0;
			removeListener();
			_initData				= null;
			dispatcher				= null;
			
			Task					= null;
			m_vecDownloadingPieces	= null;
			arrPieceidx				= null;
			
			arrByteBuf					= null;
		}
		
	}
}