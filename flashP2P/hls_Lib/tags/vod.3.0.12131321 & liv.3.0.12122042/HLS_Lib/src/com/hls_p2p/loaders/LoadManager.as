package com.hls_p2p.loaders
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.loaders.Gslbloader.Gslbloader;
	import com.hls_p2p.loaders.cdnLoader.CDNLoad;
	import com.hls_p2p.loaders.p2pLoader.P2P_Cluster;
	import com.hls_p2p.logs.P2PDebug;
	import com.p2p.utils.ParseUrl;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class LoadManager
	{
		protected var getTaskListTime:Timer;
		protected var manager:DataManager;
		//protected var cdnLoad:CDNLoad;
		protected var cdnLoadList:Array = null;
		protected var p2pCluster:P2P_Cluster;
		private   var _CacheLen:Number 		    = LiveVodConfig.DAT_BUFFER_TIME;
		protected var TaskCacheNode:Object 		= new Object;
		protected var _initData:InitData;
		protected var m_lastTime:Number			= 0;
		
		public var isDebug:Boolean			 	  			= true;
		public	static	var g_strsticLastUrl:String			= "";
		
		public function LoadManager( manager:DataManager )
		{
			this.manager = manager;
			//cdnLoad = new CDNLoad( manager, this );
			p2pCluster = new P2P_Cluster();
			
			if(null == cdnLoadList)
			{
				cdnLoadList = new Array(4);
				for( var i:int=0 ; i<cdnLoadList.length ; i++)
				{
					if( LiveVodConfig.TYPE == LiveVodConfig.LIVE && i==0 )
					{
						cdnLoadList[i] = new CDNLoad( manager, this);
						//TTT
						cdnLoadList[i].id = i;
					}
					else
					{
						cdnLoadList[i] = new CDNLoad( manager, this, false );
						//TTT
						cdnLoadList[i].id = i;
					}
				}
			}			
		}
		
		public function ifPeerHaveThisPiece(tempPiece:Piece):Boolean
		{
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				return p2pCluster.ifPeerHaveThisPiece( tempPiece );
			}
			return false;
		}
		
		public function peerHartBeat(groupIDList:Array):void
		{
			p2pCluster.peerHartBeat(groupIDList);
		}
		public function get CacheLen():Number
		{
			return _CacheLen;
		}
		public function start( _initData:InitData ):void
		{
			this._initData	= _initData;
			TaskCacheNode 	= null;
			TaskCacheNode 	= new Object;
			
			handlerGetTaskList();
			for( var i:int=0 ; i<cdnLoadList.length ; i++)
			{
				(cdnLoadList[i] as CDNLoad).start(_initData);
			}
			//cdnLoad.start(_initData);
			
			p2pCluster.initialize( _initData,manager );
		}
		
		protected function handlerGetTaskList():void
		{
			CheckCompleteTaskInCacheNode();
			//
			if( TaskCacheNode
				&& TaskCacheNode.task )
			{
				if(TaskCacheNode.task.length > 20)
				{
//					return;
				}				
			}
			
			TaskCacheNode = manager.getDataTaskList();
			handerGroupList(TaskCacheNode.groupList);
			
			//TTT
			var tmpAddtime:Number = LiveVodConfig.ADD_DATA_TIME;
			//stopDownLoad
			if( _CacheLen == LiveVodConfig.DAT_BUFFER_TIME )
			{
				if( TaskCacheNode
					&& TaskCacheNode.task
					&& TaskCacheNode.task[0] 
					&& (TaskCacheNode.task[0] as Block).id - LiveVodConfig.ADD_DATA_TIME > LiveVodConfig.DAT_BUFFER_TIME )
				{
					_CacheLen = LiveVodConfig.DAT_BUFFER_TIME / 2;
				}
			}
			else if( TaskCacheNode
					  && TaskCacheNode.task
					  && TaskCacheNode.task[0]
					  && (TaskCacheNode.task[0] as Block).id - LiveVodConfig.ADD_DATA_TIME < LiveVodConfig.DAT_BUFFER_TIME / 2 )
			{
				_CacheLen = LiveVodConfig.DAT_BUFFER_TIME;
			}
		}
		
		public function CheckCompleteTaskInCacheNode():void
		{
			if( TaskCacheNode && TaskCacheNode.task)
			{
				if(TaskCacheNode.task.length>0)
				{
					var isVacancy:Boolean = false;
					var j:int = TaskCacheNode.task.length-1;
					var maxid:Number = -1;
					
					for( j; j>=0; j-- )
					{
						var tmpblock:Block = TaskCacheNode.task[j] as Block;
						if( tmpblock.isChecked == true )
						{							
							if( -1 == maxid && false == isVacancy)
							{
								maxid = TaskCacheNode.task[j]["id"];
								LiveVodConfig.NEAREST_WANT_ID = TaskCacheNode.task[j]["id"];
							}
							TaskCacheNode.task.splice(j,1);
						}
						else
						{
							LiveVodConfig.NEAREST_WANT_ID = tmpblock.id;
							isVacancy = true;
//							P2PDebug.traceMsg(this,"NEAREST_WANT_ID:"+LiveVodConfig.NEAREST_WANT_ID);
						}
					}
				}
			}
		}
		
		public function getCDNTask( ifLoadAfterBuffer:Boolean ):Object
		{
			handlerGetTaskList();
			if( this._initData && this._initData.ifP2PFirst() )
			{
				//TTT
				P2PDebug.traceMsg(this,"getCDNTask this._initData && this._initData.ifP2PFirst() return ");
				return null;
			}
			//
			if( TaskCacheNode == null
				|| TaskCacheNode.task == null)
			{
				//TTT
				P2PDebug.traceMsg(this,"getCDNTask TaskCacheNode == null|| TaskCacheNode.task == null return ");
				return null;				
			}
			
			
			var temPiece:Piece;
			for( var i:int = 0 ; i<TaskCacheNode.task.length; i++ )
			{
				var temp:Number = this.manager.getBlockId( LiveVodConfig.ADD_DATA_TIME );
				
				
				if( -1 == temp )
				{
					//TTT
					P2PDebug.traceMsg(this,"getCDNTask temp:Number = this.manager.getBlockId -1 == temp return LiveVodConfig.ADD_DATA_TIME: " + LiveVodConfig.ADD_DATA_TIME );
					return null;
				}
				if( (TaskCacheNode.task[i] as Block).id >= temp )
				{
					var block:Block = TaskCacheNode.task[i] as Block;
					//TTT
					var tmpdebug:Number = LiveVodConfig.ADD_DATA_TIME;
					if( block && block.id - LiveVodConfig.ADD_DATA_TIME <= _CacheLen )
					{		
						if( false == block.isChecked /*&& block.downLoadStat != 1*/ )
						{
							/*block.downLoadStat = 1;*/
							for(var idx:int = 0;idx<block.pieceIdxArray.length;idx++)
							{
								temPiece = manager.getPiece(block.pieceIdxArray[idx]);
								if( temPiece && !temPiece.isChecked && temPiece.iLoadType!=1 )
								{
									//TTT
									P2PDebug.traceMsg(this,"getCDNTask false == block.isChecked && block.downLoadStat != 1 blockid:  " + block.id );
									return {"block":block,"isBuffer":true};
								}
							}	
						}
					}
				}
				else
				{
					P2PDebug.traceMsg( this,"(TaskCacheNode.task[i] as Block).id < temp: " + temp );
				}
			}
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE
				&& true == ifLoadAfterBuffer )
			{
				return {"block":getCDNRandomTask(),"isBuffer":false} ;
			}
			return null;
		}
		
		private function getCDNRandomTask():Block
		{
			return manager.getCDNRandomTask();
		}
		
		public function getP2PTask( getP2PTask:Object ):Object
		{
			handlerGetTaskList();
			//
			if( TaskCacheNode == null
				|| TaskCacheNode.task == null)
			{
				return null;				
			}
			
//			if( TaskCacheNode.task[0].id > LiveVodConfig.M3U8_MAXTIME 
//				|| (TaskCacheNode.task.length>0 && TaskCacheNode.task[TaskCacheNode.task.length-1].id < LiveVodConfig.ADD_DATA_TIME ) )
//			{
//				return null;
//			}
			
			//
			var piece:Piece;
			for( var i:int = 0; i<TaskCacheNode.task.length;i++ )
			{
				var block:Block = TaskCacheNode.task[i] as Block;
				if( block.groupID != getP2PTask.groupID )
				{
					continue;
				}
				
				if( block 
					&& ( block.id - LiveVodConfig.ADD_DATA_TIME <= _CacheLen && false == this._initData.ifP2PFirst() )
					&& (!block.isChecked) )
				{
					return null;
				}
				
				if( block && ( block.id - LiveVodConfig.ADD_DATA_TIME > _CacheLen || true == this._initData.ifP2PFirst() ) )
				{
					if( false == block.isChecked )
					{
						for( var j:int = 0; j < block.pieceIdxArray.length; j++ )
						{
							piece=block.getPiece(j);
							if( !piece.isChecked
								&& piece.iLoadType != 1
								&& piece.iLoadType != 3 
								&& ( piece.peerID == "" || (piece.peerID != getP2PTask.remoteID && getTime() - piece.begin > 30*1000) )
								)
							{
								var rangeArray:Array = getP2PTask.TNrange;
								if("PN" == piece.type)
								{
									rangeArray = getP2PTask.PNrange;
								}
								//search TN
								var p_data:*;
								for each( p_data in rangeArray )
								{
									if(	p_data.start<=Number(piece.pieceKey)
										&& Number(piece.pieceKey)<=p_data.end )
									{										
										piece.iLoadType = 2;
										piece.peerID    = getP2PTask.remoteID;
										piece.begin     = getTime();
										return piece;
									}
								}
							}//end for piece
						}
					}
				}
			}
			return null;
		}
		
		private function dealqueryurl(p_str:String):String
		{
			var strTmp:String = "";
			var ntmp:int = p_str.indexOf(".m3u8");
			strTmp = p_str.substr(0,ntmp+5);
			
			return strTmp;
		}

		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			if(_initData)
			{
				return getShiftPath(_initData.flvURL[_initData.g_nM3U8Idx]);
			}
			return "";
		}
		
		protected function getShiftPath(url:String):String
		{
			//TTT
			//url = "http://123.125.89.43/m3u8/letv_tv_800/desc.m3u8?tag=live&video_type=m3u8&stream_id=p2p_test&useloc=0&mslice=3&path=123.125.89.37,115.182.51.111&geo=CN-1-0-2&cips=10.58.100.173&tmn=1384840386&pnl=706,706,214&sign=live_tv";
			if(-1 != url.indexOf("?"))
			{
				url=url.replace("desc.xml","")+"&abtimeshift=";
			}
			else
			{
				url=url.replace("desc.xml","")+"?abtimeshift=";
			}
			return url;
		}
		
		public function getM3U8Task():Object
		{
			var tmpobj:Object 		 = new Object();
			var strTmpTask:String 	 = "";
			var tmpDelaytime:Number  = 5;
			
			if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
			{
				var tmpTimeshift:Number = 0;
				if( this._initData.g_bGslbComplete == true )
				{
					tmpTimeshift = LiveVodConfig.ADD_DATA_TIME;
					strTmpTask = _initData.flvURL[_initData.g_nM3U8Idx];
					
					strTmpTask = ParseUrl.replaceParam(strTmpTask,"mslice",String(3));
					this._initData.g_bGslbComplete = false;
				}
				else
				{
					tmpTimeshift = LiveVodConfig.M3U8_MAXTIME;
				}
				
				if( this._initData.g_seekPos != 0 )
				{
					tmpTimeshift = this._initData.g_seekPos;
					LiveVodConfig.M3U8_MAXTIME = this._initData.g_seekPos;
					P2PDebug.traceMsg(this,"===*****===_initData.g_seekPos: " + _initData.g_seekPos + "LiveVodConfig.M3U8_MAXTIME: " + LiveVodConfig.M3U8_MAXTIME );
					this._initData.g_seekPos = 0;
				}
				
				//TTT
				tmpTimeshift = Math.floor(tmpTimeshift);
				tmpTimeshift = Math.round(tmpTimeshift);
				
				
				P2PDebug.traceMsg(this,"===timeshift: " + tmpTimeshift);
				strTmpTask = abTimeShiftURL+ tmpTimeshift + "&rdm=" + getTime();
				
				strTmpTask = ParseUrl.replaceParam(strTmpTask,"mslice",String(5));
				P2PDebug.traceMsg( this,"LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME: " + (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) );
				P2PDebug.traceMsg(this,"LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME: " + (LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME) );
				
				//if((LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > (LiveVodConfig.MEMORY_TIME*60) )
				var tmpspan:Number = LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME;
				var tmpmemtime:Number = 10;
				/*
				trace("M3U8_MAXTIME = "+LiveVodConfig.M3U8_MAXTIME)
				trace("ADD_DATA_TIME = "+LiveVodConfig.ADD_DATA_TIME)
				trace("M3U8_MAXTIME - ADD_DATA_TIME = "+(LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME))
				trace("(LiveVodConfig.MEMORY_TIME-1)*60) = "+(LiveVodConfig.MEMORY_TIME-1)*60);
				trace("(LiveVodConfig.MEMORY_TIME-1)*60) = "+(LiveVodConfig.MEMORY_TIME-1)*60);
				trace("LIVE_TIME.GetLiveOffTime()"+LIVE_TIME.GetLiveOffTime());
				*/
				P2PDebug.traceMsg(this,"***************** tmpspan: " + tmpspan + " tmpmemtime: " + tmpmemtime );
				if( (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > 20 
					|| LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME < 20 )
				{
					//TTT
					P2PDebug.traceMsg(this,"(LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > (LiveVodConfig.MEMORY_TIME*60) set 3000");
					tmpDelaytime = 3000;
				}
				else
				{
					//TTT
					P2PDebug.traceMsg(this,"else set 500");
					tmpDelaytime = 500;
				}
				/*else if( LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME < 20 )
				{
					//TTT
					P2PDebug.traceMsg(this,"LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME < 20 set 3000");
					tmpDelaytime = 3000;
				}*/
				if( (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > ((LiveVodConfig.MEMORY_TIME-1)*60) )
				{
					tmpDelaytime = 3000;
					strTmpTask = "";
					P2PDebug.traceMsg(this,"(LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > 60 set 60000");
				}
			}
			else if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				tmpDelaytime = 3000;
				if( this._initData.g_bGslbComplete == true )
				{
					//TTT
					P2PDebug.traceMsg(this,"this._initData.g_bGslbComplete == true");
					strTmpTask = _initData.flvURL[_initData.g_nM3U8Idx];
					this._initData.g_bGslbComplete = false;
				}
				else
				{
					strTmpTask = _initData.flvURL[_initData.g_nM3U8Idx];
				}
			}

			tmpobj.url = strTmpTask;
			tmpobj.delaytime = tmpDelaytime;
			
			return tmpobj;
		}

		protected function handerGroupList( data:Object ):void
		{
			if( data && data is Array && (data as Array).length>0 )
			{
				p2pCluster.handlerP2PByList(data as Array);
			}
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			/*if( cdnLoad )
			{
				cdnLoad.clear();
				cdnLoad = null;
			}*/
			if( cdnLoadList )
			{
				for( var i:int=cdnLoadList.length-1 ; i>=0 ; i--)
				{
					(cdnLoadList[i] as CDNLoad).clear();
					cdnLoadList.splice(i);
				}
				cdnLoadList = null;
			}
			
			
			if( p2pCluster )
			{
				p2pCluster.clear();
				p2pCluster = null;
			}
			
			_CacheLen      = LiveVodConfig.DAT_BUFFER_TIME;
			TaskCacheNode = null;
			
			_initData	  = null;
		}
	}
}