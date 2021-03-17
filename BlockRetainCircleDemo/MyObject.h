//
//  MyObject.h
//  BlockRetainCircleDemo
//
//  Created by chenlong on 2021/3/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ExecuteBlock)(void);

@interface MyObject : NSObject

- (void)start:(ExecuteBlock)block;

@end

NS_ASSUME_NONNULL_END
