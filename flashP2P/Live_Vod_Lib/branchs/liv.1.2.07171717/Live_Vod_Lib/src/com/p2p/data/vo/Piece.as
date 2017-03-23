package com.p2p.data.vo
{
	import flash.utils.ByteArray;

	public class Piece
	{
		//固有属性======================================
		/**每片数据id*/
		public var id:uint=0;		
		/**数据流*/
		public var stream:ByteArray = new ByteArray;
		//调度===================================
		/**数据来源:http或p2p，获得数据后赋值*/
		public var from:String="";
		/**该piece的状态 ： 1为http调度紧急区设置； 2为p2p调度 ；3为已经有正确数据，默认是 2为p2p调度*/
		public var iLoadType:int=2;
		
		//p2p========================================
		/**每片数据peerID,其值是分配的临节点*/
		public var peerID:String="";
		/**对方节点的名称*/
		public var peerName:String="";
		
		//统计===========================================
		/**数据开始索取时的时间，获得数据前赋值*/
		public var begin:Number=0;
		/**获得数据时的时间，获得数据赋值*/
		public var end:Number=0;
		/**被分享的次数，分享时赋值，没分享一次累加一次*/
		public var share:int=0;
		
		
		
		public function reset():void
		{
			begin = 0;
			end   = 0;
			iLoadType = 2;
			peerID = "";
			from   = "";
			
			stream.clear();
		}
		public function _toString():String{
			//var hasStream:String="";
			//if(stream){hasStream="Y"}else{hasStream="N"}
			return " id:"+id+" s:"+iLoadType+" f:"+from;
		}
	}
}