package com.p2p.dataManager
{
	import com.p2p.data.Block;
	import com.p2p.data.Head;
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.PlayData;
	import com.p2p.data.vo.ReceiveData;
	
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public interface IDataManager
	{
		function getDataTask():Block;
		function getNextSeqID(seqID:Number):Block;
		/**获得blockid*/
		function getBlockId(blockId:Number):Number;
		function setPlayingBlockID(id:Number):void;
		
		function getHeadTask():Head;
		
		/**读取字节*/
		function  getHead(blockId:Number):Head;
		/**添加字节*/
		//function  addByte(_blockID:Number=0,_pieceID:int=0,data:ByteArray=null,begin:Number=0,end:Number=0,from:String="",remoteName:String=""):void;
		function addByte(data:ReceiveData):void;
		/**写clip数据*/
		function  writeClipList(clipList:Vector.<Clip>,isMinEnd:Boolean):void;
//		/**blocklist的最小分钟数*/
//		function  headTimestamp():Number;
		/**是否本时间戳所在的分钟加载过*/
		function getDescTask():Number;
		/**遍历区间段所包含的piece，找到本地所需的wantCount数量的piece*/
		function  getWantPiece(/*remoteHaveData:Array,*/farID:String/*,wantCount:int=3*/):Array;
		/**获得播放点之后最近的需要加载数据的索引“block_Piece”*/
		function  getNearestWantID():Number;
		/**获得id索引值之后有流的数据列表,暂时传入blockID*/
		function  getDataAfterPoint(id:Number):Array;
		/**根据id索引获得block*/
		function  getBlock(id:Number):Block;
		/**清理P2P任务超时或对方节点不提供数据分享而释放p2p任务*/
		function  handlerTimeOutWantPiece(farID:String, blockID:Number, pieceID:int):void;
		function  doAddHave():void;
		
		function  sendData(data:Object,peerID:String):void;
		function getPlayingBlockID():Number;
//		function SetMaxBlockID(maxID:Number, isReset:Boolean = false):void;
		function getMaxHttpPos():Number;
		function clear():void;
	}
}