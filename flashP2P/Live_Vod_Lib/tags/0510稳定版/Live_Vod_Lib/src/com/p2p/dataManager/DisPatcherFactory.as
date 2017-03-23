/**
 * 
 */
package com.p2p.dataManager
{
	import com.p2p.data.vo.Config;

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
				case Config.LIVE:
					return new LiveDataManager();
				case Config.VOD:
//					return new VodDispatcher();
					default:
						return null;
			}
		}
		
	}
}