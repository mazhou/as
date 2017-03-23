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
		/**统计已经下载的字节，和正在下载的字节相加可以得到下载的进度*/
		public var _countSize:Number				= 0;
		public var isDebug:Boolean					= true;
		
		/**初始化数据 */
		protected var _initData:InitData			= null;
		/**声明调度器*/
		protected var dispatcher:IDataManager;
		
		/**加载地址索引，因地址有多个*/
		protected var _mediaStream:URLStream;
		protected var getTaskListTime:Timer;
		protected var loadURLIndex:uint				= 0;

		protected var Task:Block 					= null;
		protected var url:String 					= "";
			
		/** 存放分割的流*/
		protected var arrByteBuf:ByteArray			= new ByteArray;
		protected var loadMgr:LoadManager 			= null;
		protected var m_CurPiece:Piece;
		protected var pieceTimeIdx:int 				= 1;
		
		private var linkStat:String					= "connect";
		private var loadByte:Number					= 0;
		private var lastLoad:Number					= 0;

		

		public function CDNLoad(dispatcher:IDataManager, LDMGR:LoadManager)
		{
			this.dispatcher=dispatcher;
			loadMgr = LDMGR;
			P2PDebug.traceMsg(this,"CDNLoad");
			addListener();
			
			if(getTaskListTime == null)
			{
				getTaskListTime = new Timer(0, 1);
				getTaskListTime.addEventListener(TimerEvent.TIMER, handlerGetTaskList);
			}
		}
		
		private function timeOutHandler(event:TimerEvent):void 
		{
			P2PDebug.traceMsg(this,"timeOutHandler: " + event);
			if(linkStat == "connect")
			{
				downloadError();
			}
			else if(linkStat == "download")
			{
				P2PDebug.traceMsg(this,"loadByte"+(loadByte-lastLoad)/1024*8/3,LiveVodConfig.DATARATE/5);
				if((loadByte-lastLoad)/1024*8/3<LiveVodConfig.DATARATE/5)/*106580 115340*/
				{
					downloadError();
				}
				else
				{
					lastLoad=loadByte;
				}	
			}
		}
		protected function handlerGetTaskList(evt:TimerEvent=null):void
		{
			if (Task == null)
			{
				Task = loadMgr.getCDNTask();
				if(Task)
				{
					P2PDebug.traceMsg(this,"###cdnloader_handlerGetTaskList_Task: ",Task.id);
				}
				else
				{
					P2PDebug.traceMsg(this,"###cdnloader_handlerGetTaskList_Task_null ");
				}
				
				loadTask();
			}
			else
			{
				if(getTaskListTime)
				{
					getTaskListTime.reset();
					getTaskListTime.delay = 20;
					getTaskListTime.start();
				}
			}
		}
		
		public function start( _initData:InitData):void
		{	
			if( !this._initData )
			{
				this._initData = _initData;
			}
			
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

			if(Task.url_ts.indexOf("http://")==0)
			{
				url=Task.url_ts;
			}
			else
			{
				if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
				{
					url=getDatURL_1(Task.url_ts);
				}
				else
				{
					url=getDatURL(Task.url_ts);
				}
				
			}
			
			m_vecDownloadingPieces = new Array;
			var range:String = getDownloadPieceContentTask(m_vecDownloadingPieces,-1);	
			if(range != null)
			{
				url=ParseUrl.replaceParam(url+range,"rd",""+getTime());
				linkStat="connect";
				lastLoad=0;
				
				var request:URLRequest = new URLRequest(url);
				P2PDebug.traceMsg(this,"******start load:"+url);
				P2PDebug.traceMsg(this,"******start load_blockid:"+Task.id + " PieceType:" + m_vecDownloadingPieces[0].type + " Pieceid:" + m_vecDownloadingPieces[0].id);

				try
				{
					startLoadTime=getTime();
					_mediaStream.load(request);
				}
				catch (error:Error)
				{
					P2PDebug.traceMsg(this,"Unable to load requested document.");
					Task.downLoadStat = 0;
					Task = null;
				}
			}
			else
			{
				P2PDebug.traceMsg(this,"range = null");
				downloadError();
			}
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		protected function getDatURL(name:String):String
		{
			var offset:int;
			offset = _initData.flvURL[loadURLIndex].lastIndexOf("/");
			var fileName:String=_initData.flvURL[loadURLIndex].substr(0, offset+1)+name;
			return fileName;
		}
		
		protected function getDatURL_1(name:String):String
		{
			var fileName:String="http://115.182.51.111/m3u8/letv_tv_800/"+name;
			return fileName;
		}
		
		/**本次下载开始的时间*/
		protected var startLoadTime:Number      = -1;
		/**本次下载结束的时间*/
		protected var endLoadTime:Number        = -1;
		/**本次下载需要下载的字节数*/

		protected function getDownloadPieceContentTask(p_arrPieces:Array,pieceId:int=-1):String
		{
			startLoadTime         		= -1;
			endLoadTime           		= -1;
			
			var startByte:Number 		= -1;
			var endByte:Number   		= -1;
			var piece:Piece   			= null;
			for(var i:int = 0 ; i<Task.pieceIdxArray.length ; i++)
			{
				piece = dispatcher.getPiece(Task.pieceIdxArray[i]);
				
				if(piece && piece.isChecked == false && piece.iLoadType != 1)
				{
					// 紧急区之外的数据
					if( Task.downLoadStat != 1 && piece.isLoad == false )
					{
						continue;
					}
//					else if( Task.downLoadStat != 1 && piece.isLoad == true )
//					{
//						// do nothing
//					}
//					else if( Task.downLoadStat == 1)
//					{
//						// do nothing
//					}
//					else
//					{
//						// do nothing
//					}
					
					piece.iLoadType = 1;
					if( startByte == -1)
					{
						startByte = CalculatePieceStart(Task,i);
					}
					
					endByte = CalculatePieceEnd(Task,i);	
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
			removeListener();
			errorCounts++;
			_isRead=false;
			
			if(errorCounts == _initData.flvURL.length)
			{
				errorCounts = 0;
			}
			
			_countSize=0;
			
			if(arrByteBuf)
			{
				arrByteBuf.clear()
			}
			
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

			if(getTaskListTime)
			{
				getTaskListTime.reset();
				getTaskListTime.start();
			}
		}
		
		protected function readData_1(isComplement:Boolean=false):void
		{
			endLoadTime = getTime();
			var nReadSize:Number = 0;
			var pieceCount:int	 = m_vecDownloadingPieces.length;
			var pieceTime:Number = Math.round((endLoadTime-startLoadTime)/pieceCount);
			
			
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

					m_CurPiece = m_vecDownloadingPieces[0];
					if(m_CurPiece && m_CurPiece.isChecked == false && m_CurPiece.iLoadType != 3)
					{													
						m_CurPiece.from  = "http";
						m_CurPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
						m_CurPiece.end   = m_CurPiece.begin+pieceTime;
						m_CurPiece.setStream(arrByteBuf);
					}

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
						
						m_CurPiece = m_vecDownloadingPieces[0];
						if(m_CurPiece && m_CurPiece.isChecked == false && m_CurPiece.iLoadType != 3)
						{													
							m_CurPiece.from  = "http";
							m_CurPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
							m_CurPiece.end   = m_CurPiece.begin+pieceTime;
							P2PDebug.traceMsg(this,"****** Receive_blockid:"+Task.id + " PieceType:" + m_vecDownloadingPieces[0].type + " Pieceid:" + m_vecDownloadingPieces[0].id);
							m_CurPiece.setStream(arrByteBuf);
						}

						m_vecDownloadingPieces.shift();
					}
				}
			}
			catch(err:Error)
			{
				P2PDebug.traceMsg(this,"http解析数据错误");
				downloadError();
			}
		}
		
		/**是否在读数据*/
		protected var _isRead:Boolean=false;
		protected function receiveDataHandler(event:ProgressEvent=null):void
		{
			linkStat="download";
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
		}
		
		protected function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,"ioErrorHandler: " + event);
			downloadError();
		}
		
		protected function completeHandler(event:Event):void
		{
			errorCounts = 0;
			readData_1(true);
			
			if( Task )
			{
				P2PDebug.traceMsg(this,"***completeHandler_Taskid: " + Task.id);
			}
			
			if(Task)
			{
				Task.downLoadStat = 0;
			}
			
			Task = null;
			m_vecDownloadingPieces = null;

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
			arrByteBuf				= null;
		}
		
	}
}