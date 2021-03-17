//
//  MyObject.m
//  BlockRetainCircleDemo
//
//  Created by chenlong on 2021/3/17.
//

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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
