package com.p2p.loaders
{
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.events.SelectorEvent;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.errors.IOError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	public class SelectorLoader extends EventDispatcher
	{		
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
		
		public var maxPeers:uint;
		public var maxMem:uint;
		public var urgentSize:uint;
		
		public var noRequest:Boolean = false;
		
		private var _groupName:String  = "";
		private var _selectorIP:String;
		private var _selectorPort:uint = 80;
		private var _addrLength:int    = 0;
		
		//private var _startTime:Number;
		
		private var _URLLoader:URLLoader;
	
		public function SelectorLoader(target:IEventDispatcher=null)
		{
			super(target);
		}
		//
		public function init(groupName:String, selectorIP:String, selectorPort:uint=80):void
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
			
			var url:String = String("http://" + selectorIP + ":" + selectorPort + "/query?groupId=" + _groupName+"&ran="+Math.floor(Math.random()*10000));
			//MZDebugger.trace(this,"selector url:"+url);
			try{
				_URLLoader.load(new URLRequest(url));
			}catch(err:Error){
				//trace(err.errorID+err.message+err.getStackTrace());
			}
			
		}
		
		private function loader_COMPLETE(e:Event):void
		{
			/*switch(_addrLength)
			{
				case 1:
				case 2:	
			}*/
			try
			{	
				var obj:Object = JSONDOC.decode(String(_URLLoader.data));
			}catch(e:Error)
			{
				loader_ERROR(null);
				return;
			}
			if(obj["result"] == "success")
			{
				var arr:Array = String(obj["value"]["rtmfpId"]).split(":");
				var arr1:Array = String(obj["value"]["proxyId"]).split(":");
				rtmfpIp   = arr[0];
				rtmfpPort = arr[1];
				proxyIp   = arr1[0];
				proxyPort = arr1[1];
				
				/**  STUN服务 lz0424add*/
				stunRtmfpId = obj["value"]["stunRtmfpId"];
				stunReqId   = obj["value"]["stunReqId"];
				/**/
				
				/**lz 0524 add*/
				if(obj["value"]["maxPeers"])
				{
					maxPeers = obj["value"]["maxPeers"];
				}
				if(obj["value"]["maxMem"])
				{
					maxMem = obj["value"]["maxMem"];
				}
				/**lz 0613 add*/
				if(obj["value"]["urgentSize"])
				{
					urgentSize = obj["value"]["urgentSize"];
				}
				
				
				isOK = true;
				isConnecting = false;
				redirectSelector = false;
			}
			else if(obj["result"] == "redirect")
			{
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
				loader_ERROR(null);				
				return;
			}
			
			clearURLLoader();
			
		}
		private function loader_ERROR(e:* = null):void
		{
			//trace(e.type);
			redirectSelector = false;
			isOK = false;
			isConnecting = false;
			error = true;
			
			clearURLLoader();
			
			/*_URLLoader.removeEventListener(Event.COMPLETE, loader_COMPLETE);
			_URLLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
			_URLLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
			try{
			_URLLoader.close();
			}catch(err:Error){
				trace(this+err.message+err.getStackTrace());
			}
			_URLLoader=null;*/
		}
		private function clearURLLoader():void
		{
			if( _URLLoader )
			{
				if( _URLLoader.hasEventListener(Event.COMPLETE) )
				{
					_URLLoader.removeEventListener(Event.COMPLETE, loader_COMPLETE);
					_URLLoader.removeEventListener(IOErrorEvent.IO_ERROR, loader_ERROR);
					_URLLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, loader_ERROR);
				}
				try{
					_URLLoader.close();
				}catch(err:Error){
					//trace(this+err.message+err.getStackTrace());
				}
				_URLLoader=null;
			}
		}
		
		public function clear():void
		{
			clearURLLoader();
			loader_ERROR();
		}
	}
}