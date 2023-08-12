#import "SAConfigOptions.h"

NS_ASSUME_NONNULL_BEGIN

@interface SAConfigOptions (Exception)

/// 是否自动收集 App Crash 日志，该功能默认是关闭的
// 对于 OC 来说, 在 M 文件里面, 将所有的属性都定义好, 因为这是和内存分配有关的.
// 然后在 H 文件里面, 根据业务功能将 property 进行分别暴露, 这是一个非常好的编码的方式. 
@property (nonatomic, assign) BOOL enableTrackAppCrash API_UNAVAILABLE(macos);

@end

NS_ASSUME_NONNULL_END
