package com.p2p.loaders
{
	import com.p2p.data.LIVE_TIME;
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.TimeTranslater;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	
	/**
	 * <ul>构造函数：NETSTREAM_PROTOCOL.PLAY，获得initdata参数</ul>
	 * <ul>处理数据</ul>
	 * <ul>异常处理</ul>
	 * <ul>纠错处理：请求加载和加载过程addErrorByte</ul> 
	 * @author mazhoun
	 */
	public class DescLoader
	{
		public var isDebug:Boolean=true;
		private var _dispather:IDataManager = null;		
		private var _downloadTaskTime:Timer;
		private var loader:URLLoader;//new URLLoader();
		private var _initData:InitData;
		private var _flvURLIndex:int=0;
		public function DescLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			//
			loader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, completeHandler);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
		public function start( _initData:InitData):void
		{
			this._initData = _initData;
			if (_downloadTaskTime == null)
			{
				_downloadTaskTime = new Timer(5);
				_downloadTaskTime.addEventListener(TimerEvent.TIMER, handlerDownloadTask);
			}
			_downloadTaskTime.delay=5;
			//
			if (descTask != -1)
			{
				try{
					loader.close();
				}catch(err:Error)
				{
					P2PDebug.traceMsg(this,err);
				}
				descTask = -1; 
			}
			_downloadTaskTime.reset();
			_downloadTaskTime.start();
			
		}
		/**请求时移地址*/
		public function get abTimeShiftURL():String
		{
			if(_initData)
			{
				return getShiftPath(_initData.flvURL[_flvURLIndex]);
			}
			//
			return "";
		}
		
		protected function getShiftPath(url:String):String
		{
			url=url.replace("desc.xml","")+"&abtimeshift=";
			return url;
		}
		//
		private function completeHandler(event:Event):void 
		{
			//
			descTask  = -1;
			 var _xml:XML;
			 var reg:RegExp=/\/(\d+)_(\d+)_(\d+)/;
			 var regHead:RegExp=/.header/;
			 var _clipList:Vector.<Clip>;
			 var _clip:Clip
			 var _head:String="";
			 var dugString:String="";
			
			try
			{
				_xml = new XML(event.target.data);
			}catch(err:Error)
			{
				//errorHandler();
				P2PDebug.traceMsg(this,"解析xml错误"+abTimeShiftURL+this.descTask);
				return;
			}
			
			//			Debug.traceMsg(this,"desc_xml:"+_xml);
			_clipList = new Vector.<Clip>;
			_head="";
			var minClipTime:Number    = Number.MAX_VALUE;//int.MIN_VALUE//int.MAX_VALUE;
			var _tempTimestamp:Number = 0;
			var duration:Number = 0;
			for(var i:int =0;i < _xml.children().length();i++)
			{
				if(regHead.test(_xml.children()[i].@name))
				{
					//对头处理
					_head=_xml.children()[i].@name.toString().replace(".header","");
				}else
				{
					//对clip处理
					if(reg.test(_xml.children()[i].@name)){
						if(_xml.children()[i].@name.match(reg).length==4)
						{
							//Number(_xml.children()[i].@name.match(reg)[1])
							/**desc文件处理*/
							_clip=new Clip;
							if(_head==""){break;}
							
							_clip.head=Number(_head);
							_clip.checkSum=_xml.children()[i].@checksum;
							_clip.sequence=Number(_xml.children()[i].@sequence);
							_clip.duration=Number(_xml.children()[i].@name.match(reg)[2]);
							_clip.size=Number(_xml.children()[i].@name.match(reg)[3]);
							_tempTimestamp = _clip.timestamp=Number(_xml.children()[i].@name.match(reg)[1]);
							_clip.name=_xml.children()[i].@name;
							_clipList.push(_clip);
							dugString+="\n"+_clip.head+"~_~"+_clip.timestamp+"~_~"+_clip.duration+"~_~"+_clip.size+"~_~"+_clip.checkSum+"~_~"+_clip.sequence;
							
						}
					}
				}
			}
			
			P2PDebug.traceMsg(this,"descData:"+dugString);
			dugString="";
			if(_clipList.length>=1)
			{
				if(_clip)
				{
					Statistic.getInstance().descLastTime(TimeTranslater.getTime(_clip.timestamp));
				}
				//
				_dispather.writeClipList(_clipList);
			}
		}
		
		
		private function securityErrorHandler(event:SecurityErrorEvent):void 
		{
			downloadError();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void 
		{
			downloadError();
		}
		
		private function downloadError():void
		{
			descTask = -1;
			_flvURLIndex++;
			if(_flvURLIndex>=_initData.flvURL.length)
			{
				_flvURLIndex=0;
			}
		}
		//
		private var descTask:Number = -1;
		private function handlerDownloadTask(evt:TimerEvent=null):void
		{
			_downloadTaskTime.delay = 3000;
			if (_dispather && -1 == descTask)
			{
				descTask = _dispather.getDescTask();
				//
				var url:String = abTimeShiftURL+this.getMiniMinute(descTask)+"&rdm="+getTime();
				var request:URLRequest = new URLRequest(url);
				try
				{
					loader.load(request);
					
				} catch (error:Error)
				{
					trace("Unable to load requested document.");
					descTask = -1;
				}
			}
		}
		private function getMiniMinute(id:Number):Number
		{
			var date:Date  = new Date(id*1000);
			date=new Date(date.fullYear,date.month,date.date,date.getHours(),date.getMinutes(),0,0);
			return Math.floor(date.time/1000);
		}
		protected function getDatURL(name:String):String
		{
			return _initData.flvURL[0].replace("desc.xml",name);
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}