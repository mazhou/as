package com.p2p.data.vo
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
		/**下载的clip对应得head的时间戳*/
		public var head:Number=0;
		/**时间戳*/
		public var timestamp:Number=0;
		/**文件名*/
		public var name:String="";		
		/**数据块的字节*/
		public var size:Number=0;
		/**数据块播放时长*/
		public var duration:Number=0;
		/**块校验码*/
		public var checkSum:String="";
		/**片校验码*/
		public var sunCheckSum:Array=[];
		/**指向上一个block的索引值*/
		public var preID:Number = 0;
		/**指向下一个block的索引值*/
		public var nextID:Number = 0;
	}
}