package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.vo.InitData;

	public interface IDescLoader
	{
		function start( _initData:InitData):void;
		function clear():void;
	}
}