package lee.utils
{
	public class FlashVars
	{
		private static var _instance:FlashVars;
		public var vars:Object;
		public var streamid:String;
		public var gatherName:String;
		public var gatherPort:String;
		
		public function FlashVars()
		{
		}
		public static function getInstance():FlashVars
		{
			if(!_instance)
			{
				_instance = new FlashVars();
			}
			return _instance;
		}
		public function setVars(value:*):void
		{
			for(var i:String  in value)
			{
				if(this.hasOwnProperty(i))
				{
					this[i] = value[i];
				}
			}
		}
	}
}