package com.hls_p2p.events.protocol
{
	public class NETSTREAM_PROTOCOL
	{
		public static const PLAY:String="PLAY";
		public static const SEEK:String="SEEK";
		public static const PAUSE:String="PAUSE";
		public static const RESUME:String="RESUME";
		public static const CLOSE:String="CLOSE";
		public static const HEAD:String="HEAD";
		
		//当流状态发生变法时派发
		public static const STREAM_STATUS:String = "streamStatus";
		//当p2p状态发生变法时派发
		public static const P2P_STATUS:String = "p2pStatus";
		//p2pErrorCode="0000"
		public static const P2P_All_OVER:String = "p2pAllOver";
	}
}