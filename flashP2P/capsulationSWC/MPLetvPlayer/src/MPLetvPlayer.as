package
{
	import com.hls_p2p.stream.HTTPNetStream;
	
	import flash.net.NetStream;
	
	import flash.display.Sprite;
	import flash.system.Security;
	
	public class MPLetvPlayer extends Sprite
	{
		private var object:*;
		
		public function MPLetvPlayer()
		{
			Security.allowDomain("*");
			Security.allowInsecureDomain("*");
		}
		public function create():NetStream
		{
			if(object)
			{
				object.close();
				object = null;
			}
			
			
			object = new HTTPNetStream({"playType":"VOD"});
			return object as NetStream;
		}
	}
}