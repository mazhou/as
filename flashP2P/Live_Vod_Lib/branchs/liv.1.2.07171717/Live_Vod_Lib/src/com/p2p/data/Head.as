package com.p2p.data
{
	import flash.utils.ByteArray;
	
	public class Head
	{
		/** head的索引值 1354455065.header的1354455065 */
		public var id:Number;
		
		private var _stream:ByteArray = new ByteArray;
		
		public function Head()
		{
//			_stream = new ByteArray();
		}
		/**获得块对应.dat文件,默认返回null*/
		public function setHeadStream(data:ByteArray):void
		{
			_stream.clear();
			data.readBytes(_stream);
		}
		/**获得块对应.dat文件,默认返回null*/
		public function getHeadStream():ByteArray
		{
			return _stream;
		}
	}
}