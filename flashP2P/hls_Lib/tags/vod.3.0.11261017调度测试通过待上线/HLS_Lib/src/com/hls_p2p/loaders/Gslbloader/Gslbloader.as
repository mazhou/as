package com.hls_p2p.loaders.Gslbloader
{
	import cmodule.keygen.CLibInit;
	
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.Base64;
	import com.p2p.utils.json.JSONDOC;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class Gslbloader extends EventDispatcher
	{
		private var _isLoad:Boolean			 	   = false;
		private var loader:URLLoader		 	   = null;
		//private var m_xml:XML					   = null;
		
		private var _initData:InitData;
		private var _downloadTaskTime:Timer;
		
		private var m_nQuerycount:int			   = 0;
		private var _downloadTaskTimeDelay:Number  = 0;//5*60*1000;
		private var m_nparaCnt:int				   = 0;
		
		
		protected var m_DataManager:IDataManager   = null;
		
		public var isDebug:Boolean			 	   = true;
		private static var m_bgslbComplete:Boolean = false;
		
		
		public function Gslbloader( p_DataManager:IDataManager )
		{
			m_DataManager = p_DataManager;
			
			if( _downloadTaskTime == null )
			{
				_downloadTaskTime = new Timer( _downloadTaskTimeDelay,1 );
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			
			addListener();
		}
		
		public function start( _initData:InitData ):void
		{
			this._initData = _initData;

			if( !_downloadTaskTime.running )
			{
				_downloadTaskTime.start();
			}
		}
		
		private function urldealgslburl( p_strurl:String, p_strKey:String, p_strVal:String ):String
		{
			var strbefore:String = "";
			var strback:String = "";
			
			var nidx:int = p_strurl.indexOf(p_strKey);
			if( nidx == -1 )
			{
				p_strurl += "&";
				p_strurl += p_strKey;
				p_strurl += p_strVal;
				strbefore = p_strurl;
			}
			else
			{
				strbefore = p_strurl.substr(0,nidx);
				strback = p_strurl.substr( nidx,p_strurl.length );
				var nidxend:int = strback.indexOf("&");
				strback = strback.substr(nidxend,strback.length);
				
				strbefore += p_strKey;
				strbefore += p_strVal;
				
				strbefore += strback;
			}
			
			return strbefore;
		}
		
		private function getStreamID( p_url:String ):String
		{
			var reg:RegExp = /stream_id=(\w{0,})/;
			if( reg.test(p_url) )
			{
				return p_url.match(reg)[1];
			}
			
			return "";
		}
		
		private function GetBase64String( p_gslbUrl:String ):String
		{
			var strBase64:String = p_gslbUrl;
			
			var nEnd:int = strBase64.indexOf("?");
			if( nEnd != -1 )
			{
				strBase64 = strBase64.substr(0,nEnd);
				var nBegin:int = strBase64.indexOf("v2/");
				strBase64 = strBase64.substr(nBegin+3,nEnd);
				var strDecBase64:String = Base64.decode(strBase64);
			}
			
			return strDecBase64;
		}
		
		private function Getmmsid( p_gslbUrl:String ):String
		{
			var strmmsid:String = p_gslbUrl;
			var nBegin:int = strmmsid.indexOf("mmsid=");
			if( nBegin != -1 )
			{
				strmmsid = strmmsid.substr(nBegin+6,strmmsid.length);
				var nEnd:int = strmmsid.indexOf("&");
				strmmsid = strmmsid.substr(0,nEnd);
			}
			
			return strmmsid;
		}
		
		
		private function GetsecurityKey_1( p_gslbUrl:String ):String
		{
			P2PDebug.traceMsg(this,"begin---GetsecurityKey_1--- ");
			var tmEndLine:Number = 0;
			//TTT
			var strmmsid:String = Getmmsid( p_gslbUrl );
			var strbase64:String = GetBase64String( p_gslbUrl );
			
			P2PDebug.traceMsg(this,"mmsid: " + strmmsid + " base64: " + strbase64);
			
			if( _initData.keyCreater )
			{
				//TTT
//				var strmmsid:String = Getmmsid( p_gslbUrl );
//				var strbase64:String = GetBase64String( p_gslbUrl );
				try
				{
					var tmpobj:Object = _initData.keyCreater.getKey(strmmsid,strbase64);
					if( tmpobj && tmpobj.tm && tmpobj.key )
					{
						tmEndLine = tmpobj.tm;
						var tmpKey:String = tmpobj.key;
						P2PDebug.traceMsg(this,"gslb securityKey: "+ tmpKey);
					}
					else
					{
						P2PDebug.traceMsg(this," tmpobj.tm || tmpobj.key: error ");
					}
	
					p_gslbUrl = urldealgslburl( p_gslbUrl,"key=",tmpKey );
					p_gslbUrl = urldealgslburl( p_gslbUrl,"tm=",String(tmEndLine) );
				}
				catch(error:Error)
				{
					P2PDebug.traceMsg(this,"_initData.keyCreater is null ");
				}
			}
			else
			{
				P2PDebug.traceMsg(this,"_initData.keyCreater is null ");
			}

			P2PDebug.traceMsg(this,"end---GetsecurityKey_1--- ");
			return p_gslbUrl;
		}
		
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			//_downloadTaskTimeDelay:Number = 0;//5*60*1000;
			m_bgslbComplete = false;
			if( this._initData.gslbURL != "" )
			{
				_isLoad = true;
				
				var strurl:String = _initData.gslbURL;
				
				P2PDebug.traceMsg(this,"gslb_url_in: "+ strurl);
				
				strurl = GetsecurityKey_1( strurl );
				//TTT
//				if( m_nQuerycount != 0 )
//				{
//					urldealgslburl( strurl, "realip=", "202.96.214.191" );
//				}
				//TTT
				if( m_nparaCnt < 3 )
				{
					++m_nparaCnt;
				}
				else
				{
					m_nparaCnt = 0;
				}
				
				strurl += "&retry=";
				strurl += m_nparaCnt;
				
				
				loader.load( new URLRequest(strurl) );
	
				/**test
				 loader.load(new URLRequest(arr[idx]));
				 idx++;
				 if(idx>=arr.length)
				 {
				 idx = 0;
				 }
				 */
			}
			else
			{
				_downloadTaskTime.reset();
			}
			
			m_nQuerycount++;
		}
		
		private function completeHandler(event:Event):void 
		{
			_isLoad = false;
			var tmpxml:XML = new XML(event.target.data);

			if( tmpxml.hasOwnProperty("nodelist") )
			{
				if( tmpxml.nodelist.child("node").length() )
				{
					_initData.flvURL = new Array();
					_initData.setIndex(0);
					
					for each( var tempxml:XML in tmpxml.nodelist.children() )
					{
						P2PDebug.traceMsg(this,"gslb xml_node"+ tempxml.toString());
						_initData.flvURL.push(tempxml.toString());
					}
				}
			}
			
			if( tmpxml.hasOwnProperty("forcegslb") )
			{
				var forcegslb:Number  = Number(tmpxml.forcegslb);
				//TTT
				//forcegslb = 30;
				
				if(_downloadTaskTime.delay != forcegslb*1000)
				{
					_downloadTaskTime.delay = forcegslb*1000;
				}
			}
			
			//EventWithData.getInstance().doAction(NETSTREAM_PROTOCOL.GSLB_SUCCESS,"");
			//dispatchEvent(new  EventExtensions("GSLB_SUCCESS",null));
			//TTT
			for( var i:int = 0; i< _initData.flvURL.length; i++ )
			{
				P2PDebug.traceMsg(this,"gslb "+_initData.flvURL[i]);
			}
			
//			if( LiveVodConfig.TYPE == LiveVodConfig.VOD )
//			{
//				m_DataManager.startm3u8loader( _initData );
//			}
			
			// 这里解析出下次启动时间
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
			
			_initData.g_bGslbComplete = true;
			m_bgslbComplete = true; 
		}

		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			_isLoad=false;
			removeListener();
			m_bgslbComplete = true; 
		}
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			_isLoad=false;
			removeListener();
			m_bgslbComplete = true; 
		}
		
		private function addListener():void
		{
			if(loader==null)
			{
				loader = new URLLoader();
				loader.dataFormat = URLLoaderDataFormat.TEXT;
				
				loader.addEventListener(Event.COMPLETE, completeHandler);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			}
		}
		
		private function removeListener():void
		{
			if( loader!=null )
			{
				try
				{
					loader.close();
				}
				catch(err:Error)
				{
				}
				
				loader.removeEventListener(Event.COMPLETE, completeHandler);
				loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
				loader.removeEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
				
				loader=null;
			}
		}
		
		public function clear():void
		{
			_isLoad=false;
			
			_downloadTaskTime.stop();
			_downloadTaskTime.removeEventListener(TimerEvent.TIMER, handlerDownloadTask);
			removeListener();
			
			_downloadTaskTime 		= null;
			_initData				=null;
			
			_downloadTaskTimeDelay 	= 5*60*1000;
		}
		
	}
}