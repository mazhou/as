package com.hls_p2p.data.vo
{
	/**
	 * Clip属性:
	 * <ul>head        : Number</ul>
	 * <ul>timestamp   : Number</ul>
	 * <ul>name        : String	</ul>	
	 * <ul>size        : Number</ul>
	 * <ul>duration    : Number</ul>
	 * <ul>checkSum    : String</ul>
	 * <ul>sunCheckSum : Array</ul>
	 * */
	public dynamic class Clip
	{
		/**时间戳*/
		public var timestamp:Number=0;
		/**文件名*/
		public var name:String="";
		/**数据块的字节*/
		public var size:Number=0;
		/**数据块播放时长*/
		public var duration:Number=0;
		/**groupID*/
		public var groupID:String="";
		
		/**片校验码*/
		public var pieceInfoArray:Array = new Array();
		
		/**块校验码*/
		public var block_checkSum:String;
		
		public var sequence:int=0;
		
		public var pieceTotal:int=0;
		
		/********改进版本_01******/
//		public var p2pPieceNumber:Number 	= 0;
//		public var strBlockVer:String		= "";
//		public var clipInfo:String			= "";
//		public var blockVer:String			= "";
//		public var beginKeyFrameSeq:int		= 0;
//		public var KeyFrameCount:uint		= 0;
		
		public var width:Number 			= 0;
		public var height:Number			= 0;
		public var totalDuration:Number		= 0;
		
		/**总字节偏移量*/
		public var offsize:Number			= 0;
//		public var strgroupid:String  		= "";
	}
}