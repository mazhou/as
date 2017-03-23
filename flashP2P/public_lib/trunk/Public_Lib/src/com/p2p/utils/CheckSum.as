package com.p2p.utils
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	public class CheckSum
	{
		
		private  const step:int = 47;
		public function checkSum(input:ByteArray):uint
		{
			input.position = 0;
			input.endian = Endian.BIG_ENDIAN;
			var  sum:uint = 0xffffffff, pos:int = 0;

			if( input.bytesAvailable >= 188 )
			{
				input.position += 4;
				while( input.bytesAvailable > step)
				{
					/*sum ^= (input.readUnsignedByte() << 24) + (input.readUnsignedByte() << 16) +  (input.readUnsignedByte() << 8) + input.readUnsignedByte();*/
					sum ^= input.readUnsignedInt();
					input.position += (step-4);
				}
			}
			sum  = ((sum >> 16) & 0xffff) + (sum & 0xffff);
			return (~sum & 0xffff);
		}
	}
}