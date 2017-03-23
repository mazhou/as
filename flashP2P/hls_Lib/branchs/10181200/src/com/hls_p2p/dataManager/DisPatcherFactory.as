/**
 * 
 */
package com.hls_p2p.dataManager
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.IDataManager;
	import com.hls_p2p.dataManager.LiveDataManager;

	/**
	 * 依据不同的type的值，返回不同的调度对象
	 * @author mazhoun
	 */
	public class DisPatcherFactory
	{
		/**
		 * 创建调度器，依据不同的类型可创建点播|直播调度器
		 * @param type
		 * @return 
		 * 
		 */
		public static function createDisPatcher(type:String):IDataManager{
			switch(type){
				case LiveVodConfig.LIVE:
					return new LiveDataManager();
				case LiveVodConfig.VOD:
					return new LiveDataManager();
					default:
						return null;
			}
		}
		
	}
}