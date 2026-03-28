//
// MobileGestaltBridge.m
// Objective-C bridge implementation that calls MGCopyAnswer via dlsym.
//

#import "MobileGestaltBridge.h"
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>

typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef key);

NSString * MGCopyAnswerString(NSString *key) {
    if (!key) return nil;
    static MGCopyAnswerFunc mgFunc = NULL;
    if (!mgFunc) {
        mgFunc = (MGCopyAnswerFunc)dlsym(RTLD_DEFAULT, "MGCopyAnswer");
    }
    if (!mgFunc) return nil;

    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFTypeRef result = mgFunc(cfKey);
    if (!result) return nil;

    NSString *str = nil;
    CFTypeID t = CFGetTypeID(result);
    if (t == CFStringGetTypeID()) {
        str = CFBridgingRelease(result);
    } else if (t == CFNumberGetTypeID()) {
        long long v = 0;
        CFNumberGetValue((CFNumberRef)result, kCFNumberLongLongType, &v);
        str = [NSString stringWithFormat:@"%lld", v];
        CFRelease(result);
    } else if (t == CFBooleanGetTypeID()) {
        Boolean b = CFBooleanGetValue((CFBooleanRef)result);
        str = b ? @"true" : @"false";
        CFRelease(result);
    } else {
        CFStringRef desc = CFCopyDescription(result);
        if (desc) {
            str = CFBridgingRelease(desc);
        } else {
            str = @"<non-string>";
        }
        CFRelease(result);
    }

    return str;
}
