package com.p2p.data.vo
{
	public class Config
	{
		/**内核版本号*/
		public static var VERSION:String = "liv.1.2.05281003";
		/**点播设置，内存最大字节*/
		public static var MEMORY_SIZE:uint= 80*1024*1024;
		//public static var MEMORY_SIZE:uint= 300*1024*1024;
		/**直播用，内存存放的时间，800(800*1024b/8字节)码流约50分钟*/
		public static var MEMORY_TIME:uint=50*60;
		/**每个片的字节，128k字节*/
		public static var CLIP_INTERVAL:uint = 128*1024;
		
		/**desc在内存缓存的时间，暂定2小时,单位秒*/
		public static var DESC_TIME:Number=10*60;
		//public static var DESC_TIME:Number=40*60;
		
		/**每个dat加载错误次数不得超过该值，超过该值，将跳过该值*/
		public static var DAT_ErrorTotalCount:int=2;
		/**隔断时间，观察是否有数据下载，如果没有人为是网络错误，暂定间隔时间为2000豪秒*/
		public static var DAT_CHECK_INTERVAL:Number=2000;
		
		/**伪直播偏移时间*/
		public static var TIME_OFF:Number=-60*6;
		
		/**播放码率*/
		public static var DATARATE:Number=0;
		/**播放码率的倍数，暂定为1.5倍*/
		public static var RATE_MULTIPLE:Number=1.5;
		
		/**是否有领先的资格*/
		public static var ISLEAD:int=0;
		/**是否为服务器确认的领先资格*/
		public static var IS_REAL_LEAD:Boolean=false;
		/**紧急区加载的区间，通过块的格林尼治时间相差换算，误差在一个块之间*/
		public static var DAT_BUFFER_TIME:Number=60;
		
		/**当前播放的类型*/
		public static const LIVE:String="LIVE";
		public static const VOD:String="VOD";
		public static var TYPE:String=LIVE;
		
		/**在p2p使用中，可以修改的本地名称*/
		public static var MY_NAME:String;
		
		/**
		 * 在播放状态下，如果playHead后续block没有流数据，或流数据损坏导致无法继续播放，此时跳过
		 * 该block,继续读取block.nextID指向的block数据，以此类推，直到遇到有流的block继续播放，但此时的
		 * block的时间戳与playHead的时间间隔不能超过ERROR_CORRECT_TIME规定的秒数
		 * */
		public static var ERROR_CORRECT_TIME:Number = 90;
		
		/**当前加载dat的时间*/
		public static var LoadDatTime:Number=0;
		
		/**连接失败的节点在失败列表中的保存时间*/
		public static var badPeerTime:Number = 3*60*1000;
		
	}
}