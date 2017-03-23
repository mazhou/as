package com.p2p.loaders
{
	import com.p2p.data.vo.Config;
	import com.p2p.data.vo.InitData;
	import com.p2p.data.vo.ReceiveData;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.EventWithData;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.p2p.logs.Debug;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
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
		public var isDebug:Boolean=false;
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
		
		public function DATLoader(_dispather:IDataManager)
		{
			this._dispather=_dispather;
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
		}
		
		public function start(_name:String,_errorCount:int=0,_loadSize:Number=0):void{
			this._loadSize=_loadSize;
			if(!_httpLoad){
				_httpLoad=new HttpLoad();
				_httpLoad.addEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.addEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
			}
			_index=0;
			this._name=_name;
			this._errorCount=_errorCount;
			Debug.traceMsg(this,"加载"+_name);
			_loadBeginTime=getTime();
			_httpLoad.loadData(getDatURL()+"&rdm="+getTime(),DAT_FETCH_TIMEOUT,Config.CLIP_INTERVAL,Config.DAT_CHECK_INTERVAL);
			isDownLoad=true;
		}
		
		protected function getDatURL():String{
			return _initData.flvURL[loadURLIndex].replace("desc.xml",_name);
		}
		
		public function stop():void{
			if(_httpLoad){
				_httpLoad.close();
				_httpLoad.removeEventListener(Event.COMPLETE,completeHandler);
				_httpLoad.removeEventListener(ErrorEvent.ERROR,errorHandler);
				_httpLoad.removeEventListener(HTTPLOAD_PROTOCOL.SEGMENTDATA,dataHandler);
				_httpLoad=null;
				isDownLoad=false;
				Debug.traceMsg(this,"dat停止加载"+_name);
			}
			_index=0;
		}
		
		protected function completeHandler(evt:Event):void
		{
			
			isDownLoad=false;
			Debug.traceMsg(this,"完成"+_name+" size:"+_httpLoad._countSize);
			//2013041221/1365772140_11360_1013426.dat size:1013426
			if(_name.indexOf(""+_httpLoad._countSize)==-1){
				Debug.traceMsg(this," 字节不匹配");
				_dispather.addErrorByte(getBlockID());
			}
		}
		/**纠错处理*/
		protected function errorHandler(evt:ErrorEvent=null):void
		{
			/**事件垃圾回收*/
			stop();
			/**上报处理*/
			if(evt&&evt.text==HTTPLOAD_PROTOCOL.TIME_UP){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.IO_ERROR){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.SECURITY_ERROR){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.PARSE_ERROR){
//				Debug.traceMsg(this," 字节不匹配");
//				_dispather.addErrorByte(getBlockID());
//				isDownLoad=false;
			}
			/**重试或跳过机制(即跳过本分钟加载 下一分钟)加载下分钟机制*/
			if(evt){
				Debug.traceMsg(this,"dat错误类型"+evt.text);
				//切换加载dat地址,重新加载dat，待邢波确认加载dat可以按照字节加载，地址要做处理
				loadURLIndex++;
				if(loadURLIndex==_initData.flvURL.length){
					loadURLIndex=0;
				}
				//如果连续出错，达到一定次数，将跳过本块的加载
				_errorCount++;
				start(_name,_errorCount,_loadSize);
				if(_errorCount==Config.DAT_ErrorTotalCount){
					Debug.traceMsg(this,"跳过本块dat");
					_dispather.addErrorByte(getBlockID());
					isDownLoad=false;
				}
			}
		}
		
//		_xml=<root>
//			<header name="1364221677.header"/>
//			<clip name="2013032612/1364272625_6600_593976.dat" duration="6600ms" checksum="3485068282"/>
//			<clip name="2013032612/1364272631_7920_702171.dat" duration="7920ms" checksum="2088142328"/>
//			<clip name="2013032612/1364272639_7560_702148.dat" duration="7560ms" checksum="364880931"/>
//		</root>
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
					Debug.traceMsg(this,"越界"+parseName(_name));
				}
				_loadBeginTime=endTime;
				_index++;
			}catch(err:Error){
				Debug.traceMsg(this,"跳过本块dat"+parseName(_name));
				_dispather.addErrorByte(getBlockID());
				isDownLoad=false;
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
		protected function streamPlayHandler(evt:EventExtensions):void{
			_initData=evt.data as InitData;
			Debug.traceMsg(this,"调度器响应play事件"+_initData.flvURL);
			
		}
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}