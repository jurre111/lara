// Tweak.xm — minimal hook template for amfid/installd prototype
// Replace placeholder symbols and types with actual targets per iOS build.

// Improved Tweak.xm — symbol-map aware prototype
#import <Foundation/Foundation.h>
#include <substrate.h>
#import <dlfcn.h>
#import <stdio.h>
#include <syslog.h>

// Generic placeholder typedef for binary verification functions.
// Update to the real signature when known for the target iOS build.
typedef int (*verify_fn_t)(void *arg1, void *arg2, void *arg3);

static verify_fn_t orig_verify = NULL;

static int fake_verify(void *a, void *b, void *c) {
    // Minimal behavior: log and force success (adjust when real semantics are known)
    syslog(LOG_USER | LOG_INFO, "[ThreeAppBypass] fake_verify called");

    // Optionally call original if present
    if (orig_verify) {
        int r = orig_verify(a, b, c);
        (void)r; // ignore for now
    }

    return 0; // treat as success by default (may need change per target)
}

static void write_log(NSString *msg) {
    @autoreleasepool {
        NSString *path = @"/var/mobile/Library/lara/3appbypass.log";
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions: @0644}];
            fh = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        if (fh) {
            [fh seekToEndOfFile];
            NSString *line = [NSString stringWithFormat:@"%@: %@\n", [NSDate date], msg];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    }
}

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        write_log(@"[ThreeAppBypass] init start");

        NSString *mapPath = @"/var/mobile/Library/lara/3appbypass_symbols.json";
        NSData *mapData = [NSData dataWithContentsOfFile:mapPath];
        if (mapData) {
            NSError *err = nil;
            id obj = [NSJSONSerialization JSONObjectWithData:mapData options:0 error:&err];
            if (err == nil && [obj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *d = (NSDictionary *)obj;
                // Iterate through known keys; callers can provide custom keys.
                for (NSString *key in d) {
                    id val = d[key];
                    if (![val isKindOfClass:[NSString class]]) continue;
                    NSString *s = (NSString *)val;
                    // Address form: 0xABCDEF
                    if ([s hasPrefix:@"0x"] || [s hasPrefix:@"0X"]) {
                        unsigned long long addr = 0;
                        NSScanner *sc = [NSScanner scannerWithString:s];
                        [sc setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"0x"]];
                        [sc scanHexLongLong:&addr];
                        if (addr != 0) {
                            void *sym = (void *)addr;
                            write_log([NSString stringWithFormat:@"[ThreeAppBypass] Hooking %@@0x%llx", key, addr]);
                            MSHookFunction(sym, (void *)fake_verify, (void **)&orig_verify);
                            // continue — multiple hooks may be desired
                        }
                    } else {
                        // Treat as symbol name — try to dlsym from common binaries
                        NSArray *bins = @[@"/usr/libexec/amfid", @"/usr/sbin/installd", @"/usr/lib/libamfid.dylib"];
                        BOOL hooked = NO;
                        for (NSString *bin in bins) {
                            void *h = dlopen([bin UTF8String], RTLD_NOW);
                            if (!h) continue;
                            void *sym = dlsym(h, [s UTF8String]);
                            if (sym) {
                                write_log([NSString stringWithFormat:@"[ThreeAppBypass] dlsym(%@,%@) -> hooking", bin, s]);
                                MSHookFunction(sym, (void *)fake_verify, (void **)&orig_verify);
                                hooked = YES;
                                dlclose(h);
                                break;
                            }
                            dlclose(h);
                        }
                        if (!hooked) {
                            write_log([NSString stringWithFormat:@"[ThreeAppBypass] symbol %@ not found via dlsym; provide absolute address or correct symbol name", s]);
                        }
                    }
                }
                write_log(@"[ThreeAppBypass] finished processing symbol map");
                return;
            } else {
                write_log([NSString stringWithFormat:@"[ThreeAppBypass] failed to parse symbol map: %@", err]);
            }
        } else {
            write_log([NSString stringWithFormat:@"[ThreeAppBypass] symbol map not present at %@", mapPath]);
        }

        write_log(@"[ThreeAppBypass] attempting dlsym fallback");
        // Minimal fallback example — try to find a known symbol
        void *h = dlopen("/usr/libexec/amfid", RTLD_NOW);
        if (!h) h = dlopen("/usr/sbin/installd", RTLD_NOW);
        if (h) {
            void *sym = dlsym(h, "_AMFIPathValidator_validateWithError");
            if (!sym) sym = dlsym(h, "_validateWithError");
            if (sym) {
                write_log(@"[ThreeAppBypass] found fallback symbol, hooking");
                MSHookFunction(sym, (void *)fake_verify, (void **)&orig_verify);
            } else {
                write_log(@"[ThreeAppBypass] fallback dlsym did not find a symbol; provide symbol map for your build");
            }
            dlclose(h);
        } else {
            write_log(@"[ThreeAppBypass] dlopen failed for amfid/installd; cannot proceed without symbol map");
        }
    }
}
