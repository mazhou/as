package 
{
	import flash.events.Event;
	public class P2PTestStatisticEvent extends Event
	{
		public static const P2P_TEST_STATISTIC_TIMER:String="p2pTestStatisticTimer";
		public static const GET_VID:String="getVid"
		
		protected var _info:Object;
		public function get info():Object
		{
			return _info;
		}
		public function P2PTestStatisticEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,bubbles,cancelable);
			_info = info;
		}
		public override function clone():Event
		{
			return new P2PTestStatisticEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("P2PTestStatisticEvent","info","type","bubbles","cancelable");
		}
	}
}