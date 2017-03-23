package com.p2p.loaders
{
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.ReceiveData;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.P2PDebug;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.external.ExternalInterface;
	import flash.utils.ByteArray;

	/**
	 * <ul>构造函数：NETSTREAM_PROTOCOL.PLAY，获得initdata参数</ul>
	 * <ul>处理数据</ul>
	 * <ul>异常处理</ul>
	 * <ul>纠错处理：请求加载和加载过程addErrorByte</ul> 
	 * @author mazhoun
	 */
	public class DATLoader
	{
		public var isDebug:Boolean=true;
		/**初始化数据*/
		protected var _initData:InitData;
		/**http基类加载，基于urlstream*/
		protected var _httpLoad:HttpLoad;
		/**声明调度器*/
		protected var _dispather:IDataManager;
		/**开始时间*/
		protected var _startTime:Number=0;
		/**加载地址索引，因地址有多个*/
		protected var loadURLIndex:uint=0;
		/**blockname*/
		protected var _name:String="";
		/**请求超时，3秒*/
		protected const DAT_FETCH_TIMEOUT:uint = 3000;
		/**加载分割的字节索引，如果1000，分割为100字节加载，第一个100字节是0，第二个100字节是1（下载的总字节是200字节）*/
		protected var _index:int=0;
		/**标记该对象正在加载过程*/
		public var isDownLoad:Boolean=false;
		/**如果连续出错达到给定的次数，将跳过该块*/
		public var _errorCount:int=0;
		/**开始加载时间*/
		protected var _loadBeginTime:Number=0;
		/**下载总的字节*/
		protected var _loadSize:Number=0;
		private var _test_isLoad:Boolean=true;
		
		public function DATLoader(_dispather:IDataManager)
		{
			P2PDebug.traceMsg(this,"DATLoader");
			this._dispather=_dispather;
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
		}

		public function get test_isLoad():Boolean
		{
			return _test_isLoad;
		}

		public function set test_isLoad(value:Boolean):void
		{
			_test_isLoad = value;
		}

		private function stopDat():void
		{
			test_isLoad=false;
			//P2PDebug.traceMsg(this,"测试dat停止");
		}
		
		private function startDat():void
		{
			test_isLoad=true;
			//P2PDebug.traceMsg(this,"测试dat恢复加载");
		}
		public function start(_name:String,_errorCount:int=0,_loadSize:Number=0):void{
			if(!_test_isLoad){P2PDebug.traceMsg(this,"测试dat停止加载");return;}
			isDownLoad=true;
			this._name=_name;
			this._errorCount=_errorCount;
			this._loadSize=_loadSize;
			_index=0;
			httpload();
			_loadBeginTime=getTime();
			try{
				P2PDebug.traceMsg(this,"加载"+_name);
				_httpLoad.loadData(getDatURL()+"&rdm="+getTime(),DAT_FETCH_TIMEOUT,LiveVodConfig.CLIP_INTERVAL,LiveVodConfig.DAT_CHECK_INTERVAL);
			}catch(err:Error){
				isDownLoad=false;
			}
		}
		protected function httpload():void{
			if(!_httpLoad){
				_httpLoad=new HttpLoad();
				_httpLoad.addEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
			}
		}
		protected function getDatURL():String{
			return _initData.flvURL[loadURLIndex].replace("desc.xml",_name);
		}
		/**事件垃圾回收*/
		public function stop():void{
			httpLoadGarbageCollector();
			isDownLoad=false;
			P2PDebug.traceMsg(this,"dat停止加载"+_name);
			_errorCount=0;
			_index=0;
		}
		private function httpLoadGarbageCollector():void{
			if(_httpLoad){
				try{
					_httpLoad.close();
				}catch(err:Error){
				}
				try{
					_httpLoad.removeEventListener(Event.COMPLETE,completeHandler);
					_httpLoad.removeEventListener(ErrorEvent.ERROR,errorHandler);
					_httpLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
				}catch(err:Error){
				}
				_httpLoad=null;
			}
		}
		protected function completeHandler(evt:Event):void
		{
			/*this._dispather.downloadTaskTime.reset();
			this._dispather.downloadTaskTime.start();*/
			
			P2PDebug.traceMsg(this,"完成"+_name+" size:"+_httpLoad._countSize);
			if(_name.indexOf(""+_httpLoad._countSize)==-1){
				P2PDebug.traceMsg(this," 字节不匹配");
//				ExternalInterface.call("trace",getBlockID()+" 字节不匹配");
				errorHandler();
			}else{
				stop();
			}
		}
		/**纠错处理*/
		protected function errorHandler(evt:ErrorEvent=null):void
		{
			/*this._dispather.downloadTaskTime.reset();
			this._dispather.downloadTaskTime.start();*/
//			/**上报处理*/
//			if(evt&&evt.text==HTTPLOAD_PROTOCOL.TIME_UP){
//			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.IO_ERROR){
//			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.SECURITY_ERROR){
//			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.PARSE_ERROR){
//			}
			/**重试或跳过机制(即跳过本分钟加载 下一分钟)加载下分钟机制*/
			if(evt){
				P2PDebug.traceMsg(this,"dat错误类型"+evt.text);
			}
			loadURLIndex++;
			if(loadURLIndex==_initData.flvURL.length){
				loadURLIndex=0;
			}
			//如果连续出错，达到一定次数，将跳过本块的加载
			if(_errorCount>=LiveVodConfig.DAT_RPEAT_LOAD_COUNT*_initData.flvURL.length){
//				ExternalInterface.call("trace",getBlockID()+" 连续多个节点下载错误");
				_dispather.addErrorByte(getBlockID());
				stop();
			}else{
				reload();
			}
		}
		protected function reload():void{
			_errorCount++;
			start(_name,_errorCount,_loadSize);
		}
		protected function dataHandler(evt:EventExtensions):void{
			try{
				var endTime:Number=getTime();
				//_dispather.addByte(Number(parseName(_name)),_index,evt.data as ByteArray,_loadBeginTime,endTime,"http");
				var data:ReceiveData = new ReceiveData();
				data.blockID = Number(parseName(_name));
				data.pieceID = _index;
				data.data    = evt.data as ByteArray;
				data.begin   = _loadBeginTime;
				data.end     = endTime;
				data.from    = "http";
				if(_httpLoad._countSize<=_loadSize){//添加数据不超边界做的判断
					_dispather.addByte(data);
				}else{
					P2PDebug.traceMsg(this,"越界"+parseName(_name));
//					ExternalInterface.call("trace",getBlockID()+" 越界");
					errorHandler();
				}
				_loadBeginTime=endTime;
				_index++;
			}catch(err:Error){
				P2PDebug.traceMsg(this,"越界"+parseName(_name));
//				ExternalInterface.call("trace",getBlockID()+" 越界");
				errorHandler();
			}
		}
		public function getBlockID():Number{
			return Number(parseName(_name))
		}
		/**把dat的加载的路径解析为时间戳*/
		private function parseName(str:String):String{
			if((/\//).test(str)){
				str=str.split("/")[1];
				if((/\_/).test(str)){
					str=str.split("_")[0];
					return str;
				}
			}
			return str;
		}
		protected function jsInterface():void{
			ExternalInterface.addCallback("stopDat",stopDat);
			ExternalInterface.addCallback("startDat",startDat);
		}
		protected function streamPlayHandler(evt:EventExtensions):void{
			jsInterface();
			_initData=evt.data as InitData;
			P2PDebug.traceMsg(this,"调度器响应play事件"+_initData.flvURL);
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}
//		_xml=<root>
//			<header name="1364221677.header"/>
//			<clip name="2013032612/1364272625_6600_593976.dat" duration="6600ms" checksum="3485068282"/>
//			<clip name="2013032612/1364272631_7920_702171.dat" duration="7920ms" checksum="2088142328"/>
//			<clip name="2013032612/1364272639_7560_702148.dat" duration="7560ms" checksum="364880931"/>
//		</root>