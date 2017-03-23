package com.p2p.data.vo
{
	import flash.utils.ByteArray;
	/**
	 * <P>
	 * type 
	 * <UL>
	 * HEAD:表示metadata数据流;
	 * KEY_FRAME:表示seek时的关键帧数据流; 
	 * FRAME:表示非seek时的数据流;
	 * END_FRAME:表示最终结束的数据，点播使用，直播没有结束的数据;</UL> 
	 * </p>
	 * <p>timestamp 该流所在块或片的时间戳</p>
	 * <p>
	 * stream 
	 * <UL>数据流</UL>
	 * </P>
	 * @author mazhoun
	 * 
	 */
	public class PlayData
	{
		/**表示metadata数据流*/
		public static const HEAD:int=0;
		/**表示seek时的关键帧数据流*/
		public static const KEY_FRAME:int=1;
		/**表示非seek时的数据流*/
		public static const FRAME:int=2;
		/**表示最终结束的数据，点播使用，直播没有结束的数据*/
		public static const END_FRAME:int=3;
		
		public var type:int=0;
		/**该流所在的时间戳*/
		public var timestamp:Number=0;
		/**数据流*/
		public var stream:ByteArray=null;
	}
}