package com.p2p_live.data
{
	public class DescTaskList
	{
		/**
		 * 存放视频文件头信息的地址数组 
		 */		
		private var headerArr:Array;
		/**
		 * 存放视频数据块地址的对象
		 */	
		private var blockObj:Object;
		/**
		 *最新的head 
		 */		
		private var newHead:String="";
		private var header:String=".header";
		
		public function addHead(str:String):void{
			var arr:Array=new Array;
			if(str==newHead){
				return;
			}else{
				newHead=str;
				arr=str.split("~_~");
			}
			//1358083644.header
			//此处存放的是纯数据
			for(var i:int=0;i<arr.length;i++){
				if(arr[i]){
					headerArr.push(uint(arr[i]));
				}
			}
//			trace("headerArr:"+headerArr);
			
		}

//		private function getHead(cuttrentCreatTime:String):String{
//			var str:String;
//			for(var i:int=0;i<headerArr.length;i++){
//				if(headerArr[i]==cuttrentCreatTime){
//					return headerArr[i]; 
//				}
//			}
//			return str;
//		}
		/**
		 * 如果查找到，返回数据；如果没有，返回一个最大值，该值为uint.MAX_VALUE，值为uint.MAX_VALUE相当没有找到下一个值
		 * @param cuttrentHead isHaveHead是否附带".header"
		 * @return 
		 * 
		 */		
		public function getNextHead(cuttrentHead:uint,isHaveHead:Boolean=true):String{
			
			var max:uint=uint.MAX_VALUE;
			for(var i:int=0;i<headerArr.length;i++){
				//查找在比当前的head数大的数据里找最小的数据
				if(headerArr[i]>cuttrentHead&&max>headerArr[i]){
					max=headerArr[i];
				}
			}
			if(isHaveHead){
				if(max==uint.MAX_VALUE){
				 	return "";
				}else{
				 	return max+header;
				}
			}
			
			//如果查找到，返回数据；如果没有，返回一个最大值，该值不会小于cuttrentHead
			return ""+max;
		}
		
		/**
		 *判断是否切换头文件 
		 * @param cuttrentHead
		 * @param nextClip
		 * @return 
		 * 
		 */
		public function isChangHead(cuttrentHead:uint,nextClip:uint):Boolean{
			var bool:Boolean=false;
			if(Number(getNextHead(cuttrentHead,false))<=nextClip){
				return true;
			}
			return bool
		}
		/**
		 * 删除单个的head头
		 * @param creatTime
		 * 
		 */
		public function delHead(cuttrentHead:uint):void{
			for(var i:int=0;i<headerArr.length;i++){
				if(headerArr[i]==cuttrentHead){
					headerArr.splice(i,1);
				}
			}
//			trace(headerArr);
		}
		
		public function clearHead():void{
			headerArr = new Array();
		}
		
		/**
		 * <ul>dugString
		 * elemet.name+"~_~"+str.match(reg)[1]+"~_~"+str.match(reg)[2]+"~_~"+str.match(reg)[3]+"~_~"+elemet.checksum+"\n";
		 * 2013011416/1358152280_7320_584357.dat~_~1358152280~_~7320~_~584357~_~3456453129+"\n"
		 * </ul>
		 * @param obj{"header":头文件,"clip":\n和_分开的数据}
		 * 
		 */
		public function addDesc(obj:Object):void{
			addHead(String(obj["header"]));
			var arr:Array=new Array;
			var datArr:Array=new Array;
			arr=String(obj["clip"]).split("\n");
			//trace("clip "+arr)
			var taskListBlock:TaskListBlock;
			for(var i:int=0;i<arr.length;i++){
				if(arr[i]){
					datArr=arr[i].split("~_~");
					if(datArr.length==5){
//						for(var j:int=0;j<datArr.length;j++){
							
							taskListBlock=new TaskListBlock;
							taskListBlock.name=datArr[0];
							taskListBlock.creatTime=datArr[1];
							taskListBlock.duration=datArr[2];
							taskListBlock.size=datArr[3];
							taskListBlock.checksum=datArr[4];
//							trace("addClip("+datArr[1]+",taskListBlock);")
							addClip(datArr[1],taskListBlock);
//						}
					}
				}
			}
		}
		
		public function addClip(key:uint,obj:TaskListBlock):void{
			blockObj[key]=obj
		}
		
		public function getClip(cuttrentHead:uint):Object{
			return blockObj[cuttrentHead];
		}
		
		public function getNextClip(cuttrentHead:uint):Object{
			var max:uint=uint.MAX_VALUE;
			for(var i:String in blockObj){
				//查找在比当前的head数大的数据里找最小的数据
				if(uint(i)>cuttrentHead&&max>uint(i)){
					max=uint(i);
				}
			}
			
			if(max==uint.MAX_VALUE){
				return null;
			}
			
			
			//如果查找到，返回数据；如果没有，返回一个最大值，该值不会小于cuttrentHead
			return blockObj[max];
		}
		/**
		 * 删除单个
		 * @param creatTime
		 * 
		 */
		public function delClip(cuttrentHead:uint):void{
			try{
				blockObj[cuttrentHead]=null;
				delete blockObj[cuttrentHead];
			}catch(err:Error){
				trace(this+">>>"+err.getStackTrace())
			}
		}
		
		
		/**
		 *清楚所有 
		 * 
		 */
		public function clearClip():void{
			blockObj  = new Object();
		}
		/**
		 * 清空 headerArr 和 blockObj
		 * 
		 */		
		public function clear():void
		{
			newHead="";
			clearHead();
			clearClip();
		}
		
		public function DescTaskList(single:Singleton=null)
		{
			clear();
			if(single==null){throw new Error("DescTaskList no  singleton");}
		}
		public static function getInstance():DescTaskList
		{
			if(instance==null){
				instance=new DescTaskList(new Singleton());
			}
			return instance;
		}
		private static var instance:DescTaskList=null;
	}
}
class Singleton{}