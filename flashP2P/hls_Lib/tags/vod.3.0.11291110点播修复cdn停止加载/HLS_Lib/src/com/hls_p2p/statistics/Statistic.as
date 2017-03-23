package com.hls_p2p.statistics
{
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.stream.HTTPNetStream;
	import com.p2p.utils.ArraySortMerge;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.net.sendToURL;
	import flash.utils.Timer;

	public class Statistic
	{
		public var isDebug:Boolean=true;
		
		private var _whichGroupCanDisplay:String = "";
		public function set whichGroupCanDisplay(str:String):void
		{
			_whichGroupCanDisplay = str;
			setGroupID();
		}
		public function get whichGroupCanDisplay():String
		{
			return _whichGroupCanDisplay;
		}
		
		private static var instance:Statistic=null;
		/**初始化数据*/
		protected var _initData:InitData;
		/**netstream引用*/
		protected var _netStream:HTTPNetStream;
		/**保存本地测试播放器输出面板回调函数的对象*/
		public var nativeCallBackObj:Object = new Object();
		/**正式播放器使用的回调函数*/
		public var outMsg:Function;
		/**按groupID生成的统计单元列表*/
		private var _statisticsElementList:Object = new Object();
		/***/
		private var _tempStatisticsElement:StatisticsElement;
		
		public function Statistic(single:Singleton):void
		{
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
			
			_whichGroupCanDisplay = "";
			
			for(var i:String in _statisticsElementList)
			{
				_statisticsElementList[i].clear();	
				delete _statisticsElementList[i];
			}			
			_statisticsElementList = new Object();			
			
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
		}
		private function reset():void
		{
			
		}
		
		public function creatStatisticByGroupID(groupID:String):void
		{
			if( !_statisticsElementList[groupID] )
			{
				_statisticsElementList[groupID] = new StatisticsElement(groupID);
				_statisticsElementList[groupID].start();
				loadXMLSuccess(groupID);
			}
			if( _whichGroupCanDisplay == "")
			{
				_whichGroupCanDisplay = groupID;
			}
		}
		
		public function delStatisticByGroupID(id:String):void
		{
			if( _statisticsElementList[id] )
			{
				_statisticsElementList[id].clear();
				delete _statisticsElementList[id]
			}
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
		}		
		/**输出面板调用，显示groupID*/
		private function setGroupID():void
		{
			/**外部输出面板*/
			if(outMsg != null)
			{
				outMsg(_initData.groupName,"groupName");
			}
			/**内部输出面板*/
			var object:Object = new Object();
			object.name = "groupName";
			object.info = _whichGroupCanDisplay;
			testCallBack(object);
		}
		/**回调onMateData*/
		public function callBackMateData(obj:Object):void
		{
			if (null == _netStream) return;
			//GGG 不在这里调用notify
			//_netStream.notifyTotalDuration(obj);
			if(outMsg != null)
			{
				if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
				{
					outMsg.call(null,Math.round(_initData.totalSize/(1024*1024))+", W*H="+_initData["videoWidth"]+"*"+_initData["videoHeight"],"totalSize");					
				}
				else
				{
					outMsg.call(null,"  , W*H="+_initData["videoWidth"]+"*"+_initData["videoHeight"],"totalSize");
				}					
			}
		}
		/**输出面板使用*/
		public function timeOutput(time:Number):void
		{
			/**内部输出面板上报*/
			var object:Object = new Object();
			object.name = "time";
			object.info = Math.round(time);
			testCallBack(object);
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
		/**输出面板显示*/
		public function M3U8_MaxTime():void
		{
			/**内部输出面板上报*/
			var object:Object = new Object();
			object.name = "MaxTime";
			object.info = LiveVodConfig.M3U8_MAXTIME;		
			testCallBack(object);
		}
		/***/
		private function loadXMLSuccess(groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.loadXMLSuccess();
			}
		}
		/**过程上报使用,第一次成功连接selector*/
		public function selectorSuccess(groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.selectorSuccess();
			}		
		}
		/**输出面板使用,开始连接rtmfp时*/
		public function rtmfpStart(rtmfpName:String,rtmfpPort:uint,groupID:String):void
		{
			if( _whichGroupCanDisplay != groupID )
			{
				return;
			}
		
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
		public function rtmfpSuccess(rtmfpName:String,rtmfpPort:uint,myName:String,groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.rtmfpSuccess(rtmfpName,rtmfpPort,myName);
				
			}
			
			if( _whichGroupCanDisplay != groupID )
			{
				return;
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
		public function rtmfpFailed(rtmfpName:String,rtmfpPort:uint,groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.rtmfpFailed();
			}	
			
			if( _whichGroupCanDisplay != groupID )
			{
				return;
			}
			
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
		public function gatherStart(gatherName:String,gatherPort:uint,groupID:String):void
		{			
			if( _whichGroupCanDisplay != groupID )
			{
				return;
			}
			
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
		public function gatherSuccess(gatherName:String,gatherPort:uint,groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.gatherSuccess(gatherName,gatherPort);
			}
			
			if( _whichGroupCanDisplay != groupID )
			{
				return;
			}
			
			if(outMsg != null)
			{
				outMsg(String(gatherName+":"+gatherPort+"  OK"),"gatherName");
			}
			
			var object:Object = new Object();
			object.name = "gatherOk";
			testCallBack(object);
		}
		/**输出面板使用*/
		public function gatherFailed(gatherName:String,gatherPort:uint,groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.rtmfpFailed();
			}
			
			if( _whichGroupCanDisplay != groupID )
			{
				return;
			}
			
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
		public function P2PWantData(pieceIdx:String,remoteID:String):void
		{
			if (null == _netStream) return;
			
			
				var object:Object = new Object();
				object.pieceID    = pieceIdx;	
				object.remoteID   = remoteID;
				object.code       = "P2P.WantChunk.Success";
				(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
		}
		/**过程上报使用,第一次成功下载到p2p数据*/
		/**统计上报使用，记录每次p2p下载耗时和数据大小
		 * peerType表示邻居节点是何种类型的客户端，包括"PC","TV","MP","BOX"
		 * */
		public function P2PGetData(id:String,begin:Number,end:Number,size:Number,peerID:String,groupID:String,clientType:String="PC"):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.P2PGetData(id,begin,end,size,peerID,clientType);
			}
			//-------------------------------------------------------------------------------------------
			if (null == _netStream) return;
						 
			var date:Date;
			
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.id = id+", "+peerID.substr(0,8)+", "+clientType;
			if(id.indexOf("TN") > -1)
			{
				date = new Date(int(id.split("_")[1])*1000);
				object.id = object.id+", "+date.hours+":"+date.minutes+":"+date.seconds;
			}
			
			object.code   = "P2P.P2PGetChunk.Success";
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				outMsg(String("p2p "+object.id+", "+clientType));
			}
			
			/**内部输出面板使用*/
			reportP2PRate();
		}
		/**统计上报使用,当从CDN下载数据时调用*/
		/**输出面板使用*/
		public function httpGetData(id:String,begin:Number,end:Number,size:Number,groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.httpGetData(id,begin,end,size);
			}
			//-------------------------------------------------------------------------------------------
			if (null == _netStream)
			{	
				return;
			}
				
			var date:Date;
				
			/**输出面板使用*/
			var object:Object = new Object();
			object.id = id;
			if( id.indexOf("TN") > -1)
			{
				date =new Date(int(id.split("_")[1])*1000);
				object.id = object.id+" "+date.hours+":"+date.minutes+":"+date.seconds;
			}
			
			object.code = "Http.LoadClip.Success";
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				outMsg(String("http "+object.id));
			}
			
			/**内部输出面板使用*/
			reportP2PRate();
		}
		private function reportP2PRate():void
		{	
			/**心跳周期内来自CDN端的p2p累计下载字节数*/
			//var _csize:Number=0;
			/**心跳周期内来自PC端的p2p累计下载字节数*/
			//var _dsize:Number=0;
			/**心跳周期内来自TV端的p2p累计下载字节数*/
			//var _tsize:Number=0;
			/**心跳周期内来自手机端的p2p累计下载字节数*/
			//var _msize:Number=0;
			/**心跳周期内来自盒子端的p2p累计下载字节数*/
			//var _bsize:Number=0;
			var totalP2PSize:Number = 0;
			var totalCDNSize:Number = 0;
			for ( var temp:String in _statisticsElementList )
			{
				_tempStatisticsElement = _statisticsElementList[temp];
				totalP2PSize += _tempStatisticsElement.totalP2PSize;
				totalCDNSize += _tempStatisticsElement.totalCDNSize;
				/*_csize += _tempStatisticsElement.csize;
				_dsize += _tempStatisticsElement.dsize;
				_tsize += _tempStatisticsElement.tsize;
				_msize += _tempStatisticsElement.msize;
				_bsize += _tempStatisticsElement.bsize;*/
			}
			
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.info = Math.round(Number(1000*(totalP2PSize)/(totalCDNSize+totalP2PSize)))/10;
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
			if (null == _netStream) return;
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.id = id;
			object.code = "Http.LoadClip.Failed";
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**统计上报使用，输出面板使用，更新邻居节点信息时上报*/
		public function getNeighbor(obj:Object,dnode:uint,lnode:uint,groupID:String):void
		{
			_tempStatisticsElement = _statisticsElementList[groupID];
			if( _tempStatisticsElement )
			{
				_tempStatisticsElement.getNeighbor(dnode,lnode);
			}
			
			if( _whichGroupCanDisplay != groupID )
			{
				return;
			}
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{				
				outMsg(dnode,"dnode");
				outMsg(lnode,"lnode");	
				trace(this,"dnode = "+dnode);
				trace(this,"lnode = "+lnode);
			}
			
			/**内部输出面板使用*/
			var object:Object = new Object();
			object.name = "peerID";
			object.data = obj;
			testCallBack(object);
			
		}
		/**输出面板使用,当给别人分享数据时调用*/
		public function P2PShareData(pieceID:String,remoteID:String):void
		{
			if (null == _netStream) return;
			/**输出面板使用*/
			var object:Object = new Object();			
			object.code = "P2P.P2PShareChunk.Success";
			object.pieceID  = pieceID;
			object.remoteID = remoteID;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				outMsg(String("share "+pieceID+" "+remoteID.substr(0,5)));
			}
		}
		/**输出面板显示，当淘汰数据时调用*/
		public function removeData(id:String):void
		{
			if (null == _netStream) return;
			/**输出面板使用*/
			var object:Object = new Object();			
			object.code = "P2P.RemoveData.Success";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当dat跳过时调用*/
		public function DatSkip(id:String):void
		{
			if (null == _netStream) return;
			var object:Object = new Object();			
			object.code = "P2P.DatSkip.Success";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		/**输出面板使用，当xml跳过时调用*/
		public function DESCSkip(id:String):void
		{
			if (null == _netStream) return;
			var object:Object = new Object();			
			object.code = "P2P.DESCSkip.Success";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
		}
		
		/**输出面板使用，当CheckSum验证失败时调用*/
		public function P2PCheckSumFailed(id:String):void
		{
			if (null == _netStream) return;
			/**内部输出*/
			var object:Object = new Object();			
			object.code = "P2P.CheckSum.Failed";
			object.id   = id;
			(_netStream as EventDispatcher).dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,object));
			
			/**外部输出面板使用*/
			if(outMsg != null)
			{
				outMsg(id);
			}
		}
		/**输出面板使用，当xml加载失败时调用*/
		public function DESCFailed(id:String):void
		{
			if (null == _netStream) return;
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
			if (null == _netStream) return;
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
			if(nativeCallBackObj == null)
			{
				nativeCallBackObj = new Object();
			}
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
			if (null == _netStream) return;
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
		
		private function getTime():Number {
			return Math.floor((new Date()).time);
		}
	}
}
class Singleton{}