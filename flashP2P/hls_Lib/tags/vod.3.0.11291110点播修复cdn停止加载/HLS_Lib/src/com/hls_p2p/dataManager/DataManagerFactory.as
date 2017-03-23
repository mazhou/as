/**
 * 
 */
package com.hls_p2p.dataManager
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.IDataManager;
	/**
	 * 依据不同的type的值，返回不同的调度对象
	 * @author mazhoun
	 */
	public class DataManagerFactory
	{
		/** 
		 * 创建调度器，依据不同的类型可创建点播|直播调度器
		 * @param type
		 * @return 
		 */
		public static function createDispatcher(type:String):IDataManager
		{
			return new DataManager();
		}
	}
}