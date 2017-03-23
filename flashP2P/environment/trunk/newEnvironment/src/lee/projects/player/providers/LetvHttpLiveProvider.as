package lee.projects.player.providers{
	/*import P2PTestStatistic.*;
	
	import P2PTestStatisticEvent.*;*/
	
	import analysisURL.AnalysisEvent;
	import analysisURL.LetvLiveAnalysisURL;
	
	import cmodule.keygen.CLibInit;
	
	import com.hls_p2p.stream.HTTPNetStream;
	import com.p2p.stream.P2PNetStream;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.System;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import lee.managers.P2PInfoManager;
	import lee.managers.RectManager;
	import lee.player.IProvider;
	import lee.player.PlayerError;
	import lee.player.PlayerEvent;
	import lee.player.PlayerState;
	import lee.projects.player.GlobalReference;
	
	public class LetvHttpLiveProvider extends EventDispatcher implements IProvider{
		
		protected var _nc:NetConnection;
		//protected var _ns:P2PNetStream;
		protected var _ns:HTTPNetStream;
		
		protected var _info:Object;
		protected var _ready:Boolean;
		protected var _isSeeking:Boolean;
		
		protected var _state:String=PlayerState.IDLE;
		protected var _time:Number;
		protected var _percentBuffer:Number;
		protected var _video:Video;
		protected var _volume:Number=1;
		
		protected var _streamWidth:Number;
		protected var _streamHeight:Number;
		
		protected var _hasMetaData:Boolean;
		
		protected var _timer:Timer;
		
		protected var _callBackObject:Object;
		protected var _timerIndex:uint;
		
		protected var p2pTestStatistic:P2PTestStatistic;
		
		//protected var _createTime:Number=0;
		protected var _startTime:Number=0;   //服务器当前时间
		protected var _analysis:LetvLiveAnalysisURL;
		
		protected var _serverCurtime:Number = 0;   //第一次读取的服务器当前时间（秒）
		protected var _serverStartTime:Number = 0; //服务器可以时移个最小值（秒）
		protected var _serverOffsetTime:Number = 0; //服务器与本地时间的差值（秒）
		
		public function LetvHttpLiveProvider(){
			super();
			
			_callBackObject=new Object();
			_callBackObject.onMetaData=onMetaData;
			_callBackObject.onCuePoint=onCuePoint;
			_callBackObject.onBWDone=onBWDone;
			
			reset();
		}
		//--------------------
		public function set video(video:Video):void{
			if(_video!=video)
			{
				_video=video;
				setVideo(_video);
			}
		}
		public function set volume(volume:Number):void{
			if(_volume!=volume)
			{
				_volume=volume;
				setVolume(_volume);
			}
		}
		public function get info():Object{
			return _info;
		}
		public function get type():String{
			return "live";
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
			return 0;
		}
		public function get percentLoaded():Number{
			return 0;
		}
		public function play(obj:Object):void{
			if(_ns && _state == "paused"){
				_ns.resume();
				return;
			}
			
			reset();
			
			changeState(PlayerState.LOADING);
			
			_analysis = new LetvLiveAnalysisURL();
			_analysis.addEventListener(AnalysisEvent.STATUS,OnAnalysisSuccess);
			_analysis.addEventListener(AnalysisEvent.ERROR,OnAnalysisError);
			trace(this+"obj.gslb  "+obj.gslb);
			_analysis.start(obj.gslb);
		}
		public function clear():void
		{
			reset();
			_ready=false;
			_info=null;
			_video=null;
			
			_serverCurtime = 0;   
			_serverStartTime = 0; 
			_serverOffsetTime = 0;
			
			changeState(PlayerState.IDLE);
		}
		public function resume():void{
			if(!info){return;}
			_ns.resume();
			
			changeState(PlayerState.PLAYING);
		}
		public function pause():void{
			if(!info){return;}
			if(_ns)
			{
				_ns.pause();
			}
			
			changeState(PlayerState.PAUSED);
		}
		public function stop():void{
			if(!info){return;}
			reset();
			changeState(PlayerState.STOPPED,false);
		}
		public function replay():void{
			if(!info){return;}
			play(info);
		}
		
		public function seek(offset:Number):void{
			//此处offset为小数，表示所调进度为播放条的百分比
			if(!info){return;}
			if(_info && _ready)
			{
				_isSeeking=true;
			}   
			//trace("offset ===== "+offset+"   _startTime "+_startTime+"  _time "+_time);
			var seekTime:Number = Math.round((/*_startTime + */_time + int(offset*60*60)));
			trace(this+"seekTime = "+seekTime);
			//var seekTime:Number = 1352909818;
			//
			_ns.seek(seekTime);				
			resume();/**/
		}
		//--------------------
		protected function reset():void{
			stopTimer();
			stopPlayStream();
			clearAnalysis();
			_time=0;
			_percentBuffer=0;
			_streamWidth=NaN;
			_streamHeight=NaN;
			_hasMetaData=false;
			_timerIndex=0;
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
		protected function OnAnalysisSuccess(e:AnalysisEvent):void
		{
			_info = e.info as Object;
			startPlayStream();
		}
		protected function OnAnalysisError(e:AnalysisEvent):void
		{
			clearAnalysis();
			trace("gslbFailed!!!!!!!!!!!")
		}
		protected function changeState(state:String,expa:Object=null):void{
			if(_state!=state)
			{
				_state=state;
				dispatchEvent(new PlayerEvent(PlayerEvent.STATE_CHANGE,state));
			}
		}
		protected function setVideo(video:Video):void{
			if(_ns)
			{
				video.attachNetStream(_ns);
			}
		}
		protected function setVolume(volume:Number):void{
			if(_ns)
			{
				var st:SoundTransform=_ns.soundTransform;
				st.volume=volume;
				_ns.soundTransform=st;
			}
		}
		protected function startPlayStream():void{
			changeState(PlayerState.LOADING);
			stopPlayStream();
			if(_ns!=null)
			{
				_ns.close();
				_ns=null;
			}
			
			_ns=new HTTPNetStream();
			_ns.client=_callBackObject;
			_ns.bufferTime=3;
			_ns.addEventListener("streamStatus",_streamStatus);
			_ns.addEventListener("p2pStatus",_streamLocalStatus);
			_ns.addEventListener("p2pAllOver",_streamStatus);
						
			P2PInfoManager.clear();
			
			var obj0:Object = new Object();
			obj0.fun = P2PInfoManager.p2pInfoArea.serverInfo;
			obj0.event = "*";
			obj0.key = "serverInfo";
			_ns.callBack = obj0;/**/
			//TEST
			
			var obj1:Object = new Object();
			obj1.fun = P2PInfoManager.p2pInfoArea.p2pInfo;
			obj1.event = "*";
			obj1.key = "p2pInfo";
			_ns.callBack = obj1;/**/
			//TEST
			var obj2:Object = new Object();
			obj2.fun = P2PInfoManager.p2pInfoArea.peerInfo;
			obj2.event = "*";
			obj2.key = "peerInfo";
			_ns.callBack = obj2;/**/			
			
			if( true )
			{
				_info = new Object();
				_info.flvURL  = ["http://123.125.89.43/m3u8/letv_tv_800/desc.m3u8?tag=live&video_type=m3u8&stream_id=p2p_test&useloc=0&mslice=3&path=123.125.89.37,115.182.51.111&geo=CN-1-0-2&cips=10.58.100.173&tmn=1384841465&pnl=706,706,214&sign=live_tv"];
				_info.flvNode = [751,750,751,750];
				_info.gslbURL =  "http://live.gslb.letv.com/gslb?stream_id=p2p_test&tag=live&ext=m3u8&sign=live_tv&format=2&expect=2";
				_info.serverOffsetTime = -4;
				_info.serverCurtime   = Math.round(getTime()/1000)-60;
				_info.livesftime      = 60;
				_info.serverStartTime = 1381542424;
				_info.startTime = _info.serverCurtime - _info.livesftime;
				_info.livePer   = 0.2;
				_info.geo       = "CN.1.0.2";
				_info.playType  = "LIVE"; 
				_info["keyCreater"] = new Object;
				_info["keyCreater"]["calcTimeKey"] = calcTimeKey;
//				trace(">>>"+_info["keyCreater"]["calcTimeKey"]());
			}
			
			_serverCurtime = _info.serverCurtime;
			_serverStartTime = _info.serverStartTime;
			_serverOffsetTime = _info.serverOffsetTime;
			
			_ns.play(_info);
			setVolume(_volume);
			setVideo(_video);
			startTimer();
			
			GlobalReference.statisticManager.reset(_ns);
			//
			/*p2pTestStatistic=new P2PTestStatistic();
			p2pTestStatistic.addEventListener(P2PTestStatisticEvent.P2P_TEST_STATISTIC_TIMER,p2pTestStatistic_P2P_TEST_STATISTIC_TIMER);
			p2pTestStatistic.init(_ns);*/
		}
		
		protected function calcTimeKey():Object
		{
			var tm:int=Math.floor( getTime()/1000);
			tm=tm+24*60*60*5;
			var loader:CLibInit = new CLibInit;
			var lib:Object = loader.init();
			var key:String=lib.calcLiveKey("p2p_test",String(tm));
			
			return {"tm":String(tm),"key":key};
		}
		
		public function getKey(p_mmsid:String,p_storepath:String):Object
		{
			var obj:Object = {};
			
			var tm:int=Math.floor( getTime()/1000);
			tm=tm+24*60*60*5;
			var loader:CLibInit = new CLibInit;
			var lib:Object = loader.init();

			obj.tm = tm;
			if( p_mmsid != null && p_storepath != null )
			{
				obj.key = lib.calcURLKey(p_storepath,String(tm));
			}

			return obj;
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
		protected function stopPlayStream():void{
			if(_ns)
			{
				_ns.removeEventListener(NetStatusEvent.NET_STATUS,_ns_NET_STATUS);
				_ns.close();
				_ns=null;
			}
		}
		protected function startTimer():void{
			if(!_timer)
			{
				_timer=new Timer(200);
				_timer.addEventListener(TimerEvent.TIMER,_timer_TIMER);
				_timer.start();
			}
			if(startStatisticTime == -1)
			{
				startStatisticTime = getTime();
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
		protected function onMetaData(obj:Object):void {
			//if(_hasMetaData){return;}
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
			_hasMetaData=true;
			/*_createTime=Number(obj.creationdate);
			trace("_createTime = "+_createTime)*/
			var info:Object=new Object();
			info.streamWidth=_streamWidth;
			info.streamHeight=_streamHeight;
			info.time=0;
			info.duration=duration;
			dispatchEvent(new PlayerEvent(PlayerEvent.META_DATA,info));
		}
		protected function onCuePoint(obj:Object):void {
			for(var i:String in obj)
			{
				trace("onCuePoint:"+i+" = "+obj[i])
			}
			return;
		}
		protected function onBWDone(...args):void {
			return;
		}
		protected function trySendReadyEvent():void{
			if(_hasMetaData)
			{
				//trace("_ns.time=",_ns.time)
				if(_ns.time>0)
				{
					
					var obj:Object=new Object();
					obj.streamWidth=_streamWidth;
					obj.streamHeight=_streamHeight;
					_ready=true;
					dispatchEvent(new PlayerEvent(PlayerEvent.READY,obj));
					changeState(PlayerState.PLAYING);
				}
			}
		}
		//--------------------
		protected function _byteLoader_reStart(event:Event):void {
			replay();
		}
		protected function _byteLoader_liveMode(event:Event):void {
			seek(0);
		}
		//--------------------
		protected function _streamStatus(event:Object):void 
		{			
			var code:String=event.info.code;
			switch (code)
			{
				case "Stream.Play.Start" :
					trace("NetStream.Play.Start--------------");
					break;
				case "Stream.Play.Stop" :
					stop();
					break;
				case "Stream.Play.Failed" :
					clear();
					dispatchEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E2));
					break;
				case "Stream.Play.Failed" :
					
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
				case "Stream.Buffer.Empty" :
					if(_ready)
					{
						//_ns.pause();
						changeState(PlayerState.BUFFERING);
					}
					break;
				case "Stream.Buffer.Full" :
					if(_ready /*&& _adTime<=0*/)
					{
						//_ns.resume();
						_isSeeking=false;
						changeState(PlayerState.PLAYING);
					}
					break;
				case "Stream.Pause.Notify" :
					trace("Stream.Pause.Notify");
					break;
				case "Stream.Unpause.Notify" :
					trace("Stream.Unpause.Notify");
					break;
				case "Stream.Seek.Start" :
					trace("Seek.Start--------------")
					break;
				case "Stream.Seek.Complete" :
					trace("Seek.Complete--------------")
					_isSeeking=false;
					break;		
				case "Stream.Seek.ShowIcon" :
					trace("Stream.Seek.ShowIcon--------------");
					if(_ready)
					{
						changeState(PlayerState.BUFFERING);
					}
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
		protected function _ns_NET_STATUS(event:Object):void {
			var code:String=event.info.code;
			switch (code)
			{
				case "Stream.Play.Start" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">获取播放文件头信息成功</FONT>');
					
					//_startTime = Number(event.info.startTime);
					trace("event.info.startTime      = "+event.info.startTime);
					
					/*trace("event.info.newestTime     = "+event.info.newestTime);
					trace("event.info.firstStartTime = "+event.info.firstStartTime);*/
					break;
				case "Stream.Play.Stop" :
					stop();
					break;
				case "Stream.Play.Failed" :
					if(event.info.allCDNFailed == 1)
					{
						RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">CDN Failed，id='+event.info.id+'</FONT>');

						/*clear();
					    dispatchEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E2));*/
					}
					
					break;
//				case "Stream.Buffer.Empty" :
//					if(_ready)
//					{
//						changeState(PlayerState.BUFFERING);
//					}
//					break;
//				case "Stream.Buffer.Full" :
//					if(_ready)
//					{
//						changeState(PlayerState.PLAYING);
//					}
//					break;
				case "Stream.Pause.Notify" :
					break;
				case "Stream.Unpause.Notify" :
					break;
				case "Stream.Seek.Start" :
					break;
				case "Stream.Seek.Complete" :
					break;	
				case "Stream.ForceSeek.Start" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">'+event.info.id+'</FONT>');
					break;
				case "Http.LoadXML.Success":
					RectManager.debug3('<FONT  COLOR="#cccccc" FACE="Courier New" SIZE="11">DESC, '+event.info.id+'</FONT>');
					break;
				case "Http.LoadXML.Failed":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">获取xml失败</FONT>');
					break;
				case "Http.LoadClip.Success":
					RectManager.debug3('<FONT  COLOR="#79a100" FACE="Courier New" SIZE="11">CDN, '+event.info.id+'</FONT>');
					break;
				case "Http.LoadClip.Failed":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">X  http获取chunk失败，'+event.info.id+'</FONT>');
					break;
				case "SetPieceStreamFailed":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">error: '+event.info.id+'</FONT>');
					break;
				case "P2P.CheckSum.Failed":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">CS Failed, '+event.info.id+'</FONT>');
					break;
				case "P2P.DatSkip.Success":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">Skip, '+event.info.id+'</FONT>');
					break
				case "P2P.RemoveData.Success":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">DEL，'+event.info.id+'</FONT>');
					break;
				case "P2P.P2PGetChunk.Success" :
					if(event.info.id)
					{
						if(event.info.peerID)
						{
							RectManager.debug3('<FONT  COLOR="#209fc7" FACE="Courier New" SIZE="11">P2P, '+event.info.id/*+"_"+event.info.pieceID*/+", "+String(event.info.peerID).substr(0,6)+'</FONT>');
						}
						else
						{
							RectManager.debug3('<FONT  COLOR="#209fc7" FACE="Courier New" SIZE="11">P2P, '+event.info.id/*+"_"+event.info.pieceID*/+'</FONT>');
						}
					}
					break;
				case "P2P.P2PShareChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#ee8c00" FACE="Courier New" SIZE="11">P2P, '+event.info.id/*+"_"+event.info.pID*/+", "+String(event.info.peerID).substr(0,6)+'</FONT>');
					break;
				case "P2P.WantChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#035ca8" FACE="Courier New" SIZE="11">I  , '+event.info.blockID+"_"+event.info.pieceID+", "+String(event.info.name).substr(0,6)+'</FONT>');
					break;
				case "P2P.OtherPeerWantChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#b26b05" FACE="Courier New" SIZE="11">P  , '+event.info.blockID+"_"+event.info.pieceID+", "+String(event.info.name).substr(0,6)+'</FONT>');
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
					RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">邻居加入当前组</FONT>');
					break;
				case "P2P.Neighbor.Disconnect" :
					RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">邻居离开当前组</FONT>');
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
				case "P2P.selectorConnect.Start":
					RectManager.debug3('<FONT  COLOR="#959595" FACE="Courier New" SIZE="11">selector服務器開始連接  groupName='+event.info.groupName+'  selectorName='+event.info.selectorName+"  selectorPort="+event.info.selectorPort+'</FONT>');
					
					break;
				case "P2P.selectorConnect.Success":
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">selector服務器連接成功</FONT>');
					break;
				case "addHave":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "removeHave":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "heartBeat":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "sendData":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "sendData":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "sendData"+"-->":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "requestData":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
				case "<---":
					RectManager.debug3('<FONT  COLOR="#009999" FACE="Courier New" SIZE="11">p2p信息 info='+event.info.code+'  userName='+String(event.info.userName).substr(0,10)+'  id='+event.info.id+'</FONT>');
					break;
			}
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		private var date:Date;
		private function getTimeString():String
		{
			date = new Date();
			return date.hours+":"+date.minutes+":"+date.seconds+"."+date.milliseconds;
		}
		protected function _streamLocalStatus(event:Object):void 
		{
			var code:String=event.info.code;
			switch (code)
			{			
				case "P2P.P2PShareChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#ee8c00" FACE="Courier New" SIZE="11">share , '+event.info.pieceID+", "+String(event.info.remoteID).substr(0,6)+", "+getTimeString()+'</FONT>');
					break;
				case "P2P.WantChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#035ca8" FACE="Courier New" SIZE="11">I want, '+event.info.pieceID+", "+String(event.info.remoteID).substr(0,6)+'</FONT>');
					break;
				case "P2P.CheckSum.Failed":
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">'+event.info.id+'</FONT>');
					break;
				case "P2P.loadFileInfo.Success" :
					RectManager.debug3('<FONT  COLOR="#009900" FACE="Courier New" SIZE="11">获取播放文件文件信息成功</FONT>');
					break;
				case "P2P.loadFileInfo.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">获取播放文件文件信息失败</FONT>');
					break;
				case "Http.LoadClip.Success" :
					RectManager.debug3('<FONT  COLOR="#79a100" FACE="Courier New" SIZE="11">CDN, '+event.info.id+'</FONT>');
					break;
				case "P2P.HttpGetChunk.Failed" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">X  http获取chunk失败，id='+event.info.id+'</FONT>');
					break;
				case "P2P.P2PGetChunk.Success" :
					RectManager.debug3('<FONT  COLOR="#209fc7" FACE="Courier New" SIZE="11">P2P, '+event.info.id+'</FONT>');
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
				case "P2P.RemoveData.Success" :
					RectManager.debug3('<FONT  COLOR="#990000" FACE="Courier New" SIZE="11">DEL, '+event.info.id+'</FONT>');
					break;
				case "P2P.peerRemoveHaveData.Success" :
					RectManager.debug3('<FONT  COLOR="#663300" FACE="Courier New" SIZE="11">'+event.info.peerID+' DEL,'+event.info.bID+'_'+event.info.pID+'</FONT>');
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
		private var startStatisticTime:Number = -1;
		protected function _timer_TIMER(event:TimerEvent):void{
			if(!ready)
			{
				trySendReadyEvent();
				return;
			}
			var time:Number=_ns.time;
			//trace(time);
			if(isNaN(time))
			{
				time=0;
			}
			if(_time!=time)
			{
				if(Number(info.startTime)!=0)
				{
					//info.startTime=(_startTime + time)*1000;
					info.startTime=time*1000;
				}
				_timerIndex=0;
				_time=time;
				var obj:Object=new Object();
				obj.time=(/*_startTime + */time)*1000;
				obj.duration=duration;
				obj.startTime=info.startTime;
				
				//trace("obj.time      = "+obj.time);
				//trace("_startTime    = "+_startTime)
				/**/
				dispatchEvent(new PlayerEvent(PlayerEvent.PLAYHEAD,obj));
				
				if(getTime()-startStatisticTime >= 3*60*1000)
				{
					/**模拟心跳上报*/
					startStatisticTime = getTime();
					//var oo:Object = _ns.getStatisticData();
				}
				
				
			}
			if(state==PlayerState.BUFFERING)
			{
				var buff:Number=_ns.bufferLength/_ns.bufferTime;
				buff=buff>=0?buff:0;
				buff=buff<=1?buff:1;
				if(_percentBuffer!=buff)
				{
					_percentBuffer=buff;
					dispatchEvent(new PlayerEvent(PlayerEvent.BUFFER_UPDATE,buff));
				}
			}
		}
	}
}