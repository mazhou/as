package com.p2p_live.data
{
	import flash.utils.ByteArray;

	public class SendData
	{
		/**块id*/
		public var blockID:uint=0;
		/**片id*/
		public var pieceID:int=0;
		/**数据流*/
		public var data:ByteArray=null;
		/**校验码*/
		public var checksum:uint=0;
	}
}