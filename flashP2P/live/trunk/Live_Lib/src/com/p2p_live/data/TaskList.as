package com.p2p_live.data
{
	public class TaskList
	{
		/**
		 * 存放视频文件头信息的地址数组 
		 */		
		public var headerArr:Array;
		/**
		 * 存放视频数据块地址的对象
		 */	
		public var blockObj:Object;
		/**
		 * TaskList为构造函数，初始化文件头信息的地址数组headerArr和数据块地址的对象blockObj
		 * 
		 */		
		public function TaskList()
		{
			clear();
		}
		/**
		 * 返回下一个加载任务的索引
		 * 
		 */
		public function getNextTaskID(curIndex:uint):uint
		{
			var nextIndex:uint = uint.MAX_VALUE;
			for(var index:String in blockObj)
			{
				if(uint(index) > curIndex && uint(index) < nextIndex)
				{
					nextIndex = uint(index);
				}
			}
			
			if(nextIndex == uint.MAX_VALUE)
			{
				//当前已无最新的数据块
				return curIndex;
			}
			return nextIndex;
		}
		/**
		 * 清空 headerArr 和 blockObj
		 * 
		 */		
		public function clear():void
		{
			headerArr = new Array();
			blockObj  = new Object();
		}
	}
}