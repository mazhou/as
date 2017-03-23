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
//				var queryReg:RegExp=/(\w+)=(\w+)/ig;
//				var obj:Object=null;
//				if(queryReg.test(result[4]))
//				{
//					var arr:Array=result[4].match(queryReg);
//					for(var i:* in arr)
//					{
//						if(obj==null){obj=new Object;}
//						obj[arr[i].split("=")[0]]=arr[i].split("=")[1];
//					}
//				}
//				if(obj==null){
//					objUrl.query = obj;
//				}else
//				{
					objUrl.query = result[4];
//				}
				objUrl.fragment = result[5];
				
				return objUrl;
			}
			return null;
		}
		public static function getParam(url:String,key:String):String
		{
			var reg:RegExp=new RegExp("\[?&]?"+key+"=(\\w{0,})?", "");
			var param:String="";
			if(reg.test(url))
			{
				param=url.match(reg)[1];
			}
			return param;
		}
				
		public static function replaceParam(URL:String,key:String,value:String):String
		{
			var reg:RegExp=new RegExp("\[?&]"+key+"=(\\w{0,})?", "");
			var findStr:String="";
			
			if(reg.test(URL))
			{
				findStr=URL.match(reg)[0];
			}
			
			if(URL.indexOf("?") == -1)
			{
				URL = URL+("?"+key+"="+value);
			}
			else if(findStr.length>0)
			{
				URL=URL.replace(findStr,findStr.charAt(0)+key+"="+value);
			}
			else if(findStr.length == 0 )
			{
				URL=URL+"&"+key+"="+value;
			}
			return URL;
		}
		
		public static function replaceParamAndKey(URL:String,org_key:String,dest_Key:String,value:String):String
		{
			var reg:RegExp=new RegExp("\[?&]"+org_key+"=(\\w{0,})?", "");
			var findStr:String="";
			
			if(reg.test(URL))
			{
				findStr=URL.match(reg)[0];
			}
			
			if( findStr.length > 0 )
			{
				if( findStr.indexOf("?")>=0 )
				{
					URL=URL.replace(findStr,"");
					
					if( URL.indexOf("&")>=0 )
					{
						URL = URL.replace( URL.charAt(URL.indexOf("&")),"?" );
					}
				}else
				{	
					URL=URL.replace(findStr,"");
				}
			}
			
			URL=replaceParam( URL, dest_Key, value );
			return URL;
		}
	}
}