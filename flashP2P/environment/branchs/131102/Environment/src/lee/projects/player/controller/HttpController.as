package lee.projects.player.controller{
//	import P2PTestStatisticEvent.*;
	
//	import RectLog.*;
	
	import com.p2p.utils.Base64;
	
	import fl.controls.Button;
	
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.FullScreenEvent;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.net.SharedObject;
	import flash.system.Security;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.Mouse;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import gs.TweenLite;
	import gs.easing.*;
	
	import lee.bases.BaseEvent;
	import lee.commons.DblClickSprite;
	import lee.managers.P2PInfoManager;
	import lee.managers.RectManager;
	import lee.player.Player;
	import lee.projects.player.GlobalReference;
	import lee.projects.player.events.ControlbarEvent;
	import lee.projects.player.providers.LetvHttpLiveProvider;
	import lee.projects.player.providers.LetvP2PVodProvider;
	import lee.projects.player.utils.DataLoader;
	import lee.projects.player.view.Controlbar;
	import lee.projects.player.view.Infobox;
	import lee.projects.player.view.LiveControlbar;
	import lee.projects.player.view.LogArea;
	import lee.projects.player.view.P2PInfoArea;
	
	public class HttpController extends EventDispatcher{
		public static const CONFIG:XML=<root><volume>0.5</volume></root>;
		public static const PLAYERNAME:String="LetvVideoPlayer";
		//public static const VERSION:String="1.0.0.0";
		protected var _logArea:LogArea;
		protected var _rectLog:RectLog;
		protected var _player:Player;
		protected var _infobox:Infobox;
		protected var _controlbar:Controlbar;
		protected var _liveControlbar:LiveControlbar;
		
		protected var _sharedObject:SharedObject;
		protected var _config:XML;
		
		protected var _screenMode:String="normal";
		protected var _hideControlbarID:int;
		
		protected var _loader:DataLoader;
		//protected var _btnArea:BtnArea;
		protected var _isNewVid:Boolean;
		protected var _p2pInfoArea:P2PInfoArea;
		
		public function HttpController() {
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
			GlobalReference.statisticManager.playerInit(initObject);
			
			
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
			/*_logArea.addEventListener(P2PTestStatisticEvent.GET_VID,getVid);*/
			
			//lz
			_p2pInfoArea = new P2PInfoArea();
			_p2pInfoArea.setSize(400,400);
			P2PInfoManager.p2pInfoArea = _p2pInfoArea;
			P2PInfoManager.p2pInfoArea.loadVInfo = loadVInfo;
			
			
			_player=new Player([new LetvHttpLiveProvider()]);
			_player.addEventListener(DblClickSprite.DOUBLE_CLICK,_player_DOUBLE_CLICK);
			
			/*_rectLog=new RectLog();
			_rectLog.setSize(400,400)*/
			
			
			
			
			_infobox=new Infobox(_player,_config);
			
		/*	_controlbar=new Controlbar(_player,_config);
			_controlbar.setPanel(_p2pInfoArea);
			_controlbar.addEventListener(ControlbarEvent.VOLUME_CHANGE,_controlbar_VOLUME_CHANGE);
			_controlbar.addEventListener(ControlbarEvent.FULLSCREENBTN_CLICK,_controlbar_FULLSCREENBTN_CLICK);
			_controlbar.addEventListener(ControlbarEvent.NORMALSCREENBTN_CLICK,_controlbar_NORMALSCREENBTN_CLICK);*/
			
			
			_liveControlbar=new LiveControlbar(_player,_config);
			_liveControlbar.setPanel(_p2pInfoArea);
			_liveControlbar.addEventListener(ControlbarEvent.VOLUME_CHANGE,_controlbar_VOLUME_CHANGE);
			_liveControlbar.addEventListener(ControlbarEvent.FULLSCREENBTN_CLICK,_controlbar_FULLSCREENBTN_CLICK);
			_liveControlbar.addEventListener(ControlbarEvent.NORMALSCREENBTN_CLICK,_controlbar_NORMALSCREENBTN_CLICK)
			
			var rootMenu:ContextMenu=new ContextMenu();
			rootMenu.hideBuiltInItems();
			rootMenu.customItems.push(new ContextMenuItem(Controller.PLAYERNAME+" "+GlobalReference.version,false,false));
			
			GlobalReference.root.contextMenu=rootMenu;
			
			GlobalReference.root.addChild(_player);
			GlobalReference.root.addChild(_infobox);
			GlobalReference.root.addChild(_logArea);
			/*GlobalReference.root.addChild(_controlbar);*/
			GlobalReference.root.addChild(_liveControlbar)
			
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
			httpTest();
		}
		private function test():void
		{//1559584  1513935
			loadVInfo("1631688");
		}
		private function httpTest(str:String=""):void
		{
			var videoObject:Object=new Object();
			//videoObject.url="http://123.126.32.19:8888/live/tianjin/2012091817/00.xml";
			//videoObject.flvURL="http://123.126.32.19:1935/live/tianjin/desc.xml";
			//videoObject.gslb = "http://live.gslb.letv.com/gslb?stream_id=jiangsu&tag=live&ext=xml&format=1&expect=2";
//			videoObject.gslb = "http://live.gslb.letv.com/gslb?stream_id=cctv1&tag=live&ext=xml&format=1&expect=2";
			if(str=="")
			{
				videoObject.gslb = "http://live.gslb.letv.com/gslb?stream_id=cctv5_1300&tag=live&ext=xml&format=1&expect=2";
			}else
			{
				videoObject.gslb = "http://live.gslb.letv.com/gslb?stream_id="+str+"&tag=live&ext=xml&format=1&expect=2";
			}
			/*videoObject.flvURL=["http://123.125.89.53/leflv/jiangsu_bjlt/desc.xml?tag=live&video_type=xml&useloc=1&usertmp=0&clipsize=128&clipcount=10&f_ulrg=0&cmin=3&cmax=10&path=123.125.89.15&stream_id=jiangsu",
                                "http://123.125.89.54/leflv/jiangsu_bjlt/desc.xml?tag=live&video_type=xml&useloc=1&usertmp=0&clipsize=128&clipcount=10&f_ulrg=0&cmin=3&cmax=10&path=123.125.89.15&stream_id=jiangsu"];
			videoObject.type="live";*/
			_player.play(videoObject);
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
//			_loader.load("http://www.letv.com/v_xml/"+vid+".xml","vinfo");
//			var url:String="http://live.gslb.letv.com/gslb?stream_id="+vid+"&tag=live&ext=xml&format=1&expect=2"
//			_loader.load(url,"vinfo");
			httpTest(vid);
		}
		public function playByG3(g3:String):void{
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
				
//				var infoxml:XML=XML(event.info.data);
//				var g3info:String=infoxml.typeurl[0];
//				var ary:Array=g3info.split("&");
//				var low:String=getG3URL(decodeURIComponent(String(ary[0]).slice(4)));
//				var high:String=(ary.length==2)?getG3URL(decodeURIComponent(String(ary[1]).slice(5))):"";
//				//trace(this+"low=",low,"high=",high)
//				g3init(low,high);
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
			//videoObject.dispatch="http://g3.letv.cn/15/46/77/letv-uts/1335176759-AVC-245124-AAC-54091-2705304-106384911-0b84d2d31ab1e83a8582767b705e76be-1335176759.flv?format=1&expect=1&b=384"
			//videoObject.dispatch="http://g3.letv.com/15/1/76/letv-uts/1336383898-AVC-311957-AAC-58226-2644630-127988276-910d5095f4c89a967c12329f80fdd664-1336383898.flv?format=1&expect=1"
			//videoObject.dispatch="http://g3.letv.com/6/26/80/206724949.0.flv?format=1&expect=1"
			videoObject.dispatch="http://g3.letv.cn/15/8/92/2151666464.0.flv?format=1&expect=1&b=1779"
			videoObject.start="0";
			_player.play(videoObject);
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
				_liveControlbar.setBtnsVisible("normalScreenBtn");
			}
			else
			{
				_screenMode="normal";
				_liveControlbar.setBtnsVisible("fullScreenBtn");
			}
			GlobalReference.stage.dispatchEvent(new Event(Event.RESIZE));
		}
		
		private var _w:int=0;
		private var _h:int=0;
		protected function stage_RESIZE(event:Event):void{			
			var w:int=GlobalReference.stage.stageWidth;
			var h:int=GlobalReference.stage.stageHeight;
			_w=w;
			_h=h;
			
			
			
			/*_player.setSize(w-_logArea.width,h-200-_controlbar.height);
			_infobox.setSize(w-_logArea.width,h-200-_controlbar.height);
			_controlbar.y=h-200-_controlbar.height-2;
			_controlbar.width=w-_logArea.width;
			
			
			if(_rectLog)
			{
				_rectLog.x=2;
				_rectLog.y=_h-200;
				_rectLog.setSize(w-_logArea.width,200);
			}*/
			_logArea.setSize(300,h);
			_logArea.x=w-_logArea.width;
			_player.setSize(w-_logArea.width,h-_liveControlbar.height);
			_liveControlbar.width=w-_logArea.width;
			_liveControlbar.y=h-_liveControlbar.height;
			_infobox.setSize(w,h);
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
