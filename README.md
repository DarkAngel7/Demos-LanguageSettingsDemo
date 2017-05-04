
# 前言

随着公司业务的发展，App版本的迭代，相信不少App都需要英文化（国际化）。App英文化，不外乎这三点：

1. 纯代码中引用的strings国际化；
2. Storyboard/Xib国际化；
3. Info.plist国际化。

具体这三种分别如何操作，怎么国际化，这里不再赘述。一般App做了国际化，那么在用户切换手机系统Settings里的Language时，App就会切换成对应的语言（前提是做个该语言国际化）。那么如果想实现**微博**和**微信**等App，在App内部实现切换语言，应该怎么做呢？如何做，才能更加优雅的动态切换语言呢？

下面，讲一讲如何在iOS App内优雅的动态切换语言。

# 调研

如果有相关需求，一般成熟的App都会怎么做呢？这里我们来看一下**微博**和**微信**。

**微博**：

![](http://ww3.sinaimg.cn/large/006tKfTcly1ff9jfo5a8ig306y0cctz0.gif)

**微信**：

![](http://ww1.sinaimg.cn/large/006tKfTcly1ff9d5ezj9jg30680b3kif.gif)

对比一下可以看出，微博整体的效果比微信好很多，丝滑流畅。

***这里注意一下细节***：我在微博的个人中心是故意上滑了一下，然后点击进入设置，进行语言切换，可以看到切换时很自然，然后返回个人中心时，页面`scrollView`的`contentOffset`并没有发生变化，由此可以推测：

**<u>微博的思路是，在切换语言时，发送通知`NSNotification`，所有的UI控件监听通知，然后在适当的时候刷新UI</u>**。那么其实这么写，需要做的东西很多，或是通过Base类来实现，或是通过`runtime`实现，总之`Button`、`Label`、`TextField`等等都需要有一套统一的更新机制，可能不是一个最简单的办法。

**<u>而微信切换的方案是，刷新`keyWindow`的`rootViewController`，然后跳转到设置页，所以你会看到切换语言的一瞬间界面出现匪夷所思的bug，如下图</u>**

![](http://ww1.sinaimg.cn/large/006tKfTcly1ff9iduf60aj306y0cbjrm.jpg)

其实微信的方案是个最简单的方案，只不过没有处理好这个小系统bug。

# 方案

## 核心方法

### NSBundle

其实大家应该知道，无论是代码还是Storyboard/Xib，显示的国际化字符串都会走这个方法，传入一个`key`，获取`localizedString`。

`NSBundle`的方法：

```objective-c
- (NSString *)localizedStringForKey:(NSString *)key value:(nullable NSString *)value table:(nullable NSString *)tableName;
```

比如我们常用的宏`NSLocalizedString(@"done", nil)`

```objective-c
#define NSLocalizedString(key, comment) \
	    [NSBundle.mainBundle localizedStringForKey:(key) value:@"" table:nil]
```

那么为何，系统切换语言的时候，此方法返回的就是对应语言（前提做了该语言的国际化）的字符串呢？原因在是哪个`Object`调用了这个方法，一般默认的都是`NSBundle.mainBundle`这个对象。系统语言是en，`NSBundle.mainBundle`就是

```
po [NSBundle mainBundle]

NSBundle </Users/DarkAngel/Library/Developer/CoreSimulator/Devices/CF831783-E4A6-4EC2-AB99-E04304331C3A/data/Containers/Bundle/Application/016AC9F4-91F5-41A7-A054-81621955D472/URWorkClient.app/en.lproj>
```

而是默认中文语言时，

```
po [NSBundle mainBundle]

UWBundle </Users/DarkAngel/Library/Developer/CoreSimulator/Devices/CF831783-E4A6-4EC2-AB99-E04304331C3A/data/Containers/Bundle/Application/016AC9F4-91F5-41A7-A054-81621955D472/URWorkClient.app> (loaded)
```

所以，切换语言，其实切换了`bundle`对象，所以不同语言的`bundle`对象，就会根据`key`返回不同的`localizedString`。

### NSUserDefaults

其实语言设置，只要修改`AppleLanguages`对应的值就好了。这样才能加载正确语言的`Storyboard/Xib`，以及一些`resources`(图片之类的)。

## 实现思路

方案其实很简单，每次切换语言，把用户选择的语言保存在本地，同时更改`bundle`对象，然后刷新页面就可以了。

![](http://ww2.sinaimg.cn/large/006tKfTcly1ff9ji4gz3kg306y0cce09.gif)

## 技术细节

### 保存用户设置

很简单，保存在`NSUserDefaults`里。

这里需要说明的是**跟随手机系统**，即清除用户自定义设置，只需要将`AppleLanguages`字段设为`nil`即可。

但是当`AppleLanguages`字段设为nil，你再去获取它的值时，会发现他已经变成了系统语言的默认值。

.h

```objective-c
/**
 设置类
 */
@interface UWConfig : NSObject
/**
 用户自定义使用的语言，当传nil时，等同于resetSystemLanguage
 */
@property (class, nonatomic, strong, nullable) NSString *userLanguage;
/**
 重置系统语言
 */
+ (void)resetSystemLanguage;
@end
```

.m

```objective-c
#import "UWConfig.h"

static NSString *const UWUserLanguageKey = @"UWUserLanguageKey";
#define STANDARD_USER_DEFAULT  [NSUserDefaults standardUserDefaults]

@implementation UWConfig
+ (void)setUserLanguage:(NSString *)userLanguage
{
    //跟随手机系统
    if (!userLanguage.length) {
        [self resetSystemLanguage];
        return;
    }
    //用户自定义
    [STANDARD_USER_DEFAULT setValue:userLanguage forKey:UWUserLanguageKey];
    [STANDARD_USER_DEFAULT setValue:@[userLanguage] forKey:@"AppleLanguages"];
    [STANDARD_USER_DEFAULT synchronize];
}

+ (NSString *)userLanguage
{
    return [STANDARD_USER_DEFAULT valueForKey:UWUserLanguageKey];
}

/**
 重置系统语言
 */
+ (void)resetSystemLanguage
{
    [STANDARD_USER_DEFAULT removeObjectForKey:UWUserLanguageKey];
    [STANDARD_USER_DEFAULT setValue:nil forKey:@"AppleLanguages"];
    [STANDARD_USER_DEFAULT synchronize];
}

@end
```

在需要的地方调用即可，如

```objective-c
   if (indexPath.row == 0) {
        [UWConfig setUserLanguage:nil];
    } else if (indexPath.row == 1) {
        [UWConfig setUserLanguage:@"zh-Hans"];
    } else {
        [UWConfig setUserLanguage:@"en"];
    }
```

### 切换Bundle

当需要展示内容时，才需要用到`bundle`，我们要手动切换`bundle`对象，就用到了这几个方法：

```objective-c
+ (nullable instancetype)bundleWithPath:(NSString *)path;
- (nullable instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

+ (nullable instancetype)bundleWithURL:(NSURL *)url NS_AVAILABLE(10_6, 4_0);
- (nullable instancetype)initWithURL:(NSURL *)url NS_AVAILABLE(10_6, 4_0);
```

这里直接上代码

.h

```objective-c
@interface NSBundle (UWUtils)

+ (BOOL)isChineseLanguage;

+ (NSString *)currentLanguage;

@end
```

.m

```objective-c
#import "NSBundle+UWUtils.h"

@interface UWBundle : NSBundle

@end

@implementation NSBundle (UWUtils)

+ (BOOL)isChineseLanguage
{
    NSString *currentLanguage = [self currentLanguage];
    if ([currentLanguage hasPrefix:@"zh-Hans"]) {
        return YES;
    } else {
        return NO;
    }
}

+ (NSString *)currentLanguage
{
    return [UWConfig userLanguage] ? : [NSLocale preferredLanguages].firstObject;
}

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //动态继承、交换，方法类似KVO，通过修改[NSBundle mainBundle]对象的isa指针，使其指向它的子类UWBundle，这样便可以调用子类的方法；其实这里也可以使用method_swizzling来交换mainBundle的实现，来动态判断，可以同样实现。
        object_setClass([NSBundle mainBundle], [UWBundle class]);
    });
}

@end

@implementation UWBundle

- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName
{
    if ([UWBundle uw_mainBundle]) {
        return [[UWBundle uw_mainBundle] localizedStringForKey:key value:value table:tableName];
    } else {
        return [super localizedStringForKey:key value:value table:tableName];
    }
}

+ (NSBundle *)uw_mainBundle
{
    if ([NSBundle currentLanguage].length) {
        NSString *path = [[NSBundle mainBundle] pathForResource:[NSBundle currentLanguage] ofType:@"lproj"];
        if (path.length) {
            return [NSBundle bundleWithPath:path];
        }
    }
    return nil;
}

@end
```

这里涉及到了`runtime`的使用，代码中有注释，这里就不展开了。

### 刷新页面

用微信的思路，简单化，不必要处理很多，我们只要替换`keyWindow`的`rootViewController`就好，同时解决微信的bug。

```objective-c
    UITabBarController *tbc = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateInitialViewController];
    //我这里的storyboard为了便于多人合作，这里只包含根tabBarController和多个nvc，每个nvc只有自己的rootViewController
	//跳转到个人中心
    tbc.selectedIndex = 4;
	//创建设置页面
    UWSettingViewController *vc1 = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:NSStringFromClass([UWSettingViewController class])];
    vc1.hidesBottomBarWhenPushed = YES;
    //创建语言切换页
    UWLanguageSettingsViewController *vc2 = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:NSStringFromClass([UWLanguageSettingsViewController class])];
    vc2.hidesBottomBarWhenPushed = YES;
    UINavigationController *nvc = tbc.selectedViewController;
    //备用
    NSMutableArray *vcs = nvc.viewControllers.mutableCopy;
    [vcs addObjectsFromArray:@[vc1, vc2]];
    //解决奇怪的动画bug。异步执行
    dispatch_async(dispatch_get_main_queue(), ^{
        //注意刷新rootViewController的时机，在主线程异步执行
        //先刷新rootViewController
        [UIApplication sharedApplication].keyWindow.rootViewController = tbc;
        //然后再给个人中心的nvc设置viewControllers
        nvc.viewControllers = vcs;
        //一些UI提示，可以提供更友好的用户交互（也可以删掉）
        [UWProgressHUD showLoadingWithMessage:NSLocalizedString(UWSettingMessage, nil)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UWProgressHUD dismiss];
        });
    });
```

整体下来，就可以实现在App内优雅的切换语言。

# 总结

其实在实践过程中，坑还是很多的，欢迎Issue。
