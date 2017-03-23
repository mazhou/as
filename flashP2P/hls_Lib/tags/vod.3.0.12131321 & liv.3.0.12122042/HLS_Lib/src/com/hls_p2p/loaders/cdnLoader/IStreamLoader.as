package com.hls_p2p.loaders.cdnLoader
{
	import com.hls_p2p.data.vo.InitData;
	public interface IStreamLoader
	{
		function start( _initData:InitData):void;
		function clear():void;
	}
}