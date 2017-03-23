package com.hls_p2p.loaders
{
	public class DescFactory
	{
		public static function createDescLoader(type:String):IDescLoader{
			switch(type){
//				case LiveVodConfig.LIVE:
//					return new LiveDataManager();
//				case LiveVodConfig.VOD:
					//					return new VodDispatcher();
				default:
					return null;
			}
		}
	}
}