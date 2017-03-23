/**
 * 负责建立p2p
 * 用来维护pipe列表相关属性：生命周期，可用性，和管道数（连接的用户数）
 * 同p2p服务器保持产品一致：服务器地址端口，通信协议及通信网络状态，错误机制
 * 
 * 在P2P_Loader中需要建立连接的服务器有三个，需要按顺序连接：
 * 1.selector : 将groupName发送给selector后，返回rtmfp和gather服务器的地址和端口
 * 2.rtmfp    : 访问该服务器，返回nearID
 * 3.gather   : 成功访问rtmfp才可以访问该服务器，有两种访问情况
 *              1.心跳访问：当成功连接的节点达到上限(_MaxConnectedPeers)，
 * 							或没有达到上限但有足够多的该节点可以连接时使用该访问方式
 *              2.为获得邻居节点而访问：当成功连接数量未达到上限，且所有可连接的节点
 * 							都已尝试过以后使用该方式
 * 
 */
package com.p2p.loaders
{
	import com.p2p.data.vo.Config;
	import com.p2p.data.vo.InitData;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.Debug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.errors.IOError;
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
		public var isDebug:Boolean=false;
		/**连接rtmfp服务器的通道*/
		private var _p2pConnection:NetConnection; 		
		/**播放器传递的参数*/
		private var _initData:InitData;
		/**声明调度器*/
		private var _dispather:IDataManager;
		/**保存网络运营商等信息*/
		private var _geo:String;
		/**为p2p用户划分组标识*/
		private var _groupName:String;
		/**连接selector的地址和端口*/
		private var _selectorName:String = "selector.webp2p.letv.com";;
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
		
		/**最大节点连接数*/
		private var _MaxConnectedPeers:int = 9;
		/**_pipeList中的节点数量*/
		private var _peerInPipeListNum:int = 0;
		/**_spareList中的节点数量*/
		private var _sparePipeNum:int=0;
		/**selector加载器*/
		private var _selector:Selector_Loader;
		
		private var _rtmfpName:String;
		private var _rtmfpPort:uint;
		private var _gatherName:String;
		private var _gatherPort:uint;
		
		private var _URLLoader:URLLoader;
		
		private var _canURLLoader:Boolean = true;
		
		public function P2P_Loader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
		}
		
		protected function streamPlayHandler(evt:EventExtensions):void{
			Debug.traceMsg(this,"p2p响应play事件");
			_initData=evt.data as InitData;
			try{
				_geo       = _initData.geo;
			}catch(err:Error){
				Debug.traceMsg(this,"geo错误");
			}
			try{
				_groupName = _initData.groupName;
			}catch(err:Error){
				Debug.traceMsg(this,"groupName错误");
			}
		}
		
		public function startLoadP2P():void
		{
			clear();			
			
			_pipeList    = new Object();
			_badPipeList = new Object();
			_sparePipeList = new Object();
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
				_selectorTimer = null
			}
			if (_peerHartBeatTimer)
			{
				_peerHartBeatTimer.removeEventListener(TimerEvent.TIMER, peerHartBeatTimer);
				_peerHartBeatTimer.stop();							    
				_peerHartBeatTimer = null
			}
			if (_rtmfpTimer)
			{
				_rtmfpTimer.removeEventListener(TimerEvent.TIMER, rtmfpTimer);
				_rtmfpTimer.stop();							    
				_rtmfpTimer = null
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
					Debug.traceMsg(this,err.message);
				}
				_p2pConnection = null;
			}
			if(_pipeList)
			{
				for each(var pipe:* in _pipeList)
				{
					pipe.clear();
				}
			}
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
					Debug.traceMsg(this,"rtmfp  = "+_rtmfpName+":"+_rtmfpPort);
					Debug.traceMsg(this,"gather = "+_gatherName+":"+_gatherPort);
					/**过程上报*/
					Statistic.getInstance().selectorSuccess();
					//
					_rtmfpTimer.reset();
					_rtmfpTimer.start();
					//
					_selectorTimer.stop();
					return;
				}else if (_selector.redirectSelector)
				{
					_selectorName = _selector.selectorIP;
					_selectorPort = _selector.selectorPort;
					//
					/*_selector.clear();
					_selector = new Selector_Loader();*/
					_selector.init(_groupName, _selectorName, _selectorPort);
					return;
				}
			}
			//
			_selector = new Selector_Loader();
			_selector.init(_groupName, _selectorName, _selectorPort);
			//			
		}
		
		public var playHead:Number;
		/**
		 * gatherRegisterTimer负责与gather上报心跳和查询节点功能
		 * */
		private function gatherRegisterTimer(event:* = null):void
		{
			/**
			 * 触发gather心跳条件
1：NetConnection是否连接成功
2：当前是否有连接gather动作正在执行
3：geo值是否正确*/
			_gatherRegisterTimer.delay = 5*1000;
			
			if (_p2pConnection 
				&& _p2pConnection.connected 
				&& _canURLLoader)
			{				
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
					/**需要对上传参数作检验！！！！！！！！*/
					if(array.length>=4)
					{
						var ispId:String = array[3];
						var arealevel1:String = array[0];
						var arealevel2:String = array[1];
						var arealevel3:String = array[2];
						if( _peerInPipeListNum+_sparePipeNum >= _MaxConnectedPeers )
						{
							/**执行心跳访问*/
							query = 0
						}
						var _url:String = "http://"+_gatherName+":"+_gatherPort+"/heartBeat?ver="+Config.VERSION+"&groupId=" + _groupName + "&query="+query+"&leader="+Config.ISLEAD+"&peerId=" + _p2pConnection.nearID +"&rtmfpId="+_rtmfpName+":"+_rtmfpPort+"&ispId=" + ispId + "&pos="+playHead+"&neighbors="+_peerInPipeListNum+ "&arealevel1="+arealevel1+"&arealevel2="+arealevel2+"&arealevel3="+arealevel3+"&random=" +  Math.floor(Math.random()*10000);
						
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
					var obj:Object = JSONDOC.decode(String(_URLLoader.data));				
				}catch(e:Error)
				{
					//loader_ERROR("dataError");				
					return;
				}					
				
				if( !Config.MY_NAME )
				{
					Config.MY_NAME = String(_p2pConnection.nearID);
				}
				//---------------------------
				
				try
				{
					/*if(obj["value"]["queryResult"]["isleader:"]=="true"){
						Config.IS_REAL_LEAD=1;
					}
					if(obj["value"]["queryResult"]["result"] == "success")
					{
						if(obj["value"]["queryResult"]["value"] is Array)
						{
							arr = obj["value"]["queryResult"]["value"];
							Debug.traceMsg(this,"jason = "+arr);
						}
						else
						{
							return;
						}						
					}
					else
					{
						return;
					}*/
					if(obj["result"] == "success")
					{						
						Config.IS_REAL_LEAD=obj["isLeader"];
						
						Statistic.getInstance().isLeader();
						
						if(obj["value"] is Array)
						{
							var arr:Array = obj["value"];
							Debug.traceMsg(this,"json = "+arr);
							
							for(var i:int = 0 ; i<arr.length ; i++)
							{
								var peerID:String = arr[i];					
																		
								if( peerID != ""
									&& peerID != _p2pConnection.nearID 
									&& !_pipeList[peerID]
									&& !_badPipeList[peerID]
									)
								{								
									if (_p2pConnection && _p2pConnection.connected && _peerInPipeListNum < _MaxConnectedPeers)
									{
										var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection, _dispather, _groupName);
										_pipeList[peerID] = newPipe;
										newPipe.initPipe(peerID);
										_peerInPipeListNum++;							
									}
									else
									{
										/**将arr中剩余的空闲节点保存*/
										if(!_sparePipeList[peerID])
										{
											_sparePipeList[peerID] = peerID;
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
				}
				catch(e:Error)
				{
					return;
				}	
			}
			else
			{
				/**
				 * 当_p2pConnection连接中断时需重新建立连接同事清空_pipeList列表
				 * */
				for (var pipeID:String in _pipeList)
				{
					if (_pipeList[pipeID])
					{
						_pipeList[pipeID].clear();
						delete _pipeList[pipeID];
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
				if((nowTime - _badPipeList[i]) >= Config.badPeerTime)
				{
					delete _badPipeList[i];
				}
				/*if( i.search("liveTime") == -1)
				{
					if(!_badPipeList.hasOwnProperty(i+"liveTime"))
					{
						delete _badPipeList[i];
					}
					else if( nowTime-_badPipeList[i+"liveTime"] >= 30*1000)
					{
						delete _badPipeList[i+"liveTime"];
					}					
				}*/
			}					
		}
		/**
		 * peerHartBeatTimer有三个作用：
		 * 1.对_pipeList中连接成功的节点进行心跳操作，
		 * 2.根据_pipeList和_sparePipeList的数据进行遍历获得以下数据：
		 *   successPeerNum     : _pipeList中的成功连接的节点数量；
		 *   _peerInPipeListNum : _pipeList中所有的节点的数量_pipeList.length；
		 *   _sparePipeNum      : _sparePipeList中所有的节点的数量_sparePipeList.length；
		 * 3.分别进行统计上报(dnode,lnode)和输出面板上报(peerStateObj) 
		 * 
		 * */
		private function peerHartBeatTimer(event:* = null):void
		{
			//var isJoinNetGroup:Boolean = false;
			/**已经建立好连接的节点数量*/
			var successPeerNum:int = 0;
			/**临时存放_pipeList.length*/
			var pipeListLength:int = 0;
			/**
			 * 将_pipeList列表中的节点状态保存在peerStateObj对象中,使输出面板能够显示节点的连接状态
			 * peerStateObj.peerName=true、false;
			 * */
			var peerStateObj:Object = new Object();
			/**
			 * 对_pipeList遍历，触发节点心跳并得到successPeerNum，peerInPipeListNum和peerStateObj
			 * */
			for(var pipeID:String in _pipeList)
			{
				pipeListLength++;
				peerStateObj[_pipeList[pipeID].remoteName] = false;
				if(_pipeList[pipeID].pipeConnected())
				{
					/**当节点成功连接时*/
					//isJoinNetGroup = true;
					/**执行节点心跳*/
					_pipeList[pipeID].peerHartBeatTimer();
					
					peerStateObj[_pipeList[pipeID].remoteName] = true;
					successPeerNum ++;
					
				}
				else if (_pipeList[pipeID].isDead())
				{
					/**
					 * 当节点连接失败时,在_badPipeList列表中创建key=pipeID的对象，并将本地时间存入该对象，
					 * 此时间用来对比存入_badPipeList的时长
					 * */					
					/*_badPipeList[pipeID] = pipeID;
					_badPipeList[pipeID+"liveTime"] = getTime();*/	
					_badPipeList[pipeID] =  getTime();
					
					delete peerStateObj[_pipeList[pipeID].remoteName];
					
					_pipeList[pipeID].clear();
					delete _pipeList[pipeID];
					pipeListLength--;					
					
					/**当节点从_pipeList中淘汰后，需要从_sparePipeList中取出一个节点尝试连接*/
					for(var sparePeer:String in _sparePipeList)
					{
						var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection, _dispather, _groupName);
						_pipeList[sparePeer] = newPipe;
						newPipe.initPipe(sparePeer);
						pipeListLength++;
						delete _sparePipeList[sparePeer];
						break;
					}
				}
			}
			
			_peerInPipeListNum = pipeListLength;
			
			/**对_sparePipeList遍历得到_sparePipeNum*/
			_sparePipeNum = 0;
			for(var j:String in _sparePipeList)
			{
				_sparePipeNum++;
			}			
			
			/**该属性输出面板使用，显示节点连接状态
			peerStateObj;*/
			/**成功连接的节点数量，该属性统计使用
			successPeerNum;*/
			/**所有可正常连接的节点数量，该属性统计使用
			_peerInPipeListNum+_sparePipeNum;*/
			Statistic.getInstance().getNeighbor(peerStateObj,successPeerNum,(_peerInPipeListNum+_sparePipeNum));
			
			Debug.traceMsg(this,"successPeerNum ================== "+successPeerNum);
		}
		
		/**
		 * 此方法通过遍历和对比_pipeList,_badPipeList和_sparePipeList列表对_sparePipeList进行筛选，
		 * 同时统计并返回Object：
		 * obj:Object = new Object();
		 * obj.successPeerNum :成功连接的节点数；
		 * obj.peerInPipeNum  :在_pipeList中的节点数量；
		 * obj.allPeerNum     :所有可使用的节点数量；
		 * 
		 * */
		
		public function removeHaveData(chunkStart:uint,chunkEnd:uint):void
		{
			for each(var pipe:* in _pipeList)
			{
				if( pipe.pipeConnected() )
				{
					pipe.removeHave(chunkStart,chunkEnd);
				}
			}
		}
		//	
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

					for each(var pipe:* in _pipeList)
					{
						pipe.clear();
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

					break;
				case "NetStream.Connect.Closed":
					if (_pipeList[e.info.stream.farID])
					{
						_pipeList[e.info.stream.farID].canSend = false;
						_pipeList[e.info.stream.farID].canRecieved = false;
						_pipeList[e.info.stream.farID].clear();
						delete _pipeList[e.info.stream.farID];

						_badPipeList[e.info.stream.farID] = e.info.stream.farID;
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
					_p2pConnection.close();
					_p2pConnection = null;
				}
				
				_p2pConnection = new NetConnection();
				_p2pConnection.addEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.addEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.maxPeerConnections = _MaxConnectedPeers;
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
						_sendNetStream.close();
						_sendNetStream = null;
					}
					
					if(_sendNetStream == null )
					{
						_sendNetStream = new NetStream(_p2pConnection,NetStream.DIRECT_CONNECTIONS);
						_sendNetStream.dataReliable = true;
						_sendNetStream.addEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
						var sendStreamClient:Object = new Object();
						sendStreamClient.onPeerConnect = function(callerns:NetStream):Boolean
						{
							if (_peerInPipeListNum >= _MaxConnectedPeers)
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
								var newPipe:P2P_Pipe = new P2P_Pipe( _p2pConnection, _dispather, _groupName);
								
								_pipeList[callerns.farID] = newPipe;
								/**此处this指代对象有问题！！！！
								newPipe.initPipe(this, callerns.farID);*/
								newPipe.initPipe(callerns.farID);
								newPipe.sendNetStream = callerns;
								newPipe.canSend = true;
								
							}
							return true;
						}
						_sendNetStream.client = sendStreamClient;
					}
					
					_sendNetStream.publish(_groupName);
					
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