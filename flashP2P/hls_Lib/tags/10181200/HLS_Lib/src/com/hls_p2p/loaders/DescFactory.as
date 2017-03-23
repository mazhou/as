package com.hls_p2p.loaders
{
	
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.loaders.IDescLoader;
	import com.hls_p2p.loaders.LiveM3U8Loader;
	import com.hls_p2p.loaders.DescLoader;
	import com.hls_p2p.dataManager.IDataManager;
	
	public class DescFactory
	{
		public function createDescLoader(type:String,p_dataMgr:IDataManager):IDescLoader
		{
			switch(type){
				case LiveVodConfig.LIVE:
					return new LiveM3U8Loader(p_dataMgr);
				case LiveVodConfig.VOD:
					return new DescLoader(p_dataMgr);
				default:
					return null;
			}
		}
	}
}