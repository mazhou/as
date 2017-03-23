package analysisURL
{
	import flash.events.Event;
	
	public class AnalysisEvent extends Event
	{
		public static const STATUS:String = "status";
		public static const ERROR:String = "error";		
		
		protected var _info:Object;
		public function get info():Object
		{
			return _info;
		}
		public function AnalysisEvent(type:String,info:Object=null,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,bubbles,cancelable);
			_info = info;
		}
		public override function clone():Event
		{
			return new AnalysisEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("AnalysisEvent","info","type","bubbles","cancelable");
		}
	}
}