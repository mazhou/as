package com.p2p_live.data
{
	import flash.utils.ByteArray;

	public class Piece
	{
		/**没片数据id,其值是本块数据按照固定字节划分的索引*/
		public var id:uint=0;
		
		/**数据来源:http或p2p，获得数据赋值*/
		public var from:String="";
		
		/**如果收到过p2p数据，保存该数据是从哪个邻居收到的，获得数据赋值*/
		public var peerID:String="";
		
		/**数据开始索取时的时间，获得数据前赋值*/
		public var begin:Number=0;
		
		/**获得数据时的时间，获得数据赋值*/
		public var end:Number=0;
		
		/**被分享的次数，分享时赋值，没分享一次累加一次*/
		public var share:uint=0;
		
//		public var size:Number=0;
		
		/**该piece目前的状态 ：0为未调度； 1为http调度紧急区设置； 2为p2p调度 ；3为已经有正确数据*/
		public var iLoadType:int=0;
		
		/**数据流*/
		public var stream:ByteArray=null;
	}
}