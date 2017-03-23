package com.hls_p2p.data
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.logs.P2PDebug;
	import com.p2p.utils.ParseUrl;
	
	public class ParsePiece_uniform
	{
		public var isDebug:Boolean		= false;
		private var _blockList:BlockList;
		public function ParsePiece_uniform(_blockList:BlockList)
		{
			this._blockList = _blockList;
		}
		public function parseInfo(arr:Array,groupID:String,_pieceList:Object,pieceIdxArray:Array,blockID:Number):void
		{
			/**
			 * arr = [
			 "TN=3&KEY=3&SZ=752&CKS=2912787187",
			 "PN=11&SZ=192512&CKS=4116794179",
			 "PN=12&SZ=192512&CKS=1206932452",
			 "PN=13&SZ=178976&CKS=1764064266",
			 "PN=14&SZ=192512&CKS=884408100"
			  ]
			 * */
			var i:uint = 0;
			var tempPiece:Piece = null;
			var debugMsg:String = "";
			for(i=0;i<arr.length;i++)
			{
				tempPiece 			= new Piece(_blockList);
				tempPiece.id       	= i;
				tempPiece.groupID  	= groupID;
				
				/*tempPiece.blockID  	= blockID;*/
				
				tempPiece.checkSum	= ParseUrl.getParam(String(arr[i]),"CKS");
				tempPiece.size		= int(ParseUrl.getParam(String(arr[i]),"SZ"));
				if( tempPiece.size == 0 )
				{
					tempPiece.from = "http";
					tempPiece.isChecked = true;
					tempPiece.iLoadType = 3;
				}
				tempPiece.type		= (String(arr[i]).indexOf("PN") > -1)?"PN":((String(arr[i]).indexOf("TN") > -1)?"TN":"");
				tempPiece.pieceKey	=  ParseUrl.getParam(String(arr[i]),tempPiece.type);
				
				
				if(!_pieceList)
				{
					_pieceList = new Object;
				}
				if(_pieceList[tempPiece.groupID ] == null)
				{
					_pieceList[tempPiece.groupID ] = new Object;
				}
				if(_pieceList[tempPiece.groupID ][tempPiece.type] == null)
				{
					_pieceList[tempPiece.groupID ][tempPiece.type] = new Object;
				}
				if(_pieceList[tempPiece.groupID ][tempPiece.type][tempPiece.pieceKey] == null)
				{
//					tempPiece.mapBlock(block);
					tempPiece.blockIDArray.push(blockID);
					
					if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
					{
						tempPiece.isLoad	= Math.random() < LiveVodConfig.DAT_LOAD_RATE?true:false;
						if( true == tempPiece.isLoad )
						{							
							_blockList.CDNIsLoadPieceArr.push({"piece":tempPiece,"blockID":blockID});
						}
					}
					
					/**添加总列表*/
					_pieceList[tempPiece.groupID ][tempPiece.type][tempPiece.pieceKey] = tempPiece;
					/**添加所在block的pieceIdxArray列表*/
					pieceIdxArray.push(
						{	
							"groupID":tempPiece.groupID,
							"type":tempPiece.type,
							"pieceKey":tempPiece.pieceKey
						}
					)
					if( 0==i || 1==i || i == arr.length-1 )
					{
						debugMsg += i+" key:"+tempPiece.pieceKey+" bID:"+blockID+" type:"+tempPiece.type+"\n";
					}
				}
				else
				{
					if( -1 == _pieceList[tempPiece.groupID ][tempPiece.type][tempPiece.pieceKey].blockIDArray.indexOf(blockID) )
					{
						_pieceList[tempPiece.groupID ][tempPiece.type][tempPiece.pieceKey].blockIDArray.push(blockID);
						pieceIdxArray.push(
							{	
								"groupID":tempPiece.groupID,
								"type":tempPiece.type,
								"pieceKey":tempPiece.pieceKey
							}
						)
					}
				}
			}
			P2PDebug.traceMsg(this,"emptyPiece:\n"+debugMsg);
		}
	}
}