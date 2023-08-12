#import <Foundation/Foundation.h>
#import "SAModuleProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface SAModuleManager : NSObject <SAOpenURLProtocol>

+ (void)startWithConfigOptions:(SAConfigOptions *)configOptions;

+ (instancetype)sharedInstance;

- (BOOL)isDisableSDK;

/// 关闭所有的模块功能
- (void)disableAllModules;

/// 更新数据接收地址
/// @param serverURL 新的数据接收地址
- (void)updateServerURL:(NSString *)serverURL;
@end

#pragma mark -

@interface SAModuleManager (Property)

@property (nonatomic, copy, readonly, nullable) NSDictionary *properties;

@end

#pragma mark -

@interface SAModuleManager (ChannelMatch) <SAChannelMatchModuleProtocol>
@end

#pragma mark -

@interface SAModuleManager (DebugMode) <SADebugModeModuleProtocol>

@end

#pragma mark -
@interface SAModuleManager (Encrypt) <SAEncryptModuleProtocol>

@property (nonatomic, strong, readonly) id<SAEncryptModuleProtocol> encryptManager;

@end

#pragma mark -

@interface SAModuleManager (DeepLink) <SADeepLinkModuleProtocol>

@end

#pragma mark -

@interface SAModuleManager (AutoTrack) <SAAutoTrackModuleProtocol>

@end

#pragma mark -

@interface SAModuleManager (Visualized) <SAVisualizedModuleProtocol>

@end

#pragma mark -

@interface SAModuleManager (JavaScriptBridge) <SAJavaScriptBridgeModuleProtocol>

@end

@interface SAModuleManager (RemoteConfig) <SARemoteConfigModuleProtocol>

@end

NS_ASSUME_NONNULL_END
