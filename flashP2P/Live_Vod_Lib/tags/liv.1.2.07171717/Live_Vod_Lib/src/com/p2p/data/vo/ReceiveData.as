package com.p2p.data.vo
{
	import flash.utils.ByteArray;
	
	public class ReceiveData
	{
		/**数据来源 http 或 p2p*/
		public var from:String="";
		/**数据所属的block id*/
		public var blockID:Number;
		/**数据所属的piece id*/
		public var pieceID:int;
		/**数据下载的起始时间（毫秒）*/
		public var begin:Number=0;
		/**数据下载的结束时间（毫秒）*/
		public var end:Number=0;
		/**数据流*/
		public var data:ByteArray;
		/**如果此数据从p2p获得，表示对方的名称*/
		public var remoteName:String;
		/**校验码，暂时不使用*/
		public var CheckSum:String;
		public var finished:Boolean;
		
	}
}