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
	
	import com.hls_p2p.statistics.Statistic;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class LoadManager
	{
		public var isDebug:Boolean = true;
		protected var manager:DataManager;
		//protected var cdnLoad:CDNLoad;
		protected var cdnLoadList:Array = null;
		protected var p2pCluster:P2P_Cluster;
		private   var _CacheLen:Number 		    = LiveVodConfig.DAT_BUFFER_TIME;
		protected var _initData:InitData;
		
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
			
			LiveVodConfig.TaskCacheArray = null;
			LiveVodConfig.TaskCacheArray = new Array;
			
			for (var i:int = 0; i < this.manager.blockArray.length; i++)
			{
				if (manager.blockArray[i] >= LiveVodConfig.ADD_DATA_TIME - 16
					&& manager.getBlock(manager.blockArray[i]).isChecked == false)
				{
					LiveVodConfig.TaskCacheArray.push(manager.blockArray[i]);
				}
			}
						
			for( var j:int=0 ; j<cdnLoadList.length ; j++)
			{
				(cdnLoadList[j] as CDNLoad).start(_initData);
			}
			//cdnLoad.start(_initData);
			
			p2pCluster.initialize( _initData,manager );
		}
		
		protected function handlerGetTaskList():void
		{
			while (LiveVodConfig.TaskCacheArray.length > 0)
			{
				if (LiveVodConfig.TaskCacheArray[0] < LiveVodConfig.BlockID)
				{
					LiveVodConfig.TaskCacheArray.shift();
				}else
				{
					break;
				}
			}
			//
			handerGroupList(manager.getGroupIDList());
			
			if (LiveVodConfig.TaskCacheArray.length == 0) return;
			//TTT
			//var tttArr:Array = LiveVodConfig.TaskCacheArray;
			var blk:Block = manager.getBlock(LiveVodConfig.TaskCacheArray[0]);
			if (blk)
			{
				LiveVodConfig.NEAREST_WANT_ID = blk.id;
				if( _CacheLen == LiveVodConfig.DAT_BUFFER_TIME )
				{
					if( blk.id - LiveVodConfig.ADD_DATA_TIME > LiveVodConfig.DAT_BUFFER_TIME )
					{
						_CacheLen = LiveVodConfig.DAT_BUFFER_TIME / 2;
					}
				}
				else if( blk.id - LiveVodConfig.ADD_DATA_TIME < LiveVodConfig.DAT_BUFFER_TIME / 2 )
				{
					_CacheLen = LiveVodConfig.DAT_BUFFER_TIME;
				}
			}
			
		}
		
		
		public function getCDNTask( ifLoadAfterBuffer:Boolean ):Object
		{
			//trace("getCDNTask");
			handlerGetTaskList();
			if( this._initData && this._initData.ifP2PFirst() )
			{
				//TTT
				P2PDebug.traceMsg(this,"getCDNTask this._initData && this._initData.ifP2PFirst() return ");
				return null;
			}
			//
			if( LiveVodConfig.TaskCacheArray.length == 0)
			{
				//TTT
				P2PDebug.traceMsg(this,"getCDNTask TaskCacheNode == null|| TaskCacheNode.task == null return ");
				return null;				
			}
			
			
			var temPiece:Piece;
			for( var i:int = 0 ; i < LiveVodConfig.TaskCacheArray.length; i++ )
			{
				//trace("for = "+i);
				var temp:Number = LiveVodConfig.BlockID ;
				if( -1 == temp )
				{
					//TTT
					P2PDebug.traceMsg(this,"getCDNTask temp:Number = this.manager.getBlockId -1 == temp return LiveVodConfig.ADD_DATA_TIME: " + LiveVodConfig.ADD_DATA_TIME );
					return null;
				}
				//
				var blk:Block = manager.getBlock(LiveVodConfig.TaskCacheArray[i]);
				if( blk && blk.id >= temp )
				{
					if( blk.id - LiveVodConfig.BlockID <= _CacheLen )
					{		
						if( false == blk.isChecked )
						{
							for(var idx:int = 0;idx<blk.pieceIdxArray.length;idx++)
							{
								temPiece = manager.getPiece(blk.pieceIdxArray[idx]);
								if( temPiece && !temPiece.isChecked && temPiece.iLoadType!=1 )
								{
									//TTT
									if( temPiece.peerID != "" )
									{
										Statistic.getInstance().P2PTimeOut(temPiece.pieceKey,"H_"+temPiece.peerID);
									}
									//trace("length = "+LiveVodConfig.TaskCacheArray.length+" ,i = "+i+" ,idx = "+idx);
									P2PDebug.traceMsg(this,"getCDNTask false == block.isChecked && block.downLoadStat != 1 blockid:  " + blk.id );
									return {"block":blk,"isBuffer":true};
								}
							}	
						}
					}
					else
					{
						break;
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
		
		private function BinsearchPiece( p_piece:Piece, p_rangeArray:Array, p_P2PTask:Object ):Object//二分查找，返回有序表中大于等于x的元素位置
		{
			if( !p_rangeArray || !p_P2PTask )
			{
				return null;
			}
			
			var iLow:int = 0;
			var iHigh:int = p_rangeArray.length -1;
			var imid:int = 0;
			var p_data:*;
			while( iLow <= iHigh )
			{
				imid= ( iLow + iHigh )/2;
				p_data = p_rangeArray[imid];
				
				if(	Number(p_piece.pieceKey) >= p_data.start
					&& Number(p_piece.pieceKey)<=p_data.end )
				{
					p_piece.iLoadType = 2;
					p_piece.peerID    = p_P2PTask.remoteID;
					p_piece.begin     = getTime();
					return p_piece;
				}
				else
				{
					if( Number(p_piece.pieceKey) > p_data.end )
					{
						// 右侧查找
						iLow = imid + 1;
					}
					else if( Number(p_piece.pieceKey) < p_data.start )
					{
						iHigh = imid -1;
					}
				}
			}
			return null;//返回大于x的第一个元素
		}
		
		public function getP2PTask( getP2PTask:Object ):Object
		{
			var tmpbegintime_getp2ptask:Number = getTime();
			
			handlerGetTaskList();
			//
			if( LiveVodConfig.TaskCacheArray.length == 0)
			{
				return null;				
			}
			
			var piece:Piece;
			var pieceRet:Object = null;
			for( var i:int = 0; i< LiveVodConfig.TaskCacheArray.length;i++ )
			{
				if( LiveVodConfig.TYPE == LiveVodConfig.VOD && (LiveVodConfig.TaskCacheArray[i] - LiveVodConfig.ADD_DATA_TIME >= (LiveVodConfig.MEMORY_TIME-1)*60) )
				{
					return null;
				}
				
				var blk:Block = this.manager.getBlock( LiveVodConfig.TaskCacheArray[i]);
				if( blk && blk.groupID != getP2PTask.groupID )
				{
					continue;
				}
				
				if( blk 
					&& ( blk.id - LiveVodConfig.ADD_DATA_TIME <= LiveVodConfig.DAT_BUFFER_TIME && false == this._initData.ifP2PFirst() )
					&& (!blk.isChecked) )
				{
					var tmpendtime_getp2ptask1:Number = getTime();
					var tmpspan_getp2ptask1:Number = tmpendtime_getp2ptask1 - tmpbegintime_getp2ptask;
					P2PDebug.traceMsg( this," func_timespan_getTask1: " + tmpspan_getp2ptask1 );
					
					return null;
				}
				
				if( blk && ( blk.id - LiveVodConfig.ADD_DATA_TIME > LiveVodConfig.DAT_BUFFER_TIME || true == this._initData.ifP2PFirst() ) )
				{
					if( false == blk.isChecked )
					{
						for( var j:int = 0; j < blk.pieceIdxArray.length; j++ )
						{
							piece=blk.getPiece(j);
							if( !piece.isChecked
								&& piece.iLoadType != 1
								&& piece.iLoadType != 3 
								&& ( piece.peerID == "" 
								   || (piece.peerID != getP2PTask.remoteID
									&& getTime() - piece.begin > 30*1000) )
							)
							{
								
								if( (piece.peerID != "" && piece.peerID != getP2PTask.remoteID
									&& getTime() - piece.begin > 30*1000) )
								{
									Statistic.getInstance().P2PTimeOut(piece.pieceKey,piece.peerID);
									piece.peerID = "";
									piece.begin	 = 0;
									piece.from	 = "";
									piece.iLoadType = 0;
								}
								
								var rangeArray:Array = getP2PTask.TNrange;
								if("PN" == piece.type)
								{
									rangeArray = getP2PTask.PNrange;
								}
								//search 
								var p_data:*;
								pieceRet = BinsearchPiece( piece, rangeArray, getP2PTask );
								if( pieceRet != null )
								{
									
									var tmpendtime_getp2ptask:Number = getTime();
									var tmpspan_getp2ptask:Number = tmpendtime_getp2ptask - tmpbegintime_getp2ptask;
									P2PDebug.traceMsg( this," func_timespan_getP2PTask: " + tmpspan_getp2ptask );
									
									/*for(var t:int=0 ; t<getP2PTask.TNrange.length ; t++)
									{
										trace("TNrange["+t+"] = "+getP2PTask.TNrange[t].start+"+"+getP2PTask.TNrange[t].end);
									}
									for(var p:int=0 ; p<getP2PTask.PNrange.length ; p++)
									{
										trace("PNrange["+p+"] = "+getP2PTask.PNrange[p].start+"+"+getP2PTask.PNrange[p].end);
									}
									trace("pieceRet = "+pieceRet.pieceKey);
									*/
									return pieceRet;
								}
							}//end for piece
						}
					}
				}
			}
			
			var tmpendtime_getp2ptask2:Number = getTime();
			var tmpspan_getp2ptask2:Number = tmpendtime_getp2ptask2 - tmpbegintime_getp2ptask;
			P2PDebug.traceMsg( this," func_timespan_getTask2: " + tmpspan_getp2ptask2 );
			
			return null;
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
		
			_initData	  = null;
		}
	}
}