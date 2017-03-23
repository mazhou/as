// ActionScript file
package com.p2p.utils.httpSocket
{
	public class HttpSocketUtil
	{
		/*
		* 头的限制类型
		*/
		private static const headLimitArr:Array = ["Host","Accept"];
		
		
		
		/*
		* 向socket模拟的Http访问头中加入类型
		* Params Describe:
		* type : header Name
		* value : header Value
		* 用于验证加入的httpHeader的类型和值是否合理
		*/		
		public static function checkAddItem(type:String,value:String):Boolean
		{
			try
			{
				if(type==null || type=="")return false;
				if(value==null || value=="")return false;	
				for(var i:int=0;i<headLimitArr.length;i++){
					var typeValue:String = headLimitArr[i];
					if(typeValue == type)return false;
				}
				return true;
			}catch(e:Error){				
			}
			return false;
		}
	}
}