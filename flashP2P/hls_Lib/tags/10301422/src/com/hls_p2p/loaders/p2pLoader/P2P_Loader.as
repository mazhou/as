/**
 * 负责建立p2p
 * 用来维护pipe列表相关属性：生命周期，可用性，和管道数（连接的用户数）
 * 同p2p服务器保持产品一致：服务器地址端口，通信协议及通信网络状态，错误机制
 * 
 * 在P2P_Loader中需要建立连接的服务器有三个，需要按顺序连接：
 * 1.selector : 将groupName发送给selector后，返回rtmfp和gather服务器的地址和端口
 * 2.rtmfp    : 访问该服务器，返回nearID
 * 3.gather   : 成功访问rtmfp才可以访问该服务器，有两种访问情况
 *              1.心跳访问：当成功连接的节点达到上限(LiveVodConfig.MAX_PEERS)，
 * 							或没有达到上限但有足够多的该节点可以连接时使用该访问方式
 *              2.为获得邻居节点而访问：当成功连接数量未达到上限，且所有可连接的节点
 * 							都已尝试过以后使用该方式
 * 
 */
package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.errors.IOError;
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Timer;

	public class P2P_Loader
	{
		public var isDebug:Boolean=true;
		/**连接rtmfp服务器的通道*/
		private var _p2pConnection:NetConnection; 		
		/**播放器传递的参数*/
		private var _initData:InitData;
		/**声明调度器*/
		private var _dispather:IDataManager;
		/**保存网络运营商等信息*/
		private var _geo:String;
		/**为p2p用户划分组标识*/
		private var groupID:String;
		/**连接selector的地址和端口*/
		private var _selectorName:String = "selector.webp2p.letv.com";
		private var _selectorPort:uint   = 80;
		/**p2p调度服务器时间驱动*/
		private var _selectorTimer:Timer;
		/**rtmfp协议服务器时间驱动*/
		private var _rtmfpTimer:Timer;
		/**p2p用户邻节点时间驱动*/
		private var _gatherRegisterTimer:Timer;
		/**心跳时间驱动*/
		private var _peerHartBeatTimer:Timer;		
		/**管道列表*/
		private var _pipeList:Object;
		/**
		 * <p>badPipeList保存连接失败的peerID相关信息</p>
		 * <p>每个peerID相关信息结构体为badPipeList[peerID]={"peerID":peerID,"liveTime":liveTime}</p>
		 * <p>其作用是记录有些邻节点一段时间由于某种原因不工作，当记录的liveTime时间超过给定的时间，恢复正常</p>
		 */
		private var _badPipeList:Object;
		
		/**
		 * 访问gether服务器后返回的节点信息都将存入_sparePipeList列表；
		 * 当需要从_sparePipeList中取节点建立连接时应对比_badPipeList列表和_pipeList列表，如果有相同的节点则放弃该节点而选择另外节点进行连接；
		 * 该列表中读取过的节点信息将会从列表中清除，以免重复建立相同的连接
		 * */
		private var _sparePipeList:Object;
		
		/**_pipeList中的节点数量*/
		private var _peerInPipeListNum:int = 0;
		/**_spareList中的节点数量*/
		private var _sparePipeNum:int=0;
		/**成功建立连接的节点数量*/
		private var _pipeSuccessNum:int = 0;
		/**selector加载器*/
		private var _selector:Selector_Loader;
		
		private var _rtmfpName:String;
		private var _rtmfpPort:uint;
		private var _gatherName:String;
		private var _gatherPort:uint;
		
		private var _URLLoader:URLLoader;
		
		private var _canURLLoader:Boolean = true;			
		
		/**
		 * 如果成功连接的数量达到时，判断是否已进行了达到最大值后的最后一次上报
		 * */
		private var _isFirstRequestAfterMaxPeer:Boolean = false;
		
		protected var p2pCluster:P2P_Cluster;
		
		public function P2P_Loader(_dispather:IDataManager,p2pCluster:P2P_Cluster)
		{
			this._dispather 	= _dispather;
			this.p2pCluster 	= p2pCluster;
		}

		public function ifPeerConnection():Boolean
		{
			if(_pipeList)
			{
				for(var remoteID:String in _pipeList)
				{
					if(_pipeList[remoteID].pipeConnected())
					{
						return true;
					}
				}
			}
			return false;
		}
		//		
		public function doAddHave():void
		{
			if(_pipeList)
			{
				for each(var sigtranStrategy:SigtranStrategy in _pipeList)
				{
					sigtranStrategy.doAddHave();
				}
			}
		}
		
		public function handlerPiece(piece:Piece):void
		{
			var i:uint = 0;
			for(i=0;i<piece.peerHaveData.length;i++)
			{
				if(_pipeList.hasOwnProperty(piece.peerHaveData[i]))
				{
					//如果没有发送数据
					if((_pipeList[piece.peerHaveData[i]] as SigtranStrategy).requestArr.length<=0)
					{
						(_pipeList[piece.peerHaveData[i]] as SigtranStrategy).sendRequest([{
							"type":piece.type,
							"pieceKey":piece.pieceKey
						}]);
					}	
				}
			}
		}
		
		public function startLoadP2P(_initData:InitData,groupID:String):void
		{
			try
			{
				_geo       = _initData.geo;
			}catch(err:Error)
			{
				P2PDebug.traceMsg(this,"geo错误");
			}
			
			this.groupID   = groupID;
			_pipeList    = new Object();
			_badPipeList = new Object();
			_sparePipeList = new Object();
			
			Statistic.getInstance().getGroupID(this.groupID);
			
			/**
			 * 将原_p2pWaitTaskList列表（P2P请求数据列表）去除，
			 * 对_p2pWaitTaskList所需的功能都通过调用_dispather.getWantPiece()来实现
			 * _p2pWaitTaskList = new Object();
			 * */			
			_selectorTimer = new Timer(0);
			_selectorTimer.addEventListener(TimerEvent.TIMER, selectorInit );
			_selectorTimer.start();
			
			_peerHartBeatTimer = new Timer(3*1000);
			_peerHartBeatTimer.addEventListener(TimerEvent.TIMER, peerHartBeatTimer );
			_peerHartBeatTimer.start();
			
			_rtmfpTimer = new Timer(100,1);
			_rtmfpTimer.addEventListener(TimerEvent.TIMER, rtmfpTimer );		
			
			_gatherRegisterTimer  = new Timer(300); // 注册周期 5秒
			_gatherRegisterTimer.addEventListener(TimerEvent.TIMER, gatherRegisterTimer );
		}
		
		
		public function clear():void
		{
			if (_selectorTimer)
			{
				_selectorTimer.removeEventListener(TimerEvent.TIMER, selectorInit);
				_selectorTimer.stop();							    
				_selectorTimer = null;
			}
			
			if (_peerHartBeatTimer)
			{
				_peerHartBeatTimer.removeEventListener(TimerEvent.TIMER, peerHartBeatTimer);
				_peerHartBeatTimer.stop();							    
				_peerHartBeatTimer = null;
			}
			
			if (_rtmfpTimer)
			{
				_rtmfpTimer.removeEventListener(TimerEvent.TIMER, rtmfpTimer);
				_rtmfpTimer.stop();							    
				_rtmfpTimer = null;
			}
			
			if (_gatherRegisterTimer)
			{
				_gatherRegisterTimer.removeEventListener(TimerEvent.TIMER, gatherRegisterTimer);
				_gatherRegisterTimer.stop();							    
				_gatherRegisterTimer = null
			}			
			if (_p2pConnection)
			{
				_p2pConnection.removeEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.removeEventListener(IOErrorEvent.IO_ERROR,onError);
				try{
					_p2pConnection.close();
				}catch(err:Error){
					P2PDebug.traceMsg(this,err.message);
				}
				_p2pConnection = null;
			}
			if(_URLLoader)
			{
				_URLLoader.removeEventListener(Event.COMPLETE, loader_COMPLETE);
				_URLLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
				_URLLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
			}
			_URLLoader=null;
			
			if(_pipeList)
			{
				for each(var sigtranStrategy:SigtranStrategy in  _pipeList)
				{
					try
					{
						sigtranStrategy.clear();
					}catch(err:Error)
					{
						P2PDebug.traceMsg(this,err);
					}
				}
			}
			
			if(_selector)
			{
				_selector.clear();
				_selector=null;
			}
			
			if(_publisherTimer)
			{
				_publisherTimer.removeEventListener(TimerEvent.TIMER, publisherTimer );
				_publisherTimer = null;
			}
			
			if(_sendNetStream)
			{
				_sendNetStream.removeEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
				_sendNetStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
				_sendNetStream=null;
			}
			_badPipeList=null;
			_sparePipeList=null;
			_initData=null;
			_dispather=null;
			
			_peerInPipeListNum = 0;
			_sparePipeNum =0;
			_pipeSuccessNum = 0;
			
			_isFirstRequestAfterMaxPeer = false;
		}
		
		private function selectorInit(event:* = null):void
		{			
			_selectorTimer.delay = 100;
			if (_selector)
			{
				if (_selector.isConnecting == true)
				{
					return;
				}
				if(_selector.error)
				{
					_selectorTimer.delay = 8*1000;
					_selector = null;
					
					return;
				}
				//
				if (_selector.isOK)
				{					
					_rtmfpPort = _selector.rtmfpPort;
					_rtmfpName = _selector.rtmfpIp;
					_gatherName = _selector.proxyIp;
					_gatherPort = _selector.proxyPort;
					P2PDebug.traceMsg(this,"rtmfp  = "+_rtmfpName+":"+_rtmfpPort);
					P2PDebug.traceMsg(this,"gather = "+_gatherName+":"+_gatherPort);
					/**过程上报*/
					Statistic.getInstance().selectorSuccess();
					
					_rtmfpTimer.reset();
					_rtmfpTimer.start();
					
					_selectorTimer.stop();
										
					return;
				}else if (_selector.redirectSelector)
				{
					_selectorName = _selector.selectorIP;
					_selectorPort = _selector.selectorPort;
					//
					_selector.init(groupID, _selectorName, _selectorPort);
					return;
				}
			}
			//
			_selector = new Selector_Loader();
			_selector.init(groupID, _selectorName, _selectorPort);
			//			
		}		
		
		/**
		 * gatherRegisterTimer负责与gather上报心跳和查询节点功能
		 * */
		private function gatherRegisterTimer(event:* = null):void
		{
			/**
			 * 触发gather心跳条件
				1：NetConnection是否连接成功
				2：当前是否有连接gather动作正在执行
				3：geo值是否正确
				4：_pipeSuccessNum>=LiveVodConfig.MAX_PEERS且_isMaxConnectedPeers是否为false
			 * */
			_gatherRegisterTimer.delay = 5*1000;
			
			if (_p2pConnection 
				&& _p2pConnection.connected 
				&& _canURLLoader)
			{	
				if(_pipeSuccessNum >= LiveVodConfig.MAX_PEERS  //当成功连接节点数达到最大时
					&& !_isFirstRequestAfterMaxPeer)   //并且没有进行最后一次上报
				{
					/**
					 * 为保证成功连接节点数达到最大时还能上报一次心跳，在此处将_isRequestAfterMaxConnect设为true，并继续
					 * 执行上报操作;之后当成功连接节点数达到最大时均不上报心跳。
					 * */
					_isFirstRequestAfterMaxPeer = true;					
				}
				else if(_pipeSuccessNum >= LiveVodConfig.MAX_PEERS //当成功连接节点数达到最大时
					     && _isFirstRequestAfterMaxPeer)    //并且已经进行最后一次上报
				{
					return;
				}
				else if(_pipeSuccessNum < LiveVodConfig.MAX_PEERS) //当成功连接节点数没有达到最大时
				{
					_isFirstRequestAfterMaxPeer = false;	
				}
				
				_canURLLoader = false;
				
				if (_URLLoader == null)
				{					
					_URLLoader = new URLLoader();
					_URLLoader.addEventListener(Event.COMPLETE, loader_COMPLETE);
					_URLLoader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
					_URLLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);						
				}
				
				/**取值为 0 或 1，分别代表心跳和查询，心跳时不返回节点，默认为 1*/
				var query:int = 1;
			
				if(_geo)
				{				
					var array:Array = _geo.split(".");
					
					if(array.length>=4)
					{
						var ispId:String = array[3];
						var arealevel1:String = array[0];
						var arealevel2:String = array[1];
						var arealevel3:String = array[2];
						if( _peerInPipeListNum+_sparePipeNum >= LiveVodConfig.MAX_PEERS )
						{
							/**当本地拥有的邻居节点资源大于连接最大值时*/
							query = 0;
						}
						var _url:String = "http://"+_gatherName+":"+_gatherPort
							+"/heartBeat?ver="+LiveVodConfig.GET_VERSION()
							+"&groupId=" + groupID 
							+"&query="+query
							+"&peerId=" + _p2pConnection.nearID 
							+"&rtmfpId="+_rtmfpName+":"+_rtmfpPort
							+"&ispId=" + ispId 
							+"&pos="+(LiveVodConfig.ADD_DATA_TIME>=0?LiveVodConfig.ADD_DATA_TIME:0)
							+"&neighbors="+_pipeSuccessNum
							+"&arealevel1="+arealevel1
							+"&arealevel2="+arealevel2
							+"&arealevel3="+arealevel3
							+"&random=" +  Math.floor(Math.random()*10000);
						
						_URLLoader.load(new URLRequest(_url));
						
						Statistic.getInstance().gatherStart(_gatherName,_gatherPort);						
					}									
				}
			}
		}
		
		protected function loader_COMPLETE(evt:Event):void
		{		
			_canURLLoader = true;			
			
			/**公布gather服务器连接成功*/
			Statistic.getInstance().gatherSuccess(_gatherName,_gatherPort);
			
			if (_p2pConnection && _p2pConnection.connected)
			{				
				clearBadPipeList();
				
				try
				{	
					if(String(_URLLoader.data).length == 0)
					{
						/**此条件为本地节点只上报心跳（query=0）时，服务器不做任何处理返回空数据时发生*/
						return;
					}
					var obj:Object = JSONDOC.decode(String(_URLLoader.data));				
				}
				catch(e:Error)
				{
					loader_ERROR("dataError");
					return;
				}					
				
				if( !LiveVodConfig.MY_NAME )
				{
					LiveVodConfig.MY_NAME = String(_p2pConnection.nearID);
				}
				//---------------------------
				var remoteID:String = "";
				try
				{					
					if(obj["result"] == "success")
					{						
						if(obj["value"] is Array)
						{
							var arr:Array = obj["value"];
							var newPipe:P2P_Pipe
							for(var i:int = 0 ; i<arr.length ; i++)
							{				
								if(arr[i])
								{
									remoteID = arr[i];
																			
									if( remoteID != ""
										&& remoteID != _p2pConnection.nearID 
										&& !_pipeList[remoteID]
										&& !_badPipeList[remoteID]
										)
									{								
										if (_p2pConnection && _p2pConnection.connected && _peerInPipeListNum < LiveVodConfig.MAX_PEERS)
										{
//											var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection, _dispather, groupID);
//											_pipeList[peerID] = newPipe;
//											newPipe.initPipe(peerID);
											newPipe = new P2P_Pipe( _p2pConnection,groupID);
											_pipeList[remoteID] = new SigtranStrategy(
												newPipe,
												p2pCluster,
												_dispather
											)
											newPipe.initPipe(remoteID);
											_peerInPipeListNum++;
										}
										else
										{
											/**将arr中剩余的空闲节点保存*/
											if(!_sparePipeList[remoteID])
											{
												_sparePipeList[remoteID] = remoteID;
											}							
										}
									}				
								}
							}	
						}
						else
						{
							return;
						}
					}
					else
					{
						return;
					}
				}
				catch(e:Error)
				{
					return;
				}	
			}
			else
			{
				/**
				 * 当_p2pConnection连接中断时需重新建立连接同时清空_pipeList列表
				 * */
				for (remoteID in _pipeList)
				{
					if (_pipeList[remoteID])
					{
						_pipeList[remoteID].clear();
						delete _pipeList[remoteID];
					}						
				}
			}			
		}
		protected function loader_ERROR(evt:*=null):void
		{
			_canURLLoader = true;
			
			Statistic.getInstance().gatherFailed(_gatherName,_gatherPort);
		}
		
		private function clearBadPipeList():void
		{			
			var nowTime:Number = getTime();
			
			for (var i:String in _badPipeList)
			{
				if((nowTime - _badPipeList[i]) >= LiveVodConfig.badPeerTime)
				{
					delete _badPipeList[i];
				}
			}					
		}
		/**
		 * peerHartBeatTimer有三个作用：
		 * 1.对_pipeList中连接成功的节点进行心跳操作，
		 * 2.根据_pipeList和_sparePipeList的数据进行遍历获得以下数据：
		 *   _pipeSuccessNum     : _pipeList中的成功连接的节点数量；
		 *   _peerInPipeListNum : _pipeList中所有的节点的数量_pipeList.length；
		 *   _sparePipeNum      : _sparePipeList中所有的节点的数量_sparePipeList.length；
		 * 3.分别进行统计上报(dnode,lnode)和输出面板上报(peerStateObj) 
		 * 
		 * */
		private function peerHartBeatTimer(event:* = null):void
		{
			var pipeSuccessNum:int = 0;
			/**
			 * 将_pipeList列表中的节点状态保存在peerStateObj对象中,使输出面板能够显示节点的连接状态
			 * peerStateObj.peerName=true、false;
			 * */
			var peerStateObj:Object = new Object();
			/**
			 * 对_pipeList遍历，触发节点心跳并得到_pipeSuccessNum，peerInPipeListNum和peerStateObj
			 * */
			var NearestWantID:Number = 0;
			if (this._dispather)
			{
				NearestWantID = _dispather.getNearestWantID();
			}
			for(var remoteID:String in _pipeList)
			{
				var peerInfoObj:Object = new Object();
				//~~~~~~~~~~~~~~~
				//peerStateObj[_pipeList[pipeID].remoteName] = false;
				//~~~~~~~~~~~~~~~
				peerInfoObj.name  = _pipeList[remoteID].remoteID;//_pipeList[pipeID].remoteName;
				peerInfoObj.farID = _pipeList[remoteID].remoteID;
				peerInfoObj.state = "notConnect";
				
				peerStateObj[remoteID] = peerInfoObj;
				//~~~~~~~~~~~~~~~
				if(_pipeList[remoteID].canRecieved)
				{
					/**当节点成功连接时*/
					//isJoinNetGroup = true;
					/**执行节点心跳*/
					_pipeList[remoteID].peerHartBeatTimer(NearestWantID/*, LiveVodConfig.START_RUN_TIME*/);
					
					if (_pipeList[remoteID].isDead())
					{
						delete peerStateObj[_pipeList[remoteID].remoteID];
						pipeDeadHandler(remoteID,peerStateObj);					
						continue;
					}
					
					pipeSuccessNum ++;
					if(_pipeList[remoteID].canRecieved && _pipeList[remoteID].canSend )
					{
						peerInfoObj.state = "connect";
					}
					else
					{
						peerInfoObj.state = "halfConnect";
					}
				}
				if (_pipeList[remoteID].isDead())
				{
					pipeDeadHandler(remoteID,peerStateObj);
				}
				
			}
			
			_peerInPipeListNum = getPipeListLength();
			
			/**对_sparePipeList遍历得到_sparePipeNum*/
			_sparePipeNum = 0;
			for(var j:String in _sparePipeList)
			{
				_sparePipeNum++;
			}			
			
			/**该属性输出面板使用，显示节点连接状态
			peerStateObj;*/
			/**成功连接的节点数量，该属性统计使用
			_pipeSuccessNum;*/
			/**所有可正常连接的节点数量，该属性统计使用
			_peerInPipeListNum+_sparePipeNum;*/
			_pipeSuccessNum = pipeSuccessNum;
			Statistic.getInstance().getNeighbor(peerStateObj,_pipeSuccessNum,(_peerInPipeListNum+_sparePipeNum));
			
//			P2PDebug.traceMsg(this,"_pipeSuccessNum ================== "+_pipeSuccessNum);
		}
		
		private function pipeDeadHandler(remoteID:String,peerStateObj:Object):void
		{return;
			/**
			 * 当节点连接失败时,在_badPipeList列表中创建key=pipeID的对象，并将本地时间存入该对象，
			 * 此时间用来对比存入_badPipeList的时长
			 * */					
			_badPipeList[remoteID] = getTime();
			
			_pipeList[remoteID].clear();
			
			--_peerInPipeListNum;
			delete _pipeList[remoteID];					
			
			/**当节点从_pipeList中淘汰后，需要从_sparePipeList中取出一个节点尝试连接*/
			for(var sparePeer:String in _sparePipeList)
			{
				if( _peerInPipeListNum < LiveVodConfig.MAX_PEERS )
				{
//					var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection, _dispather, groupID);
//					_pipeList[sparePeer] = newPipe;
//					newPipe.initPipe(sparePeer);
					_pipeList[sparePeer] = new SigtranStrategy(
						(new P2P_Pipe(_p2pConnection,groupID)),
						p2pCluster,
						_dispather
					)
					_pipeList[sparePeer].initPipe(sparePeer);
					_peerInPipeListNum++;
					delete _sparePipeList[sparePeer];
					break;
				}
			}
		}
		
		private function getPipeListLength():int
		{
			var length:int=0;
			for(var remoteID:String in _pipeList)
			{
				length++;
			}
			return length;
		}
		
		public function removeHaveData(peiceKeyArray:Array):void
		{
			/**
			 * tempEliminateArray数据结构：
			 * tempEliminateArray[i] = {"minuteIdx":minute,"blockIdx":-1,"pieceIdx":-1};
			 * */
			for each(var sigtranStrategy:SigtranStrategy in _pipeList)
			{
				if( sigtranStrategy.pipeConnected() )
				{
					sigtranStrategy.removeHave(peiceKeyArray);
				}
			}
		}
		
		private function p2pStatusHandler(e:NetStatusEvent):void
		{
			switch (e.info.code)
			{
				case "NetConnection.Connect.Success" :					
					/**过程上报,输出面板上报*/
					Statistic.getInstance().rtmfpSuccess(_rtmfpName,_rtmfpPort,_p2pConnection.nearID);
					
					if (_publisherTimer == null)
					{
						_publisherTimer = new Timer(0);
						_publisherTimer.addEventListener(TimerEvent.TIMER, publisherTimer );
						_publisherTimer.start();
					}

					for each(var sigtranStrategy:SigtranStrategy in _pipeList)
					{
						sigtranStrategy.clear();
					}

					_gatherRegisterTimer.start();

					break;
				case "NetConnection.Connect.Closed" :
				case "NetConnection.Connect.Failed" :
				case "NetConnection.Connect.Rejected" :
				case "NetConnection.Connect.AppShutdown" :
				case "NetConnection.Connect.InvalidApp" :
				case "NetConnection.Call.Prohibited" :
				case "NetConnection.Call.BadVersion" : 
				case "NetConnection.Call.Failed":
				case "NetConnection.Call.Prohibited":
				case "NetConnection.Connect.IdleTimeout":  
				//case "NetConnection.Connect.NetworkChange" :
					_publishedOK = false;
					
					onError();
					
					_gatherRegisterTimer.stop();
					
					_selector = null;
					_selectorTimer.start();
					
					break;
				case "NetStream.Connect.Success":
					if (_pipeList[e.info.stream.farID])
					{
						_pipeList[e.info.stream.farID].canRecieved = true;
					}
					else
					{
						if (_p2pConnection 
							&& _p2pConnection.connected 
							&& _peerInPipeListNum < LiveVodConfig.MAX_PEERS
							&& !_pipeList[e.info.stream.farID])
						{
							//											var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection, _dispather, groupID);
							//											_pipeList[peerID] = newPipe;
							//											newPipe.initPipe(peerID);
							var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection,groupID);
							_pipeList[e.info.stream.farID] = new SigtranStrategy(
								newPipe,
								p2pCluster,
								_dispather
							)
							newPipe.initPipe(e.info.stream.farID);
							_peerInPipeListNum++;
						}
					}

					break;
				case "NetStream.Connect.Closed":
					if (_pipeList[e.info.stream.farID])
					{
						//_pipeList[e.info.stream.farID].isConnect = false;
						_pipeList[e.info.stream.farID].canSend = false;
						_pipeList[e.info.stream.farID].canRecieved = false;
						_pipeList[e.info.stream.farID].clear();
						delete _pipeList[e.info.stream.farID];

						_badPipeList[e.info.stream.farID] = getTime();
					}

					break;
				case "NetStream.Publish.Start":
				case "NetStream.Publish.Idle":
					_publishedOK = true;
					break;
				case "NetStream.Publish.BadName":
					_publishedOK = false;
					break;
				default : 
					break;
			}
		}
		
		private function rtmfpTimer(e:TimerEvent = null):void
		{
			if(_p2pConnection == null || _p2pConnection.connected == false)
			{
				_publishedOK = false;
				if(_p2pConnection)
				{
					_p2pConnection.removeEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
					_p2pConnection.removeEventListener(IOErrorEvent.IO_ERROR,onError);
					try{
						_p2pConnection.close();
					}catch(err:Error){
						//trace(this+err.message);
					}
					_p2pConnection = null;
				}
				
				_p2pConnection = new NetConnection();
				_p2pConnection.addEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.addEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.maxPeerConnections = LiveVodConfig.MAX_PEERS;
				_p2pConnection.connect("rtmfp://"+_rtmfpName+":" + _rtmfpPort +"/");
				/**过程上报*/
				Statistic.getInstance().rtmfpStart(_rtmfpName,_rtmfpPort);
			}			
		}
		private function onError(event:IOErrorEvent = null):void
		{
			/**输出面板上报
			var obj:Object = new Object();
			obj.code = "P2P.rtmfpConnect.Failed";
			obj.rtmfpName=String(_rtmfpName+":"+_rtmfpPort+" new");
			dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));					
			*/
			Statistic.getInstance().rtmfpFailed(_rtmfpName,_rtmfpPort);
			
			if(_p2pConnection)
			{
				_p2pConnection.removeEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.removeEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.close();
				_p2pConnection = null;
			}
		}
		private function asyncErrorHandler(evt:AsyncErrorEvent):void{}
		protected var _publisherTimer:Timer;
		protected var _sendNetStream:NetStream = null;
		protected var _publishedOK:Boolean     = false;
		
		private function publisherTimer(event:TimerEvent):void
		{
			_publisherTimer.delay = 6*1000;
			
			if (_p2pConnection && _p2pConnection.connected)
			{
				if (_publishedOK == false)
				{
					if (_sendNetStream)
					{
						_sendNetStream.removeEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
						_sendNetStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
						try
						{
							_sendNetStream.close();
						}catch(err:Error){}
						_sendNetStream = null;
					}
					
					if(_sendNetStream == null )
					{
						_sendNetStream = new NetStream(_p2pConnection,NetStream.DIRECT_CONNECTIONS);
						_sendNetStream["dataReliable"] = true;
						_sendNetStream.addEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
						_sendNetStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);

						var sendStreamClient:Object = new Object();
						sendStreamClient.onPeerConnect = function(callerns:NetStream):Boolean
						{
							if (_peerInPipeListNum >= LiveVodConfig.MAX_PEERS)
							{
								/**此时_peerInPipeListNum已经达到最大连接数*/
								return false;
							}
							
							if (_pipeList[callerns.farID])
							{
								_pipeList[callerns.farID].sendNetStream = callerns;
								_pipeList[callerns.farID].canSend = true;
							}else
							{
								if( _peerInPipeListNum < LiveVodConfig.MAX_PEERS )
								{
									var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection,  groupID);
//									_pipeList[callerns.farID] = newPipe;
//									/**此处this指代对象有问题！！！！
//									newPipe.initPipe(this, callerns.farID);*/
//									newPipe.initPipe(callerns.farID);
									_pipeList[callerns.farID] = new SigtranStrategy(
										newPipe,
										p2pCluster,
										_dispather
									)
									newPipe.sendNetStream = callerns;
									newPipe.initPipe(callerns.farID);
									_pipeList[callerns.farID].canSend = true;
									_peerInPipeListNum++;
								}
							}
							return true;
						}
						_sendNetStream.client = sendStreamClient;
					}
					
					_sendNetStream.publish(groupID);
					
					return;
				}
			}
			//_publisherTimer.stop();
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
	}
}