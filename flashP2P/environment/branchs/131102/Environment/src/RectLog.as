package 
{
	import fl.controls.UIScrollBar;
	import fl.events.ScrollEvent;
	
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.NetStream;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	
	import lee.bases.BaseUI;
	import lee.commons.StateButton;
	import lee.managers.RectManager;

	public class RectLog extends BaseUI
	{
		private var _rq:Sprite;
		private var maskMc:Sprite;
		private var scrollbar:UIScrollBar;

		private var _allNum:int = 0;//总num
		private var _startNum:int = 0;//播放点
		private var _httpBufferLength:int = 0;

		private var timer:Timer = new Timer(2000);
		private var Chunks:Object = new Object();
		
		private var _tipRq:Sprite;
		
		
		private var _isShowPicLog:Boolean=true;
		private var _rl:RectControlbarSkin;
		private var _playBtn:SimpleButton;
		private var _pauseBtn:SimpleButton;
		private var _bg:Sprite;
		private var _rectWidth:int=9;
		private var _rectHeight:int=9;
		public function RectLog()
		{
			_rl=new RectControlbarSkin;
			addChild(_rl);
			_bg=_rl.getChildByName("background") as Sprite;
			_playBtn=_rl.getChildByName("playBtn") as SimpleButton;
			_pauseBtn=_rl.getChildByName("pauseBtn") as SimpleButton;
			_playBtn.addEventListener(MouseEvent.CLICK,playBtnClick);
			_pauseBtn.addEventListener(MouseEvent.CLICK,playBtnClick);
			
			
			RectManager.rectLog=this;
			_rq=new Sprite();
			addChild(_rq);
			_tipRq=new Sprite();
			addChild(_tipRq);
			maskMc=new Sprite();
			addChild(maskMc);
			
			
			_rq.mask = maskMc;
			
			_playBtn.visible=false;
			
			this.addEventListener(Event.ENTER_FRAME,onRun);
			timer.addEventListener(TimerEvent.TIMER,onTimer);
			
		}
		public function stop():void
		{
			if(timer)
			{
				timer.stop();
			}
			if(this.hasEventListener(Event.ENTER_FRAME))
			{
				this.removeEventListener(Event.ENTER_FRAME,onRun);
			}
			if(Chunks)
			{
				Chunks=null;
			}
			if(_tipRq.numChildren>0)
			{
				for(var a:int=0;a<_tipRq.numChildren;a++)
				{
					_tipRq.removeChildAt(a);
					
				}
			}
			if(_rq.numChildren>0)
			{
				for(var i:int=0;i<_rq.numChildren;i++)
				{
					_rq.removeChildAt(i);
				}
			}
		}
		private function playBtnClick(event:MouseEvent):void
		{
			if(_isShowPicLog==false)
			{
				_isShowPicLog=true;
				_pauseBtn.visible=true;
				_playBtn.visible=false;
			}else
			{
				_isShowPicLog=false;
				_playBtn.visible=true;
				_pauseBtn.visible=false;
			}
		}
		
		
		private var _chunksObject:Object;
		private var _chunksId:int = 0;
		private var _chunksShare:int = 0;
		private var _chunksType:int = 0;//0为未调度； 1为http调度； 2为p2p调度 ；3为已经有正确数据
		private var _httpBuffer:int=0;
		
		private function onRun(event:Event):void
		{
			if(!_isShowPicLog || !RectManager || !RectManager.dataManager )
			{
				return;
			}
            drawMap();
			//changeFrame();
			_startNum = RectManager.dataManager.playHead;
			if (RectManager.dataManager.chunks != null)
			{
				_chunksObject = RectManager.dataManager.chunks.chunksObject as Object;
				_chunksId = 0;
				_chunksShare = 0;
				_chunksType = 0;

				_httpBuffer=_httpBufferLength + _startNum;
				/*if(_httpBuffer<_allNum)
				{
					for(var c:int = _startNum; c < _httpBuffer; c++  )
					{
						var httpRect:Pian = _rq.getChildAt(c) as Pian;
						httpRect.gotoAndStop(4);
						//Chunks[c] = c;
					}
				}*/
				//for (var a:String in _chunksObject)
				for (var a:String in Chunks)
				{
					var current:MovieClip = _rq.getChildAt(int(a)) as MovieClip;					
					
					if(_chunksObject[a] == null)
					{
						if (_startNum < uint(a) && _httpBuffer > uint(a))
						{
							current.gotoAndStop(4);
						}
						else
						{
							current.gotoAndStop(1);
						}
						continue;
					}
					//
					_chunksId = int(a);
					_chunksShare = int(_chunksObject[a].share);
					_chunksType = int(_chunksObject[a].iLoadType);
					var chunkRect:Pian = _rq.getChildAt(_chunksId) as Pian;
					//Chunks[_chunksId] = _chunksId;	
					if(RectManager.dataManager.chunks.getChunk(_chunksId).getShareLevel()!=0)
					{
						chunkRect.txt.text=RectManager.dataManager.chunks.getChunk(_chunksId).getShareLevel()
					}
					switch (_chunksType)
					{
						case 0 :
							if (_startNum < uint(a) && _httpBuffer > uint(a))
								current.gotoAndStop(4);
							else
								current.gotoAndStop(1);
							break;
						case 1 :
							chunkRect.gotoAndStop(3);
							break;
						case 2 :
							if (_startNum < uint(a) && _httpBuffer > uint(a))
							{
								current.gotoAndStop(4);
							}
							else
							{
								chunkRect.gotoAndStop(6);
							}
								
							break;
						case 3 :
							if (_chunksId>=_startNum)
							{
								if (_chunksId<_httpBuffer)
								{
									chunkRect.gotoAndStop(2);
								}
								else
								{
									chunkRect.gotoAndStop(5);
								}
							}
							else
							{
								chunkRect.gotoAndStop((RectManager.dataManager.chunks.getChunk(_chunksId).getShareLevel()+8));
							}
							break;
					}
				}
			}else
			{
				changeFrame();
			}
		}
	
		private function drawMap():void
		{
			if (0 == _allNum)
			{
				if (RectManager && RectManager.dataManager && RectManager.dataManager.fileTotalChunks != 0)
				{
					_allNum = RectManager.dataManager.fileTotalChunks;
					_httpBufferLength = RectManager.dataManager.httpBufferLength;
					
					for (var i:int=0; i<_allNum; i++)
					{
						Chunks[i] = i;
						var rect:Pian=new Pian();
						rect.stop();
						rect.id=i;
						var num:int=Math.floor((_width-20)/(_rectWidth+1));
						
						rect.x=(i%num)*(_rectWidth+1);
						rect.y=int(i/num)*(_rectHeight+1);
						_rq.addChild(rect);
						rect.addEventListener(MouseEvent.CLICK,onRectClick);
					}
					
					
				/*	var showPic:ShowPic = new ShowPic  ;
					addChild(showPic);
					showPic.y = 180;*/
					addScrollbar();
				}
			}
		}
		
		private function addScrollbar():void{
			if (_rq.height > 180)
			{
				scrollbar=new UIScrollBar();
				this.addChildAt(scrollbar,0);
				scrollbar.x = _width-17;
				scrollbar.y = -1;
				scrollbar.height = 180;
				scrollbar.setScrollProperties(maskMc.height, 0, _rq.height - maskMc.height, 30);
				scrollbar.addEventListener(ScrollEvent.SCROLL, onScroll);
				scrollbar.update();
			}
		}
		private var tip:Tip;
		
		private function onRectClick(event:MouseEvent):void
		{
			timer.reset();
			if(_tipRq.numChildren>=1)
			{
				_tipRq.removeChildAt(0);
			}
			tip=new Tip();
			tip.txt.text=event.currentTarget.id;
			tip.pian.gotoAndStop(event.currentTarget.currentFrame);
			tip.pian.txt.text=event.currentTarget.txt.text;
			_tipRq.addChild(tip);
			var point:Point=event.currentTarget.parent.localToGlobal(new Point(event.currentTarget.x,event.currentTarget.y));
			var point2:Point=tip.parent.globalToLocal(point);
			tip.x=point2.x;
			tip.y=point2.y;
			
			timer.start();
		}
	
		private function rectSort():void
		{
			if(_rq.numChildren>0)
			{
				var num:int=Math.floor((_width-20)/(_rectWidth+1));
				for(var g:int=0;g<_rq.numChildren;g++)
				{
					var pian:MovieClip=_rq.getChildAt(g) as MovieClip;
					pian.x=(g%num)*(_rectWidth+1);
					pian.y=int(g/num)*(_rectHeight+1);
				}
				if(scrollbar)
				{
					if(_rq.height > 180)
					{
						scrollbar.visible=true;
						scrollbar.x = _width-17;
				    	scrollbar.y = -1;
				    	scrollbar.update()
					}else
					{
						scrollbar.visible=false;
					}
					
				}else
				{
					addScrollbar();
				}
				
			}

			_rl.y=180;
			_bg.width=_width;
			_bg.x=-2;
		}
		private function onTimer(event:TimerEvent):void
		{
			if(_tipRq.numChildren!=0)
			{
				_tipRq.removeChildAt(0);
			}
		}
		private function onScroll(event:ScrollEvent):void
		{
			_rq.y = maskMc.y - event.position;
		}
		override public function setSize(w:Number,h:Number):void
		{
			if (_width!=w||_height!=h)
			{
				_width = w;
				_height = h;
				
				
				rectSort();
				
				//maskMc.graphics.drawRect(0,0,1170,180);
				maskMc.graphics.clear();
				maskMc.graphics.beginFill(0x123456,0.8);
				maskMc.graphics.drawRect(0,0,_width-17,180);
			}
		}
		
		private function changeFrame():void
		{
			if(Chunks)
			{
				for (var i:String in Chunks)
				{
					var current:MovieClip = _rq.getChildAt(int(i)) as MovieClip;
					current.gotoAndStop(1);
					current.txt.text="";
				}
			}
		}
	}
}