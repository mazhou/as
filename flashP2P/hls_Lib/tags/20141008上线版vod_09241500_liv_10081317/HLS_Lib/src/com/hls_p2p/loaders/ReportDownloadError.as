package com.hls_p2p.loaders
{
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.p2p.utils.console;
	import com.p2p.utils.TimeTranslater;
	
	public class ReportDownloadError
	{
		private var _initData:InitData;
		
		private var _playingBlockID:Number = -1;
		private var _playingPieceID:Number = -1;
		
		private var _tsStartTime:Number   = -1;
		private var _m3u8StartTime:Number = -1;
		private var _tsOverTime:Number    = 15*1000;
		private var _m3u8OverTime:Number  = 15*1000;
		
		private var _tsFailedCount:int    = 0;
		private var _m3u8FailedCount:int  = 0;
		private var _tsMaxFailed:int  	  = 3;
		private var _m3u8MaxFailed:int 	  = 3;
		
		public function ReportDownloadError(initData:InitData)
		{
			_initData = initData;
		}

		public function reset():void
		{
			_playingBlockID	  = 0;
			_playingPieceID   = 0;

			_tsStartTime      = -1;
			_m3u8StartTime 	  = -1;
			_tsFailedCount     = 0;
			_m3u8FailedCount   = 0;
		}
		
		public function clear():void
		{
			_initData = null;
			reset();
		}
		
		public function startDownloadTS(bID:Number,pID:Number):void
		{
			if( bID == LiveVodConfig.BlockID
				&& pID == LiveVodConfig.PieceID )
			{
				if( _playingBlockID != LiveVodConfig.BlockID
					|| _playingPieceID != LiveVodConfig.PieceID )
				{
					//当开始下载播放点数据，并且是第一次下载时
					_tsStartTime 	= getTime();
					_tsFailedCount  = 0;
					_playingBlockID = LiveVodConfig.BlockID;
					_playingPieceID = LiveVodConfig.PieceID;
				}
			}
		}
		
		public function startDownloadM3U8():void
		{
			if( LiveVodConfig.TYPE != LiveVodConfig.LIVE
				&& _m3u8StartTime == -1
				&& false == _initData.g_bVodLoaded )
			{
				_m3u8StartTime = getTime();
			}
		}
		
		public function tsDownloadSuccess():void
		{
			_tsStartTime = -1;
			_tsFailedCount = 0;
		}
		
		public function m3u8DownloadSuccess():void
		{
			_m3u8StartTime = -1;
			_m3u8FailedCount = 0;
		}
		
		public function downloadTSFailed(bID:Number,pID:Number):void
		{
			console.log(this,"LiveVodConfig.BlockID = "+LiveVodConfig.BlockID+", bID = "+bID);
			console.log(this,"LiveVodConfig.PieceID = "+LiveVodConfig.PieceID+", pID = "+pID);
			
			if( _playingBlockID == LiveVodConfig.BlockID
				&& _playingPieceID == LiveVodConfig.PieceID )
			{
				if( LiveVodConfig.BlockID == bID 
					&& LiveVodConfig.PieceID == pID )
				{
					console.log(this,"LiveVodConfig.BlockID = "+LiveVodConfig.BlockID);
					console.log(this,"LiveVodConfig.PieceID = "+LiveVodConfig.PieceID);
					_tsFailedCount++;
				}
			}
			else
			{
				if( LiveVodConfig.BlockID == bID 
					&& LiveVodConfig.PieceID == pID )
				{
					_tsFailedCount++;
				}
				/*else
				{
					console.log(this,"_pieceFailedCount = 0 LiveVodConfig.BlockID = "+LiveVodConfig.BlockID);
					console.log(this,"_pieceFailedCount = 0 LiveVodConfig.PieceID = "+LiveVodConfig.PieceID);
					_tsFailedCount = 0;
				}*/
				_playingBlockID = LiveVodConfig.BlockID;
				_playingPieceID = LiveVodConfig.PieceID;				
			}
		}
		
		public function downloadM3U8Failed():void
		{
			_m3u8FailedCount++;
		}

		public function whichDownloadError():String
		{
			if( isReportM3U8Failed() )
			{
				return "m3u8";
			}
			else if( isReportTSFailed() )
			{
				return "ts";
			}
			return "";
		}
		
		public function isReportTSFailed():Boolean
		{
			if( _tsStartTime > -1
				&& (getTime() - _tsStartTime > _tsOverTime)
				&& _tsFailedCount >= 3 )
			{
				return true;
			}
			return false;
		}
		
		public function isReportM3U8Failed():Boolean
		{
			if( _m3u8StartTime > -1
				&& (getTime() - _m3u8StartTime > _m3u8OverTime)
				&& _m3u8FailedCount >= 3 )
			{
				return true;
			}
			return false;
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}