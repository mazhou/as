package 
{
	import com.hls_p2p.data.Block;
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.LiveVodConfig;
	
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
	
	public class HLSRectLog extends BaseUI
	{
		private var _rq:Sprite;
		private var maskMc:Sprite;
		private var scrollbar:UIScrollBar;
		
		//private var _allNum:int = 0;//总num
		
		private var _blockList:Object = new Object();
		private var _blockArray:Array = new Array();
		
		private var _startNum:Number = 0;//播放点
		private var _httpBufferLength:Number = 0;
		
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
		public function HLSRectLog()
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
			
			//this.addEventListener(Event.ENTER_FRAME,onRun);
			var temptimer:Timer = new Timer(100);
			temptimer.addEventListener(TimerEvent.TIMER,onRun);
			temptimer.start();
			timer.addEventListener(TimerEvent.TIMER,onTimer);
			
		}
		/*public function start():void
		{
			if( false == this.hasEventListener(Event.ENTER_FRAME) )
			{
				this.addEventListener(Event.ENTER_FRAME,onRun);
			}
		}*/
		public function clear():void
		{
			_playBtn.removeEventListener(MouseEvent.CLICK,playBtnClick);
			_pauseBtn.removeEventListener(MouseEvent.CLICK,playBtnClick);
			_bg					= null;
			_playBtn 			= null;
			_pauseBtn 			= null;
			RectManager.rectLog = null;
			
			reset();
			
			if(timer)
			{
				timer.stop();
				timer.removeEventListener(TimerEvent.TIMER,onTimer);
				timer = null;
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
			
			removeChild(_rq);
			removeChild(_tipRq);
			removeChild(maskMc);
			_rq = null;
			_tipRq = null;
			maskMc = null;
			_rl = null;
		}
		public function reset():void
		{
			_block = null;
			_piece = null;
			RectManager.dataManager = null;
			_blockList  = new Object();
			_blockArray = new Array();
			
			if( scrollbar && scrollbar.hasEventListener(ScrollEvent.SCROLL) )
			{
				scrollbar.removeEventListener(ScrollEvent.SCROLL, onScroll);
				scrollbar = null;
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
		private var _chunksId:Number = 0;
		private var _chunksShare:int = 0;
		private var _chunksType:int = 0;//0为未调度； 1为http调度； 2为p2p调度 ；3为已经有正确数据
		private var _httpBuffer:Number=0;
		
		private var current:MovieClip;
		
		private function leftOrRight(i:int,str:String):String
		{
			if(i != 0)
			{
				return String(str+"r");
			}
			return String(str+"l");
		}
		
		private var _block:Block;
		private var _piece:Piece;
		
		private function onRun(event:Event):void
		{
			stage.frameRate = 50;
			if(!_isShowPicLog || !RectManager || !RectManager.dataManager )
			{
				return;
			}
			drawMap_live();
			
			//return;
			
			_startNum 		  = RectManager.dataManager.getPlayingBlockID();
			_blockArray 	  = RectManager.dataManager.blockArray;
			_httpBufferLength =  RectManager.dataManager.getBufferTime();
			
			if ( _blockArray.length != 0)
			{
				_blockList 	= RectManager.dataManager.blockList;				
				
				_chunksObject = new Object();
				_chunksId = 0;
				_chunksShare = 0;
				_chunksType = 0;
				
				_httpBuffer=_httpBufferLength + _startNum;
				
				var tempP2PTaskArr:Array = RectManager.dataManager.getP2PTaskArray();
				
				var currentIdx:uint = 0;
				
				for(var i:int=0 ; i<_blockArray.length ; i++)
				{
					_block = _blockList[_blockArray[i]];
					if( null == _block.pieceIdxArray)
					{
						continue;
					}
					for(var j:int=0 ; j<_block.pieceIdxArray.length ; j++)
					{						
						current = Chunks[currentIdx] as MovieClip;	
						if( null == current )
						{
							//current.visible = false;
							currentIdx++;
							continue;
						}
						
						current.visible = true;
						current.name     = _block.id+"-"+j+"-"+_block.pieceIdxArray[j]["pieceKey"];
						
						_piece = RectManager.dataManager.getPiece(_block.pieceIdxArray[j]);
						
						if(_piece.share > 0)
						{
							current.txt.text = _piece.share>9 ? 9 : _piece.share;
						}
						
						if(_startNum <= _block.id && _httpBuffer >= _block.id)
						{
							/**紧急区之内*/
							if(_piece.isChecked)
							{
								/**有数据*/
								/**关键帧标签 "ppfr" "ppfl"*/
								current.gotoAndStop(leftOrRight(j,"ppf"));
							}
							else
							{
								/**没有数据*/
								/**关键帧标签 "pper" "ppel"*/
								current.gotoAndStop(leftOrRight(j,"ppe"));
							}							
						}
						else
						{
							/**紧急区之外*/
							
							if(_piece.isChecked)
							{
								/**有数据*/
								
								/**关键帧标签 "hfr" "hfl"*/
								if(_piece.from == "http")
								{
									/**http下载的数据*/
									current.gotoAndStop(leftOrRight(j,"hf"));
								}
								else
								{										
									/**p2p下载的数据*/
									/**关键帧标签 "pfr" "pfl"*/
									current.gotoAndStop(leftOrRight(j,"pf"));
								}									
							}
							else
							{
								/**没有数据*/
								if( _httpBuffer < _block.id && tempP2PTaskArr )
								{									
									for(var p:int=0 ; p<tempP2PTaskArr.length ; p++ )
									{
										if( /*_piece.blockID*/_block.id == tempP2PTaskArr[p].id )
										{
											/**在p2p请求范围内*/
											/**关键帧标签 "per" "pel";
											 * */
											current.gotoAndStop(leftOrRight(j,"pe"));
											break;
										}
									}
								}
								else
								{
									current.gotoAndStop(leftOrRight(j,"n"));
								}
								
							}							
						}
						currentIdx++;
					}
				}
				for( var q:int=currentIdx+1 ; q<_livetotalReckNum ; q++)
				{
					current = Chunks[currentIdx] as MovieClip;
					current.txt.text = "";
					current.visible = false;
				}
			}else
			{
				changeFrame();
			}
		}
		private var _livetotalReckNum:Number
		private function drawMap_live():void
		{			
			if (RectManager 
				&& RectManager.dataManager
				&& _rq.numChildren == 0)
			{
				
				var m:int = 0;
				_livetotalReckNum = Math.round(RectManager.dataManager.getMemorySize()/(188*1024))+300;//3000//
				for(var i:int=0 ; i<_livetotalReckNum ; i++)
				{						
					var rect:M3U8Pian=new M3U8Pian();
					rect.stop();
					
					rect.id       = i;							
					var num:int   = Math.floor((_width-20)/(_rectWidth+1));							
					rect.x		  = (m%num)*(_rectWidth+1);
					rect.y		  = int(m/num)*(_rectHeight+1);
					rect.name     = rect.id;
					rect.txt.text = "";
					
					Chunks[i] = rect;
					
					/**关键帧标签 "nr" "nl"*/
					rect.gotoAndStop("none");
					rect.visible = false;							
					_rq.addChild(rect);
					rect.addEventListener(MouseEvent.CLICK,onRectClick);
					
					m++;												
				}
				addScrollbar();
			}
		}
		
		private function addScrollbar():void{
			if (_rq.height > 180)
			{
				scrollbar=new UIScrollBar();
				this.addChildAt(scrollbar,0);
				scrollbar.x = _width-17;
				scrollbar.y = -1;
				scrollbar.opaqueBackground = null;
				scrollbar.height = 180;
				scrollbar.setScrollProperties(maskMc.height, 0, _rq.height - maskMc.height, 30);
				scrollbar.addEventListener(ScrollEvent.SCROLL, onScroll);
				scrollbar.update();
			}
		}
		
		private var tip:MovieClip;
		
		private function onRectClick(event:MouseEvent):void
		{
			timer.reset();
			if(_tipRq.numChildren>=1)
			{
				_tipRq.removeChildAt(0);
			}
			if( RectManager.dataManager.getPlayType() == "LIVE" )
			{
				tip=new TipLive();
				tip.txtB.text = String(event.currentTarget.name).split("-")[0];
				tip.txtP.text = String(event.currentTarget.name).split("-")[1]+"-"+String(event.currentTarget.name).split("-")[2];
			}
			else
			{
				tip=new Tip();
				tip.txt.text=event.currentTarget.name;
			}
			
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
		private var delCurrent:MovieClip;
		private function changeFrame():void
		{
			/*if(_blockList.length > 0)
			{
				for(var i:int=0 ; i<_rq.numChildren ; i++)
				{					
					delCurrent:MovieClip = _rq.getChildAt(int(i)) as MovieClip;
					delCurrent.gotoAndStop(leftOrRight(j,"n"));
					delCurrent.txt.text="";					
				}
			}*/
		}
	}
}