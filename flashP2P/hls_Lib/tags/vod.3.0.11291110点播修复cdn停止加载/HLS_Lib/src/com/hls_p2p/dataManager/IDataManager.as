package com.hls_p2p.dataManager
{
	import com.hls_p2p.data.Block;
//	import com.hls_p2p.data.Head;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public interface IDataManager
	{
		function getP2PTask(getP2PTask:Object):Object;
		function getTNRange(groupID:String):Array;
		function getPNRange(groupID:String):Array;
		function getDataTaskList():Object;
		function getPiece(data:Object):Piece;
		function getM3U8Task():Object;

		function clear():void;
		
		/**获得blockid*/
		function getBlockId(blockId:Number):Number;
		
		/**写clip数据*/
		function  writeClipList(clipList:Vector.<Clip>):void;
		
		/**根据id索引获得block*/
		function getBlock(id:Number):Block;
		function getNextBlock(p_curid:Number,p_id:Number):Block;

		function clearIsLoaded(CDNTaskPieceList:Array):void;
		function getCDNRandomTask():Block;
		/**获得决策表*/
		function getCDNTaskPieceList():Array;
		function startm3u8loader(p_initData:InitData):void;
	}
}