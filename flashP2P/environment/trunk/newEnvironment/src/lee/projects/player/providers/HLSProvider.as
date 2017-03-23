package lee.projects.player.providers{
	import com.hls_p2p.stream.HTTPNetStream;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.utils.Timer;
	
	import analysisURL.AnalysisEvent;
	import analysisURL.HLSAnalysisURL;
	
	import lee.bases.BaseEvent;
	import lee.managers.P2PInfoManager;
	import lee.managers.RectManager;
	import lee.player.IProvider;
	import lee.player.PlayerError;
	import lee.player.PlayerEvent;
	import lee.player.PlayerState;
	import lee.projects.player.GlobalReference;
	import lee.projects.player.utils.DataLoader;
	import lee.projects.player.utils.GslbLoader;
	import lee.utils.FlashVars;
	
//	import org.osmf.events.TimeEvent;
	
	public class HLSProvider extends EventDispatcher implements IProvider{
		protected var _callBackObject:Object;
		protected var _loader:DataLoader;
		
		protected var _nc:NetConnection;
		protected var _ns:HTTPNetStream;//_ns:P2PNetStream//;
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
		protected var _analysis:HLSAnalysisURL;
		protected var _startTime:Number = 0;
		protected var _flvNodeArray:Array;
		//
		
		protected var _adTime:Number = 0;
		
		private var _st:SoundTransform;
		private var _volume:Number = 0;
		
		private var _gslbloader:GslbLoader = GslbLoader.getInstance();
		private var _flashvars:FlashVars = FlashVars.getInstance();
		
		public function HLSProvider()
		{			
			_loader=new DataLoader();
			_loader.addEventListener(DataLoader.COMPLETE,_loader_COMPLETE);
			_loader.addEventListener(DataLoader.ERROR,_loader_ERROR);
			
			_callBackObject=new Object();			
			_callBackObject.onMetaData=onMetaData;
			_callBackObject.onCuePoint=onCuePoint;
			_callBackObject.onBWDone=onBWDone;
			_callBackObject.onPlayStatus=onPlayStatus;
			//reset();
		}
		
		protected function p2pTestStatistic_P2P_TEST_STATISTIC_TIMER(event:P2PTestStatisticEvent):void
		{
			var obj:Object=event.info;		
			
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
			_play(info);
			/*_analysis  = new HLSAnalysisURL();
			_analysis.addEventListener(AnalysisEvent.STATUS,OnAnalysisSuccess);
			_analysis.addEventListener(AnalysisEvent.ERROR,OnAnalysisError);
			
			_analysis.start(info);*/
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
//			_ns.getStatisticData();
			//
			reset();
			changeState(PlayerState.STOPPED);
		}
		public function replay():void{
			if(!_info){return;}
			play(_info);
		}
		//
		private function console(msg:*):void
		{
			ExternalInterface.call("console.log",msg);
		}
		private var _defaultPlayInfo:Object;
		private function completeHandler(evt:Event):void
		{
			_defaultPlayInfo.gslbURL = _gslbloader.gslb;
			//console(_gslbloader.gslb);
			var cdnArr:Array = [];
			for(var i:int =0;i<_gslbloader.cdnArr.length;i++)
			{
				cdnArr.push({"location":_gslbloader.cdnArr[i],"playlevel":1});
			}
			//console("gslb complete!"+_gslbloader.cdnArr);
			_defaultPlayInfo.remote = _gslbloader.remote;
			_defaultPlayInfo.desc = _gslbloader.desc;
			_defaultPlayInfo.cdnInfo = cdnArr;
			_defaultPlayInfo.startTime = _gslbloader.curTime-60;
			_play(_defaultPlayInfo);
		}
		private function _play(obj:Object=null):void
		{
			//直播，检查是否有调度地址
			console("-------------play");
			if(GlobalReference.type == "LIVE"&&_defaultPlayInfo==null)
			{
				if(!_gslbloader.gslbSuceess)
				{
					_defaultPlayInfo = obj;
					console("gslb load!");
					var streamid:String = "bjws";
					if(_flashvars['streamid'])
					{
						streamid = _flashvars['streamid'];
					}
					var gslbInfo:Object =
					{
						"gslbUrl":"http://live.gslb.letv.com/",
						"streamid":streamid,//只需要修改streamid更换流
						"scheme":"http",
						"cdn":"letv",
						"ext":"m3u8",
						"furl":"http://api.letv.com/time",
						"ftime":0.2,
						"from":"letv_p2p",
						"pay":"0",
						"usetype":"release"
					}
					_gslbloader.init(gslbInfo);
					_gslbloader.addEventListener(Event.COMPLETE,completeHandler);
					_gslbloader.load();
					return;
				}
			}
			for(var i:String in obj)
			{
				console(i+"="+obj[i]);
			}
			changeState(PlayerState.LOADING);
			startTimer();			
			
			var connect:NetConnection = new NetConnection();
			connect.connect(null);
			
			var startTime:int=0;
			var len:int=-1;
			
			/*if(_ns)
			{
				_ns.close();
				//_ns = null;
			}*/
			//_ns=new HTTPNetStream({"playType":GlobalReference.type});
			if( !_ns )
			{
				_ns=new HTTPNetStream({"playType":GlobalReference.type});//new P2PNetStream();
				_ns.client=_callBackObject;
				_ns.addEventListener("streamStatus",_streamStatus);
				_ns.addEventListener("p2pStatus",_streamLocalStatus);
				_ns.addEventListener("p2pAllOver",_streamStatus);
			}
			else
			{
				_ns.seek(0);
				_ns.resume();
				tempBeginPlayTime = getTime();
				return;
			}
			
			
			
			_video.attachNetStream(_ns);
			
			var obj0:Object = new Object();
			obj0.fun = P2PInfoManager.p2pInfoArea.serverInfo;
			obj0.event = "*";
			obj0.key = "serverInfo";
			_ns.callBack = obj0;
			P2PInfoManager.p2pInfoArea.netStream = (_ns as Object);
			
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
			if(!obj)
			{
				obj = new Object();	
			}
			obj.playlevel = 3;
			obj.vars = _flashvars;
			if( GlobalReference.type == "LIVE" )
			{
				//轮播台:
				//obj.flvURL  = ["http://220.181.153.109:559/m3u8/letv_test/desc.m3u8"];
				//直播台:
				//obj.flvURL  = ["http://123.125.89.43/m3u8/letv_tv_800/desc.m3u8?tag=live&video_type=m3u8&stream_id=p2p_test&useloc=0&mslice=3&path=123.125.89.37,115.182.51.111&geo=CN-1-0-2&cips=10.58.100.173&tmn=1384841465&pnl=706,706,214&sign=live_tv"];
//				obj.flvURL  = ["http://60.217.237.161/44/24/48/letv-uts/ver_00_12-8524748-AVC-546062-AAC-32000-1459320-107075565-f0ce8ca7be2da8e58c6e8aadd9485248-1384784956704.m3u8?crypt=16aa7f2e124&b=587&nlh=3072&nlt=45&bf=17&gn=750&p2p=1&video_type=mp4&opck=1&check=0&tm=1386833400&key=734af72b5516d79f73d9a4051114c355&proxy=2007470980,2071812446&cips=10.58.100.89&geo=CN-1-0-2&lgn=letv&termid=1&playid=0&sign=letv&tag=letv&platid=1&m3v=1&splatid=101&ostype=Windows%207&tss=ios&tn=0.6369544509798288&hwtype=un&ctv=pc&mmsid=3067900&pay=0&rateid=1000"];
//				JIANGXI
				//obj.flvURL  = ["http://119.188.122.49/m3u8/jiangxi/desc.m3u8?tag=live&video_type=m3u8&stream_id=jiangxi&useloc=0&mslice=5&path=119.188.122.35,60.217.237.238&geo=CN-1-0-2&cips=10.58.100.89&tmn=1386915812&pnl=751,751,246&ext=m3u8&sign=live_web&scheme=rtmp&termid=1&pay=0&ostype=Windows%207&hwtype=un&platid=10&splatid=1001&playid=1&tm=1387002212&key=a537021e33874ba5a1b280d46403ff38"];
//				obj.gslbURL =  obj["gslbURL"];//"http://live.gslb.letv.com/gslb?stream_id=letv_erge&tag=live&ext=xml&sign=live_web&format=2&expect=2&scheme=rtmp&termid=1&pay=0&ostype=Windows%207&hwtype=un&platid=10&splatid=1001&playid=1&tm=1402993182&key=505c5b8d5a24e7b195b7c7e0a8b1e080";
//				obj.cdnInfo  = obj["cdnInfo"];//,[{"location":"http://119.188.122.8/m3u8/letv2/desc.m3u8?stream_id=letv2&ltm=1438823433&lkey=b9ac18522f831f577270dfafc6e20003&platid=10&splatid=1001&tag=live&video_type=m3u8&useloc=0&mslice=5&path=119.188.122.12,60.217.237.133,60.217.237.229&ver=live_3&buss=27&qos=3&cips=10.58.101.139&geo=CN-1-9-2&tmn=1407287433&pnl=751,750,225&rson=1&ext=m3u8&sign=live_web&scheme=rtmp&termid=1&pay=0&ostype=Windows7&hwtype=un&playid=1","playlevel":1}];
				//obj.flvURL  = ["http://123.126.32.18:20090/test.m3u8"]
				obj.flvNode = [751,750,751,750];
				obj.serverOffsetTime = -4;
				obj.serverCurtime =Math.round(getTime()/1000)-0*1;// 1386801900;//
				obj.livesftime = 60;
				obj.serverStartTime = 1381542424;
//				obj.startTime = 1386801900;//1386802022;//1385951180;//obj.serverCurtime - obj.livesftime;
				obj.livePer = 0.2;
				obj.geo = "CN.1.0.2";
				//obj.startTime = Math.round(getTime()/1000)-60;//0;//Math.round(getTime()/1000)-60*35;
				obj.playType = "LIVE";
			}
			else if(GlobalReference.type == "VOD")
			{
				//
				//obj.flvURL  = ["http://60.217.237.169/50/30/48/letv-uts/ver_00_12-8524762-AVC-550833-AAC-32000-1323200-97858678-dc7ba160850b72597be5192b9c5b146f-1384790019869.m3u8?crypt=16aa7f2e187&b=589&nlh=3072&nlt=45&bf=25&gn=750&p2p=1&video_type=mp4&opck=1&check=0&tm=1387167000&key=9295c61b81d03a7d53d09555948ff164&proxy=1872838953,2071812452&cips=10.58.100.65&geo=CN-1-0-2&lgn=letv&ostype=Windows%207&playid=0&pay=0&tag=letv&mmsid=3067906&sign=letv&termid=1&m3v=1&platid=1&tn=0.34751885011792183&hwtype=un&tss=ios&ctv=pc&splatid=101&rateid=1000"];
				//1080p
//				obj.flvURL  = ["http://123.125.89.50/47/11/104/letv-uts/ver_00_12-9110424-avc-1639821-aac-127995-311240-69234940-8366e88303558078bcfdce372fa03abe-1386747197274.m3u8?crypt=95aa7f2e365&b=1779&nlh=3072&nlt=45&bf=16&gn=706&p2p=1&video_type=mp4&opck=1&check=0&tm=1387188600&key=c3657fca8c4d26a0ab47ab1c94263135&proxy=2071812449,2007470983&cips=10.58.101.114&geo=CN-1-0-2&lgn=letv&playid=0&tn=0.439950889442116&platid=1&sign=letv&tss=ios&ostype=Windows%207&tag=letv&m3v=1&pay=1&mmsid=20000117&ctv=pc&hwtype=un&splatid=101&termid=1&rateid=720p"]
				//obj.flvURL  = ["http://123.125.89.61/50/53/17/letv-uts/ver_00_12-8524605-AVC-548721-AAC-32000-2729920-201190097-a53ec648396a3cc630af0ec9b0f9f211-1384772969609.m3u8?crypt=73aa7f2e138&b=588&nlh=3072&nlt=45&bf=19&gn=706&p2p=1&video_type=mp4&opck=1&check=0&tm=1385949600&key=7275510de95afe85683e2f173a476d7a&proxy=2071812452,2007470986&cips=10.58.100.65&geo=CN-1-0-2&lgn=letv&termid=1&ostype=Mac OS 10.9.0&hwtype=un&splatid=101&sign=letv&tag=letv&tn=0.8131529376842082&pay=1&tss=ios&platid=1&m3v=1&ctv=pc&mmsid=3067852&playid=0&rateid=1000"];
				//obj.flvURL  = ["http://119.188.122.34/50/15/60/letv-uts/14/ver_00_14-12833053-avc-259786-aac-31999-1293120-48572914-b519197cb23a87bbf19eabb72fb497cd-1392927014670.m3u8?crypt=22aa7f2e74&b=300&nlh=3072&nlt=45&bf=20&gn=751&p2p=1&video_type=mp4&platid=1&splatid=101&its=12438361&opck=1&check=0&tm=1395403200&key=92e17d0fad5956d8969b52a497c6a546&proxy=1020915106,2007470986&cips=10.58.100.118&buss=100&geo=CN-1-0-2&lgn=letv&mmsid=3942177&termid=1&tn=0.11695076385512948&ctv=pc&sign=letv&playid=0&ostype=Windows7&pay=0&tag=&m3v=1&hwtype=un&tss=ios"];
				
				/*obj.flvURL  = ["http://119.188.122.34/50/15/60/letv-uts/14/ver_00_14-12833053-avc-259786-aac-31999-1293120-48572914-b519197cb23a87bbf19eabb72fb497cd-1392927014670.m3u8?crypt=22aa7f2e74&b=300&nlh=3072&nlt=45&bf=20&gn=751&p2p=1&video_type=mp4&platid=1&splatid=101&its=12438361&opck=1&check=0&tm=1395403200&key=92e17d0fad5956d8969b52a497c6a546&proxy=1020915106,2007470986&cips=10.58.100.118&buss=100&geo=CN-1-0-2&lgn=letv&mmsid=3942177&termid=1&tn=0.11695076385512948&ctv=pc&sign=letv&playid=0&ostype=Windows7&pay=0&tag=&m3v=1&hwtype=un&tss=ios",
							   "http://60.217.237.162/50/15/60/letv-uts/14/ver_00_14-12833053-avc-259786-aac-31999-1293120-48572914-b519197cb23a87bbf19eabb72fb497cd-1392927014670.m3u8?crypt=22aa7f2e86&b=300&nlh=3072&nlt=45&bf=23&gn=750&p2p=1&video_type=mp4&platid=1&splatid=101&its=12441481&opck=1&check=0&tm=1395403200&key=92e17d0fad5956d8969b52a497c6a546&proxy=1872838946,2007470986&cips=10.58.100.118&buss=100&geo=CN-1-0-2&lgn=letv&mmsid=3942177&termid=1&tn=0.11695076385512948&ctv=pc&sign=letv&playid=0&ostype=Windows7&pay=0&tag=&m3v=1&hwtype=un&tss=ios"];
				obj.flvURL  = ["http://119.167.147.54/57/28/4/letv-uts/14/ver_00_14-15080234-avc-548458-aac-32000-1229862-90757473-fa100fc26db54235e28a1bda3ee9e63c-1395982770367.m3u8?crypt=16aa7f2e142&b=590&nlh=3072&nlt=45&bf=19&gn=732&p2p=1&video_type=mp4&platid=1&splatid=101&its=12476665&opck=1&check=0&tm=1396443600&key=c8a3f7fb720d19b4d61ae506905fa885&proxy=2007471014,2071812439&cips=10.58.100.118&buss=100&geo=CN-1-0-2&lgn=letv&tn=0.9525582506321371&termid=1&sign=letv&ctv=pc&tss=ios&tag=letv&m3v=1&vtype=13&pay=0&mmsid=3942177&ostype=Windows7&hwtype=un&playid=0&rateid=1000",
								"http://60.217.237.166/57/28/4/letv-uts/14/ver_00_14-15080234-avc-548458-aac-32000-1229862-90757473-fa100fc26db54235e28a1bda3ee9e63c-1395982770367.m3u8?crypt=16aa7f2e185&b=590&nlh=3072&nlt=45&bf=25&gn=750&p2p=1&video_type=mp4&platid=1&splatid=101&its=12427753&opck=1&check=0&tm=1396443600&key=c8a3f7fb720d19b4d61ae506905fa885&proxy=2031283990,2007471014&cips=10.58.100.118&buss=100&geo=CN-1-0-2&lgn=letv&tn=0.9525582506321371&termid=1&sign=letv&ctv=pc&tss=ios&tag=letv&m3v=1&vtype=13&pay=0&mmsid=3942177&ostype=Windows7&hwtype=un&playid=0&rateid=1000",
								"http://119.167.210.166/57/28/4/letv-uts/14/ver_00_14-15080234-avc-548458-aac-32000-1229862-90757473-fa100fc26db54235e28a1bda3ee9e63c-1395982770367.m3u8?crypt=16aa7f2e165&b=590&nlh=3072&nlt=45&bf=22&gn=744&p2p=1&video_type=mp4&platid=1&splatid=101&its=12460354&opck=1&check=0&tm=1396443600&key=c8a3f7fb720d19b4d61ae506905fa885&proxy=2007471014,2071812439&cips=10.58.100.118&buss=100&geo=CN-1-0-2&lgn=letv&tn=0.9525582506321371&termid=1&sign=letv&ctv=pc&tss=ios&tag=letv&m3v=1&vtype=13&pay=0&mmsid=3942177&ostype=Windows7&hwtype=un&playid=0&rateid=1000"];
				*/
				//obj.flvURL  = ["http://123.125.89.67/47/38/106/letv-uts/14/ver_00_14-13008733-avc-550799-aac-32000-2704960-199956994-f57028c1b1016cbc86a7c743c50892a5-1393152001504.m3u8?crypt=99aa7f2e149&b=588&nlh=3072&nlt=45&bf=20&gn=706&p2p=1&video_type=mp4&platid=1&splatid=101&its=12402508&opck=1&check=0&tm=1397038800&key=5d202adfc31008943f7f0cc6574dca5c&proxy=2071812449,2007470983&cips=10.58.100.74&buss=16&geo=CN-1-0-2&lgn=letv&mmsid=4044600&playid=0&tss=ios&vtype=16&ctv=pc&m3v=1&termid=1&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.2607871904037893&pay=1&iscpn=f9051&rateid=1000"];
				obj.cdnInfo  = [{"location":"http://111.206.215.36/53/1/62/letv-uts/14/ver_00_14-17280345-avc-879363-aac-126012-2180360-277249415-bb95ffc8987e420ddb1adf2c0b7ce253-1398629275614.m3u8?crypt=13aa7f2e298&b=1017&nlh=3072&nlt=45&bf=23&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-0-2&tm=1398687000&key=7732328a742a7b8b063beb4b8913142d&platid=1&splatid=101&proxy=2071812416,2007471010&m3v=1&mmsid=20470064&playid=0&vtype=22&cvid=73932401314&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.6392153538763523&pay=1&iscpn=f9051&rateid=1300&gn=769&buss=16&qos=5&cips=10.58.101.9","playlevel":4}];
				obj.cdnInfo  = [{"location":"http://60.217.237.165/57/21/23/letv-uts/14/ver_00_14-18125544-avc-478532-aac-32000-2499000-162220092-c071a631b4b543d16d0205d78eb54937-1399192256335.m3u8?crypt=65aa7f2e200&b=519&nlh=3072&nlt=45&bf=31&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1399614600&key=be03ad4f4d86ad5f175d74d75c1366c3&platid=1&splatid=101&proxy=1872838949,2007471014&m3v=1&mmsid=20562116&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.6077616047114134&pay=0&rateid=1000&gn=750&buss=100&qos=4&cips=10.58.101.139","playlevel":4}];
				obj.cdnInfo  = [{"location":"http://119.188.122.43/70/37/108/letv-uts/14/ver_00_14-19548020-avc-479422-aac-32000-2627960-170878575-1a371478bf6d7777c70d784340605932-1400487540509.m3u8?crypt=11aa7f2e171&b=520&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1401268200&key=76ff6cba291867b803ba5b0b4abf3739&platid=1&splatid=101&proxy=1020915105,2007471027&m3v=1&mmsid=20748163&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.012146640568971634&pay=0&rateid=1000&gn=751&buss=100&qos=4&cips=10.58.101.139","playlevel":4}];
				
				obj.cdnInfo  = [{"location":"http://60.217.237.169/65/53/90/letv-uts/14/ver_00_14-22828886-avc-479813-aac-32002-2309200-150318485-a624a435decfe4009175a922243b35dc-1403029782143.m3u8?crypt=59aa7f2e147&b=520&nlh=3072&nlt=45&bf=23&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403086800&key=df2bb026be725226b91427ae50d324c8&platid=1&splatid=101&proxy=1872838953,2007471022&m3v=1&mmsid=21133313&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.9869421254843473&pay=0&rateid=1000&gn=750&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				obj.cdnInfo  = [{"location":"http://119.188.122.70/33/2/71/letv-uts/14/ver_00_16-24600016-avc-229925-aac-32000-2706320-91635986-9546737d96655807624a5daafd088c4a-1404906003823.m3u8?crypt=86aa7f2e75&b=270&nlh=3072&nlt=45&bf=22&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1406796600&key=5df3c56430f08244e150ab50915939f0&platid=1&splatid=101&proxy=2007487116,2071812995&m3v=1&mmsid=21557652&playid=0&vtype=21&cvid=2010048044622&ctv=pc&hwtype=un&ostype=MacOS10.9.4&tag=letv&sign=letv&tn=0.17279291106387973&pay=1&iscpn=f9051&rateid=350&gn=751&buss=16&qos=5&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://111.206.215.40/62/44/99/letv-uts/14/ver_00_14-22712053-avc-214981-aac-32001-6563375-209801413-f2a5a639fa08847d2f17ac03cadb6468-1402932404403.m3u8?crypt=67aa7f2e48&b=255&nlh=3072&nlt=45&bf=15&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403244000&key=d9c828fcbaa5826d429700c7bfd7bcdf&platid=1&splatid=101&proxy=1780921484,2007471019&m3v=1&mmsid=21118098&playid=0&vtype=21&cvid=1887502251070&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.6035838788375258&pay=1&iscpn=f9051&rateid=350&gn=769&buss=16&qos=5&cips=10.58.104.231&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://61.240.146.210/64/40/47/letv-uts/14/ver_00_14-22403213-avc-470443-aac-32003-1351760-86412464-18e502f9841bc968bc21be941aaf9888-1402638103216.m3u8?crypt=92aa7f2e195&b=511&nlh=3072&nlt=45&bf=31&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=add7c8817e5a632b43df5d5b8c7a8554&platid=1&splatid=101&proxy=1027062828,2007471021&m3v=1&mmsid=21073072&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.9688555095344782&pay=0&rateid=1000&gn=768&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://123.125.89.93/63/8/87/letv-uts/14/ver_00_14-22880946-avc-465606-aac-32000-2500746-158546267-030ca1ee10aaae3ac05fbe17cfe8ad07-1403062491559.m3u8?crypt=4aa7f2e166&b=507&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=3cb1030d261d6b62ef7a773197c4202c&platid=1&splatid=101&proxy=1780921485,2007471020&m3v=1&mmsid=21141587&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.17330160085111856&pay=0&rateid=1000&gn=103&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://119.188.122.49/57/10/100/letv-uts/14/ver_00_14-16812912-avc-548421-aac-31999-2708000-199384147-f913f0fffb12ae0860ade1417de3dcaa-1398113426141.m3u8?crypt=17aa7f2e162&b=588&nlh=3072&nlt=45&bf=22&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092800&key=790cd7be6f574e1751626b681261fe05&platid=1&splatid=101&proxy=1020915111,2007471014&m3v=1&mmsid=2234409&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.568748218473047&pay=0&rateid=1000&gn=751&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://123.125.89.96/66/5/63/letv-uts/14/ver_00_14-22403709-avc-473431-aac-32003-1339520-86132952-e38ebc7ca9be59cb78744fbd0c600ebf-1402640069312.m3u8?crypt=60aa7f2e135&b=514&nlh=3072&nlt=45&bf=21&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403237400&key=0f71e43b24aa6854ff6455ac794ef0ea&platid=1&splatid=101&proxy=1780921488,2007471023&m3v=1&mmsid=21073154&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.14271857496351004&pay=0&rateid=1000&gn=103&buss=100&qos=4&cips=10.58.101.139","playlevel":4}];
				//obj.flvURL  = ["http://123.126.32.19:20080/lz/vip.flv"]
				//obj.flvURL  = ["http://61.240.146.217/64/31/25/bcloud/117069/19813226-avc-956180-_-77-9200-1125138-62b53a85a22aacad5914b7e98d65d5e3-1400733141638.letv?crypt=9aa7f2e379&b=978&nlh=3072&nlt=45&bf=31&p2p=1&video_type=flv&termid=1&tss=no&geo=CN-1-9-2&tm=1401798600&key=c1f25e7962c2f4871dc11e0ebbb31644&platid=2&splatid=203&proxy=1027062825,2007471021&mmsid=20776927&playid=0&vtype=17&cvid=964368828214&tag=flash&bcloud=S7&sign=bcloud_117069&pay=0&ostype=windows&hwtype=un&tn=0.14042971329763532&rateid=1300&gn=768&buss=6&qos=4&cips=10.58.100.118"]
				//obj.flvURL  = ["http://61.240.146.217/30/19/107/letv-uts/3767270-AVC-538156-AAC-31576-92040-6775895-5486fbfb18862172881954c0e6f95437-1369399417836.letv?crypt=9aa7f2e190&b=586&nlh=3072&nlt=45&bf=26&p2p=1&video_type=flv&termid=1&tss=no&geo=CN-1-9-2&tm=1401967800&key=774291c2a74404847187734d4d6dceb2&platid=2&splatid=203&proxy=1027062830,2007470964&mmsid=2575152&playid=0&vtype=16&cvid=392530372330&tag=flash&bcloud=S7&sign=bcloud_100349&pay=0&ostype=windows&hwtype=un&tn=0.08896564180031419&rateid=1000&gn=768&buss=6&qos=4&cips=10.58.101.48"];
				//obj.flvURL  = ["http://61.240.146.210/50/14/98/bcloud/16/12264930-avc-255218-aac-31569-61978-2318989-45dbb9d182590edc6170c5b6bb7ae750-1392259762464.letv?crypt=52aa7f2e94&b=297&nlh=3072&nlt=45&bf=25&p2p=1&video_type=flv&termid=1&tss=no&geo=CN-1-9-2&tm=1401970200&key=eec2266421a9f8ce06d6e56a6d74bd22&platid=2&splatid=203&proxy=2007470986,2071813012&mmsid=3959891&playid=0&vtype=1&cvid=1135925638034&tag=flash&bcloud=S7&sign=bcloud_115109&pay=0&ostype=windows&hwtype=un&tn=0.3225187626667321&rateid=350&gn=768&buss=6&qos=4&cips=10.58.101.139"]
				obj.flvNode = [751,750,751,750];
				obj.gslbURL = "http://g3.letv.cn/vod/v2/NzAvMzkvNTIvbGV0di11dHMvMTQvdmVyXzAwXzE0LTIyODY2MDU5LWF2Yy00NzUxNTYtYWFjLTMyMDIwLTIyOTQwMC0xNDgwMjc0Ni00NDYxYWZlZDc0MDVmYTU5ZTEyYzBiMmJjMjYxZDA2Yy0xNDAzMDUzMzIzMDU5Lm1wNA==?b=516&mmsid=21139331&tm=1403061997&key=a0a409fdda6e19acadf46b456a55f3bd&platid=1&splatid=101&playid=0&tss=ios&vtype=13&cvid=1135925638034&ctv=pc&m3v=1&termid=1&format=1&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&expect=3&tn=0.5244926633313298&pay=0&rateid=1000";
				obj.gslbURL = "http://g3.letv.cn/vod/v2/MzMvMi83MS9sZXR2LXV0cy8xNC92ZXJfMDBfMTYtMjQ2MDAwMTYtYXZjLTIyOTkyNS1hYWMtMzIwMDAtMjcwNjMyMC05MTYzNTk4Ni05NTQ2NzM3ZDk2NjU1ODA3NjI0YTVkYWFmZDA4OGM0YS0xNDA0OTA2MDAzODIzLm1wNA==?b=270&mmsid=21557652&tm=1406784193&key=0a8a155944150305ed9d0f74c87dde57&platid=1&splatid=101&playid=0&tss=ios&vtype=21&cvid=2010048044622&ctv=pc&m3v=1&termid=1&format=1&hwtype=un&ostype=MacOS10.9.4&tag=letv&sign=letv&expect=3&tn=0.17279291106387973&pay=1&iscpn=f9051&rateid=350";
				obj.startTime = 0;
				obj.groupName = "c37d6e971bfc7e6d3f583c3e4a60b39bf312ff";
				obj.testSpeed = 15;
				obj.geo 	  = "CN.1.0.2";
				obj.adRemainingTime = _adTime;
				obj.playType = "VOD";
			}
			else
			{
				obj.cdnInfo  = [{"location":"http://119.188.122.34/65/8/99/letv-uts/14/ver_00_16-25125397-avc-479953-aac-32000-2398200-156150329-9386e2a27254584130f5c64d1eeb3902-1405542546491.m3u8?crypt=82aa7f2e124&b=520&nlh=3072&nlt=45&bf=19&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1405939200&key=c8047cff94b329596d0fb8646f5a14cd&platid=1&splatid=101&proxy=2008840744,2007471022&m3v=1&mmsid=21654412&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.5687881587073207&pay=0&rateid=1000&gn=751&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://111.206.215.40/62/44/99/letv-uts/14/ver_00_14-22712053-avc-214981-aac-32001-6563375-209801413-f2a5a639fa08847d2f17ac03cadb6468-1402932404403.m3u8?crypt=67aa7f2e48&b=255&nlh=3072&nlt=45&bf=15&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403244000&key=d9c828fcbaa5826d429700c7bfd7bcdf&platid=1&splatid=101&proxy=1780921484,2007471019&m3v=1&mmsid=21118098&playid=0&vtype=21&cvid=1887502251070&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.6035838788375258&pay=1&iscpn=f9051&rateid=350&gn=769&buss=16&qos=5&cips=10.58.104.231&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://61.240.146.210/64/40/47/letv-uts/14/ver_00_14-22403213-avc-470443-aac-32003-1351760-86412464-18e502f9841bc968bc21be941aaf9888-1402638103216.m3u8?crypt=92aa7f2e195&b=511&nlh=3072&nlt=45&bf=31&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=add7c8817e5a632b43df5d5b8c7a8554&platid=1&splatid=101&proxy=1027062828,2007471021&m3v=1&mmsid=21073072&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.9688555095344782&pay=0&rateid=1000&gn=768&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://123.125.89.93/63/8/87/letv-uts/14/ver_00_14-22880946-avc-465606-aac-32000-2500746-158546267-030ca1ee10aaae3ac05fbe17cfe8ad07-1403062491559.m3u8?crypt=4aa7f2e166&b=507&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=3cb1030d261d6b62ef7a773197c4202c&platid=1&splatid=101&proxy=1780921485,2007471020&m3v=1&mmsid=21141587&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.17330160085111856&pay=0&rateid=1000&gn=103&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://119.188.122.49/57/10/100/letv-uts/14/ver_00_14-16812912-avc-548421-aac-31999-2708000-199384147-f913f0fffb12ae0860ade1417de3dcaa-1398113426141.m3u8?crypt=17aa7f2e162&b=588&nlh=3072&nlt=45&bf=22&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092800&key=790cd7be6f574e1751626b681261fe05&platid=1&splatid=101&proxy=1020915111,2007471014&m3v=1&mmsid=2234409&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.568748218473047&pay=0&rateid=1000&gn=751&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				obj.flvNode = [751,750,751,750];
				obj.gslbURL = "http://g3.letv.cn/vod/v2/NzAvMzkvNTIvbGV0di11dHMvMTQvdmVyXzAwXzE0LTIyODY2MDU5LWF2Yy00NzUxNTYtYWFjLTMyMDIwLTIyOTQwMC0xNDgwMjc0Ni00NDYxYWZlZDc0MDVmYTU5ZTEyYzBiMmJjMjYxZDA2Yy0xNDAzMDUzMzIzMDU5Lm1wNA==?b=516&mmsid=21139331&tm=1403061997&key=a0a409fdda6e19acadf46b456a55f3bd&platid=1&splatid=101&playid=0&tss=ios&vtype=13&cvid=1135925638034&ctv=pc&m3v=1&termid=1&format=1&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&expect=3&tn=0.5244926633313298&pay=0&rateid=1000";
				obj.startTime = 0;
				obj.groupName = "c37d6e971bfc7e6d3f583c3e4a60b39bf312ff";
				obj.testSpeed = 15;
				obj.geo 	  = "CN.1.0.2";
				obj.adRemainingTime = _adTime;
				obj.playType = "CONTINUITY_VOD";
			}
			
			tempBeginPlayTime = getTime();
			_ns.play(obj);
			
			//_ns.pause();
			//
			_volume = _volume ? _volume : 0.5;
			_st=_ns.soundTransform;
			_st.volume=_volume;			
			_ns.soundTransform=_st;
			
			GlobalReference.version=_ns.version;
			/**方块控制器*/
			//RectManager.dataManager=(_ns as Object).getManager();
			
			GlobalReference.HLSstatisticManager.reset(_ns);
			//
			p2pTestStatistic=new P2PTestStatistic();
			p2pTestStatistic.addEventListener(P2PTestStatisticEvent.P2P_TEST_STATISTIC_TIMER,p2pTestStatistic_P2P_TEST_STATISTIC_TIMER);
			p2pTestStatistic.init(_ns);			
			
		}
		private var ifSendNextURL:int=0;
		private var sendNextURLIdx:int = 0;
		private function sendNextURL():void
		{
			ifSendNextURL++;
			if(_ns && ifSendNextURL==30)
			{
				switch(sendNextURLIdx)
				{
					case 0:
						_ns.setNextCdnUrl(["http://111.206.215.40/62/44/99/letv-uts/14/ver_00_14-22712053-avc-214981-aac-32001-6563375-209801413-f2a5a639fa08847d2f17ac03cadb6468-1402932404403.m3u8?crypt=67aa7f2e48&b=255&nlh=3072&nlt=45&bf=15&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403244000&key=d9c828fcbaa5826d429700c7bfd7bcdf&platid=1&splatid=101&proxy=1780921484,2007471019&m3v=1&mmsid=21118098&playid=0&vtype=21&cvid=1887502251070&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.6035838788375258&pay=1&iscpn=f9051&rateid=350&gn=769&buss=16&qos=5&cips=10.58.104.231&keep_stopp=on"]);
						break;
					case 1:
						_ns.setNextCdnUrl(["http://61.240.146.210/64/40/47/letv-uts/14/ver_00_14-22403213-avc-470443-aac-32003-1351760-86412464-18e502f9841bc968bc21be941aaf9888-1402638103216.m3u8?crypt=92aa7f2e195&b=511&nlh=3072&nlt=45&bf=31&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=add7c8817e5a632b43df5d5b8c7a8554&platid=1&splatid=101&proxy=1027062828,2007471021&m3v=1&mmsid=21073072&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.9688555095344782&pay=0&rateid=1000&gn=768&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on"]);
						break;
					case 2:
						_ns.setNextCdnUrl(["http://123.125.89.93/63/8/87/letv-uts/14/ver_00_14-22880946-avc-465606-aac-32000-2500746-158546267-030ca1ee10aaae3ac05fbe17cfe8ad07-1403062491559.m3u8?crypt=4aa7f2e166&b=507&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=3cb1030d261d6b62ef7a773197c4202c&platid=1&splatid=101&proxy=1780921485,2007471020&m3v=1&mmsid=21141587&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.17330160085111856&pay=0&rateid=1000&gn=103&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on"]);
						break;
					case 3:
						_ns.setNextCdnUrl(["http://60.217.237.169/65/53/90/letv-uts/14/ver_00_14-22828886-avc-479813-aac-32002-2309200-150318485-a624a435decfe4009175a922243b35dc-1403029782143.m3u8?crypt=59aa7f2e147&b=520&nlh=3072&nlt=45&bf=23&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403086800&key=df2bb026be725226b91427ae50d324c8&platid=1&splatid=101&proxy=1872838953,2007471022&m3v=1&mmsid=21133313&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.9869421254843473&pay=0&rateid=1000&gn=750&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on"]);
						
						break;
				}
				
				
			}
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
		public function seek(offset:Number):void
		{
			if(_info && _ready)
			{
				_isSeeking=true;
			}
			var seekTime:Number = offset
			if( GlobalReference.type == "LIVE" )
			{
				seekTime = Math.round((_time + int(offset*60*60)));
				trace(this+"seekTime = "+seekTime);
			}
			_ns.seek(seekTime);
			resume();
		}
		//--------------------lz
		protected function OnAnalysisSuccess(e:AnalysisEvent):void
		{
			var obj:Object = e.info as Object;
			_flvNodeArray = obj.flvNodeArray;
			_play(obj);
			
			for(var i:String in obj)
			{
				trace(i+" = "+obj[i]);
			}/**/
			
			clearAnalysis();
		}
		protected function OnAnalysisError(e:AnalysisEvent):void
		{
			
			/*for(var i:String in e.info)
			{
			trace(i+" = "+e.info[i]);
			}*/
			_play();
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
			
			RectManager.dataManager = null;
			
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
			
			isAdTimeOver = false;
			
			_startTime=0;
			tempBeginPlayTime = 0;
			
			if(_ns)
			{
				/*_ns.client=null;
				_ns.removeEventListener("streamStatus",_streamStatus);
				_ns.removeEventListener("p2pStatus",_streamStatus);
				_ns.removeEventListener("p2pAllOver",_streamStatus);*/	
				/*_ns.removeEventListener("streamLocalStatus",_streamLocalStatus);
				_ns.removeEventListener("p2pLocalStatus",_streamLocalStatus);
				_ns.removeEventListener("p2pLocalAllOver",_streamLocalStatus);*/
				ifSendNextURL = 0;
				var obj:Object = new Object();
				sendNextURLIdx++;
				switch(sendNextURLIdx)
				{
					case 1:
						obj.cdnInfo=[{"location":"http://111.206.215.40/62/44/99/letv-uts/14/ver_00_14-22712053-avc-214981-aac-32001-6563375-209801413-f2a5a639fa08847d2f17ac03cadb6468-1402932404403.m3u8?crypt=67aa7f2e48&b=255&nlh=3072&nlt=45&bf=15&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403244000&key=d9c828fcbaa5826d429700c7bfd7bcdf&platid=1&splatid=101&proxy=1780921484,2007471019&m3v=1&mmsid=21118098&playid=0&vtype=21&cvid=1887502251070&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.6035838788375258&pay=1&iscpn=f9051&rateid=350&gn=769&buss=16&qos=5&cips=10.58.104.231&keep_stopp=on","playlevel":4}];
						break;
					case 2:
						obj.cdnInfo=[{"location":"http://61.240.146.210/64/40/47/letv-uts/14/ver_00_14-22403213-avc-470443-aac-32003-1351760-86412464-18e502f9841bc968bc21be941aaf9888-1402638103216.m3u8?crypt=92aa7f2e195&b=511&nlh=3072&nlt=45&bf=31&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=add7c8817e5a632b43df5d5b8c7a8554&platid=1&splatid=101&proxy=1027062828,2007471021&m3v=1&mmsid=21073072&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.9688555095344782&pay=0&rateid=1000&gn=768&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
						break;
					case 3:
						obj.cdnInfo=[{"location":"http://123.125.89.93/63/8/87/letv-uts/14/ver_00_14-22880946-avc-465606-aac-32000-2500746-158546267-030ca1ee10aaae3ac05fbe17cfe8ad07-1403062491559.m3u8?crypt=4aa7f2e166&b=507&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=3cb1030d261d6b62ef7a773197c4202c&platid=1&splatid=101&proxy=1780921485,2007471020&m3v=1&mmsid=21141587&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.17330160085111856&pay=0&rateid=1000&gn=103&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
						break;
					case 4:
						obj.cdnInfo=[{"location":"http://http://119.188.122.49/57/10/100/letv-uts/14/ver_00_14-16812912-avc-548421-aac-31999-2708000-199384147-f913f0fffb12ae0860ade1417de3dcaa-1398113426141.m3u8?crypt=17aa7f2e162&b=588&nlh=3072&nlt=45&bf=22&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092800&key=790cd7be6f574e1751626b681261fe05&platid=1&splatid=101&proxy=1020915111,2007471014&m3v=1&mmsid=2234409&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.568748218473047&pay=0&rateid=1000&gn=751&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
						sendNextURLIdx = 0;
						break;
				}
				//obj.cdnInfo  = [{"location":"http://60.217.237.169/65/53/90/letv-uts/14/ver_00_14-22828886-avc-479813-aac-32002-2309200-150318485-a624a435decfe4009175a922243b35dc-1403029782143.m3u8?crypt=59aa7f2e147&b=520&nlh=3072&nlt=45&bf=23&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403086800&key=df2bb026be725226b91427ae50d324c8&platid=1&splatid=101&proxy=1872838953,2007471022&m3v=1&mmsid=21133313&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.9869421254843473&pay=0&rateid=1000&gn=750&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://111.206.215.40/62/44/99/letv-uts/14/ver_00_14-22712053-avc-214981-aac-32001-6563375-209801413-f2a5a639fa08847d2f17ac03cadb6468-1402932404403.m3u8?crypt=67aa7f2e48&b=255&nlh=3072&nlt=45&bf=15&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403244000&key=d9c828fcbaa5826d429700c7bfd7bcdf&platid=1&splatid=101&proxy=1780921484,2007471019&m3v=1&mmsid=21118098&playid=0&vtype=21&cvid=1887502251070&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.6035838788375258&pay=1&iscpn=f9051&rateid=350&gn=769&buss=16&qos=5&cips=10.58.104.231&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://61.240.146.210/64/40/47/letv-uts/14/ver_00_14-22403213-avc-470443-aac-32003-1351760-86412464-18e502f9841bc968bc21be941aaf9888-1402638103216.m3u8?crypt=92aa7f2e195&b=511&nlh=3072&nlt=45&bf=31&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=add7c8817e5a632b43df5d5b8c7a8554&platid=1&splatid=101&proxy=1027062828,2007471021&m3v=1&mmsid=21073072&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&tn=0.9688555095344782&pay=0&rateid=1000&gn=768&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://123.125.89.93/63/8/87/letv-uts/14/ver_00_14-22880946-avc-465606-aac-32000-2500746-158546267-030ca1ee10aaae3ac05fbe17cfe8ad07-1403062491559.m3u8?crypt=4aa7f2e166&b=507&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092200&key=3cb1030d261d6b62ef7a773197c4202c&platid=1&splatid=101&proxy=1780921485,2007471020&m3v=1&mmsid=21141587&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.17330160085111856&pay=0&rateid=1000&gn=103&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				//obj.cdnInfo  = [{"location":"http://119.188.122.49/57/10/100/letv-uts/14/ver_00_14-16812912-avc-548421-aac-31999-2708000-199384147-f913f0fffb12ae0860ade1417de3dcaa-1398113426141.m3u8?crypt=17aa7f2e162&b=588&nlh=3072&nlt=45&bf=22&p2p=1&video_type=mp4&termid=1&tss=ios&geo=CN-1-9-2&tm=1403092800&key=790cd7be6f574e1751626b681261fe05&platid=1&splatid=101&proxy=1020915111,2007471014&m3v=1&mmsid=2234409&playid=0&vtype=13&cvid=1135925638034&ctv=pc&hwtype=un&ostype=Windows7&tag=letv&sign=letv&tn=0.568748218473047&pay=0&rateid=1000&gn=751&buss=100&qos=4&cips=10.58.101.139&keep_stopp=on","playlevel":4}];
				obj.flvNode = [751,750,751,750];
				obj.gslbURL = "http://g3.letv.cn/vod/v2/NzAvMzkvNTIvbGV0di11dHMvMTQvdmVyXzAwXzE0LTIyODY2MDU5LWF2Yy00NzUxNTYtYWFjLTMyMDIwLTIyOTQwMC0xNDgwMjc0Ni00NDYxYWZlZDc0MDVmYTU5ZTEyYzBiMmJjMjYxZDA2Yy0xNDAzMDUzMzIzMDU5Lm1wNA==?b=516&mmsid=21139331&tm=1403061997&key=a0a409fdda6e19acadf46b456a55f3bd&platid=1&splatid=101&playid=0&tss=ios&vtype=13&cvid=1135925638034&ctv=pc&m3v=1&termid=1&format=1&hwtype=un&ostype=Windows7&tag=letv&sign=letv_tv&expect=3&tn=0.5244926633313298&pay=0&rateid=1000";
				obj.startTime = 0;
				obj.groupName = "c37d6e971bfc7e6d3f583c3e4a60b39bf312ff";
				obj.testSpeed = 15;
				obj.geo 	  = "CN.1.0.2";
				obj.adRemainingTime = _adTime;
				obj.playType = "CONTINUITY_VOD";
				_ns.play(obj);
				tempBeginPlayTime = getTime();
				//_ns.close();
				//_ns = null;
			}
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
					if(_ready)
					{
						if(_adTime-( getTime()-tempBeginPlayTime )/1000 <= 0)
						{
							_ns.resume();
							_isSeeking=false;
							changeState(PlayerState.PLAYING);
						}
						else
						{
							_ns.pause();
						}
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
		private function getTime():Number
		{
			return (new Date()).time;
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
				case "P2P.WebSocket.States" :
					RectManager.debug3('<FONT  COLOR="#ff00ff" FACE="Courier New" SIZE="11">SocketInfo, '+event.info.info+'</FONT>');
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
		private var tempBeginPlayTime:Number = 0;
		protected function _timer_TIMER(event:TimerEvent):void{
			adTimeOver();
			
			sendNextURL();
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
			if(_ns.bytesTotal > 0)
			{
				var loaded:Number= _ns.bytesLoaded/_ns.bytesTotal;
			
				if(_percentLoaded!=loaded)
				{
					_percentLoaded=loaded;
					//trace("loaded = ",loaded)
					dispatchEvent(new PlayerEvent(PlayerEvent.PROGRESS,loaded));
					
				}
			}
		}
		private var isAdTimeOver:Boolean = false;
		private var isCDNInfo:Boolean = false;
		protected function adTimeOver():void
		{			
			if(isAdTimeOver == false )
			{				
				var obj:Object = new Object();
				obj.name = "adTime";
				obj.info = Math.ceil(_adTime-( getTime()-tempBeginPlayTime )/1000);
				P2PInfoManager.p2pInfoArea.p2pInfo(obj);
				
				if(_adTime-( getTime()-tempBeginPlayTime )/1000 <= 0)
				{
					_ns.resume();
					isAdTimeOver = true;
				}
			}
			/*if( isCDNInfo == false && _adTime-( getTime()-tempBeginPlayTime )/1000 <= 10 )
			{
				isCDNInfo = true
				var arr:Array = [{"location":"http://119.188.122.83/39/50/38/letv-uts/14/ver_00_14-14023365-avc-492007-aac-32000-8060125-536670646-86f9fd1af26a8e4946f7e65731a09131-1394889741590.m3u8?crypt=79aa7f2e171&b=537&nlh=3072&nlt=45&bf=26&p2p=1&video_type=mp4&platid=1&splatid=101&its=12474043&termid=1&tss=ios&geo=CN-1-0-2&opck=1&check=0&tm=1397044200&key=d33bd94f8b299f3a51ef88b01514e0d5&proxy=1020915145,2007487122&m3v=1&mmsid=3750657&playid=0&vtype=16&ctv=pc&hwtype=un&ostype=MacOS10.9.2&tag=letv&sign=letv&tn=0.22324622189626098&pay=1&iscpn=f9051&rateid=1000&gn=751&cips=10.58.101.139&buss=16&qos=5&lgn=letv","playlevel":4}];
				_ns.set_CDN_INFO(arr);
			}*/
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
		protected function onPlayStatus(obj:Object):void 
		{
			trace(this,"onPlayStatus");
			for(var param:String in obj)
			{
				trace(this,param+"<>"+obj[param]);
			}
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