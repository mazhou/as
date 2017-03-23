package com.p2p.loaders
{
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.dataManager.IDataManager;

	public class ChecksumLoadFactory
	{
		public static function createChecksumLoad(type:String,_dispather:IDataManager):IChecksumLoad{
			switch(type){
				case LiveVodConfig.LIVE:
					return new DescLoader(_dispather);
				case LiveVodConfig.VOD:
//					return new LiveDispatcher(_dispather);
				default:
					return null;
			}
		}
	}
}