package com.p2p.loaders
{
	import com.p2p.data.vo.Config;
	import com.p2p.dataManager.IDataManager;

	public class ChecksumLoadFactory
	{
		public static function createChecksumLoad(type:String,_dispather:IDataManager):IChecksumLoad{
			switch(type){
				case Config.LIVE:
					return new DescLoader(_dispather);
				case Config.VOD:
//					return new LiveDispatcher(_dispather);
				default:
					return null;
			}
		}
	}
}