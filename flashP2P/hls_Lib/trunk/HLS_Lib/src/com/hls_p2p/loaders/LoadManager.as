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
	import com.p2p.utils.console;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ParseUrl;
	
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class LoadManager
	{
		public var isDebug:Boolean = false;
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
				var cdnLoadNum:int = 1;
				if( LiveVodConfig.TYPE == LiveVodConfig.LIVE )
				{
					cdnLoadNum = 4;
				}
				
				cdnLoadList = new Array(cdnLoadNum);
				
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
			
			if( _initData.playlevel == 1 )
			{
				disagreeOthersCDNLoaderRun();
			}
			//cdnLoad.start(_initData);
			
			p2pCluster.initialize( _initData,manager );
		}
		private var isHaveTask:Boolean = false;
		protected function handlerGetTaskList():void
		{
			while (LiveVodConfig.TaskCacheArray.length > 0)
			{
				isHaveTask = true;
				if (LiveVodConfig.TaskCacheArray[0] < LiveVodConfig.BlockID)
				{
					LiveVodConfig.TaskCacheArray.shift();
				}else
				{
					break;
				}
			}
			if( isHaveTask && LiveVodConfig.TaskCacheArray.length == 0 )
			{
				LiveVodConfig.NEAREST_WANT_ID = manager.blockArray[manager.blockArray.length-1];
			}
			//
			handerGroupList(manager.getGroupIDList());
			
			if (LiveVodConfig.TaskCacheArray.length == 0) return;
			var blk:Block = manager.getBlock(LiveVodConfig.TaskCacheArray[0]);
			if (blk)
			{
				LiveVodConfig.NEAREST_WANT_ID = blk.id;
				
				if( LiveVodConfig.TYPE != LiveVodConfig.LIVE )
				{
					//非直播的紧急区策略
					if( _initData.playlevel == 1 && LiveVodConfig.TOTAL_DURATION>0 )
					{
						disagreeOthersCDNLoaderRun();
						var tempBufferSize:Number = Math.ceil( LiveVodConfig.DAT_BUFFER_TIME_LEVEL1 * LiveVodConfig.DATARATE/8 );
						
						if( tempBufferSize < LiveVodConfig.MEMORY_SIZE  )
						{
							_CacheLen = LiveVodConfig.DAT_BUFFER_TIME_LEVEL1;
						}
						else
						{
							_CacheLen = LiveVodConfig.MEMORY_TIME*60;
						}
					}
					/*else if( _initData.playlevel == 2 && LiveVodConfig.DURATION>0 )
					{
						_CacheLen = Math.ceil(LiveVodConfig.MEMORY_TIME*60*2/3);
					}
					else if( _initData.playlevel == 3 && LiveVodConfig.DURATION>0 )
					{
						_CacheLen = Math.ceil(LiveVodConfig.MEMORY_TIME*60*1/3);
					}*/
					else
					{
						//trace("LiveVodConfig.DAT_BUFFER_TIME = "+LiveVodConfig.DAT_BUFFER_TIME)
						agreeOthersCDNLoaderRun();
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
						/*else
						{
							_CacheLen = LiveVodConfig.DAT_BUFFER_TIME;
						}*/
					}
				}
				else
				{
					//直播的紧急区策略
					
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
			
		}
		
		private function agreeOthersCDNLoaderRun():void
		{
			for( var j:int=0 ; j<cdnLoadList.length ; j++)
			{				
				if( j > 0 )
				{
					(cdnLoadList[j] as CDNLoad).resume();
				}
			}
		}
		
		private function disagreeOthersCDNLoaderRun():void
		{
			for( var j:int=0 ; j<cdnLoadList.length ; j++)
			{				
				if( j > 0 )
				{
					(cdnLoadList[j] as CDNLoad).pause();
				}
			}
		}
		
		public function getCDNTask( ifLoadAfterBuffer:Boolean ):Object
		{
			handlerGetTaskList();
			if( this._initData && this._initData.ifP2PFirst() )
			{
				console.log(this,"P2PFirst");
				return null;
			}
			//
			if( LiveVodConfig.TaskCacheArray.length == 0)
			{
				console.log(this,"TaskCacheArray.length == 0");
				return null;				
			}
			
			
			var temPiece:Piece;
			for( var i:int = 0 ; i < LiveVodConfig.TaskCacheArray.length; i++ )
			{
				var temp:Number = LiveVodConfig.BlockID ;
				if( -1 == temp )
				{
					return null;
				}
				//
				var blk:Block = manager.getBlock(LiveVodConfig.TaskCacheArray[i]);
				if( blk && blk.id >= temp )
				{
					var tempCacheLen:Number = _CacheLen;
					/*if( tempCacheLen>5*60 )
					{
						tempCacheLen = 5*60;
					}*/
					if( blk.id - LiveVodConfig.BlockID <= tempCacheLen/*_CacheLen*/ )
					{		
						if( false == blk.isChecked )
						{
							for(var idx:int = 0;idx<blk.pieceIdxArray.length;idx++)
							{
								temPiece = manager.getPiece(blk.pieceIdxArray[idx]);
								if( temPiece && !temPiece.isChecked && temPiece.iLoadType!=1 )
								{
									if( temPiece.peerID != "" )
									{
										Statistic.getInstance().P2PTimeOut(temPiece.pieceKey,"H_"+temPiece.peerID);
									}
									console.log(this,"getCDNTask:" + blk.id );
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
			handlerGetTaskList();
			//
			if( LiveVodConfig.TaskCacheArray.length == 0
				|| (/*_initData.playlevel == 1 && */_CacheLen >= LiveVodConfig.MEMORY_SIZE ) )
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
				//在紧急区，有cdn任务，停掉p2p
//				if( blk 
//					&& ( blk.id - LiveVodConfig.ADD_DATA_TIME <= LiveVodConfig.DAT_BUFFER_TIME && false == this._initData.ifP2PFirst() )
//					&& (!blk.isChecked) )
//				{
//					console.log(this,"紧急区不p2p");
//					return null;
//				}
				
				if( blk 
					&& ( blk.id - LiveVodConfig.ADD_DATA_TIME > _CacheLen/*LiveVodConfig.DAT_BUFFER_TIME*/ 
							|| true == this._initData.ifP2PFirst()
							|| ( LiveVodConfig.CDN_DISABLE == 1/* && Statistic.getInstance().userAllowP2P != -1 */) ) )
				{
					//trace(blk.id+" - "+LiveVodConfig.ADD_DATA_TIME+" = "+(blk.id - LiveVodConfig.ADD_DATA_TIME)+" ? "+_CacheLen);
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
			return null;
		}
		
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			return _initData.flvURL[_initData.g_nM3U8Idx];
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
					console.log(this,"===*****===_initData.g_seekPos: " + _initData.g_seekPos + "LiveVodConfig.M3U8_MAXTIME: " + LiveVodConfig.M3U8_MAXTIME );
					this._initData.g_seekPos = 0;
				}
				
				//TTT
				tmpTimeshift = Math.floor(tmpTimeshift);
				tmpTimeshift = Math.round(tmpTimeshift);
				strTmpTask = ParseUrl.replaceParam(abTimeShiftURL,"abtimeshift",""+tmpTimeshift);
				strTmpTask = ParseUrl.replaceParam(strTmpTask,"rdm",""+ getTime());
				
				strTmpTask = ParseUrl.replaceParam(strTmpTask,"mslice",String(5));
				console.log( this,"LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME: " + (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME),"timeshift: " + tmpTimeshift );
				console.log(this,"LIVE_TIME.GetLiveTime - LiveVodConfig.M3U8_MAXTIME: " + (LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME) );
				
				//if((LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > (LiveVodConfig.MEMORY_TIME*60) )
				if( (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > 20 
					|| LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME < 20 )
				{
					//TTT
					console.log(this,"m3u8 set 3000ms");
					tmpDelaytime = 3000;
				}
				else
				{
					//TTT
					console.log(this,"m3u8 set 500ms");
					tmpDelaytime = 500;
				}
				/*else if( LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME < 20 )
				{
					//TTT
					console.log(this,"LIVE_TIME.GetLiveTime() - LiveVodConfig.M3U8_MAXTIME < 20 set 3000");
					tmpDelaytime = 3000;
				}*/
				if( (LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > ((LiveVodConfig.MEMORY_TIME-1)*60) )
				{
					tmpDelaytime = 3000;
					strTmpTask = "";
					console.log(this,"(LiveVodConfig.M3U8_MAXTIME - LiveVodConfig.ADD_DATA_TIME) > 60 set 60000");
				}
			}
			else if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
			{
				tmpDelaytime = 6000;
				if( this._initData.g_bGslbComplete == true )
				{
					//TTT
					console.log(this,"this._initData.g_bGslbComplete == true");
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
			isHaveTask     = false;
			_initData	   = null;
		}
	}
}