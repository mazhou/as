package
{
	import com.hls_p2p.stream.HTTPNetStream;
	
	import flash.net.NetStream;
	
	import flash.display.Sprite;
	import flash.system.Security;
	
	public class MLPLetvPlayer extends Sprite
	{
		private var object:*;
		
		public function MLPLetvPlayer()
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
			object = new HTTPNetStream({"playType":"LIVE"});
			return object as NetStream;
		}
	}
}