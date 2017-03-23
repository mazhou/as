package lee.projects.player.providers{
	import analysisURL.*;
	
	import com.p2p.core.P2PNetStream;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.Timer;
	
	import lee.bases.BaseEvent;
	import lee.managers.P2PInfoManager;
	import lee.managers.RectManager;
	import lee.player.IProvider;
	import lee.player.PlayerError;
	import lee.player.PlayerEvent;
	import lee.player.PlayerState;
	import lee.projects.player.GlobalReference;
	import lee.projects.player.utils.DataLoader;
	
	import org.osmf.net.httpstreaming.HTTPNetStream;
	
	public class HLSProvider extends EventDispatcher implements IProvider{
		protected var _callBackObject:Object;
		protected var _loader:DataLoader;
		
		protected var _nc:NetConnection;
		protected var _ns:*;
		protected var _video:Video;
		
		protected var _state:String=PlayerState.IDLE;
		protected var _info:Object;
		
		protected var _hasMetaData:Boolean;
		protected var _ready:Boolean;
		protected var _isSeeking:Boolean;
		
		protected var _percentLoaded:Number;
		
		protected var _streamWidth:Number;
		protected var _streamHeight:Number;
		protected var _time:Number;
		protected var _duration:Number;
		protected var _fileTimes:Array;
		protected var _filePositions:Array;
		
		protected var _timer:Timer;		
		
		protected var p2pTestStatistic:P2PTestStatistic;
		
		//
		protected var _analysis:LetvAnalysisURL;
		protected var _startTime:Number = 0;
		protected var _flvNodeArray:Array;
		//
		
		protected var _adTime:Number = 0;//15;
		
		private var _st:SoundTransform;
		private var _volume:Number = 0;
		
		public function HLSProvider()
		{			
			_loader=new DataLoader();
			_loader.addEventListener(DataLoader.COMPLETE,_loader_COMPLETE);
			_loader.addEventListener(DataLoader.ERROR,_loader_ERROR);
			
			_callBackObject=new Object();			
			_callBackObject.onMetaData=onMetaData;
			_callBackObject.onCuePoint=onCuePoint;
			_callBackObject.onBWDone=onBWDone;
						
			//reset();
		}
		
		protected function p2pTestStatistic_P2P_TEST_STATISTIC_TIMER(event:P2PTestStatisticEvent):void
		{
			var obj:Object=event.info;
			obj.name = "P2PRate";
			obj.info = obj.P2PRate;
			P2PInfoManager.p2pInfoArea.p2pInfo(obj);			
			
			obj.name = "P2PSpeed";
			obj.info = obj.P2PSpeed;
			P2PInfoManager.p2pInfoArea.p2pInfo(obj);
			
			obj.name = "avgSpeed";
			obj.info = obj.avgSpeed;
			P2PInfoManager.p2pInfoArea.p2pInfo(obj);
			
		}
		//-------------------------------------------------
		public function set video(video:Video):void
		{
			_video=video;
			//_video.attachNetStream(_ns);
		}
		
		public function set volume(volume:Number):void
		{
			_volume = volume;
			if(_ns)
			{			    
				_st=_ns.soundTransform;
				_st.volume=volume;			
				_ns.soundTransform=_st;
			}
			
		}
		public function get info():Object{
			return _info;
		}
		public function get type():String{
			return "letvP2PVod";
		}
		public function get ready():Boolean{
			return _ready;
		}
		public function get state():String{
			return _state;
		}
		public function get time():Number{
			return _time;
		}
		public function get duration():Number{
			return _duration;
		}
		public function get percentLoaded():Number
		{
			return _percentLoaded;
		}
		public function play(info:Object):void
		{
			if (_analysis)
				clearAnalysis();/**/
			//
			_info      = info;
			_startTime = _info.start;
			
			_analysis  = new LetvAnalysisURL();
			_analysis.addEventListener(AnalysisEvent.STATUS,OnAnalysisSuccess);
			_analysis.addEventListener(AnalysisEvent.ERROR,OnAnalysisError);
			
			_analysis.start(info.dispatch);
		}
		public function clear():void
		{
			reset();
			_video = null;
			_info  = null;
			changeState(PlayerState.IDLE);
		}
		public function resume():void
		{
			if(!_info||!_ready)
			{
				return;
			}
			//
			_ns.resume();
			changeState(PlayerState.PLAYING);
		}
		public function pause():void{
			if(!_info||!_ready){return;}
			_ns.pause();
			changeState(PlayerState.PAUSED);
		}
		public function stop():void{
			if(!_info){return;}
			//
			_ns.getStatisticData();
			//
			reset();
			changeState(PlayerState.STOPPED);
		}
		public function replay():void{
			if(!_info){return;}
			play(_info);
		}
		//
		private function _play(obj:Object):void
		{
			changeState(PlayerState.LOADING);
			startTimer();			
			
			var connect:NetConnection = new NetConnection();
			connect.connect(null);
			var streamName:String="http://127.0.0.1/hls/group/a.m3u8";
			var startTime:int=0;
			var len:int=-1;
			
			
			_ns=new HTTPNetStream(connect);
			_ns.client=_callBackObject;
			_ns.addEventListener("streamStatus",_streamStatus);
			_ns.addEventListener(NetStatusEvent.NET_STATUS,_streamStatus);
			_ns.addEventListener("p2pStatus",_streamStatus);
			_ns.addEventListener("p2pAllOver",_streamStatus);
			
			_ns.addEventListener("streamLocalStatus",_streamLocalStatus);
			_ns.addEventListener("p2pLocalStatus",_streamLocalStatus);
			_ns.addEventListener("p2pLocalAllOver",_streamLocalStatus);
			
			_video.attachNetStream(_ns);
			//_ns.soundTransform.volume = _volume;
			
			var obj0:Object = new Object();
			obj0.fun = P2PInfoManager.p2pInfoArea.serverInfo;
			obj0.event = "*";
			obj0.key = "serverInfo";
			_ns.callBack = obj0;
			P2PInfoManager.p2pInfoArea.netStream = (_ns as Object);
			//
			
			var obj1:Object = new Object();
			obj1.fun = P2PInfoManager.p2pInfoArea.p2pInfo;
			obj1.event = "*";
			obj1.key = "p2pInfo";
			_ns.callBack = obj1;
			
			var obj2:Object = new Object();
			obj2.fun = P2PInfoManager.p2pInfoArea.peerInfo;
			obj2.event = "*";
			obj2.key = "peerInfo";
			_ns.callBack = obj2;			
			/**P2PInfoManager.p2pInfoArea.dataManager = (_ns as Object).getManager();*/
			//----------------------------		
			/**_ns.outMsg = outMsg;*/
			//			
			obj.startTime = 30;
			obj.testSpeed = 15;
			//obj.adTime    = _adTime;
			obj.adRemainingTime = _adTime;
			//obj.adTime    = _tempTime;
			_ns.play(streamName, startTime, len);
			//_ns.pause();
			//
			_volume = _volume ? _volume : 0.5;
			_st=_ns.soundTransform;
			_st.volume=_volume;			
			_ns.soundTransform=_st;
			//
			//_ns.pause();
			//_ns.resume();
			//
			
			GlobalReference.version=_ns.version;
			//RectManager.dataManager=(_ns as Object).getManager();			
			GlobalReference.HLSstatisticManager.reset(_ns);
			//
			p2pTestStatistic=new P2PTestStatistic();
			p2pTestStatistic.addEventListener(P2PTestStatisticEvent.P2P_TEST_STATISTIC_TIMER,p2pTestStatistic_P2P_TEST_STATISTIC_TIMER);
			p2pTestStatistic.init(_ns);			
			
		}
		public function outMsg(str:String,type:String=""):void
		{
			switch(type)
			{ 
				case "testSpeedBufferTime" : 
					trace("~~~~~~~~~~~~testSpeedBufferTime = "+str);
					break; 
				case "testSpeedBufferNotFull" : 
					trace("~~~~~~~~~~~~testSpeedBufferNotFull");
					break; 
			}
			/*switch(type)
			{ 
			case "gatherName" : 
			trace("~~~~~~~~~~~~gatherName = "+str);
			break; 
			case "version": 
			trace("~~~~~~~~~~~~version = "+str); 
			break; 
			case "groupName": 
			trace("~~~~~~~~~~~~groupName = "+str);
			break; 
			case "totalSize": 
			trace("~~~~~~~~~~~~totalSize = "+str); 
			break; 
			case "rtmfpName": 
			trace("~~~~~~~~~~~~rtmfpName = "+str); 
			break; 
			case "p2p下载率": 
			trace("~~~~~~~~~~~~p2p下载率 = "+str); 
			break; 
			case "bufferTime": 
			trace("~~~~~~~~~~~~bufferTime = "+str); 
			break; 
			case "myName": 
			trace("~~~~~~~~~~~~myName = "+str); 
			break;
			case "dnode": 
			trace("~~~~~~~~~~~~dnode = "+str); 
			break;
			case "lnode": 
			trace("~~~~~~~~~~~~lnode = "+str); 
			break;
			case "":
			//trace("~~~~~~~~~~~~动态信息 = "+str); 
			break;               
			}*/
		}
		public function seek(percent:Number):void{
			if(_info && _ready)
			{
				_isSeeking=true;
			}
			
			_ns.seek(percent);
			resume();
		}
		//--------------------lz
		protected function OnAnalysisSuccess(e:AnalysisEvent):void
		{
			var obj:Object = e.info as Object;
			_flvNodeArray = obj.flvNodeArray;
			_play(obj);
			
			/*for(var i:String in obj)
			{
			trace(i+" = "+obj[i]);
			}*/
			
			clearAnalysis();
		}
		protected function OnAnalysisError(e:AnalysisEvent):void
		{
			
			/*for(var i:String in e.info)
			{
			trace(i+" = "+e.info[i]);
			}*/
			
			if(e.info.allG3Failed == 1)
			{
				clearAnalysis();
				trace("allG3Failed!!!!!!!!!!!")
			}
			
		}
		protected function clearAnalysis():void
		{
			if (_analysis)
			{
				_analysis.removeEventListener(AnalysisEvent.STATUS,OnAnalysisSuccess);
				_analysis.removeEventListener(AnalysisEvent.ERROR,OnAnalysisError);
				_analysis.clear();
				_analysis = null;				
			}
		}
		//--------------------
		protected function reset():void
		{
			_loader.clear();
			stopTimer();
			if(_ns)
			{
				_ns.client=null;
				_ns.removeEventListener("streamStatus",_streamStatus);
				_ns.removeEventListener("p2pStatus",_streamStatus);
				_ns.removeEventListener("p2pAllOver",_streamStatus);				
				_ns.removeEventListener("streamLocalStatus",_streamLocalStatus);
				_ns.removeEventListener("p2pLocalStatus",_streamLocalStatus);
				_ns.removeEventListener("p2pLocalAllOver",_streamLocalStatus);
				
				_ns.close();
				_ns = null;
			}
			//
			if (p2pTestStatistic)
			{
				p2pTestStatistic.stop();
				p2pTestStatistic = null;
			}
			//
			if(_analysis)
			{
				clearAnalysis();
			}
			
			P2PInfoManager.p2pInfoArea.clearAll();
			
			_hasMetaData=false;
			_ready=false;
			_isSeeking=false;
			_percentLoaded=0;
			_streamWidth=NaN;
			_streamHeight=NaN;
			_time=0;
			_duration=0;
			_fileTimes=null;
			_filePositions=null;
			
			_flvNodeArray = null;
			
			_startTime=0;
		}
		protected function changeState(state:String):void{
			if(_state!=state)
			{
				_state=state;
				dispatchEvent(new PlayerEvent(PlayerEvent.STATE_CHANGE,state));
			}
		}
		protected function startTimer():void{
			if(!_timer)
			{
				_timer=new Timer(200);
				_timer.addEventListener(TimerEvent.TIMER,_timer_TIMER);
				_timer.start();
			}
		}
		protected function stopTimer():void{
			if(_timer)
			{
				_timer.stop();
				_timer.removeEventListener(TimerEvent.TIMER,_timer_TIMER);
				_timer=null;
			}
		}
		//--------------------
		protected function _streamStatus(event:Object):void 
		{			
			var code:String=event.info.code;
			switch (code)
			{
				case "NetStream.Play.Start" :
					trace("NetStream.Play.Start--------------");
					break;
				case "NetStream.Play.Stop" :
					stop();
					break;
				case "NetStream.Play.Failed" :
					clear();
					dispatchEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E2));
					break;
				case "NetStream.Play.Failed" :
					
					if(event.info.sockStatus == "Failed")
					{
						RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">播放过程失败——'+event.info.error+'</FONT>');
					}
					/*
					clear();
					dispatchEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E2));
					*/				    
					break;
				case "need_CDN_Bytes_Success" :
					//clear();
					for(var i:String in event.info)
					{
						trace(i+" ==!!!!!!== "+event.info[i]);
					}
					break;
				case "NetStream.Buffer.Empty" :
					if(_ready)
					{
						_ns.pause();
						changeState(PlayerState.BUFFERING);
					}
					break;
				case "NetStream.Buffer.Full" :
					if(_ready && _adTime<=0)
					{
						_ns.resume();
						_isSeeking=false;
						changeState(PlayerState.PLAYING);
					}
					break;
				case "NetStream.Pause.Notify" :
					trace("Stream.Pause.Notify");
					break;
				case "NetStream.Unpause.Notify" :
					trace("Stream.Unpause.Notify");
					break;
				case "NetStream.Seek.Start" :
					trace("Seek.Start--------------")
					break;
				case "NetStream.Seek.Complete" :
					trace("Seek.Complete--------------")
					_isSeeking=false;
					break;				
				case "checksum_success":
					//trace("qqqqqqqqqqqqqqqqqqqq  checksum_success");
					break;
				case "checksum_failed":
					//trace("qqqqqqqqqqqqqqqqqqqq  checksum_failed");
					break;
				case "selector_success":
					//trace("qqqqqqqqqqqqqqqqqqqq  selector_success");
					break;
				case "rtmfp_success":
					//trace("qqqqqqqqqqqqqqqqqqqq  rtmfp_success");;
					break;
				case "gather_success":
					//trace("qqqqqqqqqqqqqqqqqqqq  gather_success");
					break;
				case "load_success":
					//trace("qqqqqqqqqqqqqqqqqqqq  load_success");
					break;
			}
		}
		protected function _streamLocalStatus(event:Object):void 
		{
			var code:String=event.info.code;
			switch (code)
			{				
				case "P2P.loadFileInfo.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">获取播放文件文件信息成功</FONT>');
					break;
				case "P2P.loadFileInfo.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">获取播放文件文件信息失败</FONT>');
					break;
				case "P2P.HttpGetChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#9f0783" FACE="Courier New" SIZE="11">http get，id='+event.info.id+'</FONT>');
					break;
				case "P2P.HttpGetChunk.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">X  http获取chunk失败，id='+event.info.id+'</FONT>');
					break;
				case "P2P.P2PGetChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p get，id='+event.info.id+"，peerID="+String(event.info.peerID).substr(0,10)+'</FONT>');
					break;
				case "P2P.P2PShareChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">p2p分享chunk成功，id='+event.info.id+' ----></FONT>');
					break;
				case "P2P.JoinNetGroup.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">加入NetGroup成功</FONT>');
					break;
				case "P2P.JoinNetGroup.Rejected" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">用户拒绝加入！！！</FONT>');
					break;
				case "P2P.JoinNetGroup.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">加入NetGroup失败</FONT>');
					break;
				case "P2P.LoadCheckInfo.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">加载crc32验证码成功</FONT>');
					break;
				case "P2P.LoadCheckInfo.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">加载crc32验证码失败'+event.info.text+'</FONT>');
					break;
				case "P2P.LoadFinalChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">p2p加载数据完成</FONT>');
					break;
				case "P2P.Neighbor.Connect" :
					//RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">邻居加入当前组</FONT>');
					break;
				case "P2P.Neighbor.Disconnect" :
					//RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">邻居离开当前组</FONT>');
					break;
				case "P2P.NetConnection.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">连接rtmfp服务器成功</FONT>');
					break;
				case "P2P.NetConnection.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">连接rtmfp服务器失败</FONT>');
					break;
				case  "P2P.gatherConnect.Start":
					RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">gather服務器開始連接  gatherName='+event.info.gatherName+'gatherPort='+event.info.gatherPort+'</FONT>');
					break;
				case  "P2P.gatherConnect.Success":
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">gather服務器連接成功</FONT>');
					break;
				case  "P2P.rtmfpConnect.Start":
					RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">rtmfp服務器開始連接  rtmfpName='+event.info.rtmfpName+'</FONT>');//"rtmfp服務器開始連接"+"  rtmfpName=",event.info.rtmfpName
					break;
				case  "P2P.rtmfpConnect.Success":
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">rtmfp服務器連接成功</FONT>');
					break;
				case  "P2P.gatherRegistered.Success":
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">gather服務器註冊成功</FONT>');
					break;				
			}
		}
		protected function _timer_TIMER(event:TimerEvent):void{
			adTimeOver();
			//var time:Number;
			if(!_ready)
			{
				trySendReadyEvent();
				return;
			}
			if(_isSeeking)
			{
				return;
			}/**/
			
			dispatchPlayHead(_ns.time);
			
			dispatchProgress();		
		}
		protected function dispatchPlayHead(time:Number):void
		{
			if(_time!=time)
			{
				_time=time;
				var obj:Object=new Object();
				obj.time=time;
				obj.duration=_duration;
				dispatchEvent(new PlayerEvent(PlayerEvent.PLAYHEAD,obj));
			}
		}
		protected function dispatchProgress():void
		{
			var loaded:Number=_ns.bytesLoaded/_ns.bytesTotal;
			//trace("oo"+_ns.bytesLoaded)
			//trace(_ns.bytesTotal)
			//loaded=loaded>=0?loaded:0;
			//loaded=loaded<=1?loaded:1;
			if(_percentLoaded!=loaded)
			{
				_percentLoaded=loaded;
				//trace("loaded=",loaded)
				dispatchEvent(new PlayerEvent(PlayerEvent.PROGRESS,loaded));
				
			}
		}
		protected function adTimeOver():void
		{			
			if(_adTime>0)
			{
				_adTime = _adTime-_timer.delay/1000;
				
				var obj:Object = new Object();
				obj.name = "adTime";
				obj.info = Math.ceil(_adTime);
				P2PInfoManager.p2pInfoArea.p2pInfo(obj);
				
				if(_adTime<=0)
				{
					_ns.resume();
					_adTime = 0;
				}
			}
		}
		protected function trySendReadyEvent():void{
			if(_hasMetaData/*&&_ns.time>0*/)
			{
				_ready=true;
				dispatchEvent(new PlayerEvent(PlayerEvent.READY,null));
				changeState(PlayerState.PLAYING);
			}
		}
		//----------------------------
		protected function onMetaData(obj:Object):void {
			if(_hasMetaData){return;}
			if(obj.width&&obj.height)
			{
				_streamWidth=Number(obj.width);
				_streamHeight=Number(obj.height);
			}
			else
			{
				_streamWidth=400;
				_streamHeight=300;
			}
			for(var i:String in obj)
			{
				trace(i+" = "+obj[i]);
			}
			_duration=Number(obj.duration);
			//_fileTimes=obj.keyframes.times as Array;
			//_filePositions=obj.keyframes.filepositions as Array;
			_hasMetaData=true;
			var info:Object=new Object();
			info.streamWidth=_streamWidth;
			info.streamHeight=_streamHeight;
			info.time=0;
			info.duration=_duration;
			dispatchEvent(new PlayerEvent(PlayerEvent.META_DATA,info));
			
			//_ns.pause();
			
		}
		protected function onCuePoint(obj:Object):void {
			return;
		}
		protected function onBWDone(...args):void {
			return;
		}
		private function _loader_COMPLETE(event:BaseEvent):void{
			if(String(event.info.type)=="group")
			{
				var obj:Object=JSONDOC.decode(String(event.info.data));
				_info.url=String(obj.location);
				
				
				GlobalReference.statisticManager.reset(_ns);
				
				_ns.play(_info.url,_info.group,_info.check,_info.start);
			}
		}
		private function _loader_ERROR(event:BaseEvent):void{
			dispatchEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E1));
			clear();
		}
	}
}