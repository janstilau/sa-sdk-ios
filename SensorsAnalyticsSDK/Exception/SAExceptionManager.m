#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import "SAExceptionManager.h"
#import "SensorsAnalyticsSDK.h"
#import "SensorsAnalyticsSDK+Private.h"
#import "SAConstants+Private.h"
#import "SAModuleManager.h"
#import "SALog.h"
#import "SAConfigOptions+Exception.h"

#include <libkern/OSAtomic.h>
#include <execinfo.h>

static NSString * const kSASignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
static NSString * const kSASignalKey = @"UncaughtExceptionHandlerSignalKey";

static volatile int32_t kSAExceptionCount = 0;
static const int32_t kSAExceptionMaximum = 10;

static NSString * const kSAAppCrashedReason = @"app_crashed_reason";

@interface SAExceptionManager ()

@property (nonatomic) NSUncaughtExceptionHandler *defaultExceptionHandler;
@property (nonatomic, unsafe_unretained) struct sigaction *prev_signal_handlers;

@end

@implementation SAExceptionManager

+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    static SAExceptionManager *manager = nil;
    dispatch_once(&onceToken, ^{
        manager = [[SAExceptionManager alloc] init];
    });
    return manager;
}

- (void)setEnable:(BOOL)enable {
    _enable = enable;
    
    if (enable) {
        _prev_signal_handlers = calloc(NSIG, sizeof(struct sigaction));
        [self setupExceptionHandler];
    }
}

- (void)setConfigOptions:(SAConfigOptions *)configOptions {
    _configOptions = configOptions;
    self.enable = configOptions.enableTrackAppCrash;
}

- (void)dealloc {
    free(_prev_signal_handlers);
}

// 对
- (void)setupExceptionHandler {
    self.defaultExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&SAHandleException);
    
    struct sigaction action;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_SIGINFO;
    action.sa_sigaction = &SASignalHandler;
    int signals[] = {SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS};
    for (int i = 0; i < sizeof(signals) / sizeof(int); i++) {
        struct sigaction prev_action;
        int err = sigaction(signals[i], &action, &prev_action);
        if (err == 0) {
            char *address_action = (char *)&prev_action;
            char *address_signal = (char *)(_prev_signal_handlers + signals[i]);
            strlcpy(address_signal, address_action, sizeof(prev_action));
        } else {
            SALogError(@"Errored while trying to set up sigaction for signal %d", signals[i]);
        }
    }
}

#pragma mark - Handler

/*
 SIGABRT（信号中止）：当进程调用 abort 函数时，会向自身发送此信号。通常由库函数在检测到内部错误或严重的约束条件被破坏时调用 abort 函数。
 SIGILL（非法指令）：当进程试图执行一条非法指令时，会收到此信号。这通常表示程序镜像已损坏或存在硬件故障。
 SIGSEGV（段错误）：当进程试图访问其无权访问的内存区域时，会收到此信号。这通常表示程序存在指针错误或数组越界等问题。
 SIGFPE（浮点异常）：当进程执行了一条错误的算术运算指令时，会收到此信号。例如除以零或产生溢出。
 SIGBUS（总线错误）：当进程试图访问一个 CPU 无法物理寻址的内存地址时，会收到此信号。这通常是由于对齐问题导致的，例如试图从一个不是 4 的倍数的地址读取一个长整型。
 
 信号处理函数只是在接收到特定信号时被调用，它可以执行一些特定的操作来处理信号，但它并不能控制操作系统如何对待进程。
 */

// 信号处理函数.
static void SASignalHandler(int crashSignal, struct __siginfo *info, void *context) {
    int32_t exceptionCount = OSAtomicIncrement32(&kSAExceptionCount);
    if (exceptionCount <= kSAExceptionMaximum) {
        NSDictionary *userInfo = @{kSASignalKey: @(crashSignal)};
        NSString *reason = [NSString stringWithFormat:@"Signal %d was raised.", crashSignal];
        NSException *exception = [NSException exceptionWithName:kSASignalExceptionName
                                                         reason:reason
                                                       userInfo:userInfo];
        // 实际上, 无论是信号, 还是异常, 都是走了 handleUncaughtException 来进行记录.
        // 信号, 就是特殊的异常进行的处理.
        [SAExceptionManager.defaultManager handleUncaughtException:exception];
    }
    
    // 然后在这里, 触发了之前存储的信号处理函数.
    struct sigaction prev_action = SAExceptionManager.defaultManager.prev_signal_handlers[crashSignal];
    if (prev_action.sa_flags & SA_SIGINFO) {
        if (prev_action.sa_sigaction) {
            prev_action.sa_sigaction(crashSignal, info, context);
        }
    } else if (prev_action.sa_handler &&
               prev_action.sa_handler != SIG_IGN) {
        // SIG_IGN 表示忽略信号
        prev_action.sa_handler(crashSignal);
    }
}

// 异常处理函数.
static void SAHandleException(NSException *exception) {
    int32_t exceptionCount = OSAtomicIncrement32(&kSAExceptionCount);
    if (exceptionCount <= kSAExceptionMaximum) {
        [SAExceptionManager.defaultManager handleUncaughtException:exception];
    }
    
    // 在完成了 SDK 内部的对于崩溃的特殊处理之后, 还是要触发 SDK 注册之前的崩溃处理函数.
    if (SAExceptionManager.defaultManager.defaultExceptionHandler) {
        SAExceptionManager.defaultManager.defaultExceptionHandler(exception);
    }
}

- (void)handleUncaughtException:(NSException *)exception {
    if (!self.enable) {
        return;
    }
    @try {
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        // 在这里, 存储了调用堆栈的信息.
        if (exception.callStackSymbols) {
            properties[kSAAppCrashedReason] = [NSString stringWithFormat:@"Exception Reason:%@\nException Stack:%@", exception.reason, [exception.callStackSymbols componentsJoinedByString:@"\n"]];
        } else {
            properties[kSAAppCrashedReason] = [NSString stringWithFormat:@"%@ %@", exception.reason, [NSThread.callStackSymbols componentsJoinedByString:@"\n"]];
        }
        SAPresetEventObject *object = [[SAPresetEventObject alloc] initWithEventId:kSAEventNameAppCrashed];
        
        [SensorsAnalyticsSDK.sharedInstance trackEventObject:object properties:properties];
        
        //触发页面浏览时长事件
        [[SAModuleManager sharedInstance] trackPageLeaveWhenCrashed];
        
        // 触发退出事件
        [SAModuleManager.sharedInstance trackAppEndWhenCrashed];
        
        // 阻塞当前线程，完成 serialQueue 中数据相关的任务
        sensorsdata_dispatch_safe_sync(SensorsAnalyticsSDK.sdkInstance.serialQueue, ^{});
        SALogError(@"Encountered an uncaught exception. All SensorsAnalytics instances were archived.");
    } @catch(NSException *exception) {
        SALogError(@"%@ error: %@", self, exception);
    }
    
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    // SIG_DFL 的作用, 是将这些信号的处理函数都变为默认值.
}

@end
