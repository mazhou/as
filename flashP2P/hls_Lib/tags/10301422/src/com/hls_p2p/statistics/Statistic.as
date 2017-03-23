package com.hls_p2p.statistics
{
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.KernelReport;
	import com.hls_p2p.stream.HTTPNetStream;
	import com.p2p.utils.ArraySortMerge;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLRequest;
	import flash.net.sendToURL;

	public class Statistic
	{
		public var isDebug:Boolean=true;
		
		private static var instance:Statistic=null;
		/**初始化数据*/
		protected var _initData:InitData;
		/**netstream引用*/
		protected var _netStream:HTTPNetStream;
		/**心跳周期内http累计下载的字节数*/
		private var _csize:Number=0;
		/**从开始播放开始累积的总的http下载字节数*/
		private var _totalHttpsizeNum:Number=0;
		/**心跳周期内http累计下载耗时，毫秒*/
		private var _httpTimeNum:Number=0;
		/**从开始播放开始累积的总的http下载耗时，毫秒*/
		private var _totalHttpTimeNum:Number=0;
		/**是否下载数据*/
		private var _downLoadBoo:Boolean=false;	
		/**存p2p开始结尾时间数据*/
		private var _p2pArr:Array=[];
		/**存p2p已经排序合并花费时间*/
		private var _p2pTimeArr:Array=[];

		/**心跳周期内来自PC端的p2p累计下载字节数*/
		private var _dsize:Number=0;	
		/**从开始播放开始累积的总的p2p下载字节数*/
		private var _totalP2PsizeNum:Number=0;	
		/**从开始播放开始累积的总的p2p下载耗时，毫秒*/
		private var _totalP2PTimeNum:Number=0;	
		/**分享数据大小*/
		//private var _p2pSendSizeNum:Number=0;
		/**心跳周期内来自TV端的p2p累计下载字节数*/
		private var _tsize:Number=0;
		/**心跳周期内来自手机端的p2p累计下载字节数*/
		private var _msize:Number=0;
		/**心跳周期内来自盒子端的p2p累计下载字节数*/
		private var _bsize:Number=0;
		/**/
		private var _dnodeTotal:int = 0;
		private var _lnodeTotal:int = 0;
		/**_dnode次数*/
		private var _dnodeTimes:int = 0;
		/**_lnode次数*/
		private var _lnodeTimes:int = 0;
		/**rtmfp服务器的状态，当rtmfp中断时_lnodeTotal = -1，_dnodeTotal=-1*/
		private var _rtmfpSuccess:Boolean = false;//
		//
		private var _rIP:String = "0";
		private var _gIP:String = "0";
		private var _rPort:uint = 0;
		private var _gPort:uint = 0;
		
		private var _newTime:Number=0;
		private var _preTime:Number=0;
		
		/**内部心跳上报使用的地址*/
		private var nativeTrafficPath:String = "http://s.webp2p.letv.com/ClientTrafficInfo?"		
		
		/**保存本地测试播放器输出面板回调函数的对象*/
		public var nativeCallBackObj:Object = new Object();
		
		/**正式播放器使用的回调函数*/
		public var outMsg:Function;
		
		public function Statistic(single:Singleton):void
		{
			KernelReport.progressReportTime = getTime();
		}
		
		public static function getInstance():Statistic
		{
			if(instance==null)
			{
				instance=new Statistic(new Singleton());
			}
			return instance;
		}
		public function clear():void
		{			
			reset();			
			
			_newTime = 0;
			_preTime = 0;
			_rtmfpSuccess = false;
			
			_rIP = "0";
			_gIP = "0";
			_rPort = 0;
			_gPort = 0;
			
			_totalHttpsizeNum = 0;
			_totalHttpTimeNum = 0;
			_totalP2PsizeNum = 0;
			_totalP2PTimeNum = 0;
			
//			outMsg=null;
			for(var e:* in nativeCallBackObj)
			{
				e=null;
				delete nativeCallBackObj[e];
			}
			nativeCallBackObj=new Object;
			if(_netStream)
			{		
				_netStream = null;
			}
			KernelReport.clear();
		}
		
		private function reset():void
		{
			_p2pArr=[];
			_p2pTimeArr=[];	
			
			_dsize=0;
			//_p2pSendSizeNum = 0;
			_csize=0;
			
			_tsize=0;
			_msize=0;
			_bsize=0;
			
			_dnodeTotal = 0;
			_lnodeTotal = 0;
			_dnodeTimes = 0;
			_lnodeTimes = 0;
			
			_downLoadBoo=false;
		}
		/**遍历本地测试播放器的回调函数，找到相应的函数，改变输出面板的状态*/
		private function testCallBack(obj:Object):void
		{
			for each ( var i:* in nativeCallBackObj)
			{			  
				i.fun(obj);
			}
		}
		private function streamPlayHandler(evt:EventExtensions):void
		{
			P2PDebug.traceMsg(this,"统计响应play事件");
			_initData=evt.data as InitData;	
			if(outMsg != null)
			{
				outMsg(LiveVodConfig.GET_VERSION(),"version");
			}			
			/**设置KernelReport*/
			var type:String="";
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				type="vod";
			}else if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
			{
				type="live";
			}
			KernelReport.SET_INFO(LiveVodConfig.GET_VERSION(),_initData.groupName,type);
			
			/**过程上报act=1*/
			P2PNetStreamSuccess();
			
			/**输出面板显示groupID*/
			//getGroupID()
		}
		/**输出面板调用，显示groupID*/
		public function getGroupID(gID:String):void
		{
			/**外部输出面板*/
			if(outMsg != null)
			{
				outMsg(_initData.groupName,"groupName");
			}
			/**内部输出面板*/
			var object:Object = new Object();
			object.name = "groupName";
			object.info = gID;
			testCallBack(object);
		}
		/**回调onMateData*/
		public function callBackMateData(obj:Object):void
		{
			_netStream.notifyTotalDuration(obj);
		}
		/**过程上报使用,act=1,P2PNetStream成功执行*/
		public function P2PNetStreamSuccess():void
		{
			if(KernelReport.progressReportObj["P2P.P2PNetStream.Success"])
			{
				var obj:Object = new Object();
				obj.code = "P2P.P2PNetStream.Success";
				KernelReport.PROGRESS(obj);	
			}			
		}
		/**输出面板使用*/
		public function timeOutput(time:Number):void
		{
			/**内部输出面板上报*/
			var object:Object = new Object();
			object.name = "time";
			object.info = Math.round(time);//(LiveVodConfig.IS_REAL_LEAD ? "leader":LiveVodConfig.NAME_OF_LEADER);
			testCallBack(object);
			/**外部输出面板使用*/
			//trace(Config.IS_REAL_LEAD?"true":"false")
//			if(outMsg != null)
//			{
//				outMsg(object.info,"isLeader");
//				//outMsg(LiveVodConfig.IS_REAL_LEAD?"true":"false","isLeader");
//			}
		}
		/**输出面板上报*/
		public function setPlayHead(id:String):void
		{
			/**内部输出面板上报*/
			var object:Object = new Object();
			object.name = "chunkIndex";
			object.info = id;		
			testCallBack(object);
		}
		/**过程上报使用,直播第一次成功加载desc数据*/
		/**输出面板上报*/
		public function loadXMLSuccess(/*utime:Number,minute:Number=0*/):void
		{
			/**过程上报使用*/
			if(KernelReport.progressReportObj["P2P.LoadXML.Success"])
			{
				var obj:Object = new Object();
				obj.code = "P2P.LoadXML.Success";
				//obj.utime = utime;
				KernelReport.PROGRESS(obj);	
			}
			
			/**内部输出面板上报*/
			/*
			var object:Object = new Object();			
			var date:Date = new Date(minute*1000);
			object.code = "Http.LoadXML.Success";
			object.id   = date.hours+":"+date.minutes;
			_netStream.dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));*/
			
		}
		/**过程上报使用,第一次成功连接selector*/
		public function selectorSuccess():void
		{
			if(KernelReport.progressReportObj["P2P.SelectorConnect.Success"])
			{
				var obj:Object = new Object();
				obj.code = "P2P.SelectorConnect.Success";
				KernelReport.PROGRESS(obj);	
			}			
		}
		/**输出面板使用,开始连接rtmfp时*/
		public function rtmfpStart(rtmfpName:String,rtmfpPort:uint):void
		{
			_rIP   = rtmfpName;
			_rPort = rtmfpPort;
			
			if(outMsg != null)
			{
				outMsg(String(rtmfpName+":"+rtmfpPort),"rtmfpName");
			}
			
			var obj:Object = new Object();
			obj.name = "rtmfp";
			obj.info = String(rtmfpName +":"+ rtmfpPort);
			testCallBack(obj);
			
		}
		/**过程上报使用,第一次成功连接rtmfp*/
		public function rtmfpSuccess(rtmfpName:String,rtmfpPort:uint,myName:String):void
		{
			_rIP   = rtmfpName;
			_rPort = rtmfpPort;
			_rtmfpSuccess = true;
			
			/**过程上报*/
			if(KernelReport.progressReportObj["P2P.RtmfpConnect.Success"])
			{
				var obj:Object = new Object();
				obj.code = "P2P.RtmfpConnect.Success";
				obj.ip   = rtmfpName;
				obj.port = rtmfpPort;
				KernelReport.PROGRESS(obj);
			}
			
			/**外部输出面板*/
			if(outMsg != null)
			{
				outMsg(String(rtmfpName+":"+rtmfpPort+" OK"),"rtmfpName");						
				outMsg(String(myName).substr(0,10),"myName");
			}
			/**内部输出面板*/
			var object:Object = new Object();
			object.name = "myPeerID";
			object.info = myName;
			testCallBack(object);
			object.name = "rtmfpOk";
			testCallBack(object);
			object.name = "checkSum";
			object.info = LiveVodConfig.GET_VERSION();
			testCallBack(object);
			
		}
		/**输出面板使用*/
		public function rtmfpFailed(rtmfpName:String,rtmfpPort:uint):void
		{
			_rtmfpSuccess = false
			/**外部输出面板*/
			if(outMsg != null)
			{
				outMsg(String(rtmfpName+":"+rtmfpPort+" Failed"),"rtmfpName");
			}
			/**内部输出面板*/
			var object:Object = new Object();
			object.name = "rtmfpFailed";
			testCallBack(object);
		}
		/**输出面板使用*/
		public function gatherStart(gatherName:String,gatherPort:uint):void
		{
			/**外部输出面板*/
			if(outMsg != null)
			{
				outMsg(String(gatherName+":"+gatherPort),"gatherName");
			}
			/**内部输出面板*/
			var object:Object = new Object();
			object.name = "gather";
			object.info = String(gatherName+":"+gatherPort);
			testCallBack(object);
		}
		/**过程上报使用,第一次成功连接gather*/
		public function gatherSuccess(gatherName:String,gatherPort:uint):void
		{
			_gIP = gatherName;
			_gPort = gatherPort;
			
			if(outMsg != null)
			{
				outMsg(String(gatherName+":"+gatherPort+"  OK"),"gatherName");
			}
			
			if(KernelReport.progressReportObj["P2P.GatherConnect.Success"])
			{
				var obj:Object = new Object();
				obj.code = "P2P.GatherConnect.Success";
				obj.ip   = gatherName;
				obj.port = gatherPort;
				KernelReport.PROGRESS(obj);
			}
			
			var object:Object = new Object();
			object.name = "gatherOk";
			testCallBack(object);
		}
		/**输出面板使用*/
		public function gatherFailed(gatherName:String,gatherPort:uint):void
		{
			if(outMsg != null)
			{
				outMsg(String(gatherName+":"+gatherPort+" Failed"),"gatherName");
			}
			//
			var object:Object = new Object();
			object.name = "gatherFailed";
			testCallBack(object);
		}
		/**内部输出面板使用*/
		public function peerWantData(obj:Object,name:String):void
		{
			var object:Object = new Object();
			object.blockID    = obj.blockID;	
			object.pieceID    = obj.pieceID;	
			object.name       = name;
			object.code       = "P2P.OtherPeerWantChunk.Success";
			_netStream.dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**内部输出面板使用*/
		public function P2PWantData(arr:Array,name:String):void
		{
			for(var i:int=0 ; i<arr.length ; i++)
			{
				var object:Object = new Object();
				object.blockID    = arr[i].blockID;	
				object.pieceID    = arr[i].pieceID;	
				object.name       = name;
				object.code       = "P2P.WantChunk.Success";
				(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			}
		}
		/**过程上报使用,第一次成功下载到p2p数据*/
		/**统计上报使用，记录每次p2p下载耗时和数据大小
		 * peerType表示邻居节点是何种类型的客户端，包括"PC","TV","MP","BOX"
		 * */
		public function P2PGetData(id:String,begin:Number,end:Number,size:Number,peerID:String,clientType:String="PC"):void
		{
			var tempEventName:String = "P2P.P2PGetChunk.Success"
			/**过程上报使用*/
			if(KernelReport.progressReportObj[tempEventName])
			{
				var obj:Object = new Object();
				obj.code = tempEventName;
				KernelReport.PROGRESS(obj);
			}			
			
			/**统计上报使用*/
			/*if(!isNaN(begin)||!isNaN(end))
			{
				_p2pArr.push([begin,end]);						
			}else
			{
				P2PDebug.traceMsg(this,"p2p时间报NaN啦~~~~~~");
			}*/
			
			switch(clientType)
			{
				case "PC":
					_dsize += size;
					break;
				case "TV":
					_tsize += size;
					break;
				case "MP":
					_msize += size;
					break;
				case "BOX":
					_bsize += size;
					break;
			}
								
			//_peerIdArr.push(event.data.peerID);			
			_downLoadBoo=true;
			 
			var date:Date;
			
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.id = id+", "+String(peerID).substr(0,8)+", "+clientType;
			if(String(id).split("_")[2]=="0")
			{
				date = new Date(0,0,0,0,0,int(String(id).split("_")[0]));
				object.id = object.id+", "+date.hours+":"+date.minutes+":"+date.seconds;
			}
			//object.peerID = peerID;
			object.code   = tempEventName;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				if(date)
				{
					id = id+", "+date.hours+":"+date.minutes+":"+date.seconds;
				}
				outMsg(String("--> p2p "+id+" : "+peerID.substr(0,8)+", "+clientType));
			}
			
			/**内部输出面板使用*/
			reportP2PRate();
		}
		/**统计上报使用,当从CDN下载数据时调用*/
		/**输出面板使用*/
		public function httpGetData(id:String,begin:Number,end:Number,size:Number):void
		{
			/**统计上报使用*/
			if(!isNaN(begin)||!isNaN(end))
			{
				_httpTimeNum += end - begin;				
			}else
			{
				P2PDebug.traceMsg(this,"p2p时间报NaN啦~~~~~~");
			}
			_csize += size;
			_downLoadBoo=true;
			//P2PDebug.traceMsg(this,"_httpTimeNum = "+_httpTimeNum+"   _csize = "+_csize+" outMsg:"+outMsg);
				
			var date:Date;
				
			/**输出面板使用*/
			var object:Object = new Object();
			object.id = id;
			if(String(id).split("_")[2]=="0")
			{
				date =new Date(int(String(id).split("_")[0])*1000);/*new Date(Number(String(id).split("_")[0])*1000);*/
				object.id = object.id+" "+date.hours+":"+date.minutes+":"+date.seconds;
			}
			
			object.code = "Http.LoadClip.Success";
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				if(date)
				{
					id = id+", "+date.hours+":"+date.minutes+":"+date.seconds;
				}
				outMsg(String("--> http "+id));
			}
			
			/**内部输出面板使用*/
			reportP2PRate();
		}
		private function reportP2PRate():void
		{
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.info = Math.round(Number(1000*(_totalP2PsizeNum + _dsize+_tsize+_msize+_bsize)/((_totalHttpsizeNum + _csize)+(_totalP2PsizeNum + _dsize+_tsize+_msize+_bsize))))/10;
			object.name   = "P2PRate";
			testCallBack(object);
			/**外部输出面板使用*/
			if(outMsg != null)
			{				
				outMsg(String(object.info+"%"),"p2p下载率");				
			}
		}
		/**输出面板使用,当CDN加载失败时调用*/
		public function httpGetFailed(id:String):void
		{
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.id = id;
			object.code = "Http.LoadClip.Failed";
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**统计上报使用，输出面板使用，更新邻居节点信息时上报*/
		public function getNeighbor(obj:Object,dnode:uint,lnode:uint):void
		{		
			/**统计使用，*/
			_dnodeTotal += dnode;
			_dnodeTimes++;
			
			_lnodeTotal += lnode;
			_lnodeTimes++;
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{				
				outMsg(dnode,"dnode");
				outMsg(lnode,"lnode");					
			}
			
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.name = "peerID";
			object.data = obj;
			testCallBack(object);
			
		}
		/**输出面板使用,当给别人分享数据时调用*/
		public function P2PShareData(id:String,peerID:String/*,size:Number*/):void
		{
			/**输出面板使用*/
			var object:Object = new Object();			
			object.code = "P2P.P2PShareChunk.Success";
			object.id   = id;
			object.peerID = peerID;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			//_p2pSendSizeNum += size;
		}
		/**输出面板显示，当淘汰数据时调用*/
		public function removeData(id:String):void
		{
			/**输出面板使用*/
			var object:Object = new Object();			
			object.code = "P2P.RemoveData.Success";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当dat跳过时调用*/
		public function DatSkip(id:String):void
		{
			var object:Object = new Object();			
			object.code = "P2P.DatSkip.Success";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当xml跳过时调用*/
		public function DESCSkip(id:String):void
		{
			var object:Object = new Object();			
			object.code = "P2P.DESCSkip.Success";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当xml成功加载时调用*/
		public function DESCSuccess(id:String):void
		{
			//
		}
		/**输出面板使用，当CheckSum验证失败时调用*/
		public function P2PCheckSumFailed(id:String):void
		{
			/**内部输出*/
			var object:Object = new Object();			
			object.code = "P2P.CheckSum.Failed";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				outMsg(String("cs Failed "+id));
			}
		}
		/**输出面板使用，当xml加载失败时调用*/
		public function DESCFailed(id:String):void
		{
			var object:Object = new Object();			
			object.code = "Http.LoadXML.Failed";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当强行出现seek时调用*/
		public function forceSeek(id:String):void
		{
			var object:Object = new Object();			
			object.code = "Stream.ForceSeek.Start";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当CDN加载失败时调用*/
		public function httpGetDataFailed(id:String):void
		{
			//
		}
		/**统计上报使用，当彻底失败时调用*/
		public function allCDNFailed():void
		{
			
		}		
		/**输出面板使用*/
		public function bufferTime(bt:Number,bl:Number,ad:int,nowAd:int):void
		{
			/**外部输出面板使用*/
			if(outMsg != null)
			{				
				if(nowAd < 0)
				{
					nowAd = 0;
				}
				outMsg(String(bt+", BufLength= "+bl+", ad= "+ad+", nowAd= "+nowAd),"bufferTime");				
			}
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.info = bl;
			object.name = "bufferLength";
			testCallBack(object);

			object.info = bt;
			object.name = "bufferTime";
			testCallBack(object);
		}
		/**输出面板使用*/
		public function peerRemoveHaveData(peerID:String,bID:Number,pID:Number):void
		{
			var object:Object = new Object();
			
			object.code = "P2P.peerRemoveHaveData.Success";
			object.bID = bID;
			object.pID = pID;
			object.peerID = peerID.substr(0,5);
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));		
		}
		/**测试desc最大输出*/
		public function descLastTime(descT:String):void
		{
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.info = descT;
			object.name = "avgSpeed";
			testCallBack(object);
		}
		
		/**测试desc最大输出*/
		public function descLastFormatTime(descT:String):void
		{
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.info = descT;
			object.name = "P2PSpeed";
			testCallBack(object);
		}
		
		public function setNetStream(netStream:*):void
		{
			P2PDebug.traceMsg(this,"setNetStream");
			_netStream = netStream;
			KernelReport.netStream = netStream;	
			if(nativeCallBackObj == null)
			{
				nativeCallBackObj = new Object();
			}
			else
			{
				
			}
				
			_preTime = _newTime = getTime();
		}		
		
		public function addEventListener():void
		{
			EventWithData.getInstance().addEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);			
		}
		public function removeEventListener():void
		{
			if(EventWithData.getInstance().hasEventListener(NETSTREAM_PROTOCOL.PLAY))
			{
				EventWithData.getInstance().removeEventListener(NETSTREAM_PROTOCOL.PLAY,streamPlayHandler);
			}
			this.clear();
			instance=null;
		}
		/**添加下载数据流时报错输出*/
		public function setPieceStreamFailed(msg:String):void
		{
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.id = msg;			
			object.code = "SetPieceStreamFailed";
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{				
				outMsg(String("error: "+msg));
			}
		}
		public function getStatisticData():Object
		{
			_preTime=_newTime;
			_newTime=getTime();
			
			//p2p 周期内的下载耗时
			/**
			 * 目前不需要统计http和P2P的下载耗时！！！
			_p2pTimeArr=ArraySortMerge.init(_p2pArr)
			var p2ptimeNum:Number=0;
			var p2ptimeLen:int=_p2pTimeArr.length;
			p2ptimeNum = getTimeNum(p2ptimeLen,_p2pTimeArr);   //    毫秒
			*/			
			//http&p2p time
			var alltimeNum:Number=0;
			alltimeNum=(_newTime-_preTime)/1000;//秒
			
			var speedNum:Number=0;
			if(alltimeNum!=0&&(_dsize!=0||_csize!=0||_tsize!=0||_msize!=0||_bsize!=0))
			{
				speedNum=Math.ceil(Number((_csize+_dsize+_tsize+_msize+_bsize)/alltimeNum));
			}
			
			if(_downLoadBoo==false)
			{
				alltimeNum=0;
			}
			
			_totalHttpsizeNum += _csize;
			_totalP2PsizeNum  += (_dsize+_tsize+_msize+_bsize);
			
			var obj:Object = new Object();
			try
			{
				obj.code = "P2P.Statistic.Timer";
				if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
				{
					obj.type="vod";
				}else if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
				{
					obj.type="live";
				}
				
				obj.p2ptime  = 0;
				obj.p2psize  = _dsize+_tsize+_msize+_bsize;          //心跳周期内p2p下载大小（字节）		    Number			
				obj.httpsize = _csize;                     //心跳周期内http下载大小		      		Number
				obj.httpTime = 0;                          //http总下载耗（毫秒）	                    Number???????????????????
				obj.ltime    = _newTime-_preTime;          //心跳周期时长（毫秒）                Number			
				obj.cnod     = 0;                          //当前使用的cdn的标识号				
				obj.alltime  = Math.round(alltimeNum*1000);//心跳周期内总下载耗费时间(毫秒)	    Number????????????????????????需要修改
				obj.speednum = speedNum;                   //心跳周期内速度 （字节/秒）			Number
				
				if(_rtmfpSuccess)
				{
					_lnodeTimes = _lnodeTimes ? _lnodeTimes : 1;
					_dnodeTimes = _dnodeTimes ? _dnodeTimes : 1;
					obj.lnode  = Math.round((_lnodeTotal/_lnodeTimes) * 10)/10;
					obj.dnode  = Math.round((_dnodeTotal/_dnodeTimes) * 10)/10;
				}else
				{
					obj.lnode = -1;
					obj.dnode = -1;
				}			
				
				/**
				 * 内部心跳上报，上报内容：
				 * csize 周期内CDN下载大小（字节）
				 * dsize 周期内来自PC端的P2P下载大小（字节）
				 * tsize 周期内来自TV端的P2P下载大小（字节）
				 * msize 周期内来自手机端的P2P下载大小（字节）
				 * bsize 周期内来自BOX端的P2P下载大小（字节）
				 * dnode 周期内成功连接的平均节点数
				 * lnode 周期内所有可以连接的平均节点数
				 * gip   gather服务器ip
				 * gport gather服务器port
				 * rip   rtmfp服务器ip
				 * rport rtmfp服务器port
				 * gID   groupName
				 * ver   内核版本号
				 * type  live或vod
				 * termid   终端类型 直接使用调度地址提供的参数值
				 * platid   平台ID   直接使用调度地址提供的参数值
				 * splatid  子平台ID 直接使用调度地址提供的参数值
				 * r        随机数
				 * */
				var str:String = String(nativeTrafficPath+"csize="+_csize+"&dsize="+_dsize+"&tsize="+_tsize+"&msize="+_msize+"&bsize="+_bsize+"&dnode="+obj.dnode+"&lnode="+obj.lnode+"&gip="+_gIP+"&gport="+_gPort+"&rip="+_rIP+"&rport="+_rPort+"&gID="+_initData.groupName+"&ver="+LiveVodConfig.GET_VERSION()+"&type="+obj.type+"&termid="+LiveVodConfig.TERMID+"&platid="+LiveVodConfig.PLATID+"&splatid="+LiveVodConfig.SPLATID+"&r="+Math.floor(Math.random()*100000));		
				sendToURL(new URLRequest(str));
				
	 			reset();
			}
			catch(error:Error)
			{
				P2PDebug.traceMsg(this,"obj error");
			}
			return obj;
		}
		
		/**
		 *获取二维数组中，两个值的差的和。
		 */
		private function getTimeNum(len:int,arr:Array):Number
		{
			var num:Number=0;
			for(var n:int=0;n<len;n++)
			{
				num+=arr[n][1]-arr[n][0]
				//Debug.traceMsg(this,"arr[n][1] = "+arr[n][1]+"  ;  arr[n][0] = "+arr[n][0])
			}
			
			return num;
		}
		
		private function getTime():Number {
			return Math.floor((new Date()).time);
		}
	}
}
class Singleton{}