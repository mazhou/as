package com.p2p.data.vo
{
	import com.p2p.logs.Debug;
	import com.p2p.utils.TimeTranslater;

	/**
	 * DataRange属性:
	 * <ul>start: String　本区域块的左边界值</ul>
	 * <ul>end: String　本区域块的右边界值</ul>
	 * <ul>preConnectID: String	可以和本区域块的左边界值相连接的索引值</ul>	
	 * <ul>nextConnectID: String　以和本区域块的右边界值相连接的索引值</ul>
	 * */
	public class DataRange
	{
		/**本区域块的左边界值 blockID_pieceID*/
		public var startBlockID:Number;
		public var startPieceID:int;
		/**本区域块的右边界值 blockID_pieceID*/
		public var endBlockID:Number;
		public var endPieceID:int;
		
		/**可以和本区域块的左边界值相连接的索引值*/
		//public var preConnectID:String    = "";
		/**可以和本区域块的右边界值相连接的索引值*/
		public var nextConnectBlockID:Number=0;
		public var nextConnectPieceID:int=0;
		public function _toString():String{
			return "s:"+TimeTranslater.getTime(startBlockID)+" "+startBlockID+"_"+startPieceID+
				" e:"+TimeTranslater.getTime(endBlockID)+" "+endBlockID+"_"+endPieceID+
				" n:"+nextConnectBlockID+"_"+nextConnectPieceID;
//			return "sbID:"+startBlockID+" spID:"+startPieceID+
//				" ebID:"+endBlockID+" epID:"+endPieceID+
//				" ncbID:"+nextConnectBlockID+" ncpID:"+nextConnectPieceID;
		}
	}
}