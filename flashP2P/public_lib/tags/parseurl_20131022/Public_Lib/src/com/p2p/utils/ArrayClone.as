package com.p2p.utils
{
	import flash.utils.ByteArray;
	public class ArrayClone
	{
		public function ArrayClone()
		{}
		public static function Clone($source:Object):*
		{
			var _copier:ByteArray=new ByteArray();
			_copier.writeObject($source);
			_copier.position=0;
			return _copier.readObject();
		}
	}
}