﻿package com.p2p.loaders
{

	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.data.Chunk;
	import com.p2p.data.Chunks;
	import com.p2p.events.DataManagerEvent;
	import com.p2p.events.P2PEvent;
	import com.p2p.events.SelectorEvent;
	import com.p2p.loaders.P2PPipe;
	import com.p2p.managers.DataManager;
	import com.p2p.utils.CRC32;
	import com.p2p.utils.json.JSONDOC;
	
	//import com.p2p.data.P2PCookie;

    import com.p2p.data.vo.VodConfig;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.*;
	import flash.sampler.Sample;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import flash.events.AsyncErrorEvent;
	//import com.p2p.lib.STUNConnecter;

	public class P2PLoader extends EventDispatcher
	{
		private var _p2pConnection:NetConnection; //连接rtmfp服务器的
		private var _dataManager:DataManager;
		private var _groupName:String;		
				
		///////////////////////////////////////////////
		private var _rtmfpName:String;
		private var _rtmfpPort:uint;
		private var _gatherName:String;
		private var _gatherPort:uint;
				
		////////////////////////////
		private var _selectorName:String;
		private var _selectorPort:uint;
		////////////////////////////////////////
		// 从pipemanager移植的属性
		private var _pipeList:Object;//管道列表
		private var _p2pWaitTaskList:Object;//p2p任务列表,存储需要local向remote发送的数据请求时,远程数据列表没有数据时等待远程响应的任务
				
		private var _peerHartBeatTimer:Timer;
		private var _gatherRegisterTimer:Timer;
		//private var _gatherQueryTimer:Timer;
		private var _rtmfpTimer:Timer;
		private var _selectorTimer:Timer;
		
		/**管道列表中，管道的数量*/
		private var _pipeNum:int = 0; 
		/**_spareList中的节点数量*/
		private var _sparePipeNum:int=0;
		/**成功建立连接的节点数量*/
		private var _pipeSuccessNum:int = 0;
		/**最大连接数量*/
		private var _MaxConnectedPeers:int = 9;
		
		/**
		 * _badPipeList保存连接失败的peerID，用来进行对比
		   其中包含liveTime属性用来保存_badPipeList的创建时间
		   用来比较_badPipeList的存在时间
		 */		
		private var _badPipeList:Object;
		
		/**
		 * 访问gether服务器后返回的节点信息都将存入_sparePipeList列表；
		 * 当需要从_sparePipeList中取节点建立连接时应对比_badPipeList列表和_pipeList列表，如果有相同的节点则放弃该节点而选择另外节点进行连接；
		 * 该列表中读取过的节点信息将会从列表中清除，以免重复建立相同的连接
		 * */
		private var _sparePipeList:Object;
		
		private var _geo:String;//保存网络运营商等信息；
		//
		private var _URLLoader:URLLoader;
		private var _pos:int;
		private var _canURLLoader:Boolean = true;
		//
		/**  STUN服务 lz0424add   */
		//private var _STUNConnecter:STUNConnecter;
		
		private var _isGetPeerList:Boolean=false;//是否开启临近peer所拥有的peerlist的功能
		
		private var _kindOfNat:int = -1;
		
		public function P2PLoader(dataManager:DataManager,geo:String,groupName:String = "www.letv.com/p2pTest21")
		{  
			_dataManager = dataManager;
			_geo         = geo;			
			_groupName   = groupName;	
			//_selectorName = "115.182.11.31";
//			_selectorName  = "gather.webp2p.letv.com";
			_selectorName  = "selector.webp2p.letv.com";
//			_selectorPort  = 8080;
		    //_selectorName  = "selector.p2p.letv.com";
			_selectorPort  = 80;
		}
		
		private var _selector:SelectorLoader;
		//
		public function startLoadP2P():void
		{
			//clear();
			//_groupName = groupName;	
			_pipeList        = new Object();
			_p2pWaitTaskList = new Object();
			_badPipeList     = new Object();
			_sparePipeList   = new Object();
			
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
					//trace(this+err.message);
				}
				_p2pConnection = null;
			}
			if(_selector)
			{
				_selector.clear();
				_selector=null;
			}
			if(_pipeList)
			{
				for each(var pipe:* in _pipeList)
				{
					pipe.clear();
				}
			}
			
			if(_dataManager.userName && _dataManager.userName["myName"])
			{
				delete _dataManager.userName["myName"];
			}
			
			if(_publisherTimer)
			{
				_publisherTimer.stop();				
				_publisherTimer.removeEventListener(TimerEvent.TIMER, publisherTimer);
				_publisherTimer = null;
			}
			
			if(_sendNetStream)
			{
				_sendNetStream.removeEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
				_sendNetStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
				_sendNetStream=null;
			}
			
			_dataManager = null;
			
			_pipeNum = 0; 
			_sparePipeNum = 0;
			_pipeSuccessNum = 0;	
			
			_isMaxConnectedPeers = false;
						
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
					//_gatherName = "123.126.32.18";
					//_gatherPort = 80;
					_rtmfpName  = _selector.rtmfpIp;
					_rtmfpPort  = _selector.rtmfpPort;
					_gatherName = _selector.proxyIp;
					_gatherPort = _selector.proxyPort;
					
					if(_selector.maxPeers>0)
					{
						_MaxConnectedPeers = _selector.maxPeers;
					}
					if(_selector.maxMem>0)
					{
						_dataManager.memoryLength = _selector.maxMem;
					}
					if(_selector.urgentSize>0)
					{
						_dataManager.httpBufferLength = _selector.urgentSize;
					}
					
					//_rtmfpName = "rtmfp://123.126.32.18/";//:1935/livepkg/";//"rtmfp://123.126.32.18/";//"rtmfp://10.10.80.131/";//"rtmfp://"+"115.182.94.46"+"/";//"rtmfp://123.126.32.18/";//
					
					var obj:Object = new Object();
					obj.code  = "P2P.selectorConnect.Success";
					obj.act   = "selector";
					obj.error = 0;
					dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));						
					//
					_rtmfpTimer.reset();
					_rtmfpTimer.start();
					//
					_selectorTimer.stop();
					//
					
					return;
				}else if (_selector.redirectSelector)
				{
					_selectorName = _selector.selectorIP;
					_selectorPort = _selector.selectorPort;
					//
					_selector = new SelectorLoader();
					_selector.init(_groupName, _selectorName, _selectorPort);
					return;
				}
			}
			//
			_selector = new SelectorLoader();
			_selector.init(_groupName, _selectorName, _selectorPort);
			//			
		}		
		
		private var _isMaxConnectedPeers:Boolean = false;
		
		private function gatherRegisterTimer(event:* = null):void
		{
			_gatherRegisterTimer.delay = 11*1000;
			
			if (_p2pConnection 
				&& _p2pConnection.connected 
				&& _canURLLoader)
			{			
				if( _pipeSuccessNum>=_MaxConnectedPeers )
				{
					/**当成功连接节点数达到最大时*/
					if(!_isMaxConnectedPeers)
					{
						/**
						 * 为保证成功连接节点数达到最大时还能上报一次心跳，在此处将_isMaxConnectedPeers设为true;
						 * 之后当成功连接节点数达到最大时均不上报心跳。
						 * */
						_isMaxConnectedPeers = true;
					}
					else
					{
						return;
					}					
				}
				else
				{
					_isMaxConnectedPeers = false;
				}
				
				_canURLLoader = false;
				
				if (_URLLoader == null)
				{					
					_URLLoader = new URLLoader();
					_URLLoader.addEventListener(Event.COMPLETE, loader_COMPLETE);
					_URLLoader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
					_URLLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);						
				}	
				
				var _pos:String = String(_dataManager.playHead);
				
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
						
						if( _pipeNum+_sparePipeNum >= _MaxConnectedPeers )
						{
							/**执行心跳访问*/
							query = 0
						}
						/**neighbors表示成功建立连接的节点数量*/
						var _url:String = "http://"+_gatherName+":"+_gatherPort
							+"/heartBeat?ver="+VodConfig.VERSION
							+"&groupId=" + _groupName 
							+"&query="+query
							+"&peerId=" + _p2pConnection.nearID 
							+"&rtmfpId="+_rtmfpName+":"+_rtmfpPort
							+"&ispId=" + ispId 
							+"&pos="+_pos
							+"&neighbors="+_pipeSuccessNum
							+"&arealevel1="+arealevel1
							+"&arealevel2="+arealevel2
							+"&arealevel3="+arealevel3
							+"&random=" +  Math.floor(Math.random()*10000);
						
						_URLLoader.load(new URLRequest(_url));
						
						var obj:Object = new Object();
						obj.code       = "P2P.gatherConnect.Start";
						obj.act        = "gather";
						obj.error      = 0
						obj.gatherName = _gatherName;
						obj.gatherPort = _gatherPort;
						dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
					}
				}
			}
		}	
		
		protected function loader_COMPLETE(evt:Event=null,array:Array=null):void
		{		
			_canURLLoader = true;
			
			if (_p2pConnection && _p2pConnection.connected)
			{
				var arr:Array=new Array();
				if(evt!=null)
				{
					clearBadPipeList();
					
					try
					{	
						if(String(_URLLoader.data).length == 0)
						{
							return;
						}
						var obj:Object = JSONDOC.decode(String(_URLLoader.data));
						
					}catch(e:Error)
					{
						loader_ERROR(null);
						return;
					}
						
					// 存放cdn node id				
					//_ispId = obj.ispId;
					//var lnode:int = 0;//当前提供的可用peer总数
					/**
					 * freePeerNum表示当前提供的可连接peer总数,包括_pipeList列表的长度_pipeNum和剩余可连接的peer数量
					 * */
					//var freePeerNum:int = 0;
					//
					if( !_dataManager.userName["myName"])
					{
						_dataManager.userName["myName"] = _p2pConnection.nearID;
					}
					//---------------------------
					
					try
					{						
						if(obj["result"] == "success")
						{
							if(obj["value"] is Array)
							{
								arr = obj["value"];
								for(var i:int = 0 ; i<arr.length ; i++)
								{										
									var peerID:String = arr[i];
									
									if(peerID == "")
									{
										continue;
									}										
									if( peerID != _p2pConnection.nearID 
										&& !_pipeList[peerID])
									{
										//freePeerNum++;
										if(!_badPipeList[peerID])
										{										
											if (_p2pConnection && _p2pConnection.connected && _pipeNum < _MaxConnectedPeers)
											{
												var newPipe:P2PPipe = new P2PPipe( _p2pConnection, _dataManager, _p2pWaitTaskList, _groupName);
												_pipeList[peerID] = newPipe;
												newPipe.initPipe(_p2pConnection.nearID, peerID);
												_pipeNum++;
												//freePeerNum--;
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
					arr=array;
					return;
				}				
				
				//------------------------------
				var obj1:Object = new Object();
				obj1.code  = "P2P.gatherConnect.Success";
				obj1.act   = "gather";
				obj1.error = 0
				obj1.gatherName = _gatherName;
				obj1.gatherPort = _gatherPort;
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj1));
				
				/**对_sparePipeList遍历得到_sparePipeNum*/
				_sparePipeNum = 0;
				for(var j:String in _sparePipeList)
				{
					_sparePipeNum++;
				}
				
				var object:Object = new Object();
				object.code   = "P2P.Neighbor.Connect";
				object.peerID = _dataManager.userName;	
				object.lnode  = _sparePipeNum + _pipeNum;
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,object));				
			}
			else
			{
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
		public function getPeerList():Array{
			var arr:Array=new Array;
			for (var pipeID:String in _pipeList)
			{
				if(pipeID == ""||pipeID==_dataManager.userName["myName"] )
				{
					continue;
				}else{
					arr.push(pipeID);
				}
			}
			return arr
		}
		public function setPeerList(array:Object):void{
			var arr:Array=new Array();
			for(var p:* in array){
				arr.push(array[p]);
			}
			if(arr.length>=1){
				loader_COMPLETE(null,arr);
			}
		}
		protected function loader_ERROR(evt:*=null):void
		{			
			_canURLLoader = true;
			//
			var obj:Object = new Object();
			obj.code  = "P2P.gatherConnect.Failed";
			obj.act   = "gather";
			obj.error = 0
			obj.gatherName = _gatherName;
			obj.gatherPort = _gatherPort;
			this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
			clearP2PLoad();
		}
		private function clearP2PLoad():void{
			if(_URLLoader&&_URLLoader.hasEventListener(Event.COMPLETE)){
				_URLLoader.removeEventListener(Event.COMPLETE, loader_COMPLETE);
				_URLLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
				_URLLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
				try
				{
					_URLLoader.close();
				}
				catch(e:Error)
				{
					//trace(this+e.message);
				}
				_URLLoader=null;
			}
		}
		private function clearBadPipeList():void
		{			
			var nowTime:Number = Math.floor((new Date()).time);
			
			for(var i:String in _badPipeList)
			{
				if( i.search("liveTime") == -1)
				{
					if(!_badPipeList.hasOwnProperty(i+"liveTime"))
					{
						delete _badPipeList[i];
					}
					else if(nowTime-_badPipeList[i+"liveTime"]>=30*1000)
					{
						delete _badPipeList[i+"liveTime"];
					}					
				}
			}					
		}
		
		private function peerHartBeatTimer(event:* = null):void
		{
			_dataManager.isJoinNetGroup = false;
			
			/**已经建立好的pipe数量*/
			var dnode:int = 0;
			var pipeID:String;
			
			for(pipeID in _pipeList)
			{
				if( _pipeList[pipeID] && _pipeList[pipeID].canSend/*_pipeList[pipeID].pipeConnected()*/)
				{
					_dataManager.isJoinNetGroup = true;
					_pipeList[pipeID].peerHartBeatTimer();
					//lz add 0821
					_dataManager.userName[pipeID+"state"] = "ok";
					dnode ++;
					//
				}
				else if (_pipeList[pipeID])
				{
					if (_pipeList[pipeID].isDead())
					{						
						_pipeList[pipeID].clear();
						delete _pipeList[pipeID];
						
						//lz add 0821
						
						_badPipeList[pipeID] = pipeID;
						_badPipeList[pipeID+"liveTime"] = Math.floor((new Date()).time);						
						
						/**当节点从_pipeList中淘汰后，需要从_sparePipeList中取出一个节点尝试连接*/
						for(var sparePeer:String in _sparePipeList)
						{
							var newPipe:P2PPipe = new P2PPipe( _p2pConnection, _dataManager, _p2pWaitTaskList, _groupName);
							_pipeList[sparePeer] = newPipe;
							newPipe.initPipe(_p2pConnection.nearID,sparePeer);
							
							delete _sparePipeList[sparePeer];
							break;
						}
					}
				}
			}
			
			_pipeNum = getPipeListLength();
			
			if(_isGetPeerList&&_pipeNum<_MaxConnectedPeers){
				//向 临近节点要临近节点所拥有的节点
				for(pipeID in _pipeList)
				{
					if( _pipeList[pipeID] && _pipeList[pipeID].pipeConnected())
					{
						_pipeList[pipeID].startPeerHaveList(this);
					}
				}
			}
						
			/**对_sparePipeList遍历得到_sparePipeNum*/
			_sparePipeNum = 0;
			for(var j:String in _sparePipeList)
			{
				_sparePipeNum++;
			}
			
			var obj:Object = new Object();
			obj.code   = "P2P.Neighbor.Connect";
			obj.peerID = _dataManager.userName;
			obj.dnode  = dnode;    //获得成功连接的邻居数量
			obj.peerHartBeat = true;
			_pipeSuccessNum  = dnode;
			this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
		}
		
		private function getPipeListLength():int
		{
			var length:int=0;
			for(var pipeID:String in _pipeList)
			{
				length++;
			}
			return length;
		}
		
		public function addWantData(chunkStart:uint,chunkEnd:uint):void
		{
			for( var chunkID:uint = chunkStart; chunkID <= chunkEnd; chunkID++ )
			{
				if(_p2pWaitTaskList[chunkID] == null)
				{
					var task:Object = new Object();
					task.status    = "wait";
					task.beginTime = Math.floor((new Date()).time);
					_p2pWaitTaskList[chunkID] = task;
				}
			}
			//trace("________s "+chunkStart+" e "+chunkEnd);
		}
		public function removeWantData(chunkStart:uint, chunkEnd:uint):void
		{
			for( var chunkID:uint =chunkStart; chunkID<=chunkEnd; chunkID++ )
			{
				if ( _p2pWaitTaskList && _p2pWaitTaskList[chunkID])
				{
					delete _p2pWaitTaskList[chunkID];
				}
			}
		
		}
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
					
					var obj0:Object = new Object();
					obj0.code = "P2P.rtmfpConnect.Success";
					obj0.ID   = _p2pConnection.nearID;
					obj0.rtmfpName=_rtmfpName;
					obj0.rtmfpPort=_rtmfpPort;
					obj0.act  = "rtmfp";
					obj0.error = 0;	
					
					dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj0));
					
					if (_publisherTimer == null)
					{
						_publisherTimer = new Timer(0);
						_publisherTimer.addEventListener(TimerEvent.TIMER, publisherTimer );
						_publisherTimer.start();
					}
					//
					for each(var pipe:* in _pipeList)
					{
						pipe.clear();
					}
					//
//					_gatherService();
					_gatherRegisterTimer.start();
					//
					delete _dataManager.userName["myName"];
					//
					
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
					//
					_publishedOK = false;
					//
					onError();
					
					_gatherRegisterTimer.stop();
					
					_selector = null;
					_selectorTimer.start();
					
					break;
				case "NetStream.Connect.Success":
					if (_pipeList[e.info.stream.farID])
					{
						_pipeList[e.info.stream.farID]._canRecieved = true;
						//trace("Connect.Success   "+e.info.stream.farID);
					}
					
					
					break;
				case "NetStream.Connect.Closed":
					if (_pipeList[e.info.stream.farID])
					{
						_pipeList[e.info.stream.farID]._canSend = false;
						_pipeList[e.info.stream.farID]._canRecieved = false;
						_pipeList[e.info.stream.farID].clear();
						delete _pipeList[e.info.stream.farID];
						//
						_badPipeList[e.info.stream.farID] = e.info.stream.farID;
						//_badPipeList[e.info.stream.farID] = Math.floor((new Date()).time);	
					}
					//
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
		//
		private function rtmfpTimer(e:TimerEvent = null):void
		{
			if(_p2pConnection == null || _p2pConnection.connected == false)
			{
				//_rtmfpTimer.delay = 5*1000;
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
				//
				_p2pConnection = new NetConnection();
				_p2pConnection.addEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.addEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.maxPeerConnections = _MaxConnectedPeers;
				//MZDebugger.trace(this,"rfp://"+_rtmfpName+":" + _rtmfpPort +"/)");
				_p2pConnection.connect( "rtmfp://"+_rtmfpName+":" + _rtmfpPort +"/");
				//
				var obj1:Object = new Object();
				obj1.code = "P2P.rtmfpConnect.Start";
				obj1.rtmfpName=String(_rtmfpName+":"+_rtmfpPort);//+":"+_rtmfpPort);
				dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj1));
			}
		}
		private function onError(event:IOErrorEvent = null):void
		{
			var obj:Object = new Object();
			obj.code = "P2P.rtmfpConnect.Failed";
			obj.rtmfpName=String(_rtmfpName+":"+_rtmfpPort+" new");
			dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));					
			//
			if(_p2pConnection)
			{
				_p2pConnection.removeEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.removeEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.close();
				_p2pConnection = null;
			}
		}
		//
		private function asyncErrorHandler(evt:AsyncErrorEvent):void{}
		protected var _publisherTimer:Timer;
		protected var _sendNetStream:NetStream = null;
		protected var _publishedOK:Boolean         = false;
		//
		private function publisherTimer(event:TimerEvent):void
		{
			_publisherTimer.delay = 6*1000;
			//
			if (_p2pConnection && _p2pConnection.connected)
			{
				if (_publishedOK == false)
				{
					if (_sendNetStream)
					{
						_sendNetStream.removeEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
						_sendNetStream.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
						_sendNetStream.close();
						_sendNetStream = null;
					}
					//
					if(_sendNetStream == null )
					{
						_sendNetStream = new NetStream(_p2pConnection,NetStream.DIRECT_CONNECTIONS);
						_sendNetStream["dataReliable"] = true;
						_sendNetStream.addEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
						_sendNetStream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
						var sendStreamClient:Object = new Object();
						sendStreamClient.onPeerConnect = function(callerns:NetStream):Boolean
						{
							if (_pipeNum >= _MaxConnectedPeers)
								return true;
							//
							if (_pipeList[callerns.farID])
							{
								_pipeList[callerns.farID]._sendNetStream = callerns;
								_pipeList[callerns.farID]._canSend = true;
							}else
							{
								var newPipe:P2PPipe = new P2PPipe( _p2pConnection, _dataManager, _p2pWaitTaskList, _groupName);
								//设置gather	
								_pipeList[callerns.farID] = newPipe;
								_pipeNum += 1;
								newPipe.initPipe(_p2pConnection.nearID, callerns.farID);
								newPipe._sendNetStream = callerns;
								newPipe._canSend = true;
							}
							//
							return true;
						}
						//
						_sendNetStream.client = sendStreamClient;
					}
					//
					_sendNetStream.publish(_groupName/*_p2pConnection.nearID*/);
					//
					return;
				}
			}
			//
		}
		//
		
	}
}