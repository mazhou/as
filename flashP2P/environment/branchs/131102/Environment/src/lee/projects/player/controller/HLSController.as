package lee.projects.player.controller{
	import com.p2p.utils.Base64;
	
	import fl.controls.Button;
	
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.FullScreenEvent;
	import flash.events.MouseEvent;
	import flash.net.SharedObject;
	import flash.system.Security;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.Mouse;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	import flash.text.TextField;
	
	import gs.TweenLite;
	//	import gs.easing.*;
	
	import lee.bases.BaseEvent;
	import lee.commons.DblClickSprite;
	import lee.managers.P2PInfoManager;
	import lee.managers.RectManager;
	import lee.player.Player;
	import lee.projects.player.GlobalReference;
	import lee.projects.player.events.ControlbarEvent;
	//import lee.projects.player.providers.LetvP2PVodProvider;
	import lee.projects.player.providers.HLSProvider;
	import lee.projects.player.utils.DataLoader;
	import lee.projects.player.view.Controlbar;
	import lee.projects.player.view.Infobox;
	import lee.projects.player.view.LogArea;
	import lee.projects.player.view.P2PInfoArea;
	
	
	public class HLSController extends EventDispatcher{
		public static const CONFIG:XML=<root><volume>0.5</volume></root>;
		public static const PLAYERNAME:String="LetvVideoPlayer";
		//public static const VERSION:String="1.0.0.0";
		protected var _logArea:LogArea;
		protected var _rectLog:RectLog;
		protected var _player:Player;
		protected var _infobox:Infobox;
		protected var _controlbar:Controlbar;
		
		protected var _sharedObject:SharedObject;
		protected var _config:XML;
		
		protected var _screenMode:String="normal";
		protected var _hideControlbarID:int;
		
		protected var _loader:DataLoader;
		//protected var _btnArea:BtnArea;
		protected var _isNewVid:Boolean;
		protected var _p2pInfoArea:P2PInfoArea;
		
		public function HLSController() 
		{
		}
		public function initialize():void{
			
			var initObject:Object=new Object();
			initObject.ch="test_p2p";
			initObject.cid="";
			initObject.uname="";
			initObject.ver=GlobalReference.version;
			initObject.ref="";
			initObject.auto="1";
			initObject.ru="";
			initObject.videorate="";
			initObject.ftype="";
			initObject.uid="";
			GlobalReference.HLSstatisticManager.playerInit(initObject);
			
			
			_sharedObject=SharedObject.getLocal("lee_letv_player_config","/");
			if(_sharedObject.size!=0)
			{
				_config=XML(_sharedObject.data.config);
			}
			else
			{
				_config=Controller.CONFIG.copy();
				_sharedObject.data.config=_config;
				_sharedObject.flush();
			}
			
			
			_logArea=new LogArea();
			_logArea.setSize(300,400);
			_logArea.addEventListener(P2PTestStatisticEvent.GET_VID,getVid);
			
			//lz
			_p2pInfoArea = new P2PInfoArea();
			_p2pInfoArea.setSize(400,400);
			P2PInfoManager.p2pInfoArea = _p2pInfoArea;
			P2PInfoManager.p2pInfoArea.loadVInfo = loadVInfo;
			
			
			//_player=new Player([new LetvP2PVodProvider()]);
			_player=new Player([new HLSProvider()]);
			_player.addEventListener(DblClickSprite.DOUBLE_CLICK,_player_DOUBLE_CLICK);
			
			
			/*_rectLog=new RectLog();
			_rectLog.setSize(400,400)*/			
			
			
			_infobox=new Infobox(_player,_config);
			
			_controlbar=new Controlbar(_player,_config);
			_controlbar.setPanel(_p2pInfoArea);
			_controlbar.addEventListener(ControlbarEvent.VOLUME_CHANGE,_controlbar_VOLUME_CHANGE);
			_controlbar.addEventListener(ControlbarEvent.FULLSCREENBTN_CLICK,_controlbar_FULLSCREENBTN_CLICK);
			_controlbar.addEventListener(ControlbarEvent.NORMALSCREENBTN_CLICK,_controlbar_NORMALSCREENBTN_CLICK);
			
			var rootMenu:ContextMenu=new ContextMenu();
			rootMenu.hideBuiltInItems();
			rootMenu.customItems.push(new ContextMenuItem(Controller.PLAYERNAME+" "+GlobalReference.version,false,false));
			
			GlobalReference.root.contextMenu=rootMenu;
			
			GlobalReference.root.addChild(_logArea);
			GlobalReference.root.addChild(_player);
			GlobalReference.root.addChild(_infobox);
			GlobalReference.root.addChild(_controlbar);
			
			GlobalReference.root.addChild(_p2pInfoArea);
			/*GlobalReference.root.addChild(_rectLog);*/
			GlobalReference.stage.stageFocusRect=false;
			GlobalReference.stage.align=StageAlign.TOP_LEFT;
			GlobalReference.stage.scaleMode=StageScaleMode.NO_SCALE;
			GlobalReference.stage.addEventListener(FullScreenEvent.FULL_SCREEN,stage_FULL_SCREEN);
			GlobalReference.stage.addEventListener(Event.RESIZE,stage_RESIZE);
			GlobalReference.stage.dispatchEvent(new Event(Event.RESIZE));
			
			_loader=new DataLoader();
			_loader.addEventListener(DataLoader.COMPLETE,_loader_COMPLETE);
			//startup();
			//startupTest();
			
			//test();
			//JStest();
			playByG3()
		}
		private var _flvVid:String = "";
		private function test():void
		{//1559584  1325472  1675169  1675121 1033867 1033864
			//trace(_controlbar.vidText.text);
			if(P2PInfoManager.p2pInfoArea.serverInfoPanel.vid != "" && P2PInfoManager.p2pInfoArea.serverInfoPanel.vid != _flvVid)
			{
				//_flvVid = P2PInfoManager.p2pInfoArea.serverInfoPanel.vid;
				loadVInfo(P2PInfoManager.p2pInfoArea.serverInfoPanel.vid);
			}/**/			
		}
		
		private function JStest():void
		{
			var vidString:String=String(GlobalReference.root.loaderInfo.parameters["dispatch"]);
			loadVInfo(vidString);
		}
		
		private function getVid(e:P2PTestStatisticEvent):void
		{
			var vid:String=e.info as String;
			loadVInfo(vid);
		}
		
		public function loadVInfo(vid:String):void{
			
			if(vid != _flvVid)
			{
				_flvVid = vid;
				_loader.load("http://www.letv.com/v_xml/"+vid+".xml","vinfo");
				
				P2PInfoManager.p2pInfoArea.clearAll();
			}
			
		}
		public function playByG3(g3:String="http://g3.letv.cn/28/24/68/letv-uts/1289903-AVC-514481-AAC-124402-246247-20386466-dc4a6b1e89946853cdcc2e5aeec4392b-1355296253105.flv?b=662&mmsid=2101170&tm=1359432662&key=7bc0bd2d910a13255331bc91aa36daa7&format=1&tag=letv&sign=letv&expect=3&rateid=1000"):void{
			var videoObject:Object=new Object();
			videoObject.type="letvP2PVod";
			videoObject.dispatch=g3;
			var starttime:Number=_player.time;
			initRectLog();
			if(!_isNewVid)
			{
				videoObject.start=starttime;
			}
			_player.play(videoObject);
			_isNewVid=false;
		}
		private function _loader_COMPLETE(event:BaseEvent):void{
			if(String(event.info.type)=="vinfo")
			{
				var infoxml:XML=XML(event.info.data);
				var g3info:String=infoxml.playurl[0];
				var ary:Array=g3info.split("&");
				var low:String=getG3URL(decodeURIComponent(String(ary[0]).slice(4)));
				var high:String=(ary.length==2)?getG3URL(decodeURIComponent(String(ary[1]).slice(5))):"";
				//trace("low=",low,"high=",high)
				g3init(low,high);
				//playByG3(low);
			}
		}
		private function getG3URL(url:String):String{
			var ary1:Array=url.split("&br");
			var ary2:Array=String(ary1[0]).split("df=");
			return "http://g3.letv.cn/"+ary2[ary2.length-1]+"?format=1&expect=1"
		}
		
		
		protected function startup():void{
			var videoObject:Object=new Object();
			videoObject.type="letvP2PVod";
			videoObject.dispatch=Base64.decode(String(GlobalReference.root.loaderInfo.parameters["dispatch"]));
			videoObject.start="0";
			_player.play(videoObject);
		}
		protected function startupTest():void{
			var videoObject:Object=new Object();
			videoObject.type="letvP2PVod";
			//videoObject.dispatch="http://g3.letv.cn/12/28/35/letv-uts/1336472731-AVC-313000-AAC-58248-2775869-134739592-1f97fee7935fe049f8ac2158330dde1d-1336472731.flv?format=1&expect=3&b=388";
			videoObject.dispatch="http://g3.letv.cn/15/46/77/letv-uts/1335176759-AVC-245124-AAC-54091-2705304-106384911-0b84d2d31ab1e83a8582767b705e76be-1335176759.flv?format=1&expect=1&b=384"
			//videoObject.dispatch="http://g3.letv.cn/2/45/16/2021036333.0.flv?format=1&b=820&expect=3&host=www_letv_com&tag=letv&sign=free"
			////////////////////////////////////http://g3.letv.cn/2/45/16/2021036333.0.flv
			//videoObject.dispatch="http://g3.letv.com/15/1/76/letv-uts/1336383898-AVC-311957-AAC-58226-2644630-127988276-910d5095f4c89a967c12329f80fdd664-1336383898.flv?format=1&expect=1"
			//videoObject.dispatch="http://g3.letv.cn/15/46/77/letv-uts/1335176759-AVC-245124-AAC-54091-2705304-106384911-0b84d2d31ab1e83a8582767b705e76be-1335176759.flv?format=1&expect=1&b=384"
			//videoObject.dispatch="http://g3.letv.cn/13/44/58/letv-uts/1335665271-AVC-711144-AAC-54690-5961995-590522261-f057cb5b14cc9ad81a4f90f1e190665f-1335665271.flv?format=1&b=792&expect=3&host=www_letv_com&tag=letv&sign=free"
			//videoObject.dispatch="http://g3.letv.cn/20/47/86/letv-uts/1339420404-AVC-535530-AAC-31887-5064033-372978098-f57073ae8b8d6ac181fd596eb994d3f2-1339420404.flv?format=1&expect=3&b=1700"
			//videoObject.dispatch="http://g3.letv.cn/20/30/79/letv-uts/1342111096-AVC-935931-AAC-63100-9189128-1184365569-b2a95e7c52467271578130d9fb190e33-1342111096.flv?format=1&expect=1&b=1031"
			videoObject.start="0";
			_player.play(videoObject);
			
			initRectLog();
			//_player.seek(100);
		}
		
		protected function g3init(str1:String="",str2:String="",str3:String=""):void
		{
			//var str1:String="http://g3.letv.cn/15/46/77/letv-uts/1335176759-AVC-245124-AAC-54091-2705304-106384911-0b84d2d31ab1e83a8582767b705e76be-1335176759.flv?format=1&expect=1&b=384";
			//var str2:String="http://g3.letv.com/6/26/80/206724949.0.flv?format=1&expect=1";
			//var str3:String="http://g3.letv.cn/12/28/35/letv-uts/1336472731-AVC-313000-AAC-58248-2775869-134739592-1f97fee7935fe049f8ac2158330dde1d-1336472731.flv?format=1&expect=3&b=388";
			_isNewVid=true;
			
			/*if(_btnArea)
			{
			_logArea.removeChild(_btnArea);
			}
			
			_btnArea=new BtnArea(playByG3,str1,str2,str3);
			_logArea.addChild(_btnArea);*/
			_controlbar.sethd(playByG3,str1,str2);
		}
		
		protected function initRectLog():void
		{
			if(_rectLog)
			{
				_rectLog.stop();
				GlobalReference.root.removeChild(_rectLog);
			}
			
			
			_rectLog=new RectLog();
			
			GlobalReference.root.addChild(_rectLog);
			_rectLog.x=2;
			_rectLog.y=_h-200;
			_rectLog.setSize(_w-_logArea.width,100);
			
			GlobalReference.root.addChild(_p2pInfoArea);
		}
		
		protected function stage_FULL_SCREEN(event:FullScreenEvent):void{
			if(event.fullScreen)
			{
				_screenMode="fullScreen";
				_controlbar.setBtnsVisible("normalScreenBtn");
			}
			else
			{
				_screenMode="normal";
				_controlbar.setBtnsVisible("fullScreenBtn");
			}
			GlobalReference.stage.dispatchEvent(new Event(Event.RESIZE));
		}
		
		private var _w:int=0;
		private var _h:int=0;
		protected function stage_RESIZE(event:Event):void{			
			var w:int=GlobalReference.stage.stageWidth;
			var h:int=GlobalReference.stage.stageHeight;
			
			//w=w-_logArea.width;
			
			
			/*	_rectLog.x=10;
			_rectLog.y=410;*/
			
			
			/*if(_screenMode=="fullScreen")
			{
			h+=_controlbar.height;
			}*/
			_w=w;
			_h=h;
			_player.setSize(w-_logArea.width,h-200-_controlbar.height);
			_infobox.setSize(w-_logArea.width,h-200-_controlbar.height);
			_controlbar.y=h-200-_controlbar.height-2;
			_controlbar.width=w-_logArea.width;
			_logArea.setSize(300,h);
			_logArea.x=w-_logArea.width;
			//_logArea.height=h;
			
			if(_rectLog)
			{
				_rectLog.x=2;
				_rectLog.y=_h-200;
				_rectLog.setSize(w-_logArea.width,200);
			}
			
		}
		protected function _player_DOUBLE_CLICK(event:BaseEvent):void{
			if(GlobalReference.stage.displayState=="fullScreen")
			{
				GlobalReference.stage.displayState="normal";
			}
			else
			{
				GlobalReference.stage.displayState="fullScreen";
				GlobalReference.statisticManager.playerFullScreen();
			}
		}
		protected function _controlbar_VOLUME_CHANGE(event:ControlbarEvent):void{
			_config.volume[0]=String(event.info);
		}
		protected function _controlbar_FULLSCREENBTN_CLICK(event:ControlbarEvent):void{
			GlobalReference.stage.displayState="fullScreen";
			GlobalReference.statisticManager.playerFullScreen();
		}
		protected function _controlbar_NORMALSCREENBTN_CLICK(event:ControlbarEvent):void{
			GlobalReference.stage.displayState="normal";
		}
	}
}
