//
//  SecondViewController.m
//  BlockRetainCircleDemo
//
//  Created by chenlong on 2021/3/17.
//

#import "SecondViewController.h"
#import "MyObject.h"

@interface SecondViewController ()
{
    NSString *name;
}
@property (nonatomic, strong) MyObject *obj;
@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Second VC";
    name = @"Alice";
    
    self.obj = [[MyObject alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.obj start:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSLog(@"name: %@", strongSelf->name);
    }];
    
}

- (void)dealloc
{
    NSLog(@"OOPS! ⚠️⚠️⚠️ %s", __PRETTY_FUNCTION__);
}

@end
