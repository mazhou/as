package lee.utils{
	import flash.display.DisplayObject;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getQualifiedSuperclassName;
	import flash.system.ApplicationDomain;
	public final class ClassUtil{
		public function ClassUtil() {
			throw new Error("ClassUtil类无需实例化！");
		}
		//在某个应用程序域中根据类定义的名称返回该类的一个实例
		public static function instanceByName(name:String,applicationDomain:ApplicationDomain):Object{
			var cla:Class=ClassUtil.classByName(name,applicationDomain);
			return cla?(new cla()):null;
		}
		//在某个应用程序域中根据类定义的名称返回该类定义
		public static function classByName(name:String,applicationDomain:ApplicationDomain):Class{
			try
			{
				return applicationDomain.getDefinition(name) as Class;
			}
			catch(e:Error) {}
			return null;
		}
		//返回一个实例对象的类定义
		public static function classByInstance(instance:Object):Class{
			try
			{
				return getDefinitionByName(getQualifiedClassName(instance)) as Class;
			}
			catch(e:Error)
			{
				if(instance is DisplayObject)
				{
					try
				    {
					    return instance.loaderInfo.applicationDomain.getDefinition(getQualifiedClassName(instance)) as Class;
				    }
				    catch(e:Error) {}
				}
			}
			return null;
		}
		//返回一个实例对象的父级类定义
		public static function superClassByInstance(instance:Object):Class{
			try
			{
				return getDefinitionByName(getQualifiedSuperclassName(instance)) as Class;
			}
			catch(e:Error)
			{
				if(instance is DisplayObject)
				{
					try
				    {
					    return instance.loaderInfo.applicationDomain.getDefinition(getQualifiedSuperclassName(instance)) as Class;
				    }
				    catch(e:Error) {}
				}
			}
			return null;
		}
		//在startClass类中搜索类成员property
		//如果存在类成员property并且也存在property的field属性，就返回该属性的值
		//否则就在startClass类的基类中执行同样的操作，一直到stopClass类
		public static function valueByPropertyField(property:String,field:String,startClass:Class,stopClass:Class):Object{
			//trace(startClass,stopClass);
			try
			{
				var obj:Object=startClass[property];
				if(obj&&obj[field])
			    {
					return obj[field];    
			    }
			}
			catch(e:Error){}
			if(startClass!=stopClass)
			{
				return valueByPropertyField(property,field,(getDefinitionByName(getQualifiedSuperclassName(startClass)) as Class),stopClass);
			}
			else
			{
				return null;
			}
		}
    }
}