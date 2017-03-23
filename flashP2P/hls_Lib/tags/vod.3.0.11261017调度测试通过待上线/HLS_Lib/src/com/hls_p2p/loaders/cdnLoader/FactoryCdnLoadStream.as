package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.loaders.LoadManager;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	
	public class FactoryCdnLoadStream
	{
		public function createDescLoader(type:String,dispatcher:IDataManager,LDMGR:LoadManager):IStreamLoader
		{
			switch(type){
//				case LiveVodConfig.LIVE:
//					return new LiveStreamLoad(dispatcher);
//				case LiveVodConfig.VOD:
//					return new VodStreamLoader(dispatcher);
//				case "CDNLoad":
//					return new CDNLoad(dispatcher);
				default:
					return new CDNLoad(dispatcher,LDMGR);
			}
		}
	}
}