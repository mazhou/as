package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.data.vo.Piece;
	import com.hls_p2p.dispatcher.IDataManager;
	
	
	
	public class VodStreamLoader extends StreamLoader implements IStreamLoader
	{
	
		public function VodStreamLoader(_dispather:IDataManager)
		{
			super(_dispather);
		}
		
		override protected function getDownloadPieceContentTask(_task:Block,p_vecPieces:Vector.<Piece>,pieceId:int=-1):String
		{
			return "";
			startDownloadPieceIdx 		= -1;
			endDownloadPieceIdx   		= -1;
			startLoadTime         		= -1;
			endLoadTime           		= -1;
			needDownloadBytesLength 	= -1;
					
			var startByte:Number 		= -1;
			var endByte:Number   		= -1;
			
			for(var i:int = 0 ; i<_task.pieces.length ; i++)
			{
				if( _task.pieces[i].isChecked == false && _task.pieces[i].iLoadType != 1)
				{
					_task.pieces[i].iLoadType = 1;
					if( startByte == -1)
					{
						//startByte = LiveVodConfig.CLIP_INTERVAL*i;
						startByte = CalculatePieceStart(_task,i);
						startDownloadPieceIdx = i;
					}
					
					endDownloadPieceIdx = i;
					
					endByte = CalculatePieceEnd(_task,i);	
					needDownloadBytesLength = endByte-startByte+1;	

					if( i== _task.pieces.length-1)
					{
						//如果是最后一个piece
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
					p_vecPieces.push(_task.pieces[i]);
				}
				else
				{
					if(startByte != -1 && endByte != -1)
					{
						if(url.indexOf("?")>0)
						{
							return String("&rstart="+startByte+"&rend="+endByte);
						}
						else
						{
							return String("?rstart="+startByte+"&rend="+endByte);
						}
					}					
				}
			}
			return null;
		}
		
		private function CalculatePieceStart(p_block:Block,p_nIdx:Number):Number
		{
			return 0;
			var nStartPos:Number = 0;
			
			for(var i:int = 0 ; i< p_nIdx; i++)
			{
				nStartPos += p_block.pieces[i].size;
			}
			return nStartPos;
		}
		
		private function CalculatePieceEnd(p_block:Block,p_nIdx:Number):Number
		{
			return 0;
			var nEndPos:Number = 0;
			
			for(var i:int = 0 ; i<= p_nIdx; i++)
			{
				nEndPos += p_block.pieces[i].size;
			}
			nEndPos -= 1;
			return nEndPos;
		}
		
	}
}