package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDispatcher;
	import com.hls_p2p.data.vo.Piece;
	
	public class LiveStreamLoad extends StreamLoader implements IStreamLoader
	{
		public function LiveStreamLoad(_dispather:IDispatcher)
		{
			super(_dispather);
		}
		
		override protected function getDownloadPieceTaskRange(_task:Block,pieceId:int=-1):String
		{
			return "";
			startDownloadPieceIdx = -1;
			endDownloadPieceIdx   = -1;
			startLoadTime         = -1;
			endLoadTime           = -1;
			needDownloadBytesLength = -1;
			
			if(pieceId!=-1)
			{
				/**只下载该block中的一个piece*/
				startDownloadPieceIdx = endDownloadPieceIdx   = pieceId;
				needDownloadBytesLength=_task.getPiece(pieceId).size;
				return String("&rstart="+pieceId*LiveVodConfig.CLIP_INTERVAL+"&rend="+(pieceId*LiveVodConfig.CLIP_INTERVAL+_task.getPiece(pieceId).size-1)); 
			}
			
			var startByte:Number = -1;
			var endByte:Number   = -1;
			for(var i:int = 0 ; i<_task.pieces.length ; i++)
			{
				if( _task.pieces[i].isChecked == false && _task.pieces[i].iLoadType != 1)
				{
					_task.pieces[i].iLoadType = 1;
					if( startByte == -1)
					{
						startByte = LiveVodConfig.CLIP_INTERVAL*i;
						startDownloadPieceIdx = i;
					}
					
					endDownloadPieceIdx = i;
					
					if(i != _task.pieces.length-1)
					{
						endByte = LiveVodConfig.CLIP_INTERVAL*(i+1)-1;	
						needDownloadBytesLength = endByte-startByte+1;					
					}else
					{
						//如果是最后一个piece
						endByte = _task.size - 1;
						needDownloadBytesLength = endByte-startByte+1;
						if(startByte == 0)
						{		
							//当整个Task都需要加载时
							return "";								
						}else
						{
							if(url.indexOf("?")>0)
							{
								return String("&rstart="+startByte+"&rend="+endByte);
							}
							return String("?rstart="+startByte+"&rend="+endByte);
						}						
					}					
				}
				else
				{
					if(startByte != -1 && endByte != -1)
					{
						if(url.indexOf("?")>0)
						{
							return String("&rstart="+startByte+"&rend="+endByte);
						}
						return String("?rstart="+startByte+"&rend="+endByte);
					}					
				}
			}
			return null;
		}
		
		override protected function getDownloadPieceContentTask(_task:Block,p_vecPieces:Vector.<Piece>,pieceId:int=-1):String
		{
			return "";
		}
	}
}