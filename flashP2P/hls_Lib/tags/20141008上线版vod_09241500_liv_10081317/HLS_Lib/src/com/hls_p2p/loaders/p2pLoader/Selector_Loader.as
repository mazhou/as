package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.p2p.utils.console;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
//	import flash.net.Socket;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	public class Selector_Loader extends EventDispatcher
	{		
		public var isDebug:Boolean=true;
		public var proxyIp:String;
		public var proxyPort:uint;
		public var rtmfpPort:uint;
		public var rtmfpIp:String;
		public var selectorIP:String;
		public var selectorPort:uint;
		public var isConnecting:Boolean;
		public var isOK:Boolean;
		public var redirectSelector:Boolean;
		public var error:Boolean;	
		
		public var stunRtmfpId:String;
		public var stunReqId:String;
		
		public var noRequest:Boolean = false;
		
		public var sharePeers:Boolean;
		public var maxQPeers:uint  = 6;
		public var hbInterval:uint = 11;
		
		private var _groupName:String  = "";
		private var _selectorIP:String;
		private var _selectorPort:uint = 80;
		private var _addrLength:int    = 0;
		
		public var urgentSize:uint	   = 10;//点播紧急区秒数
		public var urgentLevel1:uint   = 300;//点播cdn压力为1时的紧急区秒数
		//private var _startTime:Number;
		
		private var _URLLoader:URLLoader;
		
		public function Selector_Loader(target:IEventDispatcher=null)
		{
			super(target);
		}
		//
		public function init(groupName:String, selectorIP:String, selectorPort:uint):void
		{
			_groupName    = groupName;
			_selectorIP   = selectorIP;
			_selectorPort = selectorPort;
			initLoader(_selectorIP,_selectorPort);
			//
			//_startTime = Math.floor((new Date()).time);
			//
		}
		
		private function initLoader(selectorIP:String,selectorPort:uint):void
		{
			isOK = false;
			isConnecting = true;
			
			if (_URLLoader == null)
			{					
				_URLLoader = new URLLoader();
				_URLLoader.addEventListener(Event.COMPLETE, loader_COMPLETE);
				_URLLoader.addEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
				_URLLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);						
			}
			//trace("----"+(new Date).time);
			//var url:String = String("http://" + selectorIP + ":" + selectorPort + "/queryRtmfp?groupId=" + _groupName);
			var url:String = String("http://" + selectorIP + ":" + selectorPort + "/query?groupId=" + _groupName+"&ran="+Math.floor(Math.random()*10000));
			console.log(this,"开始请求 selector ： "+url);
			_URLLoader.load(new URLRequest(url));
			
		}
		/**
		 * 返回结果（json） 
			请求成功： 
			{"result":"success","value":{"rtmfpId":"115.182.11.37:8124","proxyId":"115.182.11.37:80"}} 
			请求失败： 
			{"result":"failed"} 
			需要重定向： 
			{"result":"redirect","value":{"mselectorId":"123.126.33.186:80"}} 
		 * */
		private function loader_COMPLETE(e:Event):void
		{			
			try
			{	
				var obj:Object = JSONDOC.decode(String(_URLLoader.data));	
				console.log(this,String(_URLLoader.data))
				
			}catch(e:Error)
			{
				loader_ERROR("dataError");				
				return;
			}
			if(obj["result"] == "success")
			{
				/**成功返回所需地址和接口*/
				var arr:Array = String(obj["value"]["rtmfpId"]).split(":");
				var arr1:Array = String(obj["value"]["proxyId"]).split(":");
				rtmfpIp   = arr[0];
				rtmfpPort = arr[1];
				proxyIp   = arr1[0];
				proxyPort = arr1[1];
				
				/**  STUN服务 lz0424add*/
				/*stunRtmfpId = obj["value"]["stunRtmfpId"];
				stunReqId   = obj["value"]["stunReqId"];
				*/
//				if(obj["value"]["fetchRate"])
				if( obj["value"].hasOwnProperty("fetchRate") )
				{
					LiveVodConfig.DAT_LOAD_RATE = Number(obj["value"]["fetchRate"]);
//					console.log(this,"selector:"+LiveVodConfig.DAT_LOAD_RATE);
				}
				if(obj["value"]["maxPeers"])
				{
					LiveVodConfig.MAX_PEERS = Number(obj["value"]["maxPeers"]);
					//LiveVodConfig.MAX_PEERS = 7;
				}
				
				if(obj["value"]["urgentSize"])
				{
					LiveVodConfig.DAT_BUFFER_TIME/*urgentSize*/ = obj["value"]["urgentSize"];
				}
				if(obj["value"]["urgentLevel1"])
				{
					LiveVodConfig.DAT_BUFFER_TIME_LEVEL1/*urgentLevel1*/ = obj["value"]["urgentLevel1"];
				}
				
				if(obj["value"]["sharePeers"])
				{
					sharePeers = obj["value"]["sharePeers"];
				}
				if(obj["value"]["maxQPeers"])
				{
					maxQPeers = obj["value"]["maxQPeers"];
				}
				if(obj["value"]["hbInterval"])
				{
					hbInterval = obj["value"]["hbInterval"];
				}
				if(obj["value"]["cdnDisable"])
				{
					LiveVodConfig.CDN_DISABLE = int(obj["value"]["cdnDisable"]);
				}
				if(obj["value"]["cdnStartTime"])
				{
					LiveVodConfig.CDN_START_TIME = int(obj["value"]["cdnStartTime"]);
				}
				//LiveVodConfig.CDN_START_TIME = 40
				//LiveVodConfig.cdnDisable = 1;
				isOK = true;
				isConnecting = false;
				redirectSelector = false;
				console.log(this,"selector 成功返回 ："+rtmfpIp+":"+rtmfpPort+" "+proxyIp+":"+proxyPort);
			}
			else if(obj["result"] == "redirect")
			{
				/**需要重定向再次请求*/
				var arr2:Array = String(obj["value"]["mselectorId"]).split(":");
				selectorIP   = arr2[0];
				selectorPort = arr2[1];
				isConnecting = false;
				redirectSelector = true;
			}
			else if(obj["result"] == "failed")
			{
				noRequest = true;
			}
			else
			{
				loader_ERROR("dataError");				
				return;
			}
			
		}
		private function loader_ERROR(e:* = null):void
		{
			redirectSelector = false;
			isOK = false;
			isConnecting = false;
			error = true;
		}
		
		public function clear():void
		{
			if(_URLLoader)
			{
				if(_URLLoader.hasEventListener(Event.COMPLETE))
				{
					try{
						_URLLoader.close();
					}catch(err:Error)
					{
						
					}
					_URLLoader.removeEventListener(Event.COMPLETE, loader_COMPLETE);
					_URLLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
					_URLLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
				}
			}
			_URLLoader=null;
			loader_ERROR();
		}
	}
}