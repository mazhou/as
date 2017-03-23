package com.p2p.utils
{
	import flash.external.ExternalInterface;
	import flash.system.Capabilities;
	
	public class GetLocationParam
	{
		protected static var playerType:String = Capabilities.playerType;
		protected static var fileTitle:String = "";
		protected static var fileLocation:String = "";
		
		public static function GetBrowseLocationParams():Object
		{
			if (playerType == "ActiveX" || playerType == "PlugIn") {
				if (ExternalInterface.available) {
					try {
						var tmpLocation:String = ExternalInterface.call("window.location.href.toString");
						var tmpTitle:String = ExternalInterface.call("window.document.title.toString");
						if (tmpLocation != null) fileLocation = tmpLocation;
						if (tmpTitle != null) fileTitle = tmpTitle;
						
						if (fileTitle == "" && fileLocation != "") {
							var slash:int = Math.max(fileLocation.lastIndexOf("\\"), fileLocation.lastIndexOf("/"));
							if (slash != -1) {
								fileTitle = fileLocation.substring(slash + 1, fileLocation.lastIndexOf("."));
							} else {
								fileTitle = fileLocation;
							}
						}
						
						return {"type":playerType,"title":fileTitle,"location":fileLocation}
					} catch (e2:Error) {
						// External interface FAIL
					}
				}
			}
			return null;
		}
		
	}
}