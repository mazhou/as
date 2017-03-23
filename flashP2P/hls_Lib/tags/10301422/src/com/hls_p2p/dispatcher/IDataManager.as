package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Head;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.data.vo.PlayData;
	import com.hls_p2p.data.vo.ReceiveData;
	
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public interface IDataManager
	{
		function getDataTaskList():Object;
		function getPiece(data:Object):Piece;
		function getNextSeqID(seqID:Number):Block;
		/**获得blockid*/
		function getBlockId(blockId:Number):Number;

		/**写clip数据*/
		function  writeClipList(clipList:Vector.<Clip>):void;
		
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		function  getWantPiece(/*remoteHaveData:Array,*/farID:String/*,wantCount:int=3*/):Array;
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		function  getNearestWantID():Number;
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		function  getDataAfterPoint(groupID:String,id:Number):Array;
		/**根据id索引获得block*/
		function  getBlock(id:Number):Block;
		
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		function  handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void;
		function  doAddHave(groupID:String):void;
		function removeHaveData(tempEliminateArray:Array):void;
		function removePeerHaveData(peerID:String,peerRemoveDataArray:Array):void;
		function clear():void;
	}
}