package com.hls_p2p.data.vo
{
	public class LiveVodConfig
	{
		//public static var MEMORY_SIZE:uint= 80*1024*1024;
		/**点播设置，内存最大字节*/
		public static var MEMORY_SIZE:uint= 300*1024*1024;
		/**直播用，内存存放的时间，800(800*1024b/8字节)码流约50分钟*/
		public static var MEMORY_TIME:uint=50;
		/**每个片的字节，128k字节*/
		public static var CLIP_INTERVAL:uint = 188*1024;//128*1024;
		
		/** live_vod_piecesize*/
		public static var CLIP_LIVEVOD_PERSIZE:uint = 188*1024;
		/**伪直播偏移时间*/
		public static var TIME_OFF:Number=60*1;
		
		
		
		
		
		//********ts流的属性信息
		public static var n_EXT_X_VERSION:Number 				= 0;
		public static var n_EXT_X_MEDIA_SEQUENCE:Number 		= 0
		public static var b_EXT_X_ALLOW_CACHE:Boolean			= true;
		public static var n_EXT_X_TARGETDURATION:Number			= 0;
		public static var str_EXT_LETV_M3U8_TYPE:String			= "";
		public static var str_EXT_LETV_M3U8_VER:String			= "";
		public static var str_EXT_LETV_X_DISCONTINUITY:String	= "";
		public static var n_EXT_LETV_PROGRAM:Number				= 0;
		public static var n_EXT_LETV_PIC_WIDTH:Number			= 0;
		public static var n_EXT_LETV_PIC_HEIGHT:Number			= 0;
		public static var n_EXT_LETV_TOTAL_TS_LENGTH:Number 	= 0;
		public static var n_EXT_LETV_TOTAL_ES_LENGTH:Number 	= 0;
		public static var n_EXT_LETV_TOTAL_SEGMENT:Number		= 0;
		public static var n_EXT_LETV_TOTAL_P2P_PIECE:Number		= 0;
		
		
		public static function GET_VERSION():String
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				return LiveVodConfig.VOD_VERSION;
			}
			else
			{
				return LiveVodConfig.LIVE_VERSION;
			}
		}
		public static function GET_AGREEMENT_VERSION():String
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				return LiveVodConfig.P2P_AGREEMENT_VOD_VERSION;
			}
			else
			{
				return LiveVodConfig.P2P_AGREEMENT_LIVE_VERSION;
			}
		}
		
		public static function SET_MEMORY_TIME():void
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				MEMORY_TIME = Math.ceil((MEMORY_SIZE/(DATARATE/8*1024))/60);
			}			
		}
		
		public static var ADD_DATA_TIME:Number = -1;
		public static var PLAY_TIME:Number = -1;
		// public static var START_TIME:Number = -1;
		/**点播总时长*/
		public static var DURATION:Number = -1;
		
		public static var TOTAL_TS:Number    = 0;
		public static var TOTAL_PIECE:Number = 0;
		public static var LAST_TS_ID:Number  = 0;
		
		//DATAMANAGE***********************************************************************************************
		/**播放码率*/
		public static var DATARATE:Number=800;
		/**播放码率的倍数，暂定为1.5倍*/
		public static var RATE_MULTIPLE:Number=1.5;
		/**紧急区加载的区间，通过块的格林尼治时间相差换算，误差在一个块之间*/
		public static var DAT_BUFFER_TIME:Number=25;//7;
		
		//DESC***********************************************************************************************
		/**desc在内存缓存的时间，暂定2小时,单位秒*/
		//public static var DESC_TIME:Number=10*60;
		public static var DESC_TIME:Number=40*60;
		/**desc重复加载次数（总的次数=DESC_RPEAT_LOAD_COUNT*加载地址的个数）*/
		public static var DESC_RPEAT_LOAD_COUNT:int=3;
		/**每次请求DESC的时移时间*/
		public static var DESC_TIMESHIFT:Number = -1;
		
		//DAT***********************************************************************************************
		/**dat重复加载次数(总的次数=DAT_RPEAT_LOAD_COUNT*加载地址的个数) */
		public static var DAT_RPEAT_LOAD_COUNT:int=3;
		/**隔断时间，观察是否有数据下载，如果没有认为是网络错误，暂定间隔时间为2000豪秒*/
		public static var DAT_CHECK_INTERVAL:Number=2000;
		/**随机CDN下载数据的概率*/
		public static var DAT_LOAD_RATE:Number=0.1//0.3;
		
		//NETSTREAM*****************************************************************************************
		/**缓存时，暂停最大的时间，如果超过这个时间直接seek，单位时间是秒（原来是90秒）*/
		public static var Buffer_Count_Time:Number=60;
		/**播放不超过这个缓冲值，超过将不再喂数据*/
		public static var BufferTimeLimit:Number=20;
		
		//P2P***********************************************************************************************
		/**在p2p使用中，可以修改的本地名称*/
		public static var MY_NAME:String;
		/**连接失败的节点在失败列表中的保存时间*/
		public static var badPeerTime:Number = 10*1000;
		/**最大连接节点数*/
		public static var MAX_PEERS:Number = 9;
		
//		//m3u8文件解析
//		public static var arrGroupName:Array = new Array;
		
		
		
		
		public static function CLEAR():void
		{
			LiveVodConfig.MEMORY_SIZE   		= 300*1024*1024;
			
			LiveVodConfig.TYPE    		 		= LiveVodConfig.LIVE;
			
			LiveVodConfig.ADD_DATA_TIME  		= -1;
			LiveVodConfig.PLAY_TIME 			= -1;
			/**播放码率*/
			LiveVodConfig.DATARATE        		= 800;
			LiveVodConfig.RATE_MULTIPLE   		= 1.5;
			
			LiveVodConfig.DESC_RPEAT_LOAD_COUNT = 3;
			LiveVodConfig.DESC_TIMESHIFT 		= -1;
			
			LiveVodConfig.DAT_RPEAT_LOAD_COUNT 	= 3;
			LiveVodConfig.DAT_CHECK_INTERVAL   	= 2000;
			
			LiveVodConfig.MY_NAME       		= "";
			LiveVodConfig.badPeerTime   		= 30*1000;
			LiveVodConfig.DAT_LOAD_RATE 		= 0.1;
			
			LiveVodConfig.TOTAL_TS    			= 0;
			LiveVodConfig.TOTAL_PIECE 			= 0;
			LiveVodConfig.LAST_TS_ID  			= 0;
			
			LiveVodConfig.TERMID  = "";	//终端类型
			LiveVodConfig.PLATID  = "";	//平台ID
			LiveVodConfig.SPLATID = "";  //子平台ID
		}
		//statistics************************************************************************************
		public static const CLIENT_TYPE:String = "PC";//"TV","MP","BOX"
		public static var TERMID:String = "";		//终端类型
		public static var PLATID:String = "";		//平台ID
		public static var SPLATID:String = "";	//子平台ID
		//PLAY***********************************************************************************************
		/**内核版本号*/
		private static const VOD_VERSION:String  = "vod.2.0.09251900";
		private static const LIVE_VERSION:String = "liv.2.0.10181200";
		
		/**当前播放的类型*/
		public static const LIVE:String="LIVE";
		public static const VOD:String="VOD";
		public static var TYPE:String=LIVE;//VOD;
		
		/**P2P协议版本号 */
		private static const P2P_AGREEMENT_VOD_VERSION:String  = "1.3m3u8_09231157";//0909122->加removeHaveData功能
		private static const P2P_AGREEMENT_LIVE_VERSION:String = "1.3m3u8_10091743";
	}
}