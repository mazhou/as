package com.p2p.log
{
	import com.p2p.core.P2PNetStream;
	import com.p2p.events.P2PNetStreamEvent;
	import com.p2p.kernelReport.KernelReport;
	import com.p2p.utils.ArraySortMerge;
	
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	/**
	 * p2p数据上报
	 * */
	public class P2PStatisticData extends EventDispatcher
	{
		private var _netstream:P2PNetStream;
		private var _p2pArr:Array=[];//存p2p开始结尾时间数据
		private var _p2pTimeArr:Array=[];//存p2p已经排序合并花费时间
		private var _peerIdArr:Array=[];//存peerId		
		private var _p2psizeNum:Number=0;		
		private var _p2pSendSizeNum:Number=0;	//分享数据大小
		private var _numChunks:uint=0;//文件分成的chunk数		
		private var _httpsizeNum:Number=0;//http片大小
		private var _downLoadBoo:Boolean=false;//是否下载数据	
		private var _chunkSize:uint=0;//单个chunk字节数
		
		private var _initTime:Number=0;
		private var _newTime:Number=0;
		private var _preTime:Number=0;
		//lz 0823 add
		private var _dnodeTotal:int = 0;
		private var _lnodeTotal:int = 0;
		private var _dnodeTimes:int = 0;//_dnode次数
		private var _lnodeTimes:int = 0;//_lnode次数
		private var _rtmfpSuccess:Boolean = false;//rtmfp服务器的状态，当rtmfp中断且_lnodeTotal = -1，_dnodeTotal=-1
		//
		private var _rIP:String = "0";
		private var _gIP:String = "0";
		private var _rPort:uint = 0;
		private var _gPort:uint = 0;
		
		private var _sumHttpSize:Number = 0;     //总下载文件大小(字节)
		private var _sumHttpTime:Number = 0; //总Http下载耗时(毫秒)
		private var _sumP2PTime:Number = 0;  //总P2P下载耗时(毫秒)
		private var _sumP2PSize:Number = 0;  //总P2P下载字节
		private var _httpTime:Number = 0;    //心跳周期内http下载耗时（毫秒）
        private var _cnod:String = "";
		
		public function P2PStatisticData()
		{
			/*_netstream=netstream;			
			_netstream.addEventListener("streamStatus",netstatusHandle);
			_netstream.addEventListener("p2pStatus",netstatusHandle);
			_netstream.addEventListener("streamLocalStatus",netstatusHandle);
			_netstream.addEventListener("p2pLocalStatus",netstatusHandle);*/
		}		
		
		/*********
		 *清空
		 *****/
		public function clear():void
		{			
			reset();
			
			_initTime = 0;
			_newTime = 0;
			_preTime = 0;
			_rtmfpSuccess = false;
			
			_rIP = "0";
			_gIP = "0";
			_rPort = 0;
			_gPort = 0;
			
			_sumHttpSize = 0;
			_sumHttpTime = 0;
			_sumP2PTime  = 0;
			_sumP2PSize=0;
			_cnod    = "";
			
			if(_netstream)
			{
				//_netstream.removeEventListener("streamStatus",netstatusHandle);
				//_netstream.removeEventListener("p2pStatus",netstatusHandle);
				_netstream.removeEventListener("streamLocalStatus",netstatusHandle);
			    _netstream.removeEventListener("p2pLocalStatus",netstatusHandle);			
			    _netstream = null;
			}
			
		}
		public function get NetStream():Boolean
		{
			if(_netstream)
			{
				return true;
			}
			return false;
		}
		public function setInitTime(netstream:P2PNetStream,numChunks:uint):void
		{
			if(!_netstream)
			{
				_netstream = netstream;			
				//_netstream.addEventListener("streamStatus",netstatusHandle);
				//_netstream.addEventListener("p2pStatus",netstatusHandle);
				_netstream.addEventListener("streamLocalStatus",netstatusHandle);
				_netstream.addEventListener("p2pLocalStatus",netstatusHandle);
			}
			_numChunks = numChunks;
			_initTime = getTime();
		}
		private function reset():void
		{
			_p2pArr=[];
			_p2pTimeArr=[];
			_peerIdArr=[];		
			
			_p2psizeNum=0;
			_p2pSendSizeNum = 0;
			_httpsizeNum=0;
			
			_dnodeTotal = 0;
			_lnodeTotal = 0;
			_dnodeTimes = 0;
			_lnodeTimes = 0;			
			_httpTime   = 0;
			
			_downLoadBoo=false;
		}
		private function netstatusHandle(event:Object):void
		{
			var code:String=event.info.code;
			switch (code)
			{
				case "Stream.Play.Start" :
					break;
				case "Stream.Play.Stop" :
					//clear();
					break;
				case "P2P.HttpGetChunk.Success":					
					_httpsizeNum+=event.info.size;
					_cnod = event.info.cnod;
					_sumHttpTime=event.info.sumHttpTime
					//download
					_downLoadBoo=true;					
					break;
				case "P2P.HttpGetChunk.Failed":
					break;
				case "P2P.P2PGetChunk.Success":					
					if(!(isNaN(event.info.begin)||isNaN(event.info.end)))
					{
						_p2pArr.push([event.info.begin,event.info.end]);						
					}else
					{
						trace("p2p时间报NaN啦~~~~~~")
					}
					//size
					_p2psizeNum+=event.info.size;					
					_peerIdArr.push(event.info.peerID);
					//download
					_downLoadBoo=true;					
					break;
				case "P2P.P2PShareChunk.Success":
					_p2pSendSizeNum += event.info.size;
					break;
				case "P2P.loadFileInfo.Success":	
					//_initTime=getTime();	
					trace("P2P.loadFileInfo.Success"+"P2P.loadFileInfo.Success")
					_numChunks=Math.ceil(event.info.fileSize/_chunkSize);
					break;
				case "P2P.loadFileInfo.Failed":
					break;
				case "P2P.JoinNetGroup.Success":
					break;
				case "P2P.JoinNetGroup.Failed":
					break;
				case "P2P.LoadCheckInfo.Success":
					trace("P2P.LoadCheckInfo.Success"+"P2P.LoadCheckInfo.Success")
					_chunkSize=event.info.chunkSize;
					break;
				case "P2P.LoadCheckInfo.Failed":
					_chunkSize=event.info.chunkSize;
					break;
				case "P2P.Neighbor.Connect":
					if(event.info.dnode)
					{
						_dnodeTotal += event.info.dnode;
						_dnodeTimes++;
						/*trace("成功 = "+_dnodeTotal+"  "+event.info.dnode)
						trace("次数 = "+_dnodeTimes)*/
					}
					if(event.info.lnode)
					{
						_lnodeTotal += event.info.lnode;
						_lnodeTimes++;
						/*trace("人数 = "+_lnodeTotal+"  "+event.info.lnode)
						trace("次数 = "+_lnodeTimes)*/
					}
					break;
				case "P2P.rtmfpConnect.Success":
					_rIP = event.info.rtmfpName;
					_rPort = event.info.rtmfpPort;
					_rtmfpSuccess = true;
					break;
				case "P2P.rtmfpConnect.Failed":
					_rtmfpSuccess = false;
					break;
				case "P2P.gatherConnect.Success":
					_gIP = event.info.gatherName;
					_gPort = event.info.gatherPort;
					break;
				case "P2P.HttpGetChunk.Speed":
					_httpTime += event.info.time*1000;
					break;
			}
		}
		
		public function getStatisticData():Object
		{
			_preTime=_newTime;
			_newTime=getTime();
			
			if(_preTime==0)
			{
				_preTime=_initTime;
			}
			
			//p2p time
			_p2pTimeArr=ArraySortMerge.init(_p2pArr)
			var p2ptimeNum:Number=0;
			var p2ptimeLen:int=_p2pTimeArr.length;
			//p2ptimeNum=(getTimeNum(p2ptimeLen,_p2pTimeArr))/1000;  秒
			p2ptimeNum = getTimeNum(p2ptimeLen,_p2pTimeArr);   //    毫秒
			
			//peerNum   chunk来源的peer数
			var peerNum:int=0;
			peerNum=filterArray(_peerIdArr).length;
			
			//http&p2p time
			var alltimeNum:Number=0;
			alltimeNum=(_newTime-_preTime)/1000;//秒
			
			var speedNum:Number=0;
			if(alltimeNum!=0&&(_p2psizeNum!=0||_httpsizeNum!=0))
			{
				speedNum=Math.ceil(Number((_p2psizeNum+_httpsizeNum)/alltimeNum));
			}
			
			if(_downLoadBoo==false)
			{
				alltimeNum=0;
			}				
			//发送事件
			var obj:Object = new Object();
			var obj2:Object = new Object();
			obj.code     = "P2P.Statistic.Timer";
			obj.type     = "vod";
			
			_sumP2PTime  += Math.round(p2ptimeNum);//p2p累计时间
			_sumP2PSize+=Math.round(_p2psizeNum); //p2p累计字节//obj.p2psize;
			//obj2.p2ptime  = Math.round(p2ptimeNum)
			obj2.p2psize =Math.round(_p2psizeNum)
			obj.p2ptime  = _sumP2PTime;  //2013-01-08修订总耗时   //心跳周期内p2p下载耗费时间 (毫秒)     Number
			obj.p2psize  =  _sumP2PSize  //2013-01-08修订总下载字节//心跳周期内下载p2p大小（字节）		Number			
			obj.chunknum = _numChunks;                 //总chunk数					        uint
			obj.alltime  = obj.p2ptime + _sumHttpTime;    //心跳周期内总下载耗费时间(毫秒)	    Number
			obj.speednum = obj.alltime==0 ? 0 : Math.ceil((obj.p2psize+obj.httpsize)/obj.alltime*1000);  //心跳周期内速度 （字节/秒）			Number
			obj.lsize    = _p2pSendSizeNum;            //心跳周期p2p分享数据大小		        uint
			obj.ltime    = obj.alltime;                //心跳周期时长（毫秒）                Number
			obj.httpsize = _httpsizeNum;               //心跳周期内http下载大小		        uint
			//20130111 add 
			_sumHttpSize +=_httpsizeNum;//obj.p2psize+//2013-01-08修订该参数的意义为CDN方式下载视频文件累计大小
			obj.sumSize   = _sumHttpSize;                   //从播放开始总的下载文件大小（字节）   Number
			obj.sumTime   = _sumHttpTime//+_sumP2PTime;//2013-01-08更新为播放期间CDN方式累计下载耗时   //从播放开始总下载耗时（毫秒）         Number
			obj.cnod      = _cnod;                      //CDN的id                            String
			//lz 0823 add
			if(_rtmfpSuccess)
			{
				_lnodeTimes = _lnodeTimes ? _lnodeTimes : 1;
				_dnodeTimes = _dnodeTimes ? _dnodeTimes : 1;
				obj.lnode = Math.round((_lnodeTotal/_lnodeTimes) * 10)/10;
			    obj.peer  = Math.round((_dnodeTotal/_dnodeTimes) * 10)/10;
				//obj.lnode = Math.round((_lnodeTotal/_lnodeTimes) * 100)/100;
				//obj.peer  = Math.round((_dnodeTotal/_dnodeTimes) * 100)/100;
			}else
			{
				obj.lnode = -1;
				obj.peer  = -1;
			}
			/* *
			for(var i:String in obj)
			{
				trace(i+" = "+obj[i]);
			}
			trace("----------------------------------");
			 */
			//----------------------------内部监控上报
			kernelReport(obj,obj2);
			//----------------------------
			reset();			
			return obj;			
		}
		private function kernelReport(obj:Object,obj2:Object):void
		{
			var object:Object = new Object();
			object.csize = obj.httpsize;
			object.dsize = obj2.p2psize;
			object.dnode = obj.peer;
			object.lnode = obj.lnode;
			object.rip = _rIP;
			object.gip = _gIP;
			object.rport = _rPort;
			object.gport = _gPort;
			KernelReport.HEART(object);
		}
		/*********
		 *删除数组中所有相同的项。返回一个数组
		 *****/
		private function filterArray(arr:Array):Array {
			var tempArr:Array=[];
			var l:uint=arr.length;
			for (var i:uint=0;i<l;i++) {
				if (tempArr.indexOf(arr[i])==-1) {  
					tempArr.push(arr[i]);
				}
			}
			return tempArr;
		}
		/*********
		 *获取二维数组中，两个值的差的和。
		 *****/
		private function getTimeNum(len:int,arr:Array):Number
		{
			var num:Number=0;
			for(var n:int=0;n<len;n++)
			{
				num+=(arr[n][1]-arr[n][0]>0)?(arr[n][1]-arr[n][0]):0;
			    //trace("arr[n][1] = "+arr[n][1]+"  ;  arr[n][0] = "+arr[n][0])
			}
			
			return num;
		}
		
		private function getTime():Number {
			return Math.floor((new Date()).time);
		}		
	}
}