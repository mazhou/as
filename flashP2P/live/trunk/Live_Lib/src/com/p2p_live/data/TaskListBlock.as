package com.p2p_live.data
{
	public class TaskListBlock
	{
		/**文件名*/
		public var name:String;
		/**数据块验证码*/
		public var checksum:uint;
		/**播放时长（毫秒）*/		
		public var duration:Number;
		/**文件大小（字节）*/
		public var size:Number;
		/**是否开始预加载下一分钟数据*/
		public var needNextMinDesc:Boolean;
		
		public var creatTime:Number=0;
		/**
		 * 保存每个下载任务数据块的基本信息 ：
		 * name; checksum; duration; size; needNextMinDesc
		 * 
		 */		
		public function TaskListBlock()
		{
		}
	}
}