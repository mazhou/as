package
{
	import com.p2p.stream.P2PNetStream;
	
	import flash.net.NetStream;
	
	import flash.display.Sprite;
	import flash.system.Security;
	
	public class FLPLetvPlayer extends Sprite
	{
		private var object:*;
		public function FLPLetvPlayer()
		{
			Security.allowDomain("*");
			Security.allowInsecureDomain("*");
		}
		public function create():NetStream
		{
			if(object)
			{
				object = null
			}
			object = new P2PNetStream();
			return object;
		}
	}
}