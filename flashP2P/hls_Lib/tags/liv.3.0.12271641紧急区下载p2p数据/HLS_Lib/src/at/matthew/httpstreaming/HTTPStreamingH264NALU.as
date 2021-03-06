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
	import flash.utils.ByteArray;
	
	public class HTTPStreamingH264NALU
	{
		private var data:ByteArray;
		
		public function HTTPStreamingH264NALU(source:ByteArray):void
		{
			data = source;
		}
		
		public function get NALtype():uint
		{
			return data[0] & 0x1f;
		}
		
		public function get length():uint
		{
			return data.length;
		}
		
		public function get NALdata():ByteArray
		{
			return data;
		}

	}
}