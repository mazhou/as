package com.hls_p2p.data.vo
{
	/**
	 * Clip属性:
	 * <ul>head        : Number</ul>
	 * <ul>timestamp   : Number</ul>
	 * <ul>name        : String	</ul>	
	 * <ul>size        : Number</ul>
	 * <ul>duration    : Number</ul>
	 * <ul>checkSum    : String</ul>
	 * <ul>sunCheckSum : Array</ul>
	 * */
	public class Clip
	{
		/**时间戳*/
		public var timestamp:Number=0;
		/**文件名*/
		public var name:String="";
		/*保存网络运营商信息geo*/
		public var geo:String = "";
		/**数据块的字节*/
		public var size:Number=0;
		/**数据块播放时长*/
		public var duration:Number=0;
		/**总字节偏移量*/
		public var offsize:Number=0;
		/**片校验码*/
		public var checkSums:Array;
		/**块校验码*/
		public var block_checkSum:String;
		
		public var sequence:int=0;
		
		public var pieceTotal:int=0;
	}
}