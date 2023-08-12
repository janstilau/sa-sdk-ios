#import <Foundation/Foundation.h>
#import "SAModuleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SAExceptionManager : NSObject <SAModuleProtocol>

+ (instancetype)defaultManager;

@property (nonatomic, assign, getter=isEnable) BOOL enable;
@property (nonatomic, strong) SAConfigOptions *configOptions;

@end

NS_ASSUME_NONNULL_END
