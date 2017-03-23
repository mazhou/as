package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.LIVE_TIME;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.logs.P2PDebug;
	import com.p2p.utils.ParseUrl;

	public class ParseM3U8_uniform
	{
		public var isDebug:Boolean					= false;
		private var fileTotalSize:Number			= 0;	
		private static var stic_nClipid:Number 		= 0;
		private var bCallFunc:Boolean				= true;
		
		public var groupID:String					= "";
		public var width:Number						= 0;
		public var height:Number					= 0;
		public var totalDuration:Number				= 0;
		
		public function parseFile(file:String,_initData:InitData,p_fun:Function):void
		{
			var EXT_LETV_M3U8_VER:String = "";
			
			var objParse:Object={"fileMSG":new Object,"dataMSG":new Object};
			file=file.replace(/\r/g,"");
			//TTT
			P2PDebug.traceMsg( this,"\r\n" + file );
			
			var reg:RegExp = /(\.ts\S{0,})\n/ig;
			file=file.replace(reg,rebackStr);
			
			var tsList:Array = file.split("~_~");
			var i:uint = 0;
			var j:uint = 0;
			var _clip:Clip;
			var _fileHead:Object = new Object;
			var _tmpFileItem:Object;
			var _clipList:Vector.<Clip> = new Vector.<Clip>;

			// 不解析最后一块，因为是endlist，可以添加错误处理
			for( i=0; i < tsList.length; i++ )
			{
				var lines:Array = (tsList[i]).split("\n");
				_clip = new Clip;
				
				if( 0 != i )
				{
					for( j=0; j<lines.length; j++ )
					{
						if( lines[j].length <= 0 )
						{
							continue;
						}
						//
						_tmpFileItem = parseData(lines[j]);
						
						if( _tmpFileItem && _tmpFileItem.hasOwnProperty("key") )
						{
							if( _tmpFileItem["key"] != "" )
							{
								if( _tmpFileItem["key"] == "pieceInfoArray" )
								{
									_clip.pieceInfoArray.push(_tmpFileItem["value"]);
									continue;
								}
								_clip[_tmpFileItem["key"]]=_tmpFileItem["value"];
								
								if( _tmpFileItem["key"] == "timestamp" )
								{
									if( this.hasOwnProperty("DESC_LASTSTARTTIME") )
									{
										this["DESC_LASTSTARTTIME"] = _tmpFileItem["value"];
									}
								}
								else if( _tmpFileItem["key"] == "url_ts" )
								{
									_clip.name = GetNameKey( _tmpFileItem["value"] );
								}
							}
							continue;
						}
						//
						_tmpFileItem = parseProgram(lines[j]);
						
						if( _tmpFileItem && _tmpFileItem.hasOwnProperty("key") )
						{
							if( _tmpFileItem["key"] != "" )
							{
								if( LiveVodConfig.TYPE == LiveVodConfig.VOD && this.hasOwnProperty(_tmpFileItem["key"]) )
								{
									this[_tmpFileItem["key"]]=_tmpFileItem["value"];
								}
								else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE 
									&& this.hasOwnProperty(_tmpFileItem["key"]) 
									&& _tmpFileItem["key"] != "totalDuration" )
								{
									this[_tmpFileItem["key"]]=_tmpFileItem["value"];
								}	
							}
							continue;
						}
					}
				}
				else if( 0 == i )
				{
					for( j=0; j<lines.length; j++ )
					{
						if( lines[j].length <= 0 )
						{
							continue;
						}
						
						_tmpFileItem = parseFileHead(lines[j]);
						
						if( _tmpFileItem && _tmpFileItem.hasOwnProperty("key") )
						{
							if( _tmpFileItem["key"] != "" )
							{
								if( _tmpFileItem["key"] == "EXT_LETV_M3U8_VER" )
								{
									EXT_LETV_M3U8_VER = _tmpFileItem["value"];
								}
							}
							continue;
						}
						
						_tmpFileItem = parseProgram(lines[j]);
						
						if( _tmpFileItem && _tmpFileItem.hasOwnProperty("key") )
						{
							if( _tmpFileItem["key"] != "" )
							{
								if( LiveVodConfig.TYPE == LiveVodConfig.VOD && this.hasOwnProperty(_tmpFileItem["key"]) )
								{
									this[_tmpFileItem["key"]]=_tmpFileItem["value"];
								}
								else if( LiveVodConfig.TYPE == LiveVodConfig.LIVE 
									&& this.hasOwnProperty(_tmpFileItem["key"]) 
									&& _tmpFileItem["key"] != "totalDuration" )
								{
									this[_tmpFileItem["key"]]=_tmpFileItem["value"];
								}
							}
							continue;
						}
						
						_tmpFileItem = parseData(lines[j]);
						
						if( _tmpFileItem && _tmpFileItem.hasOwnProperty("key") )
						{
							if( _tmpFileItem["key"] != "" )
							{
								if( _tmpFileItem["key"] == "pieceInfoArray" )
								{
									_clip.pieceInfoArray.push(_tmpFileItem["value"]);
									continue;
								}
								_clip[_tmpFileItem["key"]]=_tmpFileItem["value"];

								if( _tmpFileItem["key"] == "timestamp" )
								{
									if( stic_nClipid == 0 )
									{
										stic_nClipid = _tmpFileItem["value"];
									}
									else
									{
										if( stic_nClipid == _tmpFileItem["value"] )
										{
											stic_nClipid = _tmpFileItem["value"];
										}
											
									}
									
									if( this.hasOwnProperty("DESC_LASTSTARTTIME") )
									{
										this["DESC_LASTSTARTTIME"] = _tmpFileItem["value"];
									}
								}
								else if( _tmpFileItem["key"] == "url_ts" )
								{
									_clip.name = GetNameKey( _tmpFileItem["value"] );
								}
							}
							continue;
						}
					}
				}
				
				_clip.groupID = this.groupID + EXT_LETV_M3U8_VER + LiveVodConfig.GET_AGREEMENT_VERSION();
				_clip.width   = this.width;
				_clip.height  = this.height;
				_clip.totalDuration = this.totalDuration;
				/*if( _clip.timestamp == 1387073574 )
				{
					_clip.discontinuity = 1
				}*/
				if( _clip.name!="" )
				{
					if( _clip.timestamp == 0 )
					{
						P2PDebug.traceMsg( this,"_clip.timestamp is 0" + _clip.url_ts );
					}
					_clipList.push(_clip);
				}
			}
			
			_initData.totalDuration = this.totalDuration;
			_initData.totalSize = fileTotalSize;
			
			if( _clipList.length==1 && (LIVE_TIME.GetBaseTime()-LiveVodConfig.M3U8_MAXTIME)>30 )
			{
				P2PDebug.traceMsg(this,"返回m3u8一个");
			}
				
			if(_clipList.length>0)
			{
				LiveVodConfig.M3U8_MAXTIME = _clipList[_clipList.length-1].timestamp;	
			}
			 
			p_fun(_clipList);

		}
		
		private function parseFileHead(str:String):Object
		{
			var obj:Object = new Object;
			var value:String = "";
			
			var switchStr:String = str;
			var nIdx:int = switchStr.indexOf(":");
			switchStr = switchStr.substr(0,nIdx+1);
			
			switch(switchStr)
			{
				case "#EXTM3U":
					obj.key = "";
					break;
				//case "#EXT-X-DISCONTINUITY":
					//					value=getValue(str,"#EXT-X-DISCONTINUITY:")
					//					if(value!="")
					//					{
					//						obj.key="#EXT-X-DISCONTINUITY:";
					//						obj.value=value;
					//						return obj;
					//					}
					//obj.key = "discontinuity";
					//obj.value = 1;
					//break;
				case "#EXT-X-VERSION:":
//					value=getValue(str,"#EXT-X-VERSION:")
//					if(value!="")
//					{
//						obj.key="EXT-X-VERSION";
//						obj.value=value;
//						return obj;
//					}
					obj.key = "";
					break;
				case "#EXT-X-MEDIA-SEQUENCE:":
//					value=getValue(str,"#EXT-X-MEDIA-SEQUENCE:")
//					if(value!="")
//					{
//						obj.key="n_EXT_X_MEDIA_SEQUENCE";
//						obj.value=value;
//						return obj;
//					}
					obj.key = "";
					break;
				case "#EXT-X-ALLOW-CACHE:":
//					value=getValue(str,"#EXT-X-ALLOW-CACHE:")
//					if(value!="")
//					{
//						obj.key="b_EXT_X_ALLOW_CACHE";
//						obj.value=value;
//						return obj;
//					}
					obj.key = "";
					break;
				case "#EXT-X-TARGETDURATION:":
//					value=getValue(str,"#EXT-X-TARGETDURATION:")
//					if(value!="")
//					{
//						obj.key="n_EXT_X_TARGETDURATION";
//						obj.value=value;
//						return obj;
//					}
					obj.key = "";
					break;
				case "#EXT-LETV-M3U8-TYPE:":
					value = getValue(str,"#EXT-LETV-M3U8-TYPE:")
					if( value != "" )
					{
						obj.key = "str_EXT_LETV_M3U8_TYPE";
						obj.value=value;
						return obj;
					}
					break;
				case "#EXT-LETV-M3U8-VER:":
					value = getValue(str,"#EXT-LETV-M3U8-VER:")
					if( value!="" )
					{
						obj.key="EXT_LETV_M3U8_VER";
						obj.value=value;
						return obj;
					}
					break;
			}
			return obj;
		}
		
		private function parseProgram(str:String):Object
		{
			var obj:Object = new Object;
			var value:String = "";
			
			var switchStr:String = str;
			var nIdx:int = switchStr.indexOf(":");
			if( -1!=nIdx )
			{
				switchStr = switchStr.substr(0,nIdx+1);
			}
			
			switch(switchStr)
			{
				case "#EXT-LETV-X-DISCONTINUITY:":
//					value=getValue(str,"#EXT-LETV-X-DISCONTINUITY:")
//					if(value!="")
//					{
//						obj.key="#EXT-LETV-X-DISCONTINUITY:";
//						obj.value=value;
//						return obj;
//					}
					obj.key = "";
					break;
				case "#EXT-LETV-PROGRAM-ID:":
					value=getValue(str,"#EXT-LETV-PROGRAM-ID:")
					if( value != "" )
					{
						obj.key="groupID";
						obj.value=value;
						return obj;
					}
					break;
				case "#EXT-LETV-PIC-WIDTH:":
					value=getValue(str,"#EXT-LETV-PIC-WIDTH:")
					if( value != "" )
					{
						obj.key = "width";
						obj.value = value;
						return obj;
					}
					break;
				case "#EXT-LETV-PIC-HEIGHT:":
					value=getValue(str,"#EXT-LETV-PIC-HEIGHT:")
					if( value!="" )
					{
						obj.key = "height";
						obj.value = value;
						return obj;
					}
					break;
				case "#EXT-LETV-TOTAL-TS-LENGTH:":
					obj.key = "";
					break;
				case "#EXT-LETV-TOTAL-ES-LENGTH:":
					obj.key = "";
					break;
				case "#EXT-LETV-TOTAL-SEGMENT:":
					obj.key = "";
					break;
				case "#EXT-LETV-TOTAL-P2P-PIECE:":
					obj.key = "";
					break;
				case "#EXT-LETV-TOTAL-DURATION:":
					value = getValue(str,"#EXT-LETV-TOTAL-DURATION:")
					if(value != "")
					{
						obj.key = "totalDuration";
						obj.value = value;
						return obj;
					}
					break;
			}
			return obj;
		}
		
		private function parseData(str:String):Object
		{
			var obj:Object = new Object;
			var value:String = "";
			
			var switchStr:String = str;
			
			if( switchStr.indexOf("#") != -1 )
			{
				var nIdx:int = switchStr.indexOf(":");
				if( -1!=nIdx )
				{
					switchStr = switchStr.substr(0,nIdx+1);
				}
				
				switch(switchStr)
				{
//					case "#EXT-LETV-PROGRAM:":
//						value = getValue(str,"#EXT-LETV-PROGRAM:")
//						if( value!="" )
//						{
//							obj.key="groupID";
//							obj.value=value;
//							return obj;
//						}
//						break;
					case "#EXT-X-DISCONTINUITY":
						obj.key = "discontinuity";
						obj.value = 1;
						return obj;
						break;
					case "#EXT-LETV-START-TIME:":
						value = getValue(str,"#EXT-LETV-START-TIME:")
						if( value!="" )
						{
							obj.key="timestamp";
							obj.value=parseFloat(value);
							return obj;
						}
						break;
					case "#EXT-LETV-P2P-PIECE-NUMBER:":
						value = getValue(str,"#EXT-LETV-P2P-PIECE-NUMBER:")
						if( value!="" )
						{
							obj.key="p2pPieceNumber";
							obj.value=value;
							return obj;
						}
						break;
					case "#EXT-LETV-SEGMENT-ID:":
						value = getValue(str,"#EXT-LETV-SEGMENT-ID:")
						if( value!="" )
						{
							obj.key="sequence";
							obj.value=int(value);
							return obj;
						}
						break;
					case "#EXT-LETV-CKS:":
						value = getValue(str,"#EXT-LETV-CKS:")
						if( value!="" )
						{
							obj.key = "pieceInfoArray";
							obj.value = value;
							obj.size = parseFloat(ParseUrl.getParam(obj.value,"SZ")); 
							fileTotalSize += obj.size
							return obj;
						}
						break;
					case "#EXTINF:":
						value = getValue(str,"#EXTINF:")
						if( value!="" )
						{
							obj.key = "duration";
							obj.value = parseFloat(value);
							return obj;
						}
						break;	
				}	
			}
			else if( switchStr.length > 0 )
			{
				obj.key = "url_ts";
				obj.value = switchStr;
				return obj;
			}

			return null;
		}
		
		private function getValue(str1:String,str2:String):String
		{
			var value:String = "";
			if( str1.indexOf(str2)==0 )
			{
				value=str1.replace(str2,"")
			}	
			return value;
		}
		public function rebackStr(matchedSubstring:String,capturedMatch1:String,index:int,str:String):String 
		{
			return capturedMatch1+"~_~";
		}
		
		private function GetNameKey( p_strUrl:String ):String
		{
			var tmpStrNameKey:String = "";
			
//			if( p_strUrl.indexOf("http://") == 0 )
//			{
				tmpStrNameKey 	= ParseUrl.parseUrl(p_strUrl).path;
				if( null == tmpStrNameKey )
				{
					return p_strUrl;
				}
				var nPos:Number = tmpStrNameKey.lastIndexOf("/");
				tmpStrNameKey 	= tmpStrNameKey.substr(nPos+1,tmpStrNameKey.length);
//			}
//			else
//			{
//				tmpStrNameKey = p_strUrl;
//			}
			return tmpStrNameKey;
		}
	}
}