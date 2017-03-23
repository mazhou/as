
package com.p2p_live.managers
{
	import com.p2p_live.data.*;
	import com.p2p_live.events.*;
	import com.p2p_live.loaders.HttpLiveDataLoader;
	import com.p2p_live.loaders.P2PLoader;
	import com.p2p.utils.CRC32;
	
	import flash.events.*;
	import flash.system.Security;
	import flash.utils.ByteArray;
	
	import com.mzStudio.mzStudioDebug.MZDebugger;

	public class DataManager extends EventDispatcher
	{		
		public var chunks:Chunks;	
		public var blockList:BlockList;
		public var isJoinNetGroup:Boolean;
		
		protected static const CHUNK_SHARE_WEIGHT:Number = 1.0;
		protected static const CHUNK_TIME_WEIGHT:int = 1;
		protected static const MEMORY_LENGTH:uint = 200*1024*1024;
		protected static const CLIP_INTERVAL:uint = 128*1024;
		//protected static const Chuncks_NUMBER:uint =  uint(Math.floor(MEMORY_LENGTH / CLIP_INTERVAL));		
	
		protected var _videoInfo:Object;		
		protected var _liveDataLoader:HttpLiveDataLoader;
		//protected var _p2pDataLoader:P2PLoader;
		
        protected var _playHead:uint;
		
		private var _httpBufferLength:uint;	
		
		private var _isTrueLiveType:Boolean = true;
		
		protected var _errorLoop:int = 0 ;
		protected var _errorChunkIndex:int = -1 ;

		private var _bufferTimeArray:Array=null;
		//private var _bufferTimerChunkIndexStartSave:uint = 0;
		//private var _bufferTimerChunkIndexEndSave:uint = 0;
				
		public var  userName:Object = new Object();
		//	
		/**
		 * startTimeObj记录第一次加载checkSum,selector,gather,rtmfp以及第一块p2p数据的下载的开始时间
		 * 计算出下载耗时	
		 */		
		public var startTime:Number = 0;
		
		private var _httpDownloadingTask:uint;
		public function DataManager()
		{
			
		}       
		
		public function get bufferTimeArray():Array
		{
			return _bufferTimeArray;
		}
		public function get httpBufferLength():uint
		{
			return _httpBufferLength;
		}

		public function get playHead():uint
		{
			return _playHead;
		}
		
		public function get httpDownloadingTask():uint
		{
			if(_liveDataLoader!=null)
			{
				return _liveDataLoader.httpDownloadingTask;
			}
			return 0;
		}
		
		public function start(videoInfo:Object):Boolean
		{	
			clear();
			_videoInfo = videoInfo;			
			
			blockList = new BlockList(MEMORY_LENGTH,CLIP_INTERVAL);
			MZDebugger.trace(this,{"key":"INIT","value":"\n DataManger start "});
			_liveDataLoader = new HttpLiveDataLoader(_videoInfo,this);				
			_liveDataLoader.addEventListener(HttpLiveEvent.LOAD_DATA_STATUS,liveDataLoaderHandler);
			_liveDataLoader.addEventListener(DataManagerEvent.STATUS,dispatchEvent);				
			_isTrueLiveType = _videoInfo.isTrueLiveType;
			_liveDataLoader.start();
			
			return true;
		}
		
		public function clear():void
		{			
			if(_liveDataLoader)
			{
				_liveDataLoader.removeEventListener(HttpLiveEvent.LOAD_DATA_STATUS,liveDataLoaderHandler);
				_liveDataLoader.removeEventListener(P2PLoaderEvent.STATUS,dispatchEvent);
				_liveDataLoader.clear();
				_liveDataLoader = null;
			}
			
			if(blockList)
			{
				blockList.clear();
				blockList = null;
			}
			_videoInfo = null;
			_playHead = 0;
		}
		
		public function readByteArray(index:uint):ByteArray
		{						
            if(blockList == null)
			{
				return null;
			}
			//trace("index=",index)
			_playHead = index;
			_liveDataLoader.goonHttp(_playHead);
			
			var bl:Block=blockList.getBlock(index);			
			if (bl!=null)
			{ 	
				if(bl.isAllDataAssign)
				{
					_liveDataLoader.removeChunkIndex(index);
					return bl.getBlockStream;
				}									
			}
			else
			{
				//当没有该block时，添加该block到blockList列表里
				_liveDataLoader.addP2PBlock(index,"http");
			}
			return null;
		}
		
		public function nextChunkIndex(curIndex:uint):uint
		{
			
			return _liveDataLoader.nextChunkIndex(curIndex);
			/*
			if(_videoInfo.playType == "live")
			{
				return _liveDataLoader.nextChunkIndex(curIndex);
			}else
			{
				//TODO Duration
				return 0;
			}
			*/
		}
		
		public function seek(obj:Object):void
		{
			/*if (null == chunks && _videoInfo.playType == "live")
				return ;*/	
			_playHead = 0;	
			_liveDataLoader.startSeek(obj);
		}
		
		public function writeData(e:P2PEvent):Boolean
		{
			if (null == blockList)
				return false;
			//
			var obj:Object = e.info;
			
			var timerObj:Object = addChunk(obj);
						
			if(timerObj)
			{
				eliminate();				
				
				obj.begin = timerObj.begin;
				obj.end   = timerObj.end;
				obj.size  = (obj.data as ByteArray).length;
				obj.level ="status";
				dispatchReceiveData(obj);	
				//trace(obj.begin+" "+obj.end)
				return true;
			}
			return false;
			/*var bl:Block = addChunk(obj);
			if(bl != null)
			{
				eliminate();
				
				obj.begin = bl.begin;
				obj.end   = bl.end;
				obj.size  = obj.data.bytesAvailable;
				obj.level ="status";
				
				dispatchReceiveData(obj);
				
				if (this.isJoinNetGroup)
				{
					_liveDataLoader.removeWantData(bl);
				}
				if(obj.from=="p2p")
				{
					obj.code = "P2P.P2PGetChunk.Success";
					obj.act   = "load";
					obj.error = 0;
					//this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));		
				}
				else
				{			
					obj.code = "P2P.HttpGetChunk.Success";
					//this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
				}
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));	
				return true;					
			}*/
		}
		
		protected function dispatchReceiveData(obj:Object):void
		{			
			if(obj.from=="p2p")
			{
				obj.code = "P2P.P2PGetChunk.Success";
				obj.act   = "load";
				obj.error = 0;		
			}
			else
			{			
				obj.code = "P2P.HttpGetChunk.Success";
			}
			this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));	
		}
		
		protected function checkData(data:ByteArray,id:uint):Boolean
		{
			
			return _liveDataLoader.checkData(data,id);
			/*
			if(_videoInfo.playType == "live")
			{
				return _liveDataLoader.checkData(data,id);
			} 
			return false;
			*/
		}
		/*
		处理数据淘汰
		*/
		protected function eliminate():void
		{
			if (playHead == 0 || !blockList.getBlock(playHead) || null == blockList)
				return ;			
			
			var i:int = blockList.eliminate(blockList.getBlock(playHead));
			
			if(i>0)
			{				
				trace("remove = "+i+";  playHead "+playHead);
				var info:Object = new Object();
				info.code = "P2P.RemoveData.Success";
				if(i < playHead)
				{
					info.id = i+" B";
				}
				else
				{
					info.id = i+" F";
				}
				
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,info));
				
				
				_liveDataLoader.removeHaveData(i);			
			}			
		}
		
		protected function addChunk(obj:Object):Object
		{					
			if (!blockList)
				return null;			
			
			var bl:Block = blockList.getBlock(obj.id);
			
			if( bl && !bl.isAllDataAssign)
			{
				var timeObj:Object;
				
				if(obj.from == "http")
				{
					bl.end = Number(getTime());
					bl.addBlockStream = ByteArray(obj.data);
					bl.from = obj.from;
					
					timeObj = new Object();
					timeObj.begin = bl.begin;
					timeObj.end   = bl.end;
				}
				else
				{
					if(bl.setPieceElementStream(uint(obj.pieceID),obj.data,obj.checksum))
					{
						timeObj = new Object();
						timeObj.begin = bl.getPieceElement(uint(obj.pieceID)).begin;
						timeObj.end   = bl.getPieceElement(uint(obj.pieceID)).end;
					}					
				}					
				return timeObj;
			}			
			return null;
		}		
		
		public function weightPlus(bID:uint,pID:uint,name:String):void
		{
			if (!blockList)
				return ;
			
			/*var ch:Chunk = chunks.getChunk(index);
			if(null != ch && ch.iLoadType == 3)
			{
				ch.share += CHUNK_SHARE_WEIGHT;	
			}*/	
				var info:Object = new Object();
				info.code = "P2P.P2PShareChunk.Success";
				//info.size = ch.data.length;
				info.bID   = bID;
				info.pID   = pID;
				info.name  = name;
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,info));
			
			
		}				
		
		protected function liveDataLoaderHandler(e:HttpLiveEvent):void
		{
			switch(e.info.code)
			{
				case HttpLiveEvent.CHANGE_METADATA:
				case HttpLiveEvent.LOAD_DESC_SUCCESS:										
				case HttpLiveEvent.LOAD_HEADER_SUCCESS:
				case HttpLiveEvent.LOAD_DESC_NOT_EXIST:
					
					//MZDebugger.trace(this,{"key":"INIT","value":"\n e.info.code ： "+e.info.code});
					
					dispatchEvent(e);
					break;
				case HttpLiveEvent.LOAD_CLIP_SUCCESS:					
					this.writeData(e);		
					break;
				case HttpLiveEvent.LOAD_CLIP_SECURITY_ERROR:					
				case HttpLiveDataLoader.HTTP_CLIENT_TIMEOUT:					
				case HttpLiveEvent.LOAD_CLIP_IO_ERROR:
					var info:Object = new Object();
					info = e.info;
					info.code = "P2P.HttpGetChunk.Failed";
					info.id   = info.id;
					this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,info));
					break;
			}
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}	

	}
}