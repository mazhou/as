package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
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
		public var isDebug:Boolean					= true;
		/**统计已经下载的字节，和正在下载的字节相加可以得到下载的进度*/
		public var _countSize:Number				= 0;
		public var id:int							= 0;
		/**初始化数据 */
		protected var _initData:InitData			= null;
		/**声明调度器*/
		protected var dataManager:DataManager;
		
		/**加载地址索引，因地址有多个*/
		protected var _mediaStream:URLStream;
		protected var getTaskListTime:Timer;
		//protected var loadURLIndex:uint				= 0;

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
		/**是否有权限加载紧急区之后的随机数据*/
		private var ifLoadAfterBuffer:Boolean       = true;

		public function CDNLoad(dataManager:DataManager, LDMGR:LoadManager, ifLoadAfterBuffer:Boolean=true)
		{
			this.dataManager=dataManager;
			this.ifLoadAfterBuffer = ifLoadAfterBuffer;
			loadMgr = LDMGR;
			P2PDebug.traceMsg(this,"CDNLoad"+this.id);
			addListener();
			
			if(getTaskListTime == null)
			{
				//getTaskListTime = new Timer(0, 1);
				getTaskListTime = new Timer(50);
				getTaskListTime.addEventListener(TimerEvent.TIMER, handlerGetTaskList);
			}
		}
		
//		private function timeOutHandler(event:TimerEvent):void 
//		{
//			P2PDebug.traceMsg(this,"timeOutHandler: " + event);
//			if(linkStat == "connect")
//			{
//				downloadError();
//			}
//			else if(linkStat == "download")
//			{
//				P2PDebug.traceMsg(this,"loadByte"+(loadByte-lastLoad)/1024*8/3,LiveVodConfig.DATARATE/5);
//				if((loadByte-lastLoad)/1024*8/3<LiveVodConfig.DATARATE/5)/*106580 115340*/
//				{
//					downloadError();
//				}
//				else
//				{
//					lastLoad=loadByte;
//				}	
//			}
//		}
		private var isBuffer:Boolean = false;
		protected function handlerGetTaskList(evt:TimerEvent=null):void
		{
			if( LiveVodConfig.cdnDisable == 1 && Statistic.getInstance().userAllowP2P != -1 )
			{
				return;
			}
			if (Task == null)
			{	
				if( loadMgr )
				{
					var obj:Object = loadMgr.getCDNTask( this.ifLoadAfterBuffer );
					if(obj)
					{
						Task 	 = obj["block"];
						isBuffer = obj["isBuffer"];
						obj["block"] = null;
						delete obj["block"];
						obj["isBuffer"] = null;
						delete obj["isBuffer"];
						obj = null;
						loadTask();
					}
				}
			}
//			else
//			{
//				if(getTaskListTime)
//				{
//					getTaskListTime.reset();
//					getTaskListTime.delay = 500;
//					getTaskListTime.start();
//				}
//			}
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
				
				stopDownloadingTask();
				
				/*Task.downLoadStat = 0;
				P2PDebug.traceMsg(this,"start Task.downLoadStat = 0"+"bID = "+Task.id);
				
				Task = null;*/
			}			
			
			//errorCounts = 0;
			pieceTimeIdx = 1;
			
			if(getTaskListTime)
			{
				getTaskListTime.reset();
				getTaskListTime.delay = 200;
				getTaskListTime.start();
			}
		}
		
		public function pause():void
		{
			if(getTaskListTime && true == getTaskListTime.running)
			{
				getTaskListTime.reset();
				getTaskListTime.delay = 200;
			}
		}
		
		public function resume():void
		{
			if(getTaskListTime && false == getTaskListTime.running)
			{
				getTaskListTime.reset();
				getTaskListTime.delay = 200;
				getTaskListTime.start();
			}
		}
		
		private function stopDownloadingTask():void
		{
			var debugMsg:String = "";
			if( m_vecDownloadingPieces.length>0 )
			{
				var tempPiece:Piece;
				for( var i:int = m_vecDownloadingPieces.length-1 ; i >= 0 ; i-- )
				{
					tempPiece = m_vecDownloadingPieces[i] as Piece
					if( tempPiece && false == tempPiece.isChecked && 1 == tempPiece.iLoadType)
					{
						tempPiece.iLoadType = 0;
						debugMsg += " "+tempPiece.id+" "+tempPiece.pieceKey;
					}
					 m_vecDownloadingPieces.pop();
				}
			}
			P2PDebug.traceMsg(this,this.id+" set stopDownloadingTask "+Task.id+" "+debugMsg);
			
			Task = null;
			isBuffer = false;
		}
		
		protected var m_vecDownloadingPieces:Array;
		
		public function loadTask():void
		{	
			if (Task == null)
			{
//				if(getTaskListTime)
//				{
//					getTaskListTime.reset();
//					getTaskListTime.delay = 20;
//					getTaskListTime.start();
//				}
				return ;
			}
	
			_countSize=0;
			//{"block":block,"isBuffer":true}
			
			if( Task.url_ts.indexOf("http://")==0 )
			{
				url = Task.url_ts;//测试时使用
				//
				//url = _initData.flvURL[loadURLIndex];
				//url = getDatURL1(Task.url_ts);
				//url = getDataURL2(Task.name);//上线时使用
			}
			else
			{
				url = getDataURL(Task.url_ts);
			}
			
			m_vecDownloadingPieces = new Array;
			var range:String = getDownloadPieceContentTask(m_vecDownloadingPieces,-1);	
			
			if(range != null)
			{
				url=ParseUrl.replaceParam(url+range,"rd",""+getTime());
				linkStat="connect";
				lastLoad=0;
				//trace(url.substring(0,url.indexOf("/",7))+",playlevel:"+_initData.playlevel);
				var request:URLRequest = new URLRequest(url);
				P2PDebug.traceMsg(this,this.id+" url:"+url);
				/*if( range != "" )
				{
					Task.downLoadStat = 0;
				}*/
				try
				{
					startLoadTime=getTime();
					_mediaStream.load(request);					
					
					var piece:Piece  	= null;
					var debugMsg:String = "";
					for(var i:int = 0 ; i<Task.pieceIdxArray.length ; i++)
					{
						piece = dataManager.getPiece(Task.pieceIdxArray[i]);
						
						if( piece && piece.isChecked == false )
						{
							dataManager.startDownloadTS(Task.id,piece.id);
							break;
						}
					}
					
				}
				catch (error:Error)
				{
					P2PDebug.traceMsg(this,"Unable to load requested document.");
					stopDownloadingTask();
					//Task = null;
				}
			}
			else
			{
				P2PDebug.traceMsg(this,this.id + "range = null" + this.Task.id + " " + this.Task.name);
				downloadError();
			}
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		protected function getDataURL1(name:String):String
		{
			//使用block里的ts.url地址与m3u8进行组合生成新的ts.url
			var tempM3u8Str:String = _initData.flvURL[_initData.g_nM3U8Idx];
			var tempInt1:int = tempM3u8Str.indexOf("?");
			if( tempInt1 != -1 )
			{
				var tempEndStr:String = tempM3u8Str.substr(tempInt1+1,tempM3u8Str.length);
				var tempStartStr:String = tempM3u8Str.substring(0,tempM3u8Str.indexOf("/",7));
				if( tempEndStr && tempStartStr )
				{
					name = name.replace(name.substring(0,name.indexOf("/",7)),tempStartStr);
					name = name.replace(name.substring(name.indexOf("?")+1,name.length),tempEndStr);
				}
			}
			return name;
		}
		
		protected function getDataURL2(name:String):String
		{
			//使用block里的ts文件名与m3u8进行组合生成新的ts.url
			var tempM3u8Str:String = _initData.flvURL[_initData.g_nM3U8Idx];
			return tempM3u8Str.replace(".m3u8?","_mp4/"+name+"?");
		}
		
		protected function getDataURL(name:String):String
		{
			var offset:int;
			offset = _initData.flvURL[_initData.g_nM3U8Idx].lastIndexOf("/");
			var fileName:String=_initData.flvURL[_initData.g_nM3U8Idx].substr(0, offset+1)+name;
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
			var debugMsg:String = "";
			for(var i:int = 0 ; i<Task.pieceIdxArray.length ; i++)
			{
				piece = dataManager.getPiece(Task.pieceIdxArray[i]);

				if( piece 
					&& (piece.isChecked == false && piece.errorCount <= 3) 
					&&(( piece.iLoadType != 1 && true == isBuffer)
					|| (LiveVodConfig.TYPE == LiveVodConfig.LIVE && piece.isLoad == true)
					)
				)
				{							
					piece.iLoadType = 1;
					if( startByte == -1)
					{
						startByte = CalculatePieceStart(Task,i);
						debugMsg += " start:"+i; 
					}
					
					endByte = CalculatePieceEnd(Task,i);	
					p_arrPieces.push(piece);
					
					if( i== Task.pieceIdxArray.length-1)
					{
						debugMsg += "-end:"+i; 
						P2PDebug.traceMsg(this,"-id:" + this.id + debugMsg + " Taskid: " + Task.id);
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
						debugMsg += "-end:"+(i-1); 
						P2PDebug.traceMsg(this,"*id:" + this.id + debugMsg + " Taskid: " + Task.id);
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
			
//			//TTT
//			for( var j:int = 0 ; j<Task.pieceIdxArray.length ; j++ )
//			{
//				var tmppiece:Piece = dispatcher.getPiece(Task.pieceIdxArray[j]);
//				
//				P2PDebug.traceMsg(this,"id:"+this.id+" Taskid: " + Task.id + " Task.isChecked: " + Task.isChecked + " Task.downLoadStat: " + Task.downLoadStat + " pieceid: " + tmppiece.id + " piece.isChecked: " + tmppiece.isChecked + " piece.iLoadType: " + tmppiece.iLoadType + " piece.isLoad: " + tmppiece.isLoad );
//			}
			
			P2PDebug.traceMsg(this,this.id+" range is null ");
			return null;
		}
		
		private function CalculatePieceStart(p_block:Block,p_nIdx:Number):Number
		{
			var nStartPos:Number = 0;
			for(var i:int = 0 ; i< p_nIdx; i++)
			{
				nStartPos += dataManager.getPiece(p_block.pieceIdxArray[i]).size;
			}
			return nStartPos;
		}
		
		private function CalculatePieceEnd(p_block:Block,p_nIdx:Number):Number
		{
			var nEndPos:Number = 0;
			
			for(var i:int = 0 ; i<= p_nIdx; i++)
			{
				nEndPos += dataManager.getPiece(p_block.pieceIdxArray[i]).size;
			}
			nEndPos -= 1;
			
			return nEndPos;
		}	

		protected function addListener():void
		{
			if(_mediaStream==null)
			{
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
		
		//protected var errorCounts:int = 0;
		protected function downloadError():void
		{
			if(Task && dataManager)
			{
				//错误上报
				var piece:Piece  	= null;
				var debugMsg:String = "";
				for(var i:int = 0 ; i<Task.pieceIdxArray.length ; i++)
				{
					piece = dataManager.getPiece(Task.pieceIdxArray[i]);
					
					if( piece && piece.isChecked == false )
					{
						dataManager.downloadTSFailed(Task.id,piece.id);
						break;
					}
				}
			}
			
			removeListener();
			//errorCounts++;
			_isRead=false;
			
			
			while(m_vecDownloadingPieces.length>0)
			{
				m_vecDownloadingPieces[0].iLoadType = 0;
				m_vecDownloadingPieces.shift();
			}
			
			/*if(errorCounts == _initData.flvURL.length)
			{
				errorCounts = 0;
			}*/
			
			_countSize=0;
			
			if(arrByteBuf)
			{
				arrByteBuf.clear()
			}
			
			_initData.g_nM3U8Idx++;
			
			if(_initData.g_nM3U8Idx>=_initData.flvURL.length)
			{
				_initData.g_nM3U8Idx=0;
			}
			
			//_initData.playlevel = 4;
			
			if(Task)
			{
				stopDownloadingTask();
				/*Task.downLoadStat = 0;				
				Task = null;*/
			}
			
			addListener();

//			if(getTaskListTime)
//			{
//				getTaskListTime.reset();
//				getTaskListTime.delay = 500;
//				getTaskListTime.start();
//			}
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
							m_CurPiece.setStream(arrByteBuf);
						}

						m_vecDownloadingPieces.shift();
					}
				}
			}
			catch(err:Error)
			{
				if( Task )
				{
					P2PDebug.traceMsg( this,"bID:"+this.Task.id);
				}
				P2PDebug.traceMsg(this,this.id+"http解析数据错误"+err.getStackTrace());
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
			P2PDebug.traceMsg(this,this.id+"securityErrorHandler: " + event);
			downloadError();
		}
		
		protected function ioErrorHandler(event:IOErrorEvent):void 
		{
			P2PDebug.traceMsg(this,this.id+"ioErrorHandler: " + event);
			//trace(this.id+"ioErrorHandler: " + event)
			downloadError();
		}
		
		protected function completeHandler(event:Event):void
		{
			//errorCounts = 0;
			readData_1(true);
			
			if( Task )
			{
				P2PDebug.traceMsg(this,this.id+" completeHandler Taskid: " + Task.id + " name:" + Task.name+" isCheck:" + Task.isChecked );
				stopDownloadingTask();
			}
			
			/*if(Task)
			{
				Task.downLoadStat = 0;
			}
			
			Task = null;*/
			m_vecDownloadingPieces = null;

//			if(getTaskListTime)
//			{
//				getTaskListTime.reset();
//				getTaskListTime.delay = 0;
//				getTaskListTime.start();
//			}
		}
		
		public function clear():void
		{
			getTaskListTime.stop();
			getTaskListTime 		= null;
			//loadURLIndex			=0;
			//errorCounts				=0;
			removeListener();
			
			_initData				= null;
			dataManager				= null;
			
			Task					= null;
			m_vecDownloadingPieces	= null;
			arrByteBuf				= null;
			
			ifLoadAfterBuffer		= true;
			isBuffer                = false;
		}
		
	}
}