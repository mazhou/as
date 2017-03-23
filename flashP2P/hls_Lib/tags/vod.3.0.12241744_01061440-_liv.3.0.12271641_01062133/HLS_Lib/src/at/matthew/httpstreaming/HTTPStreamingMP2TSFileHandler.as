/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the at.matthew.httpstreaming package.
 *
 * The Initial Developer of the Original Code is
 * Matthew Kaufman.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** */
 
 
package at.matthew.httpstreaming
{
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.getTimer;
	
	[Event(name="notifySegmentDuration", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]
	[Event(name="notifyTimeBias", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]	
	

	public class HTTPStreamingMP2TSFileHandler extends EventDispatcher
	{
		private var _syncFound:Boolean;
		private var _pmtPID:uint;
		private var _audioPID:uint;
		private var _videoPID:uint;
		private var _audioPES:HTTPStreamingMP2PESAudio;
		private var _videoPES:HTTPStreamingMP2PESVideo;
//		private var _doubleBuffer:ByteArray;
		private var _tmpInput:IDataInput;
		private var _cachedOutputBytes:ByteArray;
		private var alternatingYieldCounter:int = 0;
		
		private var endParse:Boolean = false;
		public function HTTPStreamingMP2TSFileHandler()
		{
			_audioPES = new HTTPStreamingMP2PESAudio;
			_videoPES = new HTTPStreamingMP2PESVideo;	
//			_doubleBuffer = new ByteArray();
			alternatingYieldCounter = 0;
		}
		
		public function beginProcessFile():void
		{
			_syncFound = false;
			endParse=false;
		}
		public function endProcessFile(input:IDataInput):ByteArray
		{
			endParse=true;
			
			if(_tmpInput && _tmpInput.bytesAvailable>0){(_tmpInput as ByteArray).clear()}
			_pmtPID = 0;
			_audioPES = null;
			_videoPES = null;
			
			_audioPES = new HTTPStreamingMP2PESAudio;
			_videoPES = new HTTPStreamingMP2PESVideo;
			return null;
		}
		public function get inputBytesNeeded():Number
		{
			//trace(this,"inputBytesNeeded");
			return _syncFound ? 187 : 1;
		}
		
		private var output:ByteArray = new ByteArray;
		private var packet:ByteArray = new ByteArray();

		public function processFileSegment(input:IDataInput):ByteArray
		{
			output.clear();
			var beginTime:Number = getTime();
			while (input.bytesAvailable > 187) 
			{
				if(endParse){
					(input as ByteArray).clear();
					break;
				}
				if(input.readByte() != 0x47)
				{
					continue;
				} 
				//
				if(input.bytesAvailable < 187)
					return output;
				
				//var packet:ByteArray = new ByteArray();
				packet.clear();
			
				input.readBytes(packet, 0, 187);
				
				var result:ByteArray = processPacket(packet);
				if (result !== null )
				{
					output.writeBytes(result);
				}
				
				if (getTime() - beginTime > 7) 
					return output;
				
			}
			//
			return output;
		}
			
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		private function processPacket(packet:ByteArray):ByteArray
		{
			// decode rest of transport stream prefix (after the 0x47 flag byte)
			
			// top of second byte
			var value:uint = packet.readUnsignedByte();
			
//			var tei:Boolean = Boolean(value & 0x80);	// error indicator
			var pusi:Boolean = Boolean(value & 0x40);	// payload unit start indication
//			var tpri:Boolean = Boolean(value & 0x20);	// transport priority indication
			
			// bottom of second byte and all of third
			value <<= 8;
			value += packet.readUnsignedByte();
			
			var pid:uint = value & 0x1fff;	// packet ID
			
			// fourth byte
			value = packet.readUnsignedByte();
			var scramblingControl:uint = (value >> 6) & 0x03;	// scrambling control bits
			var hasAF:Boolean = Boolean(value & 0x20);	// has adaptation field
			var hasPD:Boolean = Boolean(value & 0x10);	// has payload data
			var ccount:uint = value & 0x0f;		// continuty count
			
			// technically hasPD without hasAF is an error, see spec
			
			if(hasAF)
			{
				// process adaptation field

				var afLen:uint = packet.readUnsignedByte();
				
				// don't care about flags
				// don't care about clocks here
				
				packet.position += afLen;	// skip to end
			}
			
			if(hasPD)
			{
				return processES(pid, pusi, packet);
			}
			else
			{
				return null;
			}
		}
		
		private function processES(pid:uint, pusi:Boolean, packet:ByteArray):ByteArray
		{
			if(pid == 0)	// PAT
			{
				if(pusi)
					processPAT(packet);
				return new ByteArray();
			}
			else if(pid == _pmtPID)
			{
				if(pusi)
					processPMT(packet);
				return new ByteArray();
			}
			else if(pid == _audioPID)
			{
				return _audioPES.processES(pusi, packet);
			}
			else if(pid == _videoPID)
			{
				return _videoPES.processES(pusi, packet);
			}
			else
			{
				return new ByteArray();	// ignore all other pids
			}
		}
		
		private function processPAT(packet:ByteArray):void
		{
			var pointer:uint = packet.readUnsignedByte();
			var tableID:uint = packet.readUnsignedByte();
			
			var sectionLen:uint = packet.readUnsignedShort() & 0x03ff; // ignoring misc and reserved bits
			var remaining:uint = sectionLen;
			
			packet.position += 5; // skip tsid + version/cni + sec# + last sec#
			remaining -= 5;
			
			while(remaining > 4)
			{
				if(endParse){
					packet.clear();
					break;
				}
				
				packet.readUnsignedShort(); // program number
				_pmtPID = packet.readUnsignedShort() & 0x1fff; // 13 bits
				remaining -= 4;
				
				//return; // immediately after reading the first pmt ID, if we don't we get the LAST one
			}
			
			// and ignore the CRC (4 bytes)
		}
		
		private function processPMT(packet:ByteArray):void
		{
			var pointer:uint = packet.readUnsignedByte();
			var tableID:uint = packet.readUnsignedByte();
			
			if (tableID != 0x02)
			{
				//trace("PAT pointed to PMT that isn't PMT");
				return; // don't try to parse it
			}
			var sectionLen:uint = packet.readUnsignedShort() & 0x03ff; // ignoring section syntax and reserved
			var remaining:uint = sectionLen;
			
			packet.position += 7; // skip program num, rserved, version, cni, section num, last section num, reserved, PCR PID
			remaining -= 7;
			
			var piLen:uint = packet.readUnsignedShort() & 0x0fff;
			remaining -= 2;
			
			packet.position += piLen; // skip program info
			remaining -= piLen;
			
			while(remaining > 4)
			{
				if(endParse){
					packet.clear();
					break;
				}
				var type:uint = packet.readUnsignedByte();
				var pid:uint = packet.readUnsignedShort() & 0x1fff;
				var esiLen:uint = packet.readUnsignedShort() & 0x0fff;
				remaining -= 5;
				
				packet.position += esiLen;
				remaining -= esiLen;
				
				switch(type)
				{
					case 0x1b: // H.264 video
						_videoPID = pid;
						break;
					case 0x0f: // AAC Audio / ADTS
						_audioPID = pid;
						break;
				
					// need to add MP3 Audio  (3 & 4)
					default:
						//trace("unsupported type "+type.toString(16)+" in PMT");
						break;
				}
			}
			
			// and ignore CRC
		}
		
		public function flushFileSegment(input:IDataInput):ByteArray
		{
			//trace(this,"flushFileSegment");
			var flvBytes:ByteArray;
			flvBytes = new ByteArray();
			var flvBytesVideo:ByteArray = null;
			var flvBytesAudio:ByteArray = null;
			

			flvBytesVideo = _videoPES.processES(false, null, true);

			flvBytesAudio = _audioPES.processES(false, null, true);
		
			
			if(flvBytesVideo)
				flvBytes.readBytes(flvBytesVideo);
			if(flvBytesAudio)
				flvBytes.readBytes(flvBytesAudio);
			
			return flvBytes;
		}
	}
}
