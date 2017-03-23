package com.p2p_live.core
{
	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p_live.core.ClientObject;
	import com.p2p_live.events.DataManagerEvent;
	import com.p2p_live.events.HttpLiveEvent;
	import com.p2p_live.events.P2PNetStreamEvent;
	import com.p2p_live.events.P2PNetStreamLocalEvent;
	import com.p2p_live.kernelReport.KernelReport;
	import com.p2p_live.loaders.HttpLiveDataLoader;
	import com.p2p_live.log.P2PStatisticData;
	import com.p2p_live.managers.DataManager;
	import com.p2p_live.protocol.Protocol;
	import com.p2p.utils.TraceMessage;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.System;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	public class P2PNetStream extends NetStream
	{
		static public const P2P_SERVER:String = "http://p2p.letv.com/";
		static public const VERSION:String = "liv.1.1.02191611";
		protected var _connection:NetConnection;
		protected var _priority:uint = 1;
		
		protected var _statisticData:P2PStatisticData;
		protected var _manager:DataManager;
		protected var _timer:Timer;
				
		protected var _time:Number;		
		protected var _chunkSize:uint;
		protected var _byteArrayIndex:uint;
		
		protected var _p2pReady:Boolean;
		protected var _metaDataReady:Boolean;	
		protected var _isPause:Boolean;
        //protected var _isEmpty:Boolean = true;
		protected var _seekOk:Boolean;
		//用于统计p2p下载率
		private var _httpSize:Number = 0;
		private var _p2pSize:Number = 0;
		//
		private var _outMsg:Function;
		private var _callBackObject:Object = new Object(); 
		//		
		private var _isSeeking:Boolean;
		private var _isLive:Boolean = true;
		//
		protected var _startRunTime:int = 0;//开始播放的时间(秒)
		
		protected var _serverCurtime:int;    //第一次运行时的服务器时间
		protected var _firstRunTime:int;    //第一次运行时的数据块ID
		protected var _serverOffsetTime:int  //服务器时间与本地时间的差值sever-local
		protected var _isAfterMetaDate:Boolean  //是否为刚刚触发onMetaDate之后还没下载真正地数据（用来推算服务器的当前时间）
		protected var _changeMetaData:Boolean;
		
		//protected var _errorLimited:int = 0;
		//protected var _errored:int = 0;
		
		protected var _isTrueLiveType:Boolean = true; //是否为真正的直播模式而不是伪直播
		protected var _falseLiveTime:Number = 0;       //当是伪直播状态时，初始播放时的时移偏移秒数
		/**
		 * _P2PReportRecoder
		 * 保存是否已经上报过下列事件，确保只上报一次
		 * 0: P2PNetStream_success
		 * 1：selector_success
		 * 2：rtmfp_success
		 * 3：gather_success
		 * 4：load_success   p2p成功下载第一块数据
		 */		
		private var _P2PReportRecoder:Object = new Object();
		//
		public function P2PNetStream()
		{
			MZDebugger.customTrace(this,Protocol.VERSION,version,0xff0000);
			_connection = new NetConnection();
			_connection.connect(null);
			super(_connection);
			this.bufferTime = 3;
			_manager = new DataManager();
			_manager.addEventListener(HttpLiveEvent.LOAD_DATA_STATUS,liveDataLoaderHandler);
			_manager.addEventListener(DataManagerEvent.STATUS,_manager_STATUS);
			
			_statisticData=new P2PStatisticData();			
			_timer = new Timer(200);
			_timer.addEventListener(TimerEvent.TIMER,_timer_TIMER);
			super.client = new ClientObject();
			super.client.metaDataCallBackFun = onMetaData;
			this.addEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS,false,_priority);
			
			//----------------------------设置内部监控上报
			KernelReport.SET_INFO(VERSION,"live");			
			//----------------------------
		}
		
		override public function play(...arguments):void
		{			
			super.play(null);
			
			var videoInfo:Object    = new Object();
			videoInfo["url"]        = arguments[0]["flvURL"];		
			videoInfo["groupName"] = arguments[0]["groupName"];
			videoInfo["geo"]        = arguments[0]["geo"];			
			videoInfo["isTrueLiveType"] = _isTrueLiveType = decideLiveOrTimeShift(arguments[0]["livePer"]);
			
			var obj0:Object = new Object();
			obj0.name = "size";
			obj0.info = "trueLive = "+videoInfo["isTrueLiveType"];
			callBackFunction(obj0);//输出面板用的数据
			
			trace("调用---PLAY---  "+videoInfo["isTrueLiveType"]+getTime());			
			videoInfo["path"]              = getSeekPath(arguments[0]["flvURL"]);
			videoInfo["serverCurtime"]    = _serverCurtime = arguments[0]["serverCurtime"]; //秒
			videoInfo["serverStartTime"]  = arguments[0]["serverStartTime"];   //秒
			//  误差时间 = 服务器当前时间 - 本地时间
			videoInfo["serverOffsetTime"] = _serverOffsetTime = Math.round((_serverCurtime*1000-getTime())/1000);//秒
			
			if(!videoInfo["isTrueLiveType"])
			{				
				videoInfo["falseLiveTime"] = _falseLiveTime = decidePlayTime(arguments[0]["timeShiftArr"]);
				obj0.name = "chunks";
				obj0.info = "-"+videoInfo["falseLiveTime"];
				callBackFunction(obj0);
			}			
						
			MZDebugger.customTrace(this,Protocol.GROUPNAME,videoInfo["groupName"]);
			var strTmp:String="";
			for(var p:* in arguments[0]){
				strTmp+=p+":"+arguments[0][p]+"\n";
			}
			MZDebugger.trace(this,{"key":"INIT","value":strTmp+"\n是否直播："+_isTrueLiveType+"\n伪直播时移时间"+_falseLiveTime});
			//_errorLimited = videoInfo["url"].length;
			//
			if(!_manager.start(videoInfo))
			{
				trace("data manager start error");
			}
			//----------------------------设置内部监控上报  
			KernelReport.gID = videoInfo["groupName"];
			var obj:Object = new Object();
			obj["act"] = 0;
			obj["error"] = 0;
			dispatchP2PReportEvent(obj,"P2PNetStream_success");
			//----------------------------
			realPlay();
			//
			var object:Object = new Object();
			object.name = "groupName";
			object.info = videoInfo["groupName"];
			callBackFunction(object);
			/*
			if(_startRunTime == 0)
			{
				_startRunTime = getTime()/1000;
			}
			seek(1358494046);
			*/
		}
	
		override public function resume():void
		{		
			_isPause = false;			
			super.resume();
		}	

		override public function pause():void
		{			
			_isPause = true;
			super.pause();	
		}	
        		
		override public function seek(time:Number):void
		{
			trace(this+"seek:"+time);				
			var obj:Object = translate(time);
			if(obj == null){
				return;
			}
			else
			{
				if(obj.time == "-")
				{
					//时移跳直播的切换
					_isLive = true;	
					dispatchChangePlayMode("live");
				}
				else
				{
					//时移和时移之间的切换
					_isLive = false;	
					dispatchChangePlayMode("timeShift");
				}
			}
			trace(this+"是否直播 = "+_isLive);
			seekTo(obj);
		}
		protected function decideLiveOrTimeShift(per:*):Boolean
		{	
			//return true;
			trace("per = "+per);
			if(per == undefined)
			{
				per = 0.1;
			}
			if(per is int || per is uint || per is Number)
			{
				var livePer:Number = Number(per);
			
				if( livePer >= 1 )
				{
					return true;
				}
				else if( livePer<1 && livePer>0 )
				{
					var temp:Number = Math.floor(1/livePer);
					trace("随机比例 = "+temp);
					if(Math.floor(Math.random()*temp) == 0)
					{
						return true;
					}
					else
					{
						return false;
					}
				}
				else
				{
					return false;
				}		
			}
			else
			{
				return true;
			}			
			return true;
		}
		protected function decidePlayTime(arr:*):Number
		{
			trace("per = "+arr);
			if(arr is Array)
			{
				if(arr.length>1)
				{
					var i:Number = Math.abs(((arr[Math.floor(Math.random()*arr.length)])));
					if(i!=0)
					{
						return i;
					}				    
				}				
			}
			//25到60秒之间的值
			return Math.floor(Math.random()*35)+25;
		}
		/*
		protected function getComputerRoom(url:String):String
		{
			
			   //http://123.125.89.39/leflv/jiangsu_bjlt1/desc.xml?tag=live&video_type=xml&useloc=1&clipsize=128&clipcount=10&f_ulrg=0&cmin=3&cmax=10&path=123.125.89.13&cipi=168448162&isp=2&pnl=706,215&stream_id=jiangsu
			   //取jiangsu_bjlt1
			
			
			var start:int = 0;
			for(var i:int=0 ; i<4 ; i++)
			{
				start = url.indexOf("/",start)+1;
			}
			var end:int    = url.indexOf("/",start);
			var str:String = url.substring(start,end);
			return str;
		}
		*/
		protected function getSeekPath(arr:Array):Array
		{
			/*
			path属性保存desc路径的一部分，当seek时拼出时移的路径
			如：videoInfo.url[0] = "http://119.188.39.134/leflv/jiangsu_szq/desc.xml?tag=live&path=115.182.51.113";
			videoInfo.path[0] = "http://119.188.39.134/leflv/jiangsu_szq/?tag=live&path=115.182.51.113&timeshift="
			*/
			var arrPath:Array = new Array();
			for(var i:int=0 ; i<arr.length ; i++)
			{
				trace("arr["+i+"]     = "+arr[i]);
				arrPath[i] = String(arr[i]).replace("desc.xml","")+"&timeshift=";
				trace("时移地址 arrPath["+i+"] = "+arrPath[i]);
			}
			return arrPath;
		}
		protected function translate(time:Number):Object
		{			
			trace(this+"seek time = "+time);
			trace(this+"_serverCurtime-_falseLiveTime + (Math.round(getTime()/1000) - _startRunTime) - time");
			trace(_serverCurtime+" - "+_falseLiveTime+" +( "+Math.round(getTime()/1000)+" - "+_startRunTime+" )- "+time);
			trace(this+" == "+(_serverCurtime-_falseLiveTime + (Math.round(getTime()/1000) - _startRunTime) - time))
			
			MZDebugger.trace(this,{"seek time":"时移时间 "+time});
			MZDebugger.trace(this,{"服务器时间-时移时间 ":"_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time"});
			MZDebugger.trace(this,{"服务器时间-时移时间 ":" = "+_serverCurtime+" +( "+Math.round(getTime()/1000)+" - "+_startRunTime+" )- "+time});
			MZDebugger.trace(this,{"服务器时间-时移时间 ":" = "+(_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time)});
			
			var obj:Object = new Object();
			if( (_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time) <= 60 )
			{
				//当进度小于60秒时，重新启动直播;
				if(_isLive)
				{
					return null;
				}	
				obj.backToLive = true;
				obj.time = "-";
				trace("重启时移！！！");
				MZDebugger.trace(this,{"seek time":"重启时移！！！"});
			}
			else
			{		
				trace(" +=+ "+(_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time + _falseLiveTime));
				MZDebugger.trace(this,{"真实时移时间 ":"_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time + _falseLiveTime"});
				MZDebugger.trace(this,{"真实时移时间 ":" = "+_serverCurtime+" +( "+Math.round(getTime()/1000)+" - "+_startRunTime+" )- "+time + _falseLiveTime});
				MZDebugger.trace(this,{"真实时移时间 ":" = "+(-1*int((_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time + _falseLiveTime)))});
				obj.time = -1*int((_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time + _falseLiveTime));
				obj.abTime = time;
				obj.backToLive = false;	
				trace(this+"obj.time = "+obj.time);
			}			
			return obj;
			/*
			var obj:Object = new Object();
			
			if( _isTrueLiveType && (_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time) <= 120 )
			{
				//当是真正的直播模式且进度小于120秒时，重新启动直播;	
				if(_isLive)
				{
					return null;
				}	
				obj.backToLive = true;
				obj.time = "-";
				_isLive = true;
				
                dispatchChangePlayMode("live");
			}
			else
			{					
				var seekTime:int = int((_serverCurtime + (Math.round(getTime()/1000) - _startRunTime) - time));
				if(!_isTrueLiveType)
				{
					if( seekTime < _playTime )
					{
						//当是伪直播模式且时移的时间小于_playTime时
						seekTime = _playTime;
						dispatchChangePlayMode("live");
					}
					else
					{
						dispatchChangePlayMode("timeShift");
					}
				}
				else
				{
					dispatchChangePlayMode("timeShift");
				}
				_isLive = false;
				obj.time = -1*seekTime;
				obj.abTime = time;
				obj.backToLive = false;				
			}			
			return obj;
			*/
		}
		protected function seekTo(obj:Object):void
		{				
			super.seek(0);
			this.appendBytesAction("resetBegin");	
			
			_isSeeking = true;
			
			_manager.seek(obj);				    
			
			_metaDataReady = false;
			_byteArrayIndex = 0;			
		}
		
		override public function close():void
		{
			super.close();
			if(_timer)
				_timer.stop();
			if(_manager)
			{
				_manager.clear();
			}
			if(_statisticData != null)
			{
				_statisticData.clear();
			}
			_time = 0;			
			_chunkSize = 0;			
			_p2pReady = false;
			_metaDataReady = false;	
			
			_isSeeking = false;
			_seekOk = false;
			_httpSize = 0;
			_p2pSize = 0;
			
			_startRunTime = 0;
			
			_changeMetaData = false;
			_isLive = true;
			
			//_errorLimited = 0;
			//_errored = 0;
			_serverCurtime = 0;
			_serverOffsetTime = 0;
			_firstRunTime = 0;
			
			//_isEmpty = true;
			
			_isTrueLiveType = true;
			_falseLiveTime  = 0;
		}
		
		override public function get time():Number
		{
			//return _time+super.time;			
			return super.time;
		}
		public function getManager():DataManager
		{
			return _manager;
		}
		public function getStatisticData():Object
		{
			return _statisticData.getStatisticData();
		}
		
		public function get version():String
		{
			return VERSION;
		}		
		public function set callBack(obj:Object):void
		{
			_callBackObject[obj.key] = obj;
			
		}
		protected function callBackFunction(obj:Object):void
		{
			for each ( var i:* in _callBackObject)
			{			  
				i.fun.call(null,obj);
			}
		}
		public function set outMsg(fun:Function):void
		{
			_outMsg = fun;
			_outMsg.call(null,VERSION,"version");
			//			
		}
		override public function get client():Object
		{
			return super.client.client;
		}
		
		override public function set client(value:Object):void
		{
			super.client.client = value;
		}		
		
		protected function realPlay():void
		{					
			_timer.start();
			_statisticData.setInitTime(this);
			_manager.startTime = getTime();
		}	
		
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
		{
			if (priority>_priority&&type==NetStatusEvent.NET_STATUS)
			{
				this.removeEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS,false);
				_priority = priority + 1;
				this.addEventListener(NetStatusEvent.NET_STATUS,_this_NET_STATUS,false,_priority);
			}
			super.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}
		
		protected function onMetaData(obj:Object):void
		{	
			//MZDebugger.trace(this,{"key":"INIT","value":"\n 触发onMetaData事件  "+_metaDataReady});
			if (_metaDataReady)
				return ;			
			_metaDataReady = true;	
			
		}
		//---------------------------------------
		protected function _timer_TIMER(event:TimerEvent):void
		{			
			//在直播状态下，当出现数据未下载，等待数据下载时，判断是否已经超出直播范围
			// 服务器当前时间：_serverCurtime + (Math.round(getTime()/1000) - _startRunTime)
			// 如果为直播时目前应该播放的文件块索引 ：服务器当前时间 - _falseLiveTime
			// 当服务器当前的时间与直播播放的文件块索引之差大于20秒时，则判断为shiyizhuan
			if(_isLive && _byteArrayIndex!=0 )
			{		
				var standTime:int;
				if(_isTrueLiveType)
				{					
					standTime = _firstRunTime;
				}
				else
				{
					standTime = _serverCurtime;
				}
				//trace(" >> "+(standTime + (Math.round(getTime()/1000) - _startRunTime) - _falseLiveTime - _byteArrayIndex));
				if((standTime + (Math.round(getTime()/1000) - _startRunTime) - _falseLiveTime - _byteArrayIndex)>20)
				{
					_isLive = false;
					dispatchChangePlayMode("timeShift");
				}				
			}
			//MZDebugger.trace(this,{"key":"OTHER","value":"\n _p2pReady = "+_p2pReady+"\n _metaDataReady = "+_metaDataReady+"\n _isPause = "+_isPause+"\n _isSeeking = "+_isSeeking});
			if (!_p2pReady || !_metaDataReady || _isPause || _isSeeking)
			{		
				return;
			}
			//MZDebugger.trace(this,{"key":"OTHER","value":"\n 初始化准备完毕！"});
			var object:Object = new Object();//回调发送数据对象
						
			if (this.bufferLength < this.bufferTime + 1)
			{				
				var nextIndex:uint = _manager.nextChunkIndex(_byteArrayIndex);
				if(nextIndex == _byteArrayIndex || nextIndex == 0)
				{
					return;
				}
				//trace("***********  "+nextIndex);
				//MZDebugger.trace(this,{"key":"OTHER","value":"\n 播放点"+nextIndex});
				var data:ByteArray = _manager.readByteArray(nextIndex);
				if (data)
				{				
					//_errored = 0;
					
					this.appendBytes(data);
					_byteArrayIndex = nextIndex;
					
					if(_firstRunTime == 0)
					{
						_firstRunTime = _byteArrayIndex;
					}
					
					if(_changeMetaData)
					{
						var obj:Object = new Object();
						obj.startTime = nextIndex + _falseLiveTime;
						dispatchPlayStartEvent(obj);
						_changeMetaData = false;
					}
					//
					object.name = "chunkIndex";
					object.info = nextIndex;		
					callBackFunction(object);
					//
					MZDebugger.customTrace(this,Protocol.CHUNKINDEX,nextIndex);
				}
			}
			
			MZDebugger.customTrace(this,Protocol.BUFFERLENGTH,bufferLength);
			MZDebugger.customTrace(this,Protocol.TIME,time);
			MZDebugger.customTrace(this,Protocol.BUFFERTIME,bufferTime);
			MZDebugger.customTrace(this,Protocol.MEMORY,System.totalMemory);
			object.name = "bufferLength";
			object.info = bufferLength;
			callBackFunction(object);
			object.name = "time";
			object.info = time;
			callBackFunction(object);
			object.name = "bufferTime";
			object.info = bufferTime;
			callBackFunction(object);
		}
		protected function _manager_STATUS(event:DataManagerEvent):void
		{			
			var object:Object = new Object();
			var code:String = event.info.code;
			var obj:Object = new Object();
			
			//此P2PNetStreamLocalEvent事件发给_statisticData，提供数据统计,
			//P2PNetStreamLocalEvent事件不对外公布！！
			if(code.indexOf("gatherConnect") == -1 || code == "P2P.gatherConnect.Success")
			{
				dispatchEvent(new P2PNetStreamLocalEvent(P2PNetStreamLocalEvent.P2P_STATUS, event.info));
			}
			
			switch (code)
			{
				case "P2P.HttpGetChunk.Failed" :	
					dispatchLoadClipFailEvent(event.info);
					break;
				case "P2P.selectorConnect.Success":		
					dispatchP2PReportEvent(event.info,"selector_success");
					break;
				case  "P2P.gatherConnect.Start":					
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,String(event.info.gatherName+":"+event.info.gatherPort),"gatherName");
					}
					//
					object.name = "gather";
					object.info = String(event.info.gatherName+":"+event.info.gatherPort);
					callBackFunction(object);
					//			
					break;
				case "P2P.gatherConnect.Success":
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,String(event.info.gatherName+":"+event.info.gatherPort+"  OK"),"gatherName");
					}
					dispatchP2PReportEvent(event.info,"gather_success");
					
					object.name = "gatherOk";
					callBackFunction(object);
					break;
				case "P2P.gatherConnect.Failed":
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,String(event.info.gatherName+":"+event.info.gatherPort+"  Failed"),"gatherName");
					}
					object.name = "gatherFailed";
					callBackFunction(object);
					break;
				case  "P2P.rtmfpConnect.Start":
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,event.info.rtmfpName,"rtmfpName");
					}
					object.name = "rtmfp";
					object.info = String(event.info.rtmfpName +":"+ event.info.rtmfpPort);
					callBackFunction(object);
					break;
				case "P2P.rtmfpConnect.Success":
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,event.info.rtmfpName+" OK","rtmfpName");						
						_outMsg.call(null,String(event.info.ID).substr(0,10),"myName");
					}
					dispatchP2PReportEvent(event.info,"rtmfp_success");
					object.name = "myPeerID";
					object.info = event.info.ID;
					callBackFunction(object);
					object.name = "rtmfpOk";
					callBackFunction(object);
					//
					object.name = "checkSum";
					object.info = VERSION;
					callBackFunction(object);
					//
					break;
				case "P2P.rtmfpConnect.Failed":
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,event.info.rtmfpName+"  Failed","rtmfpName");
					}
					object.name = "rtmfpFailed";
					callBackFunction(object);
					break;
				case "P2P.P2PGetChunk.Success" :					
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,String("P2P "+event.info.id+"_"+event.info.pieceID+", from: "+String(event.info.peerID).substr(0,10)));
						//
						_p2pSize += event.info.size;
						_outMsg.call(null,String(Math.round(_p2pSize/(_httpSize+_p2pSize)*10000)/100+"%"),"p2p下载率");
					}
					//
					dispatchP2PReportEvent(event.info,"load_success");
					//
					break;
				case "P2P.HttpGetChunk.Success" :
					/**/
					if(_outMsg != null)
					{
						_outMsg.call(null,String("CDN "+event.info.id));
						//
						_httpSize += event.info.size;
						_outMsg.call(null,String(Math.round(_p2pSize/(_httpSize+_p2pSize)*10000)/100+"%"),"p2p下载率");
						//
					}
					dispatchLoadClipSuccessEvent(event.info);
					break;
				case "P2P.Neighbor.Connect":
					object.name = "peerID";
					object.info = event.info.peerID;
					callBackFunction(object);
					break;
				
			}
			//
			object = null;
			obj    = null;
		
		}
		
		protected function liveDataLoaderHandler(e:HttpLiveEvent):void
		{
			//dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_STATUS,e.info));		
			var info:Object = e.info;
			switch(e.info.code)
			{
				case HttpLiveEvent.LOAD_DESC_SUCCESS:
					_p2pReady = true;
					dispatchLoadXMLSuccessEvent(e.info.shiftTime);
					break;
				case HttpLiveEvent.LOAD_DESC_NOT_EXIST:
				case HttpLiveEvent.LOAD_DESC_IO_ERROR:
				case HttpLiveEvent.LOAD_DESC_SECURITY_ERROR:	
					info.error = 502;
					dispatchLoadXMLFailEvent();
					break;
				case HttpLiveEvent.LOAD_DESC_PARSE_ERROR:
					info.error = 909;
					dispatchLoadXMLFailEvent();
					break;
				
				case HttpLiveEvent.LOAD_HEADER_SUCCESS:
					trace(this+"metadata"+getTime());
					super.seek(0);
					this.appendBytesAction("resetBegin");	
					this.appendBytes(e.info.data as ByteArray);
					_seekOk    = false;
					_isSeeking = true;
					
					//MZDebugger.trace(this,{"key":"INIT","value":"\n LOAD_HEADER_SUCCESS ： "+(e.info.data as ByteArray).bytesAvailable});
					
					if(_startRunTime == 0)
					{
						_startRunTime = Math.round(getTime()/1000);
					}
						
					if(!_changeMetaData)
					{
						dispatchPlayStartEvent(e.info);
					}
                    _metaDataReady = true
					break;
				//
				case HttpLiveEvent.CHANGE_METADATA:					
					_metaDataReady = false;
					_seekOk = false;
					_changeMetaData = true;
					break;
				//
				case HttpLiveEvent.LOAD_HEADER_IO_ERROR:
				case HttpLiveEvent.LOAD_HEADER_SECURITY_ERROR:
					info.error = 502;
					dispatchLoadClipFailEvent(info);
					break;
				/*case HttpLiveEvent.LOAD_CLIP_SUCCESS:
					dispatchLoadClipSuccessEvent(info);
					break;
				case HttpLiveEvent.LOAD_CLIP_IO_ERROR:
					dispatchLoadClipFailEvent(info);
					break;
				case HttpLiveEvent.LOAD_CLIP_SECURITY_ERROR:
					dispatchLoadClipFailEvent(info);
					break;			*/
			}
		}	
		
		protected function _this_NET_STATUS(event:NetStatusEvent):void
		{
			var code:String = event.info.code;
			switch (code)
			{
				case "NetStream.Buffer.Empty" :
					//_isEmpty = true;
					dispatchBufferEmptyEvent();				
					break;
				case "NetStream.Buffer.Full" :
					//_isEmpty = false;
					dispatchBufferFullEvent();
					break;
				case "NetStream.Pause.Notify" :
					_isPause = true;
					dispatchPauseNotifyEvent();
					break;
				case "NetStream.Unpause.Notify" :
					_isPause = false;
					dispatchUnpauseNotifyEvent();
					break;
				case "NetStream.Seek.Notify" :					
				case "NetStream.Seek.Failed":
				case "NetStream.Seek.InvalidTime":									
					this.appendBytesAction("resetSeek");
					_seekOk = true;
					_isSeeking = false;
					dispatchSeekCompleteEvent();
					break;					
			}
		}		
		protected function dispatchLoadXMLSuccessEvent(shiftTime:Number):void
		{
			var info:Object=new Object();
			info.code = "Http.LoadXml.Success";
			info.shiftTime = shiftTime;
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));		
		}
		private function dispatchAllOverEvent(id:Number=-1):void
		{
			var info:Object = new Object();
			info.code = "Stream.Play.Failed";	
			info.p2pErrorCode = "0000";
			info["allCDNFailed"] = 1;
			info.id = id;
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_All_OVER,info));
			//_errored = 0;
		}
		protected function dispatchLoadXMLFailEvent():void
		{
			/*var info:Object=new Object();
			_errored++;
			if(_errored < _errorLimited)
			{
				info["code"] = "Http.LoadXml.Failed";
				info["allCDNFailed"] = 0;
				dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));	
			}
			else
			{
				dispatchAllOverEvent();
			}*/
			dispatchAllOverEvent();
		}
		protected function dispatchLoadClipSuccessEvent(obj:Object):void
		{
			var info:Object=new Object();
			info = obj ; 
			info.code = "Http.LoadClip.Success";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
		}		
		protected function dispatchLoadClipFailEvent(obj:Object):void
		{		
			if(!obj)
			{
				return;
			}
			var info:Object=new Object();
			info = obj ;
			
			if(info["allCDNFailed"])
			{
				if(info["allCDNFailed"]!=1)
				{
					info["code"] = "Stream.Play.Failed";
					info["allCDNFailed"] = 0;
					dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));	
				}
				else
				{
					if(this.bufferLength<=0.5)
					{
						dispatchAllOverEvent(info.id);
					}					
				}
			}
			else
			{
				info["code"] = "Stream.Play.Failed";
				info["allCDNFailed"] = 0;
				dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));	
			}					
		}
		protected function dispatchSeekStartEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Seek.Start";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
			TraceMessage.tracer("Stream.Seek.Start,time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchSeekCompleteEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Seek.Complete";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));
			TraceMessage.tracer("Stream.Seek.Complete,time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchPlayStartEvent(obj:Object):void
		{	
			var info:Object=new Object();
			info = obj;
			info.code = "Stream.Play.Start";
			if(!info.startTime)
			{
				info.startTime = Math.round(getTime()/1000) + _serverOffsetTime;
				trace("info.startTime  "+info.startTime)
			}			
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
			TraceMessage.tracer("Stream.Play.Start");
			//-----------------------
		}
		protected function dispatchPlayStopEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Play.Stop";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));		
			TraceMessage.tracer("Stream.Play.Stop");
			//-----------------------
		}
		protected function dispatchBufferEmptyEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Buffer.Empty";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
			TraceMessage.tracer(info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchBufferFullEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Buffer.Full";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
			TraceMessage.tracer(info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchPauseNotifyEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Pause.Notify";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
			TraceMessage.tracer(info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		protected function dispatchUnpauseNotifyEvent():void
		{
			var info:Object=new Object();
			info.code = "Stream.Unpause.Notify";
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));			
			TraceMessage.tracer(info.code+","+"time="+time+",bufferLength="+bufferLength+",bufferTime"+bufferTime);
			//-----------------------
		}
		/*
		protected function dispatchPlayFailedEvent(obj:Object,type:String=null):void
		{			
			var info:Object=new Object();
			info = obj ;
			_errored++;
			if(_errored < _errorLimited)
			{
				info["code"] = "Stream.Play.Failed";	
				info["allCDNFailed"] = 0;
				dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,info));	
			}
			else
			{
				dispatchAllOverEvent();
			}
					
			TraceMessage.tracer(""+info.code+","+info.error+","+info.text+",time="+time+",bufferLength="+bufferLength+",bufferTime="+bufferTime+",allCDNFailed="+info.allCDNFailed);			
		}
		*/
		private function dispatchP2PReportEvent(obj:Object,type:String):void
		{
			if(_P2PReportRecoder[type])
			{
				return;
			}
			
			var thisTime:Number = Math.floor((new Date()).time);
			
			var info:Object = new Object();
			info.code  = type;
			info.act   = obj.act;
			info.err   = obj.error;
			info.type  = "live";
			info.utime = thisTime - _manager.startTime;
			if(type == "gather_success")
			{
				info.ip   = obj.gatherName;
				info.port = obj.gatherPort;
			}
			else if(type == "rtmfp_success")
			{
				info.ip   = obj.rtmfpName;
				info.port = obj.rtmfpPort;
			}
			else
			{
				info.ip   = "0";
				info.port = 0;
			}
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.P2P_STATUS,info));
			//----------------------------内部监控上报
			KernelReport.PROGRESS(info);
			//----------------------------
			
			
			_P2PReportRecoder[type] = type;
			_manager.startTime = thisTime;
			
			trace("核心_____________________info.act = "+info.act+"  utime = "+info.utime+"  error = "+info.err);
			
		}
		private function dispatchChangePlayMode(mode:String):void
		{
			var obj:Object = new Object();
			obj["code"] = "Stream.Change.PlayMode";
			obj["mode"] = mode;
			//对播放器切换模式
			dispatchEvent(new P2PNetStreamEvent(P2PNetStreamEvent.STREAM_STATUS,obj));
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		} 
	}
}