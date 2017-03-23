package com.hls_p2p.statistics
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.logs.P2PDebug;
	
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.net.sendToURL;
	import flash.utils.Timer;
	
	internal class StatisticsElement
	{
		private var _groupID:String = "";
		//protected var _netStream:HTTPNetStream;
		/**心跳周期内http累计下载的字节数*/
		public var csize:Number=0;
		/**心跳周期内来自PC端的p2p累计下载字节数*/
		public var dsize:Number=0;
		/**心跳周期内来自TV端的p2p累计下载字节数*/
		public var tsize:Number=0;
		/**心跳周期内来自手机端的p2p累计下载字节数*/
		public var msize:Number=0;
		/**心跳周期内来自盒子端的p2p累计下载字节数*/
		public var bsize:Number=0;
		/**心跳周期内http累计下载耗时，毫秒 */
		private var _httpTimeNum:Number=0;
		/**是否下载数据*/
		private var _downLoadBoo:Boolean=false;	
		/**存p2p开始结尾时间数据*/
		private var _p2pArr:Array=[];
		/**存p2p已经排序合并花费时间*/
		private var _p2pTimeArr:Array=[];
		/**心跳周期内累计成功连接节点的数量*/
		public var dnodeTotal:int = 0;
		/**心跳周期内累计获得可连接节点的数量*/
		public var lnodeTotal:int = 0;
		/**_dnode次数*/
		public var dnodeTimes:int = 0;
		/**_lnode次数*/
		public var lnodeTimes:int = 0;
		/**rtmfp服务器的状态，当rtmfp中断时_lnodeTotal = -1，_dnodeTotal=-1*/
		public var rtmfpSuccess:Boolean = false;//
		//
		public var rIP:String = "0";
		public var gIP:String = "0";
		public var rPort:uint = 0;
		public var gPort:uint = 0;
		
		private var _newTime:Number=0;
		private var _preTime:Number=0;
		
		/**内部心跳上报使用的地址*/
		private var nativeTrafficPath:String = "http://s.webp2p.letv.com/ClientTrafficInfo?"		
				
		/**/
		private var heartBeatReportTimer:Timer;
		
		private var heartTime:int=3*60*1000;
		
		private var runningState:String = "on"//"off";
			
		private var processReport:ProcessReport;
		
		public function StatisticsElement(id:String)
		{
			_groupID = id;
			
			if( !heartBeatReportTimer )
			{
				heartBeatReportTimer = new Timer(heartTime);
				heartBeatReportTimer.addEventListener(TimerEvent.TIMER,getStatisticData);
				heartBeatReportTimer.start();
			}
			
			processReport = new ProcessReport();
		}
		
		public function get groupID():String
		{
			return _groupID;
		}
		
		public function start():void
		{
			if( false == heartBeatReportTimer.running )
			{
				heartBeatReportTimer.start();
			}			
		}
		
		public function stop():void
		{
			heartBeatReportTimer.reset();
		}
		
		public function clear():void
		{
			reset();
			
			processReport.clear();
			
			if(heartBeatReportTimer)
			{
				heartBeatReportTimer.stop();
				heartBeatReportTimer.removeEventListener(TimerEvent.TIMER,getStatisticData);
			}	
		}
		private function reset():void
		{
			_p2pArr=[];
			_p2pTimeArr=[];	
			
			dsize=0;
			csize=0;			
			tsize=0;
			msize=0;
			bsize=0;
			
			dnodeTotal = 0;
			lnodeTotal = 0;
			dnodeTimes = 0;
			lnodeTimes = 0;
			
			_downLoadBoo=false;
		}
		public function getStatisticData(evt:TimerEvent=null):Object
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
			if(alltimeNum!=0&&(dsize!=0||csize!=0||tsize!=0||msize!=0||bsize!=0))
			{
				speedNum=Math.ceil(Number((csize+dsize+tsize+msize+bsize)/alltimeNum));
			}
			
			if(_downLoadBoo==false)
			{
				alltimeNum=0;
			}			
			
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
				obj.p2psize  = dsize+tsize+msize+bsize;          //心跳周期内p2p下载大小（字节）		    Number			
				obj.httpsize = csize;                     //心跳周期内http下载大小		      		Number
				obj.httpTime = 0;                          //http总下载耗（毫秒）	                    Number???????????????????
				obj.ltime    = _newTime-_preTime;          //心跳周期时长（毫秒）                Number			
				obj.cnod     = 0;                          //当前使用的cdn的标识号				
				obj.alltime  = Math.round(alltimeNum*1000);//心跳周期内总下载耗费时间(毫秒)	    Number????????????????????????需要修改
				obj.speednum = speedNum;                   //心跳周期内速度 （字节/秒）			Number
				
				var lnode:Number = -1;
				var dnode:Number = -1;
				if(rtmfpSuccess)
				{
					lnodeTimes = lnodeTimes ? lnodeTimes : 1;
					dnodeTimes = dnodeTimes ? dnodeTimes : 1;
					lnode  = Math.round((lnodeTotal/lnodeTimes) * 10)/10;
					dnode  = Math.round((dnodeTotal/dnodeTimes) * 10)/10;
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
				var str:String = String(nativeTrafficPath+"csize="+csize+"&dsize="+dsize+"&tsize="+tsize+"&msize="+msize+"&bsize="+bsize+"&dnode="+dnode+"&lnode="+lnode+"&gip="+gIP+"&gport="+gPort+"&rip="+rIP+"&rport="+rPort+"&gID="+groupID+"&ver="+LiveVodConfig.GET_VERSION()+"&type="+LiveVodConfig.TYPE+"&termid="+LiveVodConfig.TERMID+"&platid="+LiveVodConfig.PLATID+"&splatid="+LiveVodConfig.SPLATID+"&r="+Math.floor(Math.random()*100000));		
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