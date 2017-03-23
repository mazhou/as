package com.p2p.data.vo
{
	public class LiveVodConfig
	{
		//PLAY***********************************************************************************************
		/**内核版本号*/
		public static var VERSION:String = "liv.1.2.06251933";
		/**点播设置，内存最大字节*/
		//public static var MEMORY_SIZE:uint= 80*1024*1024;
		public static var MEMORY_SIZE:uint= 300*1024*1024;
		/**直播用，内存存放的时间，800(800*1024b/8字节)码流约50分钟*/
		public static var MEMORY_TIME:uint=50*60;
		/**每个片的字节，128k字节*/
		public static var CLIP_INTERVAL:uint = 128*1024;
		/**伪直播偏移时间*/
		public static var TIME_OFF:Number=-60*3;
		/**当前播放的类型*/
		public static const LIVE:String="LIVE";
		public static const VOD:String="VOD";
		public static var TYPE:String=LIVE;
		
		//DATAMANAGE***********************************************************************************************
		/**播放码率*/
		public static var DATARATE:Number=0;
		/**播放码率的倍数，暂定为1.5倍*/
		public static var RATE_MULTIPLE:Number=1.5;
		/**紧急区加载的区间，通过块的格林尼治时间相差换算，误差在一个块之间*/
		public static var DAT_BUFFER_TIME:Number=15;
		/**是否有领先的资格*/
		public static var ISLEAD:int=0;
		/**是否为服务器确认的领先资格*/
		public static var IS_REAL_LEAD:Boolean=false;
		
		//DESC***********************************************************************************************
		/**desc在内存缓存的时间，暂定2小时,单位秒*/
		//public static var DESC_TIME:Number=10*60;
		public static var DESC_TIME:Number=40*60;
		/**desc重复加载次数（总的次数=DESC_RPEAT_LOAD_COUNT*加载地址的个数）*/
		public static var DESC_RPEAT_LOAD_COUNT:int=3;
		
		//DAT***********************************************************************************************
		/**dat重复加载次数(总的次数=DAT_RPEAT_LOAD_COUNT*加载地址的个数) */
		public static var DAT_RPEAT_LOAD_COUNT:int=3;
		/**隔断时间，观察是否有数据下载，如果没有认为是网络错误，暂定间隔时间为2000豪秒*/
		public static var DAT_CHECK_INTERVAL:Number=2000;
		/**dat该加载的block id,播放器跳跃不应超越加载的进度*/
		public static var DAT_LoadBlockID:Number=0;
		
		//netstream****************************************************************************************
		/**block读取失败时，服务器的时间与blockID的延时范围，单位：秒*/
		public static var DALY_TIME_LIMITED:Number = -8;
		public static var FORWARD_PERIOD:Number=15;
		//P2P***********************************************************************************************
		/**在p2p使用中，可以修改的本地名称*/
		public static var MY_NAME:String;
		/**连接失败的节点在失败列表中的保存时间*/
		public static var badPeerTime:Number = 30*1000;
		
	}
}