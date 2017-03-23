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
		function getP2PTask(getP2PTask:Object):Object;
		function getTNRange(groupID:String):Array;
		function getPNRange(groupID:String):Array;
		function getDataTaskList():Object;
		function getPiece(data:Object):Piece;
		function clear():void;
		
		/**获得blockid*/
		function getBlockId(blockId:Number):Number;
		
		/**写clip数据*/
		function  writeClipList(clipList:Vector.<Clip>):void;
		
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		function  getNearestWantID(isPiece:Boolean=false):Number;
		
		/**根据id索引获得block*/
		function  getBlock(id:Number):Block;
		
		
		
	}
}