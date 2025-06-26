#import "AppDelegate.h"
#import "QLMainWindowController.h"
#import "QLHelpWindowController.h"
#if DEBUG
#import "QLUITest.h"
#endif
#include <stdio.h>
#include <stdlib.h>

@interface AppDelegate () <QLHelpWindowControllerDelegate>
@end

@implementation AppDelegate {
    QLMainWindowController *_windowController;
    QLHelpWindowController *_helpController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    NSImage *appIcon = [NSWorkspace.sharedWorkspace iconForFile:NSBundle.mainBundle.bundlePath];
    if (appIcon) NSApp.applicationIconImage = appIcon;
    [self buildMenu];
    _windowController = [[QLMainWindowController alloc] init];
    [_windowController showWindow:nil];
#if DEBUG
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--uitest"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [QLUITest runWithWindowController:self->_windowController completion:^(BOOL ok) {
                fflush(stdout);
                exit(ok ? 0 : 1);
            }];
        });
        return;
    }
#endif
    [_windowController runDefaultSimulation];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [_windowController persistState];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (NSMenuItem *)itemWithTitle:(NSString *)title action:(SEL)action key:(NSString *)key modifiers:(NSEventModifierFlags)modifiers {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key ?: @""];
    item.target = self;
    if (modifiers != 0) item.keyEquivalentModifierMask = modifiers;
    return item;
}

- (void)buildMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"QuantumLab" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"QuantumLab"];
    [appMenu addItem:[[NSMenuItem alloc] initWithTitle:@"About QuantumLab"
                                                action:@selector(orderFrontStandardAboutPanel:)
                                         keyEquivalent:@""]];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *hide = [[NSMenuItem alloc] initWithTitle:@"Hide QuantumLab" action:@selector(hide:) keyEquivalent:@"h"];
    hide.target = NSApp;
    [appMenu addItem:hide];
    NSMenuItem *hideOthers = [[NSMenuItem alloc] initWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    hideOthers.target = NSApp;
    [appMenu addItem:hideOthers];
    NSMenuItem *showAll = [[NSMenuItem alloc] initWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    showAll.target = NSApp;
    [appMenu addItem:showAll];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit QuantumLab" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    [appMenu addItem:quit];
    appItem.submenu = appMenu;
    [mainMenu addItem:appItem];

    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItem:[self itemWithTitle:@"Export Plot PNG…" action:@selector(exportPNG:) key:@"e" modifiers:NSEventModifierFlagCommand]];
    [fileMenu addItem:[self itemWithTitle:@"Export Data CSV…" action:@selector(exportCSV:) key:@"e"
                               modifiers:(NSEventModifierFlagCommand | NSEventModifierFlagShift)]];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *close = [[NSMenuItem alloc] initWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    close.target = nil;
    [fileMenu addItem:close];
    fileItem.submenu = fileMenu;
    [mainMenu addItem:fileItem];

    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Undo" action:NSSelectorFromString(@"undo:") keyEquivalent:@"z"]];
    NSMenuItem *redo = [[NSMenuItem alloc] initWithTitle:@"Redo" action:NSSelectorFromString(@"redo:") keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:redo];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"]];
    [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"]];
    [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"]];
    [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"]];
    editItem.submenu = editMenu;
    [mainMenu addItem:editItem];

    NSMenuItem *simItem = [[NSMenuItem alloc] initWithTitle:@"Simulation" action:nil keyEquivalent:@""];
    NSMenu *simMenu = [[NSMenu alloc] initWithTitle:@"Simulation"];
    [simMenu addItem:[self itemWithTitle:@"Solve" action:@selector(solvePressed:) key:@"r" modifiers:NSEventModifierFlagCommand]];
    [simMenu addItem:[self itemWithTitle:@"Play / Pause" action:@selector(togglePlayPressed:) key:@"" modifiers:0]];
    [simMenu addItem:[self itemWithTitle:@"Step Back" action:@selector(stepBackPressed:) key:@"" modifiers:0]];
    [simMenu addItem:[self itemWithTitle:@"Step Forward" action:@selector(stepForwardPressed:) key:@"" modifiers:0]];
    [simMenu addItem:[self itemWithTitle:@"Reset Frame" action:@selector(resetSimulationPressed:) key:@"0" modifiers:NSEventModifierFlagCommand]];
    simItem.submenu = simMenu;
    [mainMenu addItem:simItem];

    NSMenuItem *viewItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    [viewMenu addItem:[self itemWithTitle:@"2D Plot" action:@selector(set2DView:) key:@"1" modifiers:NSEventModifierFlagCommand]];
    [viewMenu addItem:[self itemWithTitle:@"3D Plot" action:@selector(set3DView:) key:@"2" modifiers:NSEventModifierFlagCommand]];
    [viewMenu addItem:[NSMenuItem separatorItem]];
    [viewMenu addItem:[self itemWithTitle:@"Toggle Sidebar" action:@selector(toggleSidebar:) key:@"s"
                               modifiers:(NSEventModifierFlagControl | NSEventModifierFlagCommand)]];
    [viewMenu addItem:[self itemWithTitle:@"Reset 3D Camera" action:@selector(resetCamera:) key:@"" modifiers:0]];
    viewItem.submenu = viewMenu;
    [mainMenu addItem:viewItem];

    NSMenuItem *helpItem = [[NSMenuItem alloc] initWithTitle:@"Help" action:nil keyEquivalent:@""];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu addItem:[self itemWithTitle:@"QuantumLab Help" action:@selector(showHelp:) key:@"?" modifiers:NSEventModifierFlagCommand]];
    [helpMenu addItem:[NSMenuItem separatorItem]];
    [helpMenu addItem:[self itemWithTitle:@"Quick Start" action:@selector(showQuickStart:) key:@"" modifiers:0]];
    [helpMenu addItem:[self itemWithTitle:@"Keyboard Shortcuts" action:@selector(showShortcuts:) key:@"" modifiers:0]];
    [helpMenu addItem:[self itemWithTitle:@"Troubleshooting" action:@selector(showTroubleshooting:) key:@"" modifiers:0]];
    helpItem.submenu = helpMenu;
    [mainMenu addItem:helpItem];

    NSApp.mainMenu = mainMenu;
}

#pragma mark - Help

- (QLHelpWindowController *)helpController {
    if (!_helpController) {
        _helpController = [[QLHelpWindowController alloc] init];
        _helpController.delegate = self;
    }
    return _helpController;
}

- (void)showHelp:(id)sender {
    QLHelpWindowController *help = [self helpController];
    [help showWindow:nil];
    [help.window makeKeyAndOrderFront:nil];
    [help focusSearch];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showQuickStart:(id)sender {
    [self presentHelpTopic:QLHelpTopicQuickStart];
}

- (void)showShortcuts:(id)sender {
    [self presentHelpTopic:QLHelpTopicShortcuts];
}

- (void)showTroubleshooting:(id)sender {
    [self presentHelpTopic:QLHelpTopicTroubleshooting];
}

- (void)presentHelpTopic:(NSString *)identifier {
    QLHelpWindowController *help = [self helpController];
    [help showTopicWithIdentifier:identifier];
    [help.window makeKeyAndOrderFront:nil];
    [help focusSearch];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)helpWindowController:(QLHelpWindowController *)controller
             openPresetNamed:(NSString *)presetName
                        mode:(NSInteger)mode
                     variant:(NSInteger)variant {
    BOOL opened = [_windowController applyPresetNamed:presetName
                                                 mode:(QLSimulationMode)mode
                                              variant:variant];
    if (!opened) return NO;
    [_windowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    return YES;
}

- (void)solvePressed:(id)sender { [_windowController solvePressed:sender]; }
- (void)togglePlayPressed:(id)sender { [_windowController togglePlayPressed:sender]; }
- (void)stepBackPressed:(id)sender { [_windowController stepBackPressed:sender]; }
- (void)stepForwardPressed:(id)sender { [_windowController stepForwardPressed:sender]; }
- (void)resetSimulationPressed:(id)sender { [_windowController resetSimulationPressed:sender]; }
- (void)set2DView:(id)sender { [_windowController set2DView:sender]; }
- (void)set3DView:(id)sender { [_windowController set3DView:sender]; }
- (void)toggleSidebar:(id)sender { [_windowController toggleSidebar:sender]; }
- (void)resetCamera:(id)sender { [_windowController resetCamera:sender]; }
- (void)exportPNG:(id)sender { [_windowController exportPNG:sender]; }
- (void)exportCSV:(id)sender { [_windowController exportCSV:sender]; }

@end
