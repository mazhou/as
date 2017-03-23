package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.loaders.descLoader.DescLoader;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.loaders.descLoader.LiveM3U8Loader;
	
	public class FactoryCdnLoadStream
	{
		public function createDescLoader(type:String,dispatcher:IDataManager):IStreamLoader
		{
			switch(type){
//				case LiveVodConfig.LIVE:
//					return new LiveStreamLoad(dispatcher);
//				case LiveVodConfig.VOD:
//					return new VodStreamLoader(dispatcher);
//				case "CDNLoad":
//					return new CDNLoad(dispatcher);
				default:
					return new CDNLoad(dispatcher);
			}
		}
	}
}