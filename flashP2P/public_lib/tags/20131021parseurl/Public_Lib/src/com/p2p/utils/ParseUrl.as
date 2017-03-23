package com.p2p.utils
{
	public class ParseUrl
	{
		/**{protocol,hostName,path,query,fragment}*/
		public static  function parseUrl(tempUrl:String):Object
		{
			var pattern:RegExp = /^([a-z+\w\+\.\-]+:\/?\/?)?([^\/?#]*)?(\/[^?#]*)?(\?[^#]*)?(\#.*)?/i;		
			var result:Array = tempUrl.match(pattern);
			
			if (result != null)
			{
				//protocol = result[1];
				//hostName = result[2];
				//path = result[3];
				//query = result[4];
				//fragment = result[5];
				//去掉后缀名
				var objUrl:Object = new Object;
				
				objUrl.protocol = result[1];
				objUrl.hostName = result[2];
				objUrl.path = result[3];
				objUrl.query = result[4];
				objUrl.fragment = result[5];
				
				return objUrl;
			}
			return null;
		}
	}
}