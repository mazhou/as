package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	
	public class FactoryCdnLoadStream
	{
		public function createDescLoader(type:String,dispatcher:DataManager,LDMGR:LoadManager):IStreamLoader
		{
			return new CDNLoad(dispatcher,LDMGR);
		}
	}
}