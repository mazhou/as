package lee.player{
	import lee.commons.DblClickSprite;
	import lee.player.PlayerError;
	import lee.player.IProvider;
	import lee.player.PlayerEvent;
	import flash.events.EventDispatcher;
	import flash.display.Sprite;
	import flash.media.Video;
	public class Player extends DblClickSprite{
		protected var _width:Number;
		protected var _height:Number;

		protected var _streamWidth:Number=400;
		protected var _streamHeight:Number=300;
		protected var _useDefaultVideoRatio:Boolean=true;
		protected var _videoRatio:Number=4/3;
		protected var _videoSize:Number=1;
		protected var _volume:Number=1;
		
		protected var _video:Video;
		
		protected var _providers:Array;
		protected var _provider:IProvider;
		
		
		public function Player(providers:Array,w:Number=400,h:Number=300){
			_providers=providers;
			
			var len:int=providers.length;
			for(var i:int=0;i<len;i++)
			{
				var provider:EventDispatcher=providers[i] as EventDispatcher;
				provider.addEventListener(PlayerEvent.MESSAGE,sendPlayerEvent);
				provider.addEventListener(PlayerEvent.META_DATA,provider_META_DATA);
				provider.addEventListener(PlayerEvent.ERROR,sendPlayerEvent);
			    provider.addEventListener(PlayerEvent.READY,sendPlayerEvent);
			    provider.addEventListener(PlayerEvent.PLAYHEAD,sendPlayerEvent);
			    provider.addEventListener(PlayerEvent.PROGRESS,sendPlayerEvent);
			    provider.addEventListener(PlayerEvent.BUFFER_UPDATE,sendPlayerEvent);
				provider.addEventListener(PlayerEvent.STATE_CHANGE,sendPlayerEvent);
				provider.addEventListener(PlayerEvent.CONTINUE,sendPlayerEvent);
			}
			
			
			_provider=getProviderByType(null);
			

			
			_video=new Video(w,h);
			_video.smoothing=true;
			addChild(_video);
			setSize(w,h);
		}
		//---------------------
		override public function get width():Number{return _width;}
		override public function set width(w:Number):void{setSize(w,height);}
		override public function get height():Number{return _height;}
		override public function set height(h:Number):void{setSize(width,h);}
		//设置播放器宽高
		public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
				
				graphics.clear();
				graphics.beginFill(0);
                graphics.drawRect(0,0,w,h);
                graphics.endFill();
				
				align();
			}
		}
		//设置视频画面相对于播放器的大小比例
		public function setVideoSize(s:Number):void{
			if(_videoSize!=s)
			{
				_videoSize=s;
				align();
			}
		}
		//设置视频画面宽高比例，使用默认比例，传递NaN
		public function setVideoRatio(r:Number):void{
			_useDefaultVideoRatio=isNaN(r)?true:false;
			if(_useDefaultVideoRatio)
			{
				r=_streamWidth/_streamHeight;
			}
			if(_videoRatio!=r)
			{
				_videoRatio=r;
				align();
			}
		}
		//---------------------
		public function get info():Object{
			return _provider.info;
		}
		public function get type():String{
			return _provider.type;
		}
		public function get ready():Boolean{
			return _provider.ready;
		}
		public function get state():String{
			return _provider.state;
		}
		public function get time():Number{
			return _provider.time;
		}
		public function get duration():Number{
			return _provider.duration;
		}
		public function get percentLoaded():Number{
			return _provider.percentLoaded;
		}
		public function get volume():Number{
			return _volume;
		}
		public function set volume(volume:Number):void{
			if(_volume!=volume)
			{
				_volume=volume;
				_provider.volume=volume;
			}
		}
		public function play(info:Object):void{
			if(info)
			{
			    _provider.clear();
				
			    _provider=getProviderByType(info.type);
			    sendPlayerEvent(new PlayerEvent(PlayerEvent.RESET,info));
			    _video.clear();
				_provider.volume=_volume;
				_provider.video=_video;
			    _provider.play(info);
			}
			else
			{
				sendPlayerEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E0));
			}
		}
		public function clear():void{
			_provider.clear();
		}
		public function resume():void{
			_provider.resume();
		}
		public function pause():void{
			_provider.pause();
		}
		public function stop():void{
			_provider.stop();
		}
		public function replay():void{
			_provider.replay();
		}
		public function seek(percent:Number):void{
			_provider.seek(percent);
		}
		//=====================
		protected function provider_META_DATA(event:PlayerEvent):void{
			_streamWidth=Number(event.info.streamWidth);
			_streamHeight=Number(event.info.streamHeight);
			if(_useDefaultVideoRatio)
			{
				setVideoRatio(NaN);
			}
			sendPlayerEvent(event);
		}
		protected function sendPlayerEvent(event:PlayerEvent):void{
			dispatchEvent(event);
		}
		protected function align():void{
			if(width/height>=_videoRatio)
			{
			    _video.width=height*_videoRatio*_videoSize;
				_video.height=height*_videoSize;
			}
			else
			{
				_video.width=width*_videoSize;
			    _video.height=(width/_videoRatio)*_videoSize;
			}
			_video.x=int((width-_video.width)/2);
			_video.y=int((height-_video.height)/2);
		}
		protected function getProviderByType(type:String):IProvider{
			var len:int=_providers.length;
			if(len>0)
			{
				if(type)
				{
					var ret:IProvider;
			        for(var i:int=0;i<len;i++)
			        {
						if(_providers[i].type==type)
						{
							ret=_providers[i] as IProvider;
							break;
						}
			        }
					if(ret)
					{
						return ret;
					}
					else
					{
						throw new Error("找不到type为"+type+"的_provider");
					}
				}
				else
				{
					return _providers[0] as IProvider;
				}
			}
			else
			{
				throw new Error("_providers数组长度为0");
			}
		}
	}
}
