package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.p2p.utils.ParseUrl;
	import com.hls_p2p.statistics.Statistic;
	
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
		/**初始化数据*/
		protected var _initData:InitData	=null;
		/**声明调度器*/
		protected var dispatcher:IDataManager;
		
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint		=0;
		protected var _downloadTaskTime:Timer;
		protected var _mediaStream:URLStream;
		
		//protected var timeOutTimer:Timer;
		
		protected var Task:Block 			= null;
		protected var taskObj:Object		=null;
		protected var linkStat:String		="connect";
		protected var lastTaskName:String	="";
		protected var url:String 			="";
		
			
		/**统计已经下载的字节，和正在下载的字节相加可以得到下载的进度*/
		public var _countSize:Number		=0;
		/** 存放分割的流*/
		protected var pies:ByteArray		= new ByteArray;
		protected var tempPiece:Piece;
		protected var pieceTimeIdx:int 		= 1;
		
		
		public function CDNLoad(dispatcher:IDataManager)
		{
			this.dispatcher=dispatcher;
			P2PDebug.traceMsg(this,"CDNLoad");
			addListener();
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
			_isLoad = false;
		}
		
		
		protected var m_vecDownloadingPieces:Vector.<Piece>;
		
		public function loadTask(block:Block):void
		{
//			if(m_vecDownloadingPieces == null)
//			{
//				m_vecDownloadingPieces = new Vector.<Piece>;
//			}
//			else
//			{
//				// vector中有元素，说明还有piece没有下载完。
//				return;
//			}
			
			if(dispatcher && null == Task && !_isLoad)
			{
				Task=block;
				_countSize=0;
				
				Task.downLoadStat = 1;
				//
				
				if(Task.name.indexOf("http://")==0)
				{
					url=Task.name;
				}
				else
				{
					url=getDatURL(Task.name);
				}
				
				//timeOutTimer.reset();
				m_vecDownloadingPieces = new Vector.<Piece>;
				var range:String = getDownloadPieceContentTask(m_vecDownloadingPieces,-1);	
				if(range != null)
				{
					url=ParseUrl.replaceParam(url+range,"rd",""+getTime());
					var request:URLRequest = new URLRequest(url);
					P2PDebug.traceMsg(this,"start load:"+url);
					linkStat="connect";
					try
					{
						startLoadTime=getTime();
						_mediaStream.load(request);
						_isLoad = true;
					}
					catch (error:Error)
					{
						P2PDebug.traceMsg(this,"Unable to load requested document.");
						Task.downLoadStat = 0;//
						Task = null;
					}
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
		protected function getDownloadPieceContentTask(p_vecPieces:Vector.<Piece>,pieceId:int=-1):String
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
					p_vecPieces.push(piece);
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
		
		protected function readData_1(isComplement:Boolean=false):void
		{
			endLoadTime = getTime();
			var pieceCount:int= m_vecDownloadingPieces.length;
			var pieceTime:Number=Math.round((endLoadTime-startLoadTime)/pieceCount);
			
			var nPieceIdx:int = 0;
			var nReadSize:Number = 0;
			
			try
			{
				while(_mediaStream && _mediaStream.bytesAvailable > m_vecDownloadingPieces[startDownloadPieceIdx].size )
				{
					_isRead=true;
					pies.clear();
					
					nReadSize = m_vecDownloadingPieces[startDownloadPieceIdx].size;
					_countSize += nReadSize;
					
					_mediaStream.readBytes(pies,0,nReadSize);
					//Task.pieceIdxArray[i]
					//{"groupID":Task.groupID,"pieceKey":Task.pieceIdxArray[i].pieceKey}
					tempPiece = dispatcher.getPiece(Task.pieceIdxArray[startDownloadPieceIdx]);//Task.getPiece(Task.pieceIdxArray[startDownloadPieceIdx]);
					if(tempPiece && tempPiece.isChecked == false && tempPiece.iLoadType != 3)
					{													
						tempPiece.from  = "http";
						tempPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
						tempPiece.end   = tempPiece.begin+pieceTime;
						if(tempPiece.setStream(pies))
						{
							try{
								dispatcher.doAddHave(tempPiece.groupID);
							}catch(err:Error)
							{
								P2PDebug.traceMsg("doAddHave error 0"+err);
							}
						}
					}
					
					pieceTimeIdx++;
					startDownloadPieceIdx++;
					if(startDownloadPieceIdx == m_vecDownloadingPieces.length)
					{
						break;
					}
				}
				_isRead=false;
				if(isComplement)
				{
					if(_mediaStream.bytesAvailable>0&&_mediaStream.bytesAvailable<=m_vecDownloadingPieces[startDownloadPieceIdx].size)
					{
						pies.clear();
						_mediaStream.readBytes(pies);
						nReadSize = m_vecDownloadingPieces[startDownloadPieceIdx].size;
						_countSize+=pies.length;
						
						tempPiece = dispatcher.getPiece(Task.pieceIdxArray[startDownloadPieceIdx]);//Task.getPiece(Task.pieceIdxArray[startDownloadPieceIdx]);
						if(tempPiece && tempPiece.isChecked == false && tempPiece.iLoadType != 3)
						{													
							tempPiece.from  = "http";
							tempPiece.begin = startLoadTime+pieceTimeIdx*pieceTime;
							tempPiece.end   = tempPiece.begin+pieceTime;
							if(tempPiece.setStream(pies))
							{
								try{
									dispatcher.doAddHave(tempPiece.groupID);
									Statistic.getInstance().httpGetData(Task.id+"_"+tempPiece.pieceKey+"_"+tempPiece.id,tempPiece.begin,tempPiece.end,tempPiece.size);
								}catch(err:Error)
								{
									P2PDebug.traceMsg("doAddHave error 1"+err);
								}
							}
						}
						
						pieceTimeIdx++;
						startDownloadPieceIdx++;
					}
					if(startDownloadPieceIdx == m_vecDownloadingPieces.length)
					{
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
		
		/**是否在读数据*/
		protected var _isRead:Boolean=false;
		protected var loadByte:Number=0;		
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
			//dispatcher.setPiece("",new ByteArray)
			
			/*
			if(Task._downLoadStat != 1)
			{
			Task = null;
			return;
			}*/
			//timeOutTimer.reset();
			errorCounts = 0;
			Task.downLoadStat = 0;
			readData_1(true);
			//			if(Task)
			//			{
			//				P2PDebug.traceMsg(this,"load complete:"+Task.name);
			//			}
			//
			Task = null;
			m_vecDownloadingPieces = null;
			_isLoad = false;
		}
		
		public function get isLoad():Boolean
		{
			return _isLoad;
		}
		
		public function clear():void
		{
			loadURLIndex		=0;
			_isLoad				= false;
			removeListener();
			_initData				= null;
			dispatcher				= null;
			
			Task					= null;
			m_vecDownloadingPieces	= null;
		}
		
		protected var _isLoad:Boolean;
	}
}