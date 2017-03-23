package com.p2p.data
{
	import flash.net.SharedObject;
	
	public class P2PCookie
	{
		private static var _shaderObject:SharedObject = SharedObject.getLocal('com.letv.P2PCookie','/');
		
		public function P2PCookie()
		{
		}
		public static function GetNatType():int
		{
			return _shaderObject.data["net"];			
		}
		public static function SetNatType(i:int):Boolean
		{
			try
			{
				_shaderObject.data["net"] = i;
				_shaderObject.flush();
			}
			catch(e:Error)
			{
				return false;
			}
			return true;
		}
	}
}