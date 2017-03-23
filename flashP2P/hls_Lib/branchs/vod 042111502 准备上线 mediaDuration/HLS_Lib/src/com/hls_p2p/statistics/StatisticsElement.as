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
		/**心跳周期内http累计下载的字节数 */
		private var _csize:Number=0;
		public function get csize():Number
		{
			return _csize;
		}
		/**心跳周期内来自PC端的p2p累计下载字节数*/
		private var _dsize:Number=0;
		public function get dsize():Number
		{
			return _dsize;
		}
		/**心跳周期内来自TV端的p2p累计下载字节数*/
		private var _tsize:Number=0;
		public function get tsize():Number
		{
			return _tsize;
		}
		/**心跳周期内来自手机端的p2p累计下载字节数*/
		private var _msize:Number=0;
		public function get msize():Number
		{
			return _msize;
		}
		/**心跳周期内来自盒子端的p2p累计下载字节数*/
		private var _bsize:Number=0;
		public function get bsize():Number
		{
			return _bsize;
		}
		public var totalP2PSize:Number = 0;
		public var totalCDNSize:Number = 0;
		/**周期内http累计下载耗时，毫秒*/
		private var _httpTimeForSpeed:Number=0;
		/**是否下载数据*/
		private var _downLoadBoo:Boolean=false;	
		/**存p2p开始结尾时间数据*/
		private var _p2pArr:Array=[];
		/**存p2p已经排序合并花费时间*/
		private var _p2pTimeArr:Array=[];
		/**心跳周期内累计成功连接节点的数量*/
		private var _dnodeTotal:int = 0;
		/**心跳周期内累计获得可连接节点的数量*/
		private var _lnodeTotal:int = 0;
		/**_dnode次数*/
		private var _dnodeTimes:int = 0;
		/**_lnode次数*/
		private var _lnodeTimes:int = 0;
		/**rtmfp服务器的状态，当rtmfp中断时__lnodeTotal = -1，__dnodeTotal=-1*/
		private var _rtmfpSuccess:Boolean = false;
		private var _gatherSuccess:Boolean = false;
		
		private var _rIP:String = "0";
		private var _gIP:String = "0";
		private var _rPort:uint = 0;
		private var _gPort:uint = 0;
		
		private var _newTime:Number=0;
		private var _preTime:Number=0;
		
		/**内部心跳上报使用的地址*/
		private var nativeTrafficPath:String = "http://s.webp2p.letv.com/ClientTrafficInfo?"		
		
		private var heartBeatReportTimer:Timer;
		
		private var heartTime:int = 3*60*1000;//30*1000;//
		
		private var speedSizeTime:int = 15;//计算下载速度时使用，表示speedSizeTime秒内累计（http和p2p）下载的字节大小
			
		private var _processReport:ProcessReport;
		
		private var _statistic:Statistic;
		
		public function StatisticsElement(statistic:Statistic,id:String)
		{
			_statistic = statistic
			_groupID = id;
			
			if( !heartBeatReportTimer )
			{
				heartBeatReportTimer = new Timer(heartTime);
				heartBeatReportTimer.addEventListener(TimerEvent.TIMER,getStatisticData);
				heartBeatReportTimer.start();
			}
			
			_processReport = new ProcessReport(id);
			_processReport.progressReportTime = getTime();
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
			//最后一次上报
			getStatisticData();
			
			reset();
			
			totalP2PSize = 0;
			totalCDNSize = 0;
			
			_httpTimeForSpeed = 0;
			
			while( speedArray && speedArray.length>0 )
			{
				speedArray.shift();
			}
			speedArray = null;
			
			_processReport.clear();
			
			if(heartBeatReportTimer)
			{
				heartBeatReportTimer.stop();
				heartBeatReportTimer.removeEventListener(TimerEvent.TIMER,getStatisticData);
			}
			_statistic = null;
		}
		
		private function reset():void
		{
			_p2pArr=[];
			_p2pTimeArr=[];	
			
			_dsize=0;
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
		
		public function getStatisticData(evt:TimerEvent=null):void
		{
			var lnode:Number = -1;
			var dnode:Number = -1;
			
			if( _rtmfpSuccess )
			{
				_lnodeTimes = _lnodeTimes ? _lnodeTimes : 1;
				_dnodeTimes = _dnodeTimes ? _dnodeTimes : 1;
				lnode  = Math.round((_lnodeTotal/_lnodeTimes) * 10)/10;
				dnode  = Math.round((_dnodeTotal/_dnodeTimes) * 10)/10;
			}

			var ec:int = 0
			
			if( _statistic && _statistic.userAllowP2P == -1 )
			{
				ec = -2;
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
			 * _rIP   rtmfp服务器ip
			 * _rPort rtmfp服务器port
			 * gID   groupName
			 * ver   内核版本号
			 * type  live或vod
			 * termid   终端类型 直接使用调度地址提供的参数值
			 * platid   平台ID   直接使用调度地址提供的参数值
			 * splatid  子平台ID 直接使用调度地址提供的参数值
			 * r        随机数
			 * */
			var termid:String = LiveVodConfig.TERMID=="" ? "1" : LiveVodConfig.TERMID;
			var platid:String = LiveVodConfig.PLATID=="" ? "0" : LiveVodConfig.PLATID;
			var splatid:String = LiveVodConfig.SPLATID=="" ? "0" : LiveVodConfig.SPLATID;
			var testID:String  = "";
			if( LiveVodConfig.LIVE == LiveVodConfig.TYPE && LiveVodConfig.IS_TEST_ID == true )
			{
				if( LiveVodConfig.TEST_TYPE_ID == LiveVodConfig.TEST_ID )
				{
					testID = "_t";
				}
				else if( LiveVodConfig.TEST_TYPE_ID == LiveVodConfig.TEST_ID_1 )
				{
					testID = "_t1";
				}
			}
			var str:String = String(nativeTrafficPath+"csize="+_csize+"&dsize="+_dsize+"&tsize="+_tsize+"&msize="+_msize+"&bsize="+_bsize+"&dnode="+dnode+"&lnode="+lnode+"&gip="+_gIP+"&gport="+_gPort+"&rip="+_rIP+"&rport="+_rPort+"&gID="+groupID+"&ver="+LiveVodConfig.GET_VERSION()+testID+"&type="+LiveVodConfig.TYPE.toLowerCase()+"&termid="+termid+"&platid="+platid+"&splatid="+splatid+"&ec="+ec+"&r="+Math.floor(Math.random()*100000));		
			sendToURL(new URLRequest(str));
			//trace(this,String(nativeTrafficPath+"csize="+_csize+"&dsize="+_dsize+"&tsize="+_tsize+"&msize="+_msize+"&bsize="+_bsize+"&dnode="+dnode+"&lnode="+lnode+"&gip="+_gIP+"&gport="+_gPort+"&rIP="+_rIP+"&rPort="+_rPort+"&gID="+groupID+"&ver="+LiveVodConfig.GET_VERSION()+"&type="+LiveVodConfig.TYPE+"&termid="+LiveVodConfig.TERMID+"&platid="+LiveVodConfig.PLATID+"&splatid="+LiveVodConfig.SPLATID+"&r="+Math.floor(Math.random()*100000)))
			reset();
			
		}
		public function loadXMLSuccess():void
		{
			var obj:Object = new Object();
			if( _processReport.progressReportObj["P2P.P2PNetStream.Success"] )
			{
				obj.code 	   = "P2P.P2PNetStream.Success";
				_processReport.progress(obj);	
			}
			if( _processReport.progressReportObj["P2P.LoadXML.Success"] )
			{
				obj.code 	   = "P2P.LoadXML.Success";
				_processReport.progress(obj);	
			}
		}
		public function getNeighbor(dnode:uint,lnode:uint):void
		{
			_dnodeTotal += dnode;
			_dnodeTimes++;
			
			_lnodeTotal += lnode;
			_lnodeTimes++;
		}
		
		private var speedArray:Array;
		private function creatSpeedArray(creatTime:Number):void
		{
			/*当speedArray为null时，创建一个长度为15的空数组，每个元素代表每一秒钟的数据下载情况
			每一秒钟的数据结构
			obj.time 	 = 0;秒数
			obj.httpSize = 0;字节
			obj.p2pSize  = 0;字节
			*/
			if( !speedArray )
			{
				speedArray = new Array();
				for( var i:int=speedSizeTime-1 ; i>=0 ; i--)
				{
					var obj:Object = new Object();
					obj.time 	 = Math.floor(creatTime/1000)-(speedSizeTime-1-i);
					obj.httpSize = 0;
					obj.p2pSize  = 0;
					speedArray[i] = obj;
					//speedArray.push(obj);
				}
			}
			else
			{
				for( var j:int=speedArray.length-1 ; j>=0 ; j--)
				{
					speedArray[j].time 	  = Math.floor(creatTime/1000)-j;
					speedArray[j].httpSize = 0;
					speedArray[j].p2pSize  = 0;
				}
			}
			
		}
		private function cleanUpSpeedArray(tempTime:Number):void
		{
			//var tempTime:Number = getTime();
			if( !speedArray )
			{
				creatSpeedArray(tempTime);
				return;
			}
			else
			{				
				var overTimes:Number = Math.floor(tempTime/1000)-speedArray[speedSizeTime-1].time;
				if( overTimes > 0 )
				{
					if( overTimes < speedSizeTime )
					{
						/*当前收到数据没有超过15秒的存储范围，进行存储淘汰，调整speedArray数组*/
						for( var j:int=0 ; j<speedArray.length ; j++ )
						{
							if( (j+overTimes)<speedArray.length )
							{
								speedArray[j].time 	   = speedArray[j+overTimes].time;
								speedArray[j].httpSize = speedArray[j+overTimes].httpSize;
								speedArray[j].p2pSize  = speedArray[j+overTimes].p2pSize;
							}
							else
							{
								speedArray[j].time 	   = speedArray[j].time+overTimes;
								speedArray[j].httpSize = 0;
								speedArray[j].p2pSize  = 0;
							}
						}
					}
					else
					{
						/*当前收到数据已经超过15秒的存储范围，将speedArray数组重置*/
						creatSpeedArray(tempTime);
					}
				}				
			}
		}
		
		private function pushSpeedArray(size:Number,from:String):void
		{
			var tempTime:Number = getTime();
			if( !speedArray )
			{
				creatSpeedArray( tempTime );
			}
			else
			{
				cleanUpSpeedArray(tempTime);
			}
			for( var j:int=speedArray.length-1 ; j>=0 ; j-- )
			{					
				if( speedArray[j].time == Math.floor(tempTime/1000) )
				{
					/*当前数据落入这一秒钟时*/
					if( from == "http" )
					{
						speedArray[j].httpSize += size;
					}
					else
					{
						speedArray[j].p2pSize  += size;
					}
					return;
				}
			}
		}
		
		public function httpGetData(id:String,begin:Number,end:Number,size:Number):void
		{
			/**统计上报使用*/
			if(!isNaN(begin)||!isNaN(end))
			{
				_httpTimeForSpeed += end - begin;
				
			}else
			{
				P2PDebug.traceMsg(this,"p2p时间报NaN啦~~~~~~");
			}
			_csize += size;
			
			totalCDNSize += size;
			
			if( _newTimeForSpeed == 0)
			{
				_newTimeForSpeed = getTime();
			}
			
			pushSpeedArray(size,"http");
			
			_downLoadBoo=true;
		}
		
		public function P2PGetData(id:String,begin:Number,end:Number,size:Number,peerID:String,clientType:String="PC"):void
		{
			var tempEventName:String = "P2P.P2PGetChunk.Success"
			/**过程上报使用*/
			if( _processReport.progressReportObj[tempEventName] )
			{
				var obj:Object = new Object();
				obj.code = tempEventName;
				_processReport.progress(obj);
			}
			
			/**统计上报使用*/			
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
			
			totalP2PSize += size;
			
			if( _newTimeForSpeed == 0)
			{
				_newTimeForSpeed = getTime();
			}
			
			pushSpeedArray(size,"p2p");
			
			_downLoadBoo=true;
		}
		
		private var _oldTimeForSpeed:Number = 0;
		private var _newTimeForSpeed:Number = 0;
		private var _speedObj:Object = new Object();
		
		public function dealDownloadSpeed():Object
		{
			_speedObj.httpSpeed = 0;			
			_speedObj.p2pSpeed  = 0;
			if( !speedArray )
			{
				return _speedObj;
			}
			
			var durtion:Number = 0;			
			
			/**周期内http累计下字节数*/
			var _httpSizeForSpeed:Number = 0;
			/**周期内p2p累计下字节数*/
			var _p2pSizeForSpeed:Number  = 0;
			
			var tempTime:Number = getTime();
			
			_oldTimeForSpeed = _newTimeForSpeed;
			tempTime = _newTimeForSpeed = getTime();			
			
			cleanUpSpeedArray(tempTime);			
			
			for( var i:int=0 ; i<speedArray.length ; i++ )
			{
				_httpSizeForSpeed += speedArray[i].httpSize;
				_p2pSizeForSpeed  += speedArray[i].p2pSize;
				
				if( durtion == 0 && Math.floor(_statistic.startRunningTimeForDownLoad/1000) <= speedArray[i].time )
				{
					/*如果durtion有值且起始时间小于统计速度时间*/
					durtion = speedArray.length-i;
				}
				//trace("http = "+speedArray[i].httpSize);
				//trace("p2p  = "+speedArray[i].p2pSize);
			}
			//trace("durtion  = "+durtion);
			_speedObj.httpSpeed = Math.round( 10*(_httpSizeForSpeed/1024)/durtion )/10;			
			_speedObj.p2pSpeed  = Math.round( 10*(_p2pSizeForSpeed/1024)/durtion )/10;
			//trace("_httpSizeForSpeed = "+_httpSizeForSpeed);
			//trace("_p2pSizeForSpeed = "+_p2pSizeForSpeed);
			//trace("------------------------------------------------------------------")
			/*_speedObj.httpSpeed = Math.round( 10*(_httpSizeForSpeed/1024)/durtion )/10;			
			_speedObj.p2pSpeed  = Math.round( 10*(_p2pSizeForSpeed/1024)/durtion )/10;*/
			
			_httpTimeForSpeed = 0;
			
			return _speedObj;
		}
		
		public function selectorSuccess():void
		{			
			if( _processReport.progressReportObj["P2P.SelectorConnect.Success"] )
			{
				var obj:Object = new Object();
				obj.code 	   = "P2P.SelectorConnect.Success";
				_processReport.progress(obj);	
			}			
		}
		
		public function rtmfpSuccess(rtmfpName:String,rtmfpPort:uint,myName:String):void
		{
			_rIP	  = rtmfpName;
			_rPort = rtmfpPort;
			_rtmfpSuccess = true;
			
			if( _processReport.progressReportObj["P2P.RtmfpConnect.Success"] )
			{
				var obj:Object 	 = new Object();
				obj.code		 = "P2P.RtmfpConnect.Success";
				obj.ip   		 = rtmfpName;
				obj.port 		 = rtmfpPort;
				_processReport.progress(obj);
			}
		}
		public function rtmfpFailed():void
		{
			_rtmfpSuccess = false;
		}
		public function gatherSuccess(gatherName:String,gatherPort:uint):void
		{
			_gIP   = gatherName;
			_gPort = gatherPort;
			_gatherSuccess = true;
			
			if( _processReport.progressReportObj["P2P.GatherConnect.Success"] )
			{
				var obj:Object  = new Object();
				obj.code 		= "P2P.GatherConnect.Success";
				obj.ip   		= gatherName;
				obj.port 		= gatherPort;
				_processReport.progress(obj);
			}
		}
		public function gatherFailed():void
		{
			_gatherSuccess = false;
		}
		
		/**
		 *获取二维数组中，两个值的差的和。
		 */
		private function getTimeNum(len:int,arr:Array):Number
		{
			var num:Number=0;
			for(var n:int=0;n<len;n++)
			{
				num+=arr[n][1]-arr[n][0];
			}
			
			return num;
		}
		
		private function getTime():Number {
			return Math.floor((new Date()).time);
		}
	}
}