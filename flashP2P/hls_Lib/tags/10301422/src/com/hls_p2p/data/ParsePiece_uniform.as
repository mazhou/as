package com.hls_p2p.data
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.p2p.utils.ParseUrl;
	
	public class ParsePiece_uniform
	{
		public function ParsePiece_uniform()
		{
		}
		public function parseInfo(arr:Array,groupID:String,_pieceList:Object,pieceIdxArray:Array,block:Block):void
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
			for(i=0;i<arr.length;i++)
			{
				tempPiece 			= new Piece();
				tempPiece.id       	= i;
				tempPiece.groupID  	= groupID;
				tempPiece.checkSum	= ParseUrl.getParam(String(arr[i]),"CKS");
				tempPiece.size		= int(ParseUrl.getParam(String(arr[i]),"SZ"));
				tempPiece.type		= (String(arr[i]).indexOf("PN") > -1)?"PN":((String(arr[i]).indexOf("TN") > -1)?"TN":"");
				tempPiece.pieceKey	=  ParseUrl.getParam(String(arr[i]),tempPiece.type);
				if(LiveVodConfig.TYPE == LiveVodConfig.LIVE)
				{
					tempPiece.isLoad	= Math.random() < LiveVodConfig.DAT_LOAD_RATE?true:false;
				}
				tempPiece.block		=  block;
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
				}
			}
		}
	}
}