package lee.projects.player.view{
    import fl.controls.Button;
    
    import flash.display.MovieClip;
    import flash.display.SimpleButton;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.MouseEvent;
    import flash.text.TextField;
    
    import lee.bases.BaseEvent;
    import lee.bases.BaseUI;
    import lee.commons.DblClickSprite;
    import lee.commons.StateButton;
    import lee.player.Player;
    import lee.player.PlayerEvent;
    import lee.player.PlayerState;
    import lee.projects.player.events.ControlbarEvent;
    import lee.projects.player.utils.BaseSlider;
	
	import lee.projects.player.GlobalReference;
	
	public class Controlbar extends BaseUI{
		protected var _player:Player;
		protected var _background:Sprite;
		protected var _timeText:TextField;
		protected var _playBtn:StateButton;
		protected var _pauseBtn:StateButton;
		protected var _muteonBtn:StateButton;
		protected var _muteoffBtn:StateButton;
		protected var _fullScreenBtn:StateButton;
		protected var _normalScreenBtn:StateButton;
		protected var _greatPlayBtn:StateButton;
		protected var _soundSlider:BaseSlider;
		protected var _seekSlider:BaseSlider;
		
		protected var _vidBtn:SimpleButton;
		public var vidText:TextField = new TextField();
		
		protected var _showBtn1:SimpleButton;
		protected var _showBtn2:SimpleButton;
		protected var _showBtn3:SimpleButton;
		protected var _gaoqingBtn:StateButton;
		protected var _biaoqingBtn:StateButton;
		
		
		protected var _prevVolume:Number;
		protected var _duration:Number;
		//lz
		protected var _p2pInfoArea:P2PInfoArea;
		protected var _seekSliderOffset:Number;
        //
		public function Controlbar(player:Player,config:XML=null) {
			
			var cb:PlayControlbarSkin=new PlayControlbarSkin;
			addChild(cb);
			
			_player=player;
			_player.addEventListener(DblClickSprite.SINGLE_CLICK,_player_SINGLE_CLICK);
			_player.addEventListener(PlayerEvent.RESET,_player_RESET);
			_player.addEventListener(PlayerEvent.META_DATA,_player_META_DATA);
			_player.addEventListener(PlayerEvent.READY,_player_READY);
			_player.addEventListener(PlayerEvent.PLAYHEAD,_player_PLAYHEAD);
			_player.addEventListener(PlayerEvent.PROGRESS,_player_PROGRESS);
			_player.addEventListener(PlayerEvent.STATE_CHANGE,_player_STATE_CHANGE);

			_background=cb.getChildByName("background") as Sprite;
			_timeText=cb.getChildByName("timeText") as TextField;
			
			_playBtn=new StateButton(cb.getChildByName("playBtn") as MovieClip);
			_pauseBtn=new StateButton(cb.getChildByName("pauseBtn") as MovieClip);
			_muteonBtn=new StateButton(cb.getChildByName("muteonBtn") as MovieClip);
			_muteoffBtn=new StateButton(cb.getChildByName("muteoffBtn") as MovieClip);
			_fullScreenBtn=new StateButton(cb.getChildByName("fullScreenBtn") as MovieClip);
			_normalScreenBtn=new StateButton(cb.getChildByName("normalScreenBtn") as MovieClip);
			_greatPlayBtn=new StateButton(cb.getChildByName("greatPlayBtn") as MovieClip);
			_soundSlider=new BaseSlider(cb.getChildByName("soundSlider") as Sprite,3);
			_seekSlider=new BaseSlider(cb.getChildByName("seekSlider") as Sprite,1);
			
			//
			/*_vidBtn=cb.getChildByName("vidBtn") as SimpleButton;
			_vidBtn.addEventListener(MouseEvent.CLICK,_vidBtn_CLICK);
			vidText=cb.getChildByName("vidText") as TextField;*/
			//
			
			_showBtn1=cb.getChildByName("showBtn1") as SimpleButton;
			_showBtn2=cb.getChildByName("showBtn2") as SimpleButton;
			_showBtn3=cb.getChildByName("showBtn3") as SimpleButton;
			_biaoqingBtn=new StateButton(cb.getChildByName("biaoqingBtn") as MovieClip);
			_gaoqingBtn=new StateButton(cb.getChildByName("gaoqingBtn") as MovieClip);
			
			
			
			_playBtn.addEventListener(MouseEvent.CLICK,_playBtn_CLICK);
			_pauseBtn.addEventListener(MouseEvent.CLICK,_pauseBtn_CLICK);
			_muteonBtn.addEventListener(MouseEvent.CLICK,_muteonBtn_CLICK);
			_muteoffBtn.addEventListener(MouseEvent.CLICK,_muteoffBtn_CLICK);
			_fullScreenBtn.addEventListener(MouseEvent.CLICK,_fullScreenBtn_CLICK);
			_normalScreenBtn.addEventListener(MouseEvent.CLICK,_normalScreenBtn_CLICK);
			_greatPlayBtn.addEventListener(MouseEvent.CLICK,_playBtn_CLICK);
			_showBtn1.addEventListener(MouseEvent.CLICK,_showBtn1_CLICK);
			_showBtn2.addEventListener(MouseEvent.CLICK,_showBtn2_CLICK);
			_showBtn3.addEventListener(MouseEvent.CLICK,_showBtn3_CLICK);
			//_biaoqingBtn.addEventListener(MouseEvent.CLICK,_biaoqingBtn_CLICK);
			//_gaoqingBtn.addEventListener(MouseEvent.CLICK,_gaoqingBtn_CLICK);

			_soundSlider.addEventListener(BaseSlider.DRAG,_soundSlider_CHANGE);
			_soundSlider.addEventListener(BaseSlider.CHANGE,_soundSlider_CHANGE);
			_seekSlider.addEventListener(BaseSlider.CHANGE,_seekSlider_CHANGE);
			_seekSlider.addEventListener(BaseSlider.TRACKON,_seekSlider_TRACKON);
			_seekSlider.addEventListener(BaseSlider.TRACKOFF,_seekSlider_TRACKOFF);
			
			//_playBtn.state="disabled";
			_pauseBtn.state="disabled";
			_greatPlayBtn.skin.visible=false;

			var volume:Number=Number(config.volume[0]);
			_prevVolume=volume>0?volume:0.5;
			_soundSlider.position=volume;
			_soundSlider.width=60;
			_soundSlider.isFullOnDrag=true;
			_player.volume=volume;
			setBtnsVisible(volume>0?"muteonBtn":"muteoffBtn");
			
			_seekSlider.enabled=false;
			_seekSliderOffset = 0;
			
			setBtnsVisible("playBtn");
			setBtnsVisible("fullScreenBtn");
			setTime(null);
			
			_fullScreenBtn.skin.visible=false;
			_height=_background.height+_seekSlider.skin.height;
		}
		override public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
				_background.width=w;
				//_timeText.x=w-170;
				_seekSlider.width=w;
              //  _fullScreenBtn.skin.x=_normalScreenBtn.skin.x=w-40;
				
				/*_gaoqingBtn.x=_fullScreenBtn.skin.x-60;
				_biaoqingBtn.x=_gaoqingBtn.x-60;*/
				
				_showBtn3.x=w-40;
				_showBtn2.x=_showBtn3.x-40;
				_showBtn1.x=_showBtn2.x-40;
				_seekSlider.updateBuffer();
			}
		}
		public function setBtnsVisible(btnName:String):void{
			switch(btnName)
			{
				case "playBtn":
				    _playBtn.skin.visible=true;
					_pauseBtn.skin.visible=false;
				    break;
				case "pauseBtn":
				    _pauseBtn.skin.visible=true;
					_playBtn.skin.visible=false;
				    break;
				case "muteonBtn":
				    _muteonBtn.skin.visible=true;
					_muteoffBtn.skin.visible=false;
				    break;
				case "muteoffBtn":
				    _muteoffBtn.skin.visible=true;
					_muteonBtn.skin.visible=false;
				    break;
				case "fullScreenBtn":
				    _fullScreenBtn.skin.visible=true;
					_normalScreenBtn.skin.visible=false;
				    break;
				case "normalScreenBtn":
				    _normalScreenBtn.skin.visible=true;
					_fullScreenBtn.skin.visible=false;
				    break;
				default:
				    return;
			}
		}
		private var _fun:Function;
		private var _str1:String;
		private var _str2:String;
		public function setPanel(p2pInfoArea:P2PInfoArea):void
		{
			_p2pInfoArea = p2pInfoArea;
		}
		public function sethd(fun:Function,str1:String="",str2:String=""):void
		{
			_fun=fun;
			_str1=str1;
			_str2=str2;
			if(str1!="")
			{
				_biaoqingBtn.addEventListener(MouseEvent.CLICK,_biaoqingBtn_CLICK);
			}
			
			if(str2!="")
			{
				_gaoqingBtn.addEventListener(MouseEvent.CLICK,_gaoqingBtn_CLICK);
			}
			
			
			_biaoqingBtn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		}
		protected function setTime(obj:Object=null):void{
			if(obj)
			{
				if( GlobalReference.type == "VOD" || GlobalReference.type == "ContinuityVOD" )
				{
					_timeText.text=getTimeString(Number(obj.time))+" / "+getTimeString(Number(obj.duration));
				}
				else
				{
					_timeText.text=getTimeString_1(obj.time);
				}
			}
			else
			{
				_timeText.text="00:00:00 / 00:00:00";
			}
		}
		protected function getTimeString(time:Number):String{
			var s:Number=  Math.floor(time/3600);
			time=time-s*3600;
	        var f:Number = Math.floor(time/60);
	        var m:Number = Math.floor(time-f*60);
			s=s<100?s:99;
	        return (s<10 ? ("0"+s) : String(s))+":"+(f<10 ? ("0"+f) : f)+":"+(m<10 ? ("0"+m) : m);
		}
		protected function getTimeString_1(time:Number):String{
			var date:Object=new Date(time*1000);
			var y:String=(date.month<9)?("0"+String(date.month+1)):String(date.month+1);
			var r:String=((date.date<10)?("0"+String(date.date)):String(date.date));
			var s:String=(date.hours<10)?("0"+String(date.hours)):String(date.hours);
			var f:String=(date.minutes<10)?("0"+String(date.minutes)):String(date.minutes);
			var m:String=(date.seconds<10)?("0"+String(date.seconds)):String(date.seconds);
			
			return y+"月"+r+"日 "+s+":"+f+":"+m;
		}
		//====================
		protected function _player_SINGLE_CLICK(event:BaseEvent):void{
			if(_playBtn.skin.visible&&_playBtn.state!="disabled")
			{
				_playBtn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
			}
			else if(_pauseBtn.skin.visible&&_pauseBtn.state!="disabled")
			{
				_pauseBtn.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
			}
		}
		protected function _player_RESET(event:PlayerEvent):void{
			_playBtn.state="disabled";
			_pauseBtn.state="disabled";
			_seekSlider.position=0;
			_seekSlider.progress=0;
			_seekSlider.enabled=false;
			setBtnsVisible("pauseBtn");
			setTime(null);
		}
		protected function _player_META_DATA(event:PlayerEvent):void{
			setTime(event.info);
			_duration=event.info.duration;
		}
		protected function _player_READY(event:PlayerEvent):void{
			_playBtn.state="up";
			_pauseBtn.state="up";
			_seekSlider.enabled=true;
		}
		protected function _player_PLAYHEAD(event:PlayerEvent):void{
			setTime(event.info);
			if(!_seekSlider.isDraging&&_player.state==PlayerState.PLAYING)
			{
				if( GlobalReference.type == "VOD" || GlobalReference.type == "ContinuityVOD")
				{
					_seekSlider.position=Number(event.info.time)/Number(event.info.duration);
				}
				else
				{
					_seekSlider.position=0.5;
					setFullnessSprite(_seekSliderOffset);
				}				
			}
		}
		protected function _player_PROGRESS(event:PlayerEvent):void
		{
			if( GlobalReference.type == "VOD" || GlobalReference.type == "ContinuityVOD" )
			{
				_seekSlider.progress=Number(event.info);
			}			
			_seekSlider.updateBuffer();
		}
		
		protected function _player_STATE_CHANGE(event:PlayerEvent):void{
			var pstate:String=String(event.info);
			_greatPlayBtn.skin.visible=false;
			switch (pstate)
			{
				case PlayerState.PLAYING :
				    setBtnsVisible("pauseBtn");
					break;
				case PlayerState.PAUSED :
				    setBtnsVisible("playBtn");
					_greatPlayBtn.skin.visible=true;
					break;
				case PlayerState.STOPPED :
					_playBtn.state="up";
					_seekSlider.position=0;
				    _seekSlider.progress=0;
					_seekSlider.clearBuffer();
					_seekSlider.enabled=false;
                    setBtnsVisible("playBtn");
					dispatchEvent(event);
					break;
				case PlayerState.IDLE :
				    _playBtn.state="up";
					_seekSlider.position=0;
				    _seekSlider.progress=0;
					_seekSlider.clearBuffer();
					_seekSlider.enabled=false;
                    setBtnsVisible("playBtn");
					break;
			}
		}
		//----------------------
		protected function _playBtn_CLICK(event:MouseEvent):void{
			if(_player.info)
			{
				if(_player.state!=PlayerState.STOPPED)
				{
			    	_player.resume();
			    	setBtnsVisible("pauseBtn");
			    	_greatPlayBtn.skin.visible=false;
				}
				else
				{
					_player.replay();
				}
			}
		}
		protected function _pauseBtn_CLICK(event:MouseEvent):void{
			_player.pause();
		}
		
		/*protected function _vidBtn_CLICK(event:MouseEvent):void{
			
			
			
		}*/
		
		protected function _showBtn1_CLICK(event:MouseEvent):void{
			trace("_showBtn1_CLICK")
			if(!_p2pInfoArea.peerInfoPanel.visible)
			{
				_p2pInfoArea.peerInfoPanel.show();
			}else
			{
				_p2pInfoArea.peerInfoPanel.hide();
			}
			
			
		}
		protected function _showBtn2_CLICK(event:MouseEvent):void{
			trace("_showBtn2_CLICK");
			if(!_p2pInfoArea.serverInfoPanel.visible)
			{
				_p2pInfoArea.serverInfoPanel.show();
			}else
			{
				_p2pInfoArea.serverInfoPanel.hide();
			}
		
		}
		protected function _showBtn3_CLICK(event:MouseEvent):void{
			trace("_showBtn3_CLICK")
			if(!_p2pInfoArea.p2pInfoPanel.visible)
			{
				_p2pInfoArea.p2pInfoPanel.show();
			}else
			{
				_p2pInfoArea.p2pInfoPanel.hide();
			}
			
		}
		protected function _biaoqingBtn_CLICK(event:MouseEvent):void{
			//trace("_biaoqingBtn_CLICK");
			_gaoqingBtn.state="up";
			_biaoqingBtn.state="disabled";
			_fun.call(this,_str1);
		}
		protected function _gaoqingBtn_CLICK(event:MouseEvent):void{
			//trace("_gaoqingBtn_CLICK")
			_biaoqingBtn.state="up";
			_gaoqingBtn.state="disabled";
			_fun.call(this,_str2);
		}
		
		protected function _muteonBtn_CLICK(event:MouseEvent):void{
			_prevVolume=_soundSlider.position;
			setBtnsVisible("muteoffBtn");
			_soundSlider.position=0;
			_soundSlider_CHANGE(new BaseEvent(BaseSlider.CHANGE,0));
		}
		protected function _muteoffBtn_CLICK(event:MouseEvent):void{
			setBtnsVisible("muteonBtn");
			_soundSlider.position=_prevVolume;
			_soundSlider_CHANGE(new BaseEvent(BaseSlider.CHANGE,_prevVolume));
		}
		protected function _fullScreenBtn_CLICK(event:MouseEvent):void{
			dispatchEvent(new ControlbarEvent(ControlbarEvent.FULLSCREENBTN_CLICK,null));
		}
		protected function _normalScreenBtn_CLICK(event:MouseEvent):void{
			dispatchEvent(new ControlbarEvent(ControlbarEvent.NORMALSCREENBTN_CLICK,null));
		}
		protected function _soundSlider_CHANGE(event:BaseEvent):void{
			setBtnsVisible(Number(event.info)>0?"muteonBtn":"muteoffBtn");
			_player.volume=Number(event.info);
			dispatchEvent(new ControlbarEvent(ControlbarEvent.VOLUME_CHANGE,event.info));
		}
		protected function _seekSlider_CHANGE(event:BaseEvent):void
		{
			if( GlobalReference.type == "VOD" || GlobalReference.type == "ContinuityVOD" )
			{
				_player.seek(Number(event.info)*_duration);
			}
			else
			{
				var offset:Number = Number(event.info) - 0.5;			
				_player.seek(offset);
				
				_seekSliderOffset += offset;
				setFullnessSprite(_seekSliderOffset);
			}			
		}
		protected function setFullnessSprite(Offset:Number):void
		{		
			var offsetPer:Number = 0.5 - Offset;
			if( offsetPer < 0.5)
			{
				_seekSliderOffset = 0;
				_seekSlider.fullnessSprite.width =_seekSlider.width*0.5;
			}
			else if(offsetPer >= 1)
			{
				_seekSlider.fullnessSprite.width = _seekSlider.width;
			}
			else
			{
				_seekSlider.fullnessSprite.width = _seekSlider.width*offsetPer;
			}
		}
		protected function _seekSlider_TRACKON(event:BaseEvent):void{
			//_previewPane.show(Number(event.info));
		}
		protected function _seekSlider_TRACKOFF(event:BaseEvent):void{
			//_previewPane.hide();
		}
	}
}