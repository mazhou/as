package lee.player.providers{
	import lee.player.IProvider;
	import lee.player.PlayerState;
	import lee.player.PlayerError;
	import lee.player.PlayerEvent;
	import flash.events.EventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
	import flash.media.SoundTransform;
	
	import flash.utils.Timer;
	
	public class RtmpProvider extends EventDispatcher implements IProvider{
		
        protected var _nc:NetConnection;
		protected var _ns:NetStream;
		
		protected var _info:Object;
		protected var _ready:Boolean;
		protected var _state:String=PlayerState.IDLE;
		protected var _time:Number;
		protected var _duration:Number;
		protected var _percentLoaded:Number;
		protected var _percentBuffer:Number;
		protected var _volume:Number=1;
		
		protected var _streamWidth:Number;
		protected var _streamHeight:Number;
		
		protected var _hasMetaData:Boolean;
		protected var _pauseOnReady:Boolean;
		

		protected var _timer:Timer;

		public function RtmpProvider(){
			super();

			_nc=new NetConnection();
			_nc.connect(null);

			_ns = new NetStream(_nc);
			_ns.client=new Object();
			_ns.client.onMetaData=onMetaData;
			_ns.bufferTime=3;
			_ns.addEventListener(NetStatusEvent.NET_STATUS,_ns_NET_STATUS);

			reset();
		}
		//--------------------
		public function get stream():NetStream{
			return _ns;
		}
		public function get info():Object{
			return _info;
		}
		public function get type():String{
			return "http";
		}
		public function get ready():Boolean{
			return _ready;
		}
		public function get state():String{
			return _state;
		}
		public function get time():Number{
			return _time;
		}
		public function get duration():Number{
			return _duration;
		}
		public function get percentLoaded():Number{
			return _percentLoaded;
		}
		public function get volume():Number{
			return _volume;
		}
		public function set volume(volume:Number):void{
			if(_volume!=volume)
			{
				_volume=volume;
				if(ready)
				{
					setVolume(volume);
				}
			}
		}
		protected function setVolume(volume:Number):void{
			var st:SoundTransform=_ns.soundTransform;
			st.volume=volume;
			_ns.soundTransform=st;
		}
		public function play(info:Object):void{
			reset();
			_info=info;
			setVolume(0);
			playStream(info.url);
		}
		public function clear():void{
			reset();
			_info=null;
			changeState(PlayerState.IDLE);
		}
		public function resume():void{
			if(!info){return;}
			if(ready)
			{
				_ns.resume();
				changeState(PlayerState.PLAYING);
			}
			else
			{
				replay();
		    }
		}
		public function pause():void{
			if(!info){return;}
			if(ready)
			{
				_ns.pause();
				changeState(PlayerState.PAUSED);
			}
			else
			{
				_pauseOnReady=true;
			}
		}
		public function stop():void{
			if(!info){return;}
			reset();
			changeState(PlayerState.STOPPED,false);
		}
		public function replay():void{
			if(!info){return;}
			play(info);
		}
		public function seek(percent:Number):void{
			if(!info){return;}
			if(ready)
			{
				_ns.seek(percent*duration);
			}
		}
		//--------------------
		protected function playStream(url:String,startFrame:Object=null):void{
			changeState(PlayerState.LOADING);
			_ns.play(url);
			startTimer();
		}
		protected function reset():void{
			stopTimer();
			_ns.close();
			_ready=false;
			
			_time=0;
			_duration=0;
			_percentLoaded=0;
			_percentBuffer=0;
			_streamWidth=NaN;
			_streamHeight=NaN;
			_hasMetaData=false;
			_pauseOnReady=false;

		}
		protected function changeState(state:String,expa:Object=null):void{
			if(_state!=state)
			{
				_state=state;
				dispatchEvent(new PlayerEvent(PlayerEvent.STATE_CHANGE,state,expa));
			}
		}
		protected function startTimer():void{
			if(!_timer)
			{
				_timer=new Timer(200);
                _timer.addEventListener(TimerEvent.TIMER,_timer_TIMER);
				_timer.start();
			}
		}
		protected function stopTimer():void{
			if(_timer)
			{
				_timer.stop();
				_timer.removeEventListener(TimerEvent.TIMER,_timer_TIMER);
				_timer=null;
			}
		}
		protected function onMetaData(obj:Object):void {
			if(_hasMetaData){return;}
			if(obj.width&&obj.height)
			{
				_streamWidth=Number(obj.width);
		        _streamHeight=Number(obj.height);
			}
			else
			{
				_streamWidth=400;
		        _streamHeight=300;
			}
			if(obj.duration)
			{
				_duration=Number(obj.duration);
			}
			else
			{
				_duration=0;
			}
			_hasMetaData=true;
		}
		protected function trySendReadyEvent():void{
			if(_hasMetaData)
			{
				if(_ns.time>0)
				{
					var obj:Object=new Object();
					obj.streamWidth=_streamWidth;
					obj.streamHeight=_streamHeight;
					obj.duration=_duration;
					
					setVolume(volume);
					_ready=true;
					dispatchEvent(new PlayerEvent(PlayerEvent.READY,obj));
					if(!_pauseOnReady)
					{
						changeState(PlayerState.PLAYING);
					}
					else
					{
						_pauseOnReady=false;
						_ns.pause();
					    _ns.seek(0);
						changeState(PlayerState.PAUSED);
					}
				}
			}
		}
		//--------------------
		protected function _ns_NET_STATUS(event:NetStatusEvent):void {
			var code:String=event.info.code;
			trace("流状态改变:"+code);
			switch (code)
			{
				case "NetStream.Play.Start" :
					break;
				case "NetStream.Play.Stop" :
				    reset();
			        changeState(PlayerState.STOPPED,true);
					break;
				case "NetStream.Play.Failed" :
				case "NetStream.Play.StreamNotFound" :
				    reset();
			        changeState(PlayerState.IDLE);
					dispatchEvent(new PlayerEvent(PlayerEvent.ERROR,PlayerError.E2));
					break;
				case "NetStream.Buffer.Empty" :
					if(ready)
			        {
				        changeState(PlayerState.BUFFERING);
			        }
					break;
				case "NetStream.Buffer.Full" :
				    if(ready)
			        {
				        changeState(PlayerState.PLAYING);
			        }
					break;
				case "NetStream.Seek.Notify" :
					break;
				case "NetStream.Seek.Failed" :
				case "NetStream.Seek.InvalidTime" :
					break;
			}
		}
		protected function _timer_TIMER(event:TimerEvent):void{
			if(!ready)
			{
				trySendReadyEvent();
				return;
			}
			var time:Number=_ns.time;
			if(_time!=time)
			{
				_time=time;
				var obj:Object=new Object();
				obj.time=time;
				obj.duration=duration;
				dispatchEvent(new PlayerEvent(PlayerEvent.PLAYHEAD,obj));
			}
			var loaded:Number=_ns.bytesLoaded/_ns.bytesTotal;
			loaded=loaded>=0?loaded:0;
			loaded=loaded<=1?loaded:1;
			if(_percentLoaded!=loaded)
			{
				_percentLoaded=loaded;
				dispatchEvent(new PlayerEvent(PlayerEvent.PROGRESS,loaded));
			}
			if(state==PlayerState.BUFFERING)
			{
				var buff:Number=_ns.bufferLength/_ns.bufferTime;
				buff=buff>=0?buff:0;
				buff=buff<=1?buff:1;
				if(_percentBuffer!=buff)
				{
					_percentBuffer=buff;
					dispatchEvent(new PlayerEvent(PlayerEvent.BUFFER_UPDATE,buff));
				}
			}
		}
	}
}