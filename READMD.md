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

