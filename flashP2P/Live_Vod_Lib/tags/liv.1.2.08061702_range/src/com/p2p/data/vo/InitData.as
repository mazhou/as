package com.p2p.data.vo
{
	import com.p2p.logs.P2PDebug;
	import com.p2p.utils.TimeTranslater;

	/**
	 * _initData：特殊处理的地方TimerShift.TIME_OFF 
	 * @author mazhoun
	 */
	public dynamic class InitData
	{
		public var isDebug:Boolean=true;
		
		private var _startTime:Number=0;
		private var _flvURL:Array;
		private var _flvNode:Array;
		private var _groupName:String; 
		private var _url:String;
		private var _checkURL:String;
		
		private var _serverCurtime:Number = 0;
		private var _gslb:String="";

		public function get gslb():String
		{
			return _gslb;
		}

		public function set gslb(value:String):void
		{
			value=replaceParam(value,"expect","4");
			value=replaceParam(value,"format","2");
			_gslb = value;
		}

		public function get checkURL():String
		{
			return _checkURL;
		}
		
		public function set checkURL(value:String):void
		{
			_checkURL = value;
		}
		
		public function get url():String
		{
			return _url;
		}
		
		public function set url(value:String):void
		{
			_url = value;
		}
		
		public function get groupName():String
		{
			/*return _groupName+LiveVodConfig.VERSION;*/
			return _groupName;
		}
		
		public function set groupName(value:String):void
		{
			_groupName = value;
		}
		
		public function get flvNode():Array
		{
			return _flvNode;
		}
		
		public function set flvNode(value:Array):void
		{
			_flvNode = value;
		}
		
		public function get flvURL():Array
		{
			if(LiveVodConfig.TYPE==LiveVodConfig.VOD){
				return supportP2P( _flvURL);
			}
			return _flvURL;
		}
		
		public function set flvURL(value:Array):void
		{
			_flvURL = value;
		}
		
		public function get startTime():Number
		{
//			Debug.traceMsg(this,"真实的_startTime"+_startTime+" "+(new Date(_startTime*1000)).getMinutes()+":"+(new Date(_startTime*1000)).getSeconds())
			if((_startTime == 0 || _startTime>_serverCurtime) && _serverCurtime > 0)
			{
				_startTime = _serverCurtime;
			}
			return _startTime+LiveVodConfig.TIME_OFF;
		}
		
		public function get realStartTime():Number
		{
			return _startTime;
		}
		public function set startTime(value:Number):void
		{
			_startTime = value;
		}
		public function set serverCurtime(value:Number):void
		{
			//_startTime = value;
			_serverCurtime = value; 
			P2PDebug.traceMsg(this,"serverCurtime"+TimeTranslater.getTime(_serverCurtime),_serverCurtime);
		}
		public function get serverCurtime():Number
		{
			return _serverCurtime;
		}
		/**
		 * 查询flv数组将乐视的（p2p=1）CDN保留并返回
		 * @param arr
		 * @return 
		 * 
		 */		
		protected function supportP2P(arr:Array):Array
		{
			var tempArray:Array = new Array();
			for(var i:int=0 ; i<arr.length ; i++)
			{
				var str:String = arr[i];
				if(str.indexOf("p2p=1") != -1)
				{
					tempArray.push(arr[i]);
				}
			}
			return tempArray;
		}
		private function replaceParam(url:String,key:String,value:String):String
		{
			var reg:RegExp=new RegExp("\[?&]"+key+"=(\\w{0,})?", "");
//			var reg:RegExp=new RegExp(key+"=(\\w{0,})?", "");
			var findStr:String="";
			if(reg.test(url))
			{
				findStr=url.match(reg)[0];
			}
			if(findStr.length>0){
				url=url.replace(findStr,findStr.charAt(0)+key+"="+value);
			}
			return url;
		}
	}
	/**etry:1
	 res:-
	 flvURL:http://113.57.216.211/leflv/cctv1/desc.xml?tag=live&video_type=xml&useloc=1&clipsize=128&clipcount=10&f_ulrg=0&cmin=3&cmax=10&path=119.167.147.50,119.167.147.34,119.167.210.19&cipi=1899624512&tm=1362556150&pnl=741,215,732,730,205&stream_id=cctv1&sign=live_web&scheme=rtmp&uip=113.57.248.64,http://113.57.216.212/leflv/cctv1/desc.xml?tag=live&video_type=xml&useloc=1&clipsize=128&clipcount=10&f_ulrg=0&cmin=3&cmax=10&path=113.57.248.163,119.167.147.35,119.167.210.19&cipi=1899624513&tm=1362556150&pnl=741,739,215,730,205&stream_id=cctv1&sign=live_web&scheme=rtmp&uip=113.57.248.64
	 serverOffsetTime:2
	 flvNode:706,706
	 url:http://live.gslb.letv.com/gslb?stream_id=jiangsu&tag=live&ext=xml&format=1&expect=2
	 error:0
	 groupName:64a3d7e15a797e6e761ec752e8a7a863cfbc15e
	 livePer:0.2
	 serverCurtime:1363858813
	 geo:CN.1.9.2
	 code:URLAnalysisSuccess
	 serverStartTime:1363772416
	 utime:378
	 * */
	/**
	 *startTime<><><>0
	 code<><><>URLAnalysisSuccess
	 error<><><>0
	 utime<><><>394
	 retry<><><>1
	 url<><><>http://g3.letv.cn/19/53/82/letv-uts/684508-AVC-537889-AAC-31586-6767257-498020185-c2ce9304df17ddcfe16adb8b7199dc67-1350293248246.flv?b=588&mmsid=1944433&tm=1359357666&key=6ba67d4178663dbd414afdcffdb5ebaa&format=1&tag=letv&sign=letv&expect=3&rateid=1000
	 res<><><>-
	 flvURL<><><>http://123.125.89.49/19/53/82/letv-uts/684508-AVC-537889-AAC-31586-6767257-498020185-c2ce9304df17ddcfe16adb8b7199dc67-1350293248246.letv?crypt=474f0090aa7f2e132&b=588&gn=706&nc=3&bf=18&p2p=1&video_type=flv&check=0&tm=1364040000&key=5530cae046bb4a1b335fee64c76fd178&opck=1&lgn=letv&proxy=2071812441&cipi=168448064&tsnp=1&mmsid=1944433&tag=letv&sign=letv&rateid=1000,http://220.181.155.129/19/53/82/letv-uts/684508-AVC-537889-AAC-31586-6767257-498020185-c2ce9304df17ddcfe16adb8b7199dc67-1350293248246.letv?crypt=12210d4baa7f2e220&b=588&gn=820&nc=3&bf=30&p2p=1&video_type=flv&check=0&tm=1364040000&key=5530cae046bb4a1b335fee64c76fd178&opck=1&lgn=letv&proxy=3702879667&cipi=168448064&tsnp=1&mmsid=1944433&tag=letv&sign=letv&rateid=1000,http://123.125.89.89/19/53/82/letv-uts/684508-AVC-537889-AAC-31586-6767257-498020185-c2ce9304df17ddcfe16adb8b7199dc67-1350293248246.letv?crypt=6d139d68aa7f2e110&b=588&gn=103&nc=3&bf=15&p2p=1&video_type=flv&check=0&tm=1364040000&key=5530cae046bb4a1b335fee64c76fd178&opck=1&lgn=letv&proxy=3721187009&cipi=168448064&tsnp=1&mmsid=1944433&tag=letv&sign=letv&rateid=1000
	 testSpeed<><><>15
	 geo<><><>CN.1.9.2
	 flvNode<><><>706,820,103
	 groupName<><><>553c936e12cb964e88a1dc778bbffc6b1a834
	 checkURL<><><>http://webchecksum.letv.com/19/53/82/letv-uts/684508-AVC-537889-AAC-31586-6767257-498020185-c2ce9304df17ddcfe16adb8b7199dc67-1350293248246.xml
	 */
}