package com.p2p_live.events
{
	import flash.events.Event;
	public class P2PNetStreamLocalEvent extends Event
	{
		//当流状态发生变法时派发
		public static const STREAM_STATUS:String = "streamLocalStatus";
		//当p2p状态发生变法时派发
		public static const P2P_STATUS:String = "p2pLocalStatus";
		//p2pErrorCode="0000"
		public static const P2P_All_OVER:String = "p2pLocalAllOver";
		protected var _info:Object;
		public function get info():Object
		{
			return _info;
		}
		public function P2PNetStreamLocalEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,bubbles,cancelable);
			_info = info;
		}
		public override function clone():Event
		{
			return new P2PNetStreamEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("P2PNetStreamLocalEvent","info","type","bubbles","cancelable");
		}
	}
}