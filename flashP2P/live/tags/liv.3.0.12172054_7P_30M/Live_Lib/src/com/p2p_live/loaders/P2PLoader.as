package com.p2p_live.loaders
{
	
	import com.mzStudio.event.EventExtensions;
	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p_live.data.Chunk;
	import com.p2p_live.data.Chunks;
	import com.p2p_live.events.DataManagerEvent;
	import com.p2p_live.events.P2PEvent;
	import com.p2p_live.events.SelectorEvent;
	import com.p2p_live.loaders.P2PPipe;
	
	import com.p2p_live.managers.DataManager;
	import com.p2p_live.protocol.Protocol;
	import com.p2p.utils.CRC32;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.*;
	import flash.sampler.Sample;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;

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
		private var _rtmfpTimer:Timer;
		private var _selectorTimer:Timer;
		
		private var _MaxConnectedPeers:int = 7;
		private var countConnectedPeer:int=1;
		/**
		 * _badPipeList保存连接失败的peerID，用来进行对比
		 其中包含liveTime属性用来保存_badPipeList的创建时间
		 用来比较_badPipeList的存在时间
		 */		
		private var _badPipeList:Object;		
		
		private var _geo:String;//保存网络运营商等信息；
		//
		private var _URLLoader:URLLoader;
		private var _pos:int;
		private var _canURLLoader:Boolean = true;
		//
		
		public function P2PLoader(dataManager:DataManager,geo:String)
		{  
			_dataManager = dataManager;
			_geo = geo;
			//_selectorName = "123.126.32.18";//"115.182.94.26";//
			//_selectorName  = "115.182.94.26";
			//_selectorName  = "gather.webp2p.letv.com";
			_selectorName  = "selector.webp2p.letv.com";
			_selectorPort  = 80;
			//_selectorPort  = 80;
			MZDebugger.getInstance().addEventListener("DATA",dataHandler);
		}
		private function dataHandler(evt:EventExtensions):void{
			if(_dataManager&&evt.data["key"]=="peerid"){
				_dataManager.userName["myName"]=evt.data["value"];
			}
		}
		private var _selector:SelectorLoader;
		//
		public function startLoadP2P(groupName:String = "www.letv.com/p2pTest21"):void
		{
			clear();
			
			_groupName = groupName;	
			_pipeList        = new Object();
			_p2pWaitTaskList = new Object();
			_badPipeList     = new Object();
			
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
			_gatherRegisterTimer.start();					
			
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
			//
			if (_p2pConnection)
			{
				_p2pConnection.removeEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.removeEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.close();
				_p2pConnection = null;
			}			
			//
			if(_pipeList)
			{
				for each(var pipe:* in _pipeList)
				{
					pipe.clear();
				}
			}			
			//
			if( _dataManager.userName && _dataManager.userName["myName"])
			{
				delete _dataManager.userName["myName"];
			}
			//
			MZDebugger.customTrace(this,Protocol.MYPEERID,"null");
		}	
		/*public function isLeader():Boolean
		{
			if(!_pipeList)
			{
				return true;
			}
			for(var index:String in _pipeList)
			{
				if(_pipeList[index] && _pipeList[index].remotePlayHead > _dataManager.httpDownloadingTask)
				{
					return false;
				}
			}
			//trace(this+"leader=",index)
			return true;
		}*/
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
					//trace(this+"_selector_selector_selector = "+_selector);
					return;
				}
				//
				if (_selector.isOK)
				{
										
					_rtmfpPort = _selector.rtmfpPort;
					_rtmfpName = _selector.rtmfpIp;
					_gatherName = _selector.proxyIp;
					_gatherPort = _selector.proxyPort;
					MZDebugger.customTrace(this,Protocol.RTMFP,_rtmfpName+":"+_rtmfpPort);
					MZDebugger.customTrace(this,Protocol.PROXY,_gatherName+":"+_gatherPort);
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
		//
		private function gatherRegisterTimer(event:* = null):void
		{
			_gatherRegisterTimer.delay = 5*1000;

			if (_p2pConnection 
				&& _p2pConnection.connected 
				&& _canURLLoader
				&& _pipeNum < _MaxConnectedPeers)
			{
				
				_canURLLoader = false;
				
				if (_URLLoader == null)
				{					
					_URLLoader = new URLLoader();
					_URLLoader.addEventListener(Event.COMPLETE, loader_COMPLETE);
					_URLLoader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
					_URLLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);						
				}	
				
				var _pos:String = String(_dataManager.playHead);
				
				if(_geo){
					var array:Array = _geo.split(".");
					if(array.length>=4){
						var ispId:String = array[3];
						var arealevel1:String = array[0];
						var arealevel2:String = array[1];
						var arealevel3:String = array[2];
						
						//var _url:String = "http://"+_gatherName+":"+_gatherPort+"/get?groupId=" + _groupName + "&peerId=" + _p2pConnection.nearID +"&rtmfpAddr="+_rtmfpName+":"+_rtmfpPort+"&ispId=" + ispId + "&pos="+_pos+"&neighbors="+_pipeNum+ "&arealevel1="+arealevel1+"&arealevel2="+arealevel2+"&arealevel3="+arealevel3+"&random=" +  Math.floor(Math.random()*10000);
						//var _url:String = "http://"+_selectorName+"/heartBeat?groupId=" + _groupName + "&peerId=" + _p2pConnection.nearID +"&rtmfpId="+_rtmfpName+":"+_rtmfpPort+"&ispId=" + ispId + "&pos="+_pos+"&neighbors="+_pipeNum+ "&arealevel1="+arealevel1+"&arealevel2="+arealevel2+"&arealevel3="+arealevel3+"&random=" +  Math.floor(Math.random()*10000);
						var _url:String = "http://"+_gatherName+":"+_gatherPort+"/heartBeat?groupId=" + _groupName + "&peerId=" + _p2pConnection.nearID +"&rtmfpId="+_rtmfpName+":"+_rtmfpPort+"&ispId=" + ispId + "&pos="+_pos+"&neighbors="+_pipeNum+ "&arealevel1="+arealevel1+"&arealevel2="+arealevel2+"&arealevel3="+arealevel3+"&random=" +  Math.floor(Math.random()*10000);
						MZDebugger.trace(this,{"key":"OTHER","value":"_url:"+_url});
						_URLLoader.load(new URLRequest(_url));
						//trace(this+_url);
						var obj:Object = new Object();
						obj.code       = "P2P.gatherConnect.Start";
						obj.act        = "gather";
						obj.error      = 0;
						obj.gatherName = _gatherName;
						obj.gatherPort = _gatherPort;
						dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
					}
				}
			}
		}		
		protected function loader_COMPLETE(evt:Event):void
		{		
			_canURLLoader = true;			
			
			if (_p2pConnection && _p2pConnection.connected)
			{			
				
				clearBadPipeList();
				
				try
				{	
					var obj:Object = JSONDOC.decode(String(_URLLoader.data));				
					MZDebugger.trace(this,{"key":"OTHER","value":"_URLLoader.data:"+_URLLoader.data});
				}catch(e:Error)
				{
					loader_ERROR("dataError");				
					return;
				}					
				// 存放cdn node id				
				//_ispId = obj.ispId;
				var lnode:int = 0;//当前提供的可用peer总数
				//
				if( !_dataManager.userName["myName"])
				{
					_dataManager.userName["myName"] = _p2pConnection.nearID;
					MZDebugger.customTrace(this,Protocol.MYPEERID,_p2pConnection.nearID);
				}
				//---------------------------
				var arr:Array=new Array();
				try
				{
					if(obj["value"]["queryResult"]["result"] == "success")
					{
						if(obj["value"]["queryResult"]["value"] is Array)
						{
							arr = obj["value"]["queryResult"]["value"];
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
					trace(this+"loader_COMPLETE   arr error");
					return;
				}
				/**/
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
						if(!_badPipeList[peerID])
						{										
							if (_p2pConnection && _p2pConnection.connected && _pipeNum < _MaxConnectedPeers)
							{
								var newPipe:P2PPipe = new P2PPipe( _p2pConnection, _dataManager, _p2pWaitTaskList, _groupName);
								
								//设置gather	
								_pipeList[peerID] = newPipe;
								newPipe.initPipe(_p2pConnection.nearID, peerID);
								MZDebugger.trace(this,{"key":"OTHER","value":"nearID:"+_p2pConnection.nearID+" peerID:"+peerID+")"});
								_pipeNum++;
								MZDebugger.customTrace(this,Protocol.MYPEERID,""+_p2pConnection.nearID);
								countConnectedPeer++;
								if(countConnectedPeer>_MaxConnectedPeers){
									countConnectedPeer=0;
								}
							}							
						}
						lnode++;
					}				
				}
				//------------------------------
				MZDebugger.customTrace(this,Protocol.PROXY,_gatherName+":"+_gatherPort+" (Y)");
				var obj1:Object = new Object();
				obj1.code  = "P2P.gatherConnect.Success";
				obj1.act   = "gather";
				obj1.error = 0
				obj1.gatherName = _gatherName;
				obj1.gatherPort = _gatherPort;
				this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj1));
					
				var object:Object = new Object();
				object.code   = "P2P.Neighbor.Connect";
				object.peerID = _dataManager.userName;	
				object.lnode  = lnode + _pipeNum;
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
		protected function loader_ERROR(evt:*=null):void
		{
			MZDebugger.customTrace(this,Protocol.PROXY,_gatherName+":"+_gatherPort+" (N)");
//			MZDebugger.customTrace(this,Protocol.RTMFP,_rtmfpName+":"+_rtmfpPort);
			//trace(this+evt.type)
			_canURLLoader = true;
			//
			var obj:Object = new Object();
			obj.code  = "P2P.gatherConnect.Failed";
			obj.act   = "gather";
			obj.error = 0
			obj.gatherName = _gatherName;
			obj.gatherPort = _gatherPort;
			this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
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
					else if(_badPipeList[i+"liveTime"]>=30*1000)
					{
						delete _badPipeList[i+"liveTime"];
					}					
				}
			}					
		}
		
		private var _pipeNum:int = 0; //管道列表中，管道的数量		
		
		private function peerHartBeatTimer(event:* = null):void
		{
			_dataManager.isJoinNetGroup = false;
			var pipeNum:int = 0;
			var dnode:int = 0;   //已经建立好的pipe数量
			for(var pipeID:String in _pipeList)
			{
				pipeNum++;
				if( _pipeList[pipeID] && _pipeList[pipeID].pipeConnected())
				{
					_dataManager.isJoinNetGroup = true;
					_pipeList[pipeID].peerHartBeatTimer();
					//lz add 0821
					_dataManager.userName[pipeID+"state"] = "ok";
					dnode ++;
					//
				}else if (_pipeList[pipeID])
				{
					if (_pipeList[pipeID].isDead())
					{						
						_pipeList[pipeID].clear();
						delete _pipeList[pipeID];
						pipeNum--;
						
						//lz add 0821
						
						_badPipeList[pipeID] = pipeID;
						_badPipeList[pipeID+"liveTime"] = Math.floor((new Date()).time);						
						
						//
					}
				}
			}
			MZDebugger.customTrace(this,Protocol.PEERID,_dataManager.userName);
			_pipeNum = pipeNum;
			if(_dataManager.isJoinNetGroup)
			{
			var obj:Object = new Object();
			obj.code   = "P2P.Neighbor.Connect";
			obj.peerID = _dataManager.userName;
			obj.dnode  = dnode;    //获得成功连接的邻居数量
			//trace(this+"obj.dnode = "+obj.dnode);
			obj.peerHartBeat = true;
			this.dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj));
            }
		}
		//	
		/*public function addWantData(chunkStart:uint,chunkEnd:uint):void
		{
			for( var chunkID:uint = chunkStart; chunkID <= chunkEnd; chunkID++ )
			{
				if(_p2pWaitTaskList[ chunkID] == null)
				{
					//trace(this+"addWant = "+chunkID);
					var task:Object = new Object();
					task.status    = "wait";
					task.beginTime = Math.floor((new Date()).time);
					_p2pWaitTaskList[ chunkID] = task;
				}
			}
		}*/
		/*public function removeWantData(blockID:String):void
		{
			
			if ( _p2pWaitTaskList && _p2pWaitTaskList[blockID])
			{
				//trace(this+"chunkID = "+chunkID)
				delete _p2pWaitTaskList[blockID];
			}			
		}*/
		/*public function removeWantData(chunkStart:uint, chunkEnd:uint):void
		{
			for( var chunkID:uint =chunkStart; chunkID<=chunkEnd; chunkID++ )
			{
				if ( _p2pWaitTaskList && _p2pWaitTaskList[chunkID])
				{
					//trace(this+"chunkID = "+chunkID)
					delete _p2pWaitTaskList[chunkID];
				}
			}
			
		}*/
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
					trace(this+"=======================>NetConnection.Connect.Success"+Protocol.RTMFP,_rtmfpName+":"+_rtmfpPort+"(Y)")
					MZDebugger.customTrace(this,Protocol.RTMFP,_rtmfpName+":"+_rtmfpPort+"(Y)");
					var obj0:Object = new Object();
					obj0.code = "P2P.rtmfpConnect.Success";
					obj0.ID   = _p2pConnection.nearID;
					obj0.rtmfpName = _rtmfpName;
					obj0.rtmfpPort = _rtmfpPort;
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
					//_gatherService();
					_gatherRegisterTimer.start();				
					//
					delete _dataManager.userName["myName"];
					MZDebugger.customTrace(this,Protocol.MYPEERID,"null");
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
						//trace(this+"Connect.Success   "+e.info.stream.farID);
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
					_p2pConnection.close();
					_p2pConnection = null;
				}
				//
				_p2pConnection = new NetConnection();
				_p2pConnection.addEventListener(NetStatusEvent.NET_STATUS,p2pStatusHandler);
				_p2pConnection.addEventListener(IOErrorEvent.IO_ERROR,onError);
				_p2pConnection.maxPeerConnections = 7;
				MZDebugger.trace(this,{"key":"OTHER","value":"~_~"+_rtmfpName+":" + _rtmfpPort +"/)"});
				_p2pConnection.connect("rtmfp://"+_rtmfpName+":" + _rtmfpPort +"/");
				//
				var obj1:Object = new Object();
				obj1.code = "P2P.rtmfpConnect.Start";
				obj1.rtmfpName=_rtmfpName;//+":"+_rtmfpPort);
				obj1.rtmfpPort=_rtmfpPort;
				dispatchEvent(new DataManagerEvent(DataManagerEvent.STATUS,obj1));	
				//
			}
			
		}
		private function onError(event:IOErrorEvent = null):void
		{
			MZDebugger.customTrace(this,Protocol.RTMFP,_rtmfpName+":"+_rtmfpPort+" (N)");
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
						_sendNetStream.close();
						_sendNetStream = null;
					}
					//
					if(_sendNetStream == null )
					{
						_sendNetStream = new NetStream(_p2pConnection,NetStream.DIRECT_CONNECTIONS);
						_sendNetStream.dataReliable = true;
						_sendNetStream.addEventListener(NetStatusEvent.NET_STATUS, p2pStatusHandler);
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
								newPipe.initPipe(_p2pConnection.nearID, callerns.farID);
								newPipe._sendNetStream = callerns;
								newPipe._canSend = true;
								
								MZDebugger.customTrace(this,Protocol.MYPEERID,""+_p2pConnection.nearID);
								countConnectedPeer++;
								if(countConnectedPeer>_MaxConnectedPeers){
									countConnectedPeer=0;
								}
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
			//_publisherTimer.stop();
		}
		//
		
	}
}