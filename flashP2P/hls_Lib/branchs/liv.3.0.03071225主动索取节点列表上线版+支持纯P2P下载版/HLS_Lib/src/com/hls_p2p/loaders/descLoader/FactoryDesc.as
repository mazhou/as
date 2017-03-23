package com.hls_p2p.loaders.descLoader
{
	
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.loaders.descLoader.IDescLoader;
	import com.hls_p2p.dataManager.DataManager;
	
	public class FactoryDesc
	{
		public function createDescLoader(type:String,datamanger:DataManager):IDescLoader
		{
			return new GeneralLiveM3U8Loader(datamanger);
			/*
			switch(type)
			{
				case LiveVodConfig.LIVE:
					return new LiveM3U8Loader(dispatcher);
				case LiveVodConfig.VOD:
					return new DescLoader(dispatcher);
				default:
					return null;
			}
			*/
		}
	}
}