package com.hls_p2p.loaders.descLoader
{
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.p2p.utils.ParseUrl;

	public class ParseM3U8_uniform
	{
		private var fileTotalSize:Number=0;	
		public function parseFile(file:String,_initData:InitData,p_fun:Function,descPoint:DescLoader=null):void
		{
			var objParse:Object={"fileMSG":new Object,"dataMSG":new Object};
			file=file.replace(/\r/g,"");
			file=file.replace(/.ts\n/g,".ts~_~");
			var tsList:Array = file.split("~_~");
			var i:uint = 0;
			var j:uint = 0;
			var _clip:Clip;
			var _fileHead:Object=new Object;
			var _tmpFileItem:Object
			var _clipList:Vector.<Clip>=new Vector.<Clip>;

			// 不解析最后一块，因为是endlist，可以添加错误处理
			for(i=0;i<tsList.length;i++)
			{
				var lines:Array =(tsList[i]).split("\n");
				_clip=new Clip;
				
				if(0 != i)
				{
					for(j=0;j<lines.length;j++)
					{
						//
						if(lines[j].length <= 0)
						{
							continue;
						}
						_tmpFileItem=parseProgram(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								descPoint[_tmpFileItem["key"]]=_tmpFileItem["value"];
							}
							continue;
						}
						//
						_tmpFileItem=parseData(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								if(_tmpFileItem["key"] == "pieceInfoArray")
								{
									_clip.pieceInfoArray.push(_tmpFileItem["value"]);
									continue;
								}
								_clip[_tmpFileItem["key"]]=_tmpFileItem["value"];
							}
							continue;
						}
						//
					}
				}
				else if(0 == i)
				{
					for(j=0;j<lines.length;j++)
					{
						//
						if(lines[j].length <= 0)
						{
							continue;
						}
						_tmpFileItem=parseFileHead(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								//暂时没有可用的数据
							}
							continue;
						}
						//
						_tmpFileItem=parseProgram(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								if(descPoint.hasOwnProperty(_tmpFileItem["key"]))
								{
									descPoint[_tmpFileItem["key"]]=_tmpFileItem["value"];
								}
							}
							continue;
						}
						//
						_tmpFileItem=parseData(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								if(_tmpFileItem["key"] == "pieceInfoArray")
								{
									_clip.pieceInfoArray.push(_tmpFileItem["value"]);
									continue;
								}
								_clip[_tmpFileItem["key"]]=_tmpFileItem["value"];
							}
							continue;
						}
					}
				}
				_clip.groupID = descPoint.groupID ;
				_clip.width = descPoint.width;
				_clip.height = descPoint.height;
				_clip.totalDuration = descPoint.totalDuration;
				if(_clip.name!=""){
					_clipList.push(_clip);
				}
			}
			_initData.totalDuration = descPoint.totalDuration;
			_initData.totalSize = fileTotalSize;
			p_fun(_clipList);
		}
		
		public function parseFile_1(file:String,_initData:InitData,p_fun:Function,descPoint:LiveM3U8Loader=null):void
		{
			var objParse:Object={"fileMSG":new Object,"dataMSG":new Object};
			file=file.replace(/\r/g,"");
			file=file.replace(/.ts\n/g,".ts~_~");
			var tsList:Array = file.split("~_~");
			var i:uint = 0;
			var j:uint = 0;
			var _clip:Clip;
			var _fileHead:Object=new Object;
			var _tmpFileItem:Object
			var _clipList:Vector.<Clip>=new Vector.<Clip>;
			
			// 不解析最后一块，因为是endlist，可以添加错误处理
			for(i=0;i<tsList.length;i++)
			{
				var lines:Array =(tsList[i]).split("\n");
				_clip=new Clip;
				
				if(0 != i)
				{
					for(j=0;j<lines.length;j++)
					{
						//
						if(lines[j].length <= 0)
						{
							continue;
						}
						_tmpFileItem=parseProgram(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								descPoint[_tmpFileItem["key"]]=_tmpFileItem["value"];
							}
							continue;
						}
						//
						_tmpFileItem=parseData(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								if(_tmpFileItem["key"] == "pieceInfoArray")
								{
									_clip.pieceInfoArray.push(_tmpFileItem["value"]);
									continue;
								}
								_clip[_tmpFileItem["key"]]=_tmpFileItem["value"];
							}
							continue;
						}
						//
					}
				}
				else if(0 == i)
				{
					for(j=0;j<lines.length;j++)
					{
						//
						if(lines[j].length <= 0)
						{
							continue;
						}
						_tmpFileItem=parseFileHead(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								//暂时没有可用的数据
							}
							continue;
						}
						//
						_tmpFileItem=parseProgram(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								if(descPoint.hasOwnProperty(_tmpFileItem["key"]))
								{
									descPoint[_tmpFileItem["key"]]=_tmpFileItem["value"];
								}
							}
							continue;
						}
						//
						_tmpFileItem=parseData(lines[j]);
						if(_tmpFileItem && _tmpFileItem.hasOwnProperty("key"))
						{
							if(_tmpFileItem["key"] != "")
							{
								if(_tmpFileItem["key"] == "pieceInfoArray")
								{
									_clip.pieceInfoArray.push(_tmpFileItem["value"]);
									continue;
								}
								_clip[_tmpFileItem["key"]]=_tmpFileItem["value"];
							}
							continue;
						}
					}
				}
				_clip.groupID = descPoint.groupID ;
				_clip.width = descPoint.width;
				_clip.height = descPoint.height;
				_clip.totalDuration = descPoint.totalDuration;
				if(_clip.name!=""){
					_clipList.push(_clip);
				}
			}
			_initData.totalDuration = descPoint.totalDuration;
			_initData.totalSize = fileTotalSize;
			p_fun(_clipList);
		}
		
		private function parseFileHead(str:String):Object
		{
			var obj:Object=new Object;
			var value:String="";
			
			var switchStr:String = str;
			var nIdx:int = switchStr.indexOf(":");
			switchStr = switchStr.substr(0,nIdx+1);
			
			switch(switchStr)
			{
				case "#EXTM3U":
					obj.key="";
					break;
				case "#EXT-X-VERSION:":
//					value=getValue(str,"#EXT-X-VERSION:")
//					if(value!="")
//					{
//						obj.key="n_EXT_X_VERSION";
//						obj.value=value;
//						return obj;
//					}
					obj.key="";
					break;
				case "#EXT-X-MEDIA-SEQUENCE:":
//					value=getValue(str,"#EXT-X-MEDIA-SEQUENCE:")
//					if(value!="")
//					{
//						obj.key="n_EXT_X_MEDIA_SEQUENCE";
//						obj.value=value;
//						return obj;
//					}
					obj.key="";
					break;
				case "#EXT-X-ALLOW-CACHE:":
//					value=getValue(str,"#EXT-X-ALLOW-CACHE:")
//					if(value!="")
//					{
//						obj.key="b_EXT_X_ALLOW_CACHE";
//						obj.value=value;
//						return obj;
//					}
					obj.key="";
					break;
				case "#EXT-X-TARGETDURATION:":
//					value=getValue(str,"#EXT-X-TARGETDURATION:")
//					if(value!="")
//					{
//						obj.key="n_EXT_X_TARGETDURATION";
//						obj.value=value;
//						return obj;
//					}
					obj.key="";
					break;
				case "#EXT-LETV-M3U8-TYPE:":
					value=getValue(str,"#EXT-LETV-M3U8-TYPE:")
					if(value!="")
					{
						obj.key="str_EXT_LETV_M3U8_TYPE";
						obj.value=value;
						return obj;
					}
					break;
				case "#EXT-LETV-M3U8-VER:":
					value=getValue(str,"#EXT-LETV-M3U8-VER:")
					if(value!="")
					{
						obj.key="str_EXT_LETV_M3U8_VER";
						obj.value=value;
						return obj;
					}
					break;
			}
			return obj;
		}
		
		private function parseProgram(str:String):Object
		{
			var obj:Object=new Object;
			var value:String="";
			
			var switchStr:String = str;
			var nIdx:int = switchStr.indexOf(":");
			switchStr = switchStr.substr(0,nIdx+1);
			
			switch(switchStr)
			{
				case "#EXT-X-DISCONTINUITY:":
//					value=getValue(str,"#EXT-X-DISCONTINUITY:")
//					if(value!="")
//					{
//						obj.key="#EXT-X-DISCONTINUITY:";
//						obj.value=value;
//						return obj;
//					}
					obj.key="";
					break;
				case "#EXT-LETV-X-DISCONTINUITY:":
//					value=getValue(str,"#EXT-LETV-X-DISCONTINUITY:")
//					if(value!="")
//					{
//						obj.key="#EXT-LETV-X-DISCONTINUITY:";
//						obj.value=value;
//						return obj;
//					}
					obj.key="";
					break;
				case "#EXT-LETV-PROGRAM:":
					value=getValue(str,"#EXT-LETV-PROGRAM:")
					if(value!="")
					{
						obj.key="groupID";
						obj.value=value;
						return obj;
					}
					break;
				case "#EXT-LETV-PIC-WIDTH:":
					value=getValue(str,"#EXT-LETV-PIC-WIDTH:")
					if(value!="")
					{
						obj.key="width";
						obj.value=value;
						return obj;
					}
					break;
				case "#EXT-LETV-PIC-HEIGHT:":
					value=getValue(str,"#EXT-LETV-PIC-HEIGHT:")
					if(value!="")
					{
						obj.key="height";
						obj.value=value;
						return obj;
					}
					break;
				case "#EXT-LETV-TOTAL-TS-LENGTH:":
					obj.key="";
					break;
				case "#EXT-LETV-TOTAL-ES-LENGTH:":
					obj.key="";
					break;
				case "#EXT-LETV-TOTAL-SEGMENT:":
					obj.key="";
					break;
				case "#EXT-LETV-TOTAL-P2P-PIECE:":
					obj.key="";
					break;
				case "#EXT-LETV-TOTAL-DURATION:":
					value=getValue(str,"#EXT-LETV-TOTAL-DURATION:")
					if(value!="")
					{
						obj.key="totalDuration";
						obj.value=value;
						return obj;
					}
					break;
			}
			return obj;
		}
		
		private function parseData(str:String):Object
		{
			var obj:Object=new Object;
			var value:String="";
			
			var switchStr:String = str;
			
			if(switchStr.indexOf("#") != -1)
			{
				var nIdx:int = switchStr.indexOf(":");
				switchStr = switchStr.substr(0,nIdx+1);
				
				switch(switchStr)
				{
					case "#EXT-LETV-PROGRAM:":
						value=getValue(str,"#EXT-LETV-PROGRAM:")
						if(value!="")
						{
							obj.key="groupID";
							obj.value=value;
							return obj;
						}
						break;
					case "#EXT-LETV-START-TIME:":
						value=getValue(str,"#EXT-LETV-START-TIME:")
						if(value!="")
						{
							obj.key="timestamp";
							obj.value=parseFloat(value);
							return obj;
						}
						break;
					case "#EXT-LETV-P2P-PIECE-NUMBER:":
						value=getValue(str,"#EXT-LETV-P2P-PIECE-NUMBER:")
						if(value!="")
						{
							obj.key="p2pPieceNumber";
							obj.value=value;
							return obj;
						}
						break;
					case "#EXT-LETV-M3U8-SEQ:":
						value=getValue(str,"#EXT-LETV-M3U8-SEQ:")
						if(value!="")
						{
							obj.key="sequence";
							obj.value=int(value);
							return obj;
						}
						break;
					case "#EXT-LETV-CKS:":
						value=getValue(str,"#EXT-LETV-CKS:")
						if(value!="")
						{
							obj.key = "pieceInfoArray";
							obj.value = value;
							obj.size = parseFloat(ParseUrl.getParam(obj.value,"SZ")); 
							fileTotalSize += obj.size
							return obj;
						}
						break;
					case "#EXTINF:":
						value=getValue(str,"#EXTINF:")
						if(value!="")
						{
							obj.key="duration";
							obj.value= parseFloat(value);
							return obj;
						}
						break;	
				}	
			}
			else if( switchStr.length > 0)
			{
				obj.key="name";
				obj.value = switchStr;
				return obj;
			}

			return null;
		}
		
		private function getValue(str1:String,str2:String):String
		{
			var value:String="";
			if(str1.indexOf(str2)==0)
			{
				value=str1.replace(str2,"")
			}	
			return value;
		}
		
//		private function urlParseClipinfo(p_objParse:Object,strinfo:String):String
//		{
//			var end:int = strinfo.indexOf(".ts");
//			var start:int = 0;
//			strinfo = strinfo.substring(start,end);
//			var arrInfo:Array = strinfo.split("_");
//			p_objParse.offsize = Number(arrInfo[arrInfo.length-1]);
//			p_objParse.size = Number(arrInfo[arrInfo.length-2]);
//			p_objParse.KeyFrameCount = Number(arrInfo[arrInfo.length-3]);
//			p_objParse.beginKeyFrameSeq = Number(arrInfo[arrInfo.length-4]);
//			p_objParse.sequence = Number(arrInfo[arrInfo.length-5]);
//			p_objParse.strBlockVer = String(arrInfo[arrInfo.length-8]) + "_" + String(arrInfo[arrInfo.length-7]) + "_" +String(arrInfo[arrInfo.length-6]); 
//			
//			fileTotalSize += p_objParse.size;
//			return strinfo;
//		}
		
	}
	
}