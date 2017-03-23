/**
 * 
 */
package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDispatcher;
	import com.hls_p2p.dispatcher.LiveDispatcher;
	import com.hls_p2p.dispatcher.VodDispatcher;
	/**
	 * 依据不同的type的值，返回不同的调度对象
	 * @author mazhoun
	 */
	public class DispatcherFactory
	{
		/**
		 * 创建调度器，依据不同的类型可创建点播|直播调度器
		 * @param type
		 * @return 
		 * 
		 */
		public static function createDispatcher(type:String):IDispatcher{
			switch(type){
				case LiveVodConfig.LIVE:
					return new LiveDispatcher();
				case LiveVodConfig.VOD:
					return new VodDispatcher();
					default:
						return new Dispatcher();
			}
		}
		
	}
}