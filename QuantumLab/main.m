#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "QLSelfTest.h"
#include <string.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--selftest") == 0) {
                BOOL ok = [QLSelfTest runAll];
                fflush(stdout);
                return ok ? 0 : 1;
            }
        }
    }
    NSApplication *application = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    application.delegate = delegate;
    [application setActivationPolicy:NSApplicationActivationPolicyRegular];
    [application run];
    return 0;
}
