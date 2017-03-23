package lee.managers{
	public class RectManager extends Object{
		static public var showLogFun:Function;
		static public var showSpeedFun:Function;
		static public var dataManager:Object;
		static public var p2pTestStatistic:Object;
		static public var rectLog:Object;
		public function RectManager(){
		}
		static public function debug(...info):void{
			if(showLogFun!=null)
			{
				showLogFun.call(null,info);
			}
		}
		static public function debug2(...info):void{
			if(showLogFun!=null)
			{
				showLogFun.call(null,info);
			}
		}
		static public function debug3(...info):void{
			if(showLogFun!=null)
			{
				showLogFun.call(null,info);
			}
		}
		static public function debug4(...info):void{
			if(showSpeedFun!=null)
			{
				showSpeedFun.call(null,info);
			}
		}
		
		static public function box1(boo:Boolean):void{
			if(dataManager)
			{
				//trace("box1  "+!boo)
				dataManager.test_canP2PShare=boo;
			}
		}
		static public function box2(boo:Boolean):void{
			if(dataManager)
			{
				//trace("box2  "+!boo)
				dataManager.test_canP2PBufferShare=boo;
			}
		}
		static public function box3(boo:Boolean):void{
			if(dataManager)
			{
				dataManager.test_canP2PReceive=boo;
			}
		}
		static public function box5(boo:Boolean):void{
			if(p2pTestStatistic)
			{
				p2pTestStatistic.isShowSpeed=boo;
			}
		}
		static public function box6(boo:Boolean):void{
			if(rectLog)
			{
				rectLog.isShowPicLog=boo;
			}
		}
		static public function txtBtn(str:String):void{
			if(dataManager)
			{
				//dataManager.test_userID=str;
				dataManager.userName["myName"] = str;
			}
		}
	}
}