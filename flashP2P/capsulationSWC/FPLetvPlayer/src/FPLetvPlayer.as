package
{
	import com.p2p.core.P2PNetStream;
	
	import flash.net.NetStream;
	
	import flash.display.Sprite;
	import flash.system.Security;

	public class FPLetvPlayer extends Sprite
	{
		private var object:*;
		public function FPLetvPlayer()
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
			object = new P2PNetStream();
			return object;
		}
	}
}