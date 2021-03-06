package com.hls_p2p.loaders.descLoader
{
	
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.loaders.descLoader.LiveM3U8Loader;
	import com.hls_p2p.loaders.descLoader.DescLoader;
	import com.hls_p2p.dispatcher.IDispatcher;
	
	public class FactoryDesc
	{
		public function createDescLoader(type:String,dispatcher:IDispatcher):IDescLoader
		{
			switch(type){
				case LiveVodConfig.LIVE:
					return new LiveM3U8Loader(dispatcher);
				case LiveVodConfig.VOD:
					return new DescLoader(dispatcher);
				default:
					return null;
			}
		}
	}
}