# weakSelf和strongSelf引起的奔溃

## 前言

在`OC`中，我们经常会遇到一个东西叫**循环引用**，毫无疑问，**循环引用**会导致内存泄漏，严重的时候，导致应用程序奔溃也是可能的。我们经常遇到的**循环引用**就是`Block`（或者`delegate`）所引起的，而解决的方式也是老生常谈的使用`weak`来弱引用被引用的对象，打破循环，这样就可以避免循环引用这个问题。

但是，如果你稍微不慎，有时候使用`weak`也会导致应用程序奔溃，造成难以挽回的后果。这篇文章就是简要说明下，如何正确地使用`weak`，以及有时候需要结合`strong`来避免**循环引用**的内存泄漏。

## Block循环引用

一个对象持有一个`Block`，这个`Block`中又引用了这个对象，这就是**循环引用**。最常见最简单的就是持有当前`self`，这也是在开发中经常遇到的情况。在`SecondViewController.m`中，比如：

```
#import "SecondViewController.h"
#import "MyObject.h"

@interface SecondViewController ()
@property (nonatomic, strong) MyObject *obj;
@property (nonatomic, copy) NSString *name;
@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Second VC";
    self.name = @"Alice";
    
    self.obj = [[MyObject alloc] init]; 
    [self.obj start:^{
        NSLog(@"name: %@", self.name);
    }];
    
}

- (void)dealloc
{
    NSLog(@"OOPS! ⚠️⚠️⚠️ %s", __PRETTY_FUNCTION__);
}

@end
```

在`MyObject.h`中

```
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ExecuteBlock)(void);

@interface MyObject : NSObject

- (void)start:(ExecuteBlock)block;

@end

NS_ASSUME_NONNULL_END
```

`MyObject.m`中

```
#import "MyObject.h"

@interface MyObject()
@property (nonatomic, copy) ExecuteBlock myBlock;
@end

@implementation MyObject

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initData];
    }
    return self;
}

- (void)initData
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.myBlock) {
            self.myBlock();
        }
    });
}

- (void)start:(ExecuteBlock)block
{
    self.myBlock = block;
}

@end
```

显然，`self`持有`obj`，`obj`持有`block`	（`start`方法的参数`block`）, `block`又持有`self`（`name`是当前`self`的一个属性），因此造成了显而易见的**循环引用**。

这种处理起来也是十分简单，一个`weak`就可以搞定：

```
self.obj = [[MyObject alloc] init];
__weak typeof(self) weakSelf = self;
[self.obj start:^{
    NSLog(@"name: %@", weakSelf.name);
}];
```

在这里，我们这样处理，有什么问题吗？答案是**没有任何问题**。

接着，我们把`name`换成`成员变量`，即：

```
@interface SecondViewController ()
{
    NSString *name;
}
@property (nonatomic, strong) MyObject *obj;
@end

......
self.obj = [[MyObject alloc] init];
__weak typeof(self) weakSelf = self;
[self.obj start:^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    NSLog(@"name: %@", strongSelf->name);
}];
...... 
```
注意，由于`name`是**成员变量**，不能使用`weakSelf `来引用`name`，因为它是一个**弱指针**。因此这里必须对`weakSelf `做一次强引用，即使用`strongSelf `来引用`name`。

想一下，当用户进入页面，在`10s`内返回上一级页面，待`block`被执行时，会发生什么？**应用程序奔溃！！！**

## Crash分析

奇怪！为什么会发生这个问题呢？感觉没问题了呀，使用`weakSelf`避免循环引用，使用`strongSelf `来引用成员变量，怎么就奔溃了呢？当`name`是属性时，即`weakSelf.name`时，并不会有任何问题，就只是将`name`由**属性**变成**成员变量**就不行了？

实际上，只要理解`OC`中的**消息发送**机制，你就基本能够知道上面所说的奔溃原因了。在`OC`中，对`nil`发送消息是**“合法”**的，因此，当使用**点语法**来访问时，实际上是访问**属性**（这里是`name`）的**getter**方法，因此不会发生奔溃。

但是，如果是获取**成员变量**的话，就不是方法了，而是通过**self指针直接访问其内部的成员变量的内存地址**，此时，当页面已经释放时，`self`已经不存在，`strongSelf`即为`nil`，可想而知，对一个不存在的**“对象”**，去访问所谓的**“成员变量”**，即`nil -> name`，奔溃就是在意料之中了。

## Crash解决

#### 一 尽量使用属性

这种方式其实本质上就是基于`OC`的消息机制，对`nil`发送消息是允许的。这样即使`self`被销毁，也不会存在任何的问题，因为你通过`strongSelf.name`调用的是方法，`OC`的消息机制允许你这样做。虽然有时候我们出于性能考虑，会直接使用**成员变量**进行获取，因为调用方法是有一定代价的，但是，在大多数情况下，这样的带来的性能考量还是可以接受的，可忽略的。

因此，要绝对安全，在`block`内部使用**属性**的方式获取，是一种可行的有效的方式。

#### 二 依然使用成员变量，对`weakSelf`做安全检查

如果你说我就是要使用`成员变量`来使性能达到最优解，那也无可厚非，这种也是我们开发中很有必要的一种应该必备的思想，但是，你要足够小心，来避免奔溃的发生。解决方式就是对`weakSelf`做安全检查，如：

```
self.obj = [[MyObject alloc] init];
__weak typeof(self) weakSelf = self;
[self.obj start:^{
    if (!weakSelf) return; // Security-check here.
    __strong typeof(weakSelf) strongSelf = weakSelf;
    NSLog(@"name: %@", strongSelf->name);
}];
```

## 总结

在开发中，一定要避免**循环引用**、**代理**所引起的内存泄漏(`memory leak`)，当然，相信对于大多数开发者来说，这种基本不需要思考，都可以习以为常的写上相应的关键字来或者中间层来避免这个问题，但是估计也有不少人会出现本文所说的**粗心大意**，导致线上出现奔溃的问题。`weak`并不是在所有遇到`block`的情况都需要使用的，比如系统提供的动画`API`:

```
[UIView animateWithDuration:1.0 animations:^{
    NSLog(@"name: %@", self->name);
}];
```

**过度的不必要的`weak`使用会使代码变得冗余并且产生不必要的性能问题！**





