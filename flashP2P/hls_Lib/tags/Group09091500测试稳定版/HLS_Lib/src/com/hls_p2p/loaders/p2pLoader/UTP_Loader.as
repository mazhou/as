package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.p2p.utils.console;
	import com.p2p.utils.console;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.ParseUrl;
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
	
	public class UTP_Loader
	{
		public var isDebug:Boolean = true;
		private var _canURLLoader:Boolean 	= true;	
		private var _URLLoader:URLLoader;
		/**播放器传递的参数*/
		private var _initData:InitData;
		/**声明调度器*/
		private var _dataManager:DataManager;
		protected var p2pCluster:P2P_Cluster;
		
		private var _pipeListArr:Array;
		private var _badPipeList:Object;		
		private var _sparePipeArr:Array;
		/**心跳时间驱动*/
		private var _peerHartBeatTimer:Timer;
		
		private var _gatherRegisterTimer:Timer;
		
		private var groupID:String;
		private var resourceID:String;
		
		private var _maxQPeers:uint  = 0;
		private var _hbInterval:uint = 30;//gathert心跳时长
		
		private var _sparePipeArrUpdateTime:Number = 0;
		private var _sparePipeArrDelayTime:Number = 45*1000;
		private var _haveToUpdateSparePipeArr:Boolean = false;
		
		private var _pipeSuccessNum:int = 0;
		
		protected var _gatherName:String = "";
		protected var _gatherPort:uint;
		
		public function UTP_Loader(_dataManager:DataManager,p2pCluster:P2P_Cluster,_gatherName:String,_gatherPort:uint)
		{
			this._dataManager 	= _dataManager;
			this.p2pCluster 	= p2pCluster;
			
			this._gatherName = _gatherName;
			this._gatherPort = _gatherPort;
		}
		
		public function startLoadP2P(_initData:InitData,groupID:String,resourceID:String):void
		{
			this.groupID   	= groupID;
			this.resourceID = resourceID;
			this._initData = _initData;
			_pipeListArr    = new Array();
			_badPipeList 	= new Object();
			_sparePipeArr   = new Array();
			
			_peerHartBeatTimer = new Timer(1*1000);
			_peerHartBeatTimer.addEventListener(TimerEvent.TIMER, peerHartBeatTimer );
			_peerHartBeatTimer.start();	
			
			_gatherRegisterTimer  = new Timer(300);
			_gatherRegisterTimer.addEventListener(TimerEvent.TIMER, gatherRegisterTimer );
			_gatherRegisterTimer.start();
			
		}
		
		public function gatherRegisterTimer(event:* = null):void
		{
			_gatherRegisterTimer.delay = _hbInterval*1000;
			
			if( _canURLLoader )
			{					
				_canURLLoader = false;
				
				if( _URLLoader == null )
				{					
					_URLLoader = new URLLoader();
					_URLLoader.addEventListener(Event.COMPLETE, loader_COMPLETE);
					_URLLoader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
					_URLLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);						
				}
				if( _gatherName && _initData)
				{
					var _url:String = "";
					_url += "http://"+_gatherName+":"+_gatherPort+"/lean?termid=1"
					if(_initData['gslbURL'] )
					{
						_url += "&platid="+ ParseUrl.getParam(_initData['gslbURL'],"platid");
						_url += "&splatid="+ParseUrl.getParam(_initData['gslbURL'],"splatid");
					}else if( _initData['gslb'] )
					{
						_url += "&platid="+ ParseUrl.getParam(_initData['gslb'],"platid");
						_url += "&splatid="+ParseUrl.getParam(_initData['gslb'],"splatid");
					}
					_url += "&pid=21-"+LiveVodConfig.uuid+"-0-18090";
					_url += "&ver="+LiveVodConfig.GET_VERSION();
//					_url += "&utpid=d6de2b74c77b4db9a6da53326b7dca93";
					_url += "&appid=0";
//					_url += "&nettype=1";
					var array:Array = _initData.geo.split(".");
					_url += "&ispId="+array[3];
					_url += "&arealevel1="+array[0];
					_url += "&arealevel2="+array[1];
					_url += "&arealevel3="+array[2];
					_url += "&neighbors="+_pipeSuccessNum;
					_url += "&ckey="+LiveVodConfig.resourceID;
					_url += "&expect=21";
					_url += "&op=3";
					_url += "&format=1";
					_url += "&rdm="+this.getTime();
					_URLLoader.load(new URLRequest(_url));
					console.log(this,"UTP peerlist:"+_url);
				}
			}
		}
		
		private function pipeDeadHandler(remoteID:String,idx:int):void
		{
			/**
			 * 当节点连接失败时,在_badPipeList列表中创建key=pipeID的对象，并将本地时间存入该对象，
			 * 此时间用来对比存入_badPipeList的时长
			 * */
			_badPipeList[remoteID] = getTime();
			console.log(this,"deadPipe id:"+remoteID);
			(_pipeListArr[idx] as SignallingStrategy_UTP).clear();
			_pipeListArr[idx] = null;
			_pipeListArr.splice(idx, 1);			
		}
		
		protected function loader_COMPLETE(evt:Event):void
		{		
			_canURLLoader = true;
			Statistic.getInstance().gatherSuccess(_gatherName,_gatherPort,groupID);
			clearBadPipeList();
			try
			{	
				if(String(_URLLoader.data).length == 0)
				{
					return;
				}
				
				var obj:Object = JSONDOC.decode(String(_URLLoader.data));	
				
				if( !obj["peerlist"] || !(obj["peerlist"] is Array) || obj["peerlist"].length == 0)
				{
					return;
				}
				
			}
			catch(e:Error)
			{
				loader_ERROR("dataError");
				return;
			}					
			
			if( !LiveVodConfig.MY_NAME )
			{
				LiveVodConfig.MY_NAME = LiveVodConfig.uuid;
			}
			//---------------------------
			var remoteID:String = "";
			var arr:Array = obj["peerlist"];
			var newPipe:UTP_Pipe
			try
			{
				for( var i:int = 0 ; i<arr.length ; i++ )
				{
					remoteID = arr[i]["peerid"];
					if( remoteID != ""
						&& !_badPipeList[remoteID]
						&& remoteID != LiveVodConfig.MY_NAME 
						&& -1 == ifHasPipeInArray(_pipeListArr,remoteID)
						&& arr[i]["userip"]
						&& arr[i]["pport"]
						&& arr[i]["termid"] !="1"
					)
					{
						if( _pipeListArr.length < LiveVodConfig.MAX_PEERS )
						{
							console.log(this,"create UTP pipe:"+arr[i]["userip"]+":"+arr[i]["pport"]+" "+remoteID);
							newPipe = new UTP_Pipe(groupID,remoteID,arr[i]["userip"],int(arr[i]["pport"]),arr[i]["termid"]);
							_pipeListArr.push(new SignallingStrategy_UTP( newPipe, this, _dataManager ));
							newPipe.init();
						}
						else
						{
							/**将arr中剩余的空闲节点保存*/
							if( -1 == ifHasPipeInArray(_sparePipeArr,remoteID,false) )
							{
								pushPeerIDIntoSparePipeArr( remoteID,arr[i]["userip"],arr[i]["pport"],arr[i]["termid"] );
							}							
						}
					}
					
				}
			}
			catch(e:Error)
			{
				return;
			}
		}
		
		protected function loader_ERROR(evt:*=null):void
		{
			console.log(this,"load UTP Peerlist error:"+evt);
			_canURLLoader = true;
		}
		
		public function getSuccessPeerList( peerID:String ):Array
		{
			var arr:Array=new Array;
			for(var i:int=0 ; i<_pipeListArr.length ; i++)
			{				
				if(  (_pipeListArr[i] as SignallingStrategy_UTP).remoteID != ""
					&& (_pipeListArr[i] as SignallingStrategy_UTP).remoteID != peerID
					&& (_pipeListArr[i] as SignallingStrategy_UTP).isActivePeer()
					&& true == (_pipeListArr[i] as SignallingStrategy_UTP).isReceivedData )
				{
					arr.push((_pipeListArr[i] as SignallingStrategy_UTP).remoteID);
				}
			}
			return arr;
		}
		public function isWantPeerList():Boolean
		{
			if( _sparePipeArr.length < _hbInterval
				|| ( getTime()-_sparePipeArrUpdateTime ) >= _sparePipeArrDelayTime )
			{
				if( ( getTime()-_sparePipeArrUpdateTime ) >= _sparePipeArrDelayTime )
				{
					/*当需要更新_sparePipeArr时，当再次向_sparePipeArr添加节点ID时需要先将该列表清空*/
					_haveToUpdateSparePipeArr = true;
				}
				return true;
			}
			return false;
		}
		public function peerHartBeatTimer(event:* = null):void
		{			
			var peerStateObj:Object = new Object();
			_pipeSuccessNum = 0;
			
			for(var idx:int = _pipeListArr.length-1; idx >= 0; idx--)
			{
				var pipe:SignallingStrategy_UTP = _pipeListArr[idx];
				
				if ( pipe.isDead() )
				{
					pipeDeadHandler( pipe.remoteID,idx );
					continue;
				}
				
				if( pipe.canRecieved && pipe.canSend )
				{
					_pipeSuccessNum++;
					pipe.resetHartBeatTimer(idx*50);
				}
				
				peerStateObj[pipe["remoteID"]] = {
					name:pipe.remoteID, 
					farID:pipe.remoteID, 
					state: pipe.canRecieved && pipe.canSend ? "connect" 
						: (pipe.canRecieved || pipe.canSend) ? "halfConnect" : "notConnect"
				};
				//trace("remoteID = "+pipe.remoteID.substr(0,5))
			}
			
			pushSparePeerIntoPipeList(peerStateObj);
			
			Statistic.getInstance().getNeighbor(peerStateObj,_pipeSuccessNum,(_pipeListArr.length+_sparePipeArr.length),groupID);
		}
		
		private function pushSparePeerIntoPipeList( peerStateObj:Object ):void
		{
			for(var i:int=_sparePipeArr.length-1 ; i>=0 ; i--)
			{
				if( _pipeListArr.length < LiveVodConfig.MAX_PEERS )
				{
					var newPipe:UTP_Pipe = new UTP_Pipe(groupID,_sparePipeArr[i]['remoteID'],_sparePipeArr[i]["userip"],int(_sparePipeArr[i]["pport"]),_sparePipeArr[i]["termid"]);
					_pipeListArr.push(new SignallingStrategy_UTP( newPipe, this, _dataManager ));

				}
				else
				{
					break;
				}
			}
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
		
		private function ifHasPipeInArray(arr:Array,id:String,isPipListArr:Boolean=true):int
		{
			for( var i:int=0 ; i<arr.length ; i++ )
			{
				if( true == isPipListArr )
				{
					if( arr[i]["remoteID"] == id )
					{
						return i;
					}
				}
				else
				{
					if( arr[i] == id )
					{
						return i;
					}
				}
			}
			return -1;
		}
		
		private function pushPeerIDIntoSparePipeArr( peerID:String,ip:String,port:String,termid:String ):void
		{
			if( true == _haveToUpdateSparePipeArr )
			{
				_sparePipeArr = new Array();
				_haveToUpdateSparePipeArr = false;
			}
			_sparePipeArr.push( {"remoteID":peerID,"ip":ip,"port":port,"termid":termid} );
			if(_sparePipeArr.length>50)
			{
				_sparePipeArr.shift();
			}
			_sparePipeArrUpdateTime = getTime();
		}
		
		private function clearPipeInArr():void
		{
			if( _pipeListArr )
			{
				for( var i:int=_pipeListArr.length-1 ; i>=0 ; i--)
				{
					try
					{
						(_pipeListArr[i] as SignallingStrategy_UTP).clear();
					}
					catch(err:Error)
					{
						console.log(this,err+err.getStackTrace());
					}
					
					_pipeListArr[i] = null;
					_pipeListArr.splice(i,1);		
				}
			}
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			console.log(this,"clear");
			if( _peerHartBeatTimer )
			{
				_peerHartBeatTimer.stop();
				_peerHartBeatTimer.removeEventListener(TimerEvent.TIMER, peerHartBeatTimer);											    
				_peerHartBeatTimer = null;
				console.log(this,"_peerHartBeatTimer clear");
			}
			
			if( _gatherRegisterTimer )
			{
				_gatherRegisterTimer.stop();
				_gatherRegisterTimer.removeEventListener(TimerEvent.TIMER, gatherRegisterTimer);											    
				_gatherRegisterTimer = null;
				console.log(this,"_gatherRegisterTimer clear");
			}
			
			if( _URLLoader )
			{
				if(false == _canURLLoader)
				{
					try
					{
						_URLLoader.close();
					}
					catch(err:Error)
					{
						console.log(this,"_URLLoader close() error");
					}
				}
				_URLLoader.removeEventListener(Event.COMPLETE, loader_COMPLETE);
				_URLLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
				_URLLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
				_URLLoader=null;
				console.log(this,"_URLLoader clear");
			}			
			
			clearPipeInArr();
			_pipeListArr  = null;
			_badPipeList  = null;
			_sparePipeArr = null;
			
			_initData		= null;
			_dataManager	= null;
			p2pCluster      = null;
			
			_pipeSuccessNum = 0;
			
			_maxQPeers  = 0;
			_hbInterval = 11;
			
			_sparePipeArrUpdateTime = 0;
			_sparePipeArrDelayTime = 45*1000;
			_haveToUpdateSparePipeArr = false;
			
		}
	}
}