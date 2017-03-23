package com.hls_p2p.statistics
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.events.EventExtensions;
	import com.hls_p2p.events.protocol.NETSTREAM_PROTOCOL;
	import com.hls_p2p.stream.HTTPNetStream;
	
	import flash.net.URLRequest;
	import flash.net.sendToURL;
	
	internal class ProcessReport
	{
		private var stagePath:String   = "http://s.webp2p.letv.com/ClientStageInfo?"
		
		private var _groupID:String = "";
		
		/**
		 * 保存过程上报的起始时间，当Statistics被实例化时取一次时间值付给progressReportTime，当发生第一次过程上报时
		 * 再取一次时间与之相减，得到的时间差即为本次过程上报的耗时，并将新取得时间值付给_progressReportTime，
		 * 当下一个过程事件发生时重复上述操作，从而得到每一个过程上报的时间值，因为过程上报的每一个事件都是按顺序执行的，
		 * 所以上报的耗时可认为是准确的（P2P.LoadXML.Success事件需单独统计耗时，因为该事件与P2P.P2PNetStream.success之后的
		 * 时间并行发生）
		 * */
		public var progressReportTime:Number=0;
		/**
		 * progressReportObj对象保存过程上报的事件类型，并记录该事件是否已经上报过
		 * 过程上报分为内部上报和外部上报；
		 * P2P.P2PNetStream.success：   P2P内核第一次执行play()操作时上报（内部上报）
		 * P2P.LoadCheckInfo.Success：  第一次下载DESC时上报（内、外部上报）
		 * P2P.selectorConnect.Success：第一次成功连接selector时上报（内、外部上报）
		 * P2P.rtmfpConnect.Success：   第一次成功连接rtmfp时上报（内、外部上报）
		 * P2P.gatherConnect.Success：  第一次成功连接gather时上报（内、外部上报）
		 * P2P.P2PGetChunk.Success：    第一次从p2p获得数据时上报（内、外部上报）
		 * 以上事件只上报一次。
		 * */
		public var progressReportObj:Object = {"P2P.P2PNetStream.Success":true,
			"P2P.LoadXML.Success":true,
			"P2P.SelectorConnect.Success":true,
			"P2P.RtmfpConnect.Success":true,
			"P2P.GatherConnect.Success":true,
			"P2P.P2PGetChunk.Success":true};
		
		//public var netStream:*;
		
		public function ProcessReport(gID:String)
		{
			_groupID = gID
		}
		public function clear():void
		{
			_groupID = "";
			progressReportObj = {"P2P.P2PNetStream.Success":true,
				"P2P.LoadXML.Success":true,
				"P2P.SelectorConnect.Success":true,
				"P2P.RtmfpConnect.Success":true,
				"P2P.GatherConnect.Success":true,
				"P2P.P2PGetChunk.Success":true};
		}
		/**
		 * 负责上报关于P2P过程的相关信息给播放器
		 * 每次调用dispatchProgressEvent时，都依具info.act在progressReportObj中查找是否有相关属性，如果找到
		 * 相关属性则说明需要将此事件上报，同时将该属性从progressReportObj中删除，保证相同的事件只上报一次。
		 * */ 
		public function progress(obj:Object):void
		{			
			/**保证相同的过程事件只上报一次*/
			if(obj.code && progressReportObj[obj.code])
			{			
				/**该过程没有上报过*/
				progressReportObj[obj.code] = false;
			}
			else
			{
				/**该过程已经上报过*/
				return;
			}
			var act:int = -1;
			var err:int = 0;
			var IP:String = "0";
			var Port:int  = 0;
			
			switch(obj.code)
			{
				case "P2P.P2PNetStream.Success":
					act = 0;
					break;
				case "P2P.LoadXML.Success":
					act = 1;
					break;
				case "P2P.LoadXML.Failed":
					act = 1;
					err = 1;
					break;
				case "P2P.SelectorConnect.Success":
					act = 2;
					break;	
				case "P2P.RtmfpConnect.Success":
					act = 3;
					IP = obj.ip;
					Port = obj.port;
					break;
				case "P2P.GatherConnect.Success":
					act = 4;
					IP = obj.ip;
					Port = obj.port;
					break;
				case "P2P.P2PGetChunk.Success":
					act = 5;
					break;
				
			}
			
			if(act != -1)
			{
				if(!obj.utime)
				{
					var thisTime:Number = Math.floor((new Date()).time);
					obj.utime = thisTime - progressReportTime;
					progressReportTime = thisTime;
				}
				/**上报给播放器,主站目前未贮备该上报*/
				/*if(obj.code != "P2P.P2PNetStream.Success")
				{					
					netStream.dispatchEvent(new EventExtensions(NETSTREAM_PROTOCOL.P2P_STATUS,obj));					 
				}*/
				/**上报给内部统计*/
				var termid:String = LiveVodConfig.TERMID=="" ? "0" : LiveVodConfig.TERMID;
				var platid:String = LiveVodConfig.PLATID=="" ? "0" : LiveVodConfig.PLATID;
				var splatid:String = LiveVodConfig.SPLATID=="" ? "0" : LiveVodConfig.SPLATID;
				var testID:String  = LiveVodConfig.IS_TEST_ID==true ? "_t" : "";
				if( LiveVodConfig.VOD == LiveVodConfig.TYPE )
				{
					testID = "";
				}
				var str:String = String(stagePath+"act="+act+"&err="+err+"&utime="+obj.utime+"&ip="+IP+"&port="+Port+"&gID="+_groupID+"&ver="+LiveVodConfig.GET_VERSION()+testID+"&type="+LiveVodConfig.TYPE.toLowerCase()+"&termid="+termid+"&platid="+platid+"&splatid="+splatid+"&r="+Math.floor(Math.random()*100000));
				sendToURL(new URLRequest(str));
//				trace("KernelReport str ========== "+str);
			}
			
			obj = null;
		}
	}
}