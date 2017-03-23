package com.hls_p2p.dispatcher
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Head;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.PlayData;
	import com.hls_p2p.data.vo.ReceiveData;
	
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public interface IDataManager
	{
		function getTNRange(groupID:String):Array;
		function getPNRange(groupID:String):Array;
		function getDataTaskList():Object;
		function getPiece(data:Object):Piece;
		/**获得blockid*/
		function getBlockId(blockId:Number):Number;
		/**写clip数据*/
		function  writeClipList(clipList:Vector.<Clip>):void;
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		function  getNearestWantID(isPiece:Boolean=false):Number;
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		//function  getDataAfterPoint(groupID:String,id:Number):Array;
		/**根据id索引获得block*/
		function  getBlock(id:Number):Block;
		
		function clear():void;
		function getP2PTask(getP2PTask:Object):Object;
	}
}