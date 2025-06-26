#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class QLHelpWindowController;

extern NSString * const QLHelpTopicWelcome;
extern NSString * const QLHelpTopicQuickStart;
extern NSString * const QLHelpTopicInterface;
extern NSString * const QLHelpTopicSchrodinger1D;
extern NSString * const QLHelpTopicSchrodinger2D;
extern NSString * const QLHelpTopicSpin;
extern NSString * const QLHelpTopicOscillator;
extern NSString * const QLHelpTopicViews;
extern NSString * const QLHelpTopicOptions;
extern NSString * const QLHelpTopicPlayback;
extern NSString * const QLHelpTopicExport;
extern NSString * const QLHelpTopicPhysics;
extern NSString * const QLHelpTopicShortcuts;
extern NSString * const QLHelpTopicTroubleshooting;

/// Asked to open a built-in preset from a "Try it" link in the help content.
/// Return YES when the preset was opened; the help window will close itself.
@protocol QLHelpWindowControllerDelegate <NSObject>
@optional
- (BOOL)helpWindowController:(QLHelpWindowController *)controller
            openPresetNamed:(NSString *)presetName
                       mode:(NSInteger)mode
                    variant:(NSInteger)variant;
@end

/// A searchable Help window with a source-list of topics and a rich content pane.
@interface QLHelpWindowController : NSWindowController

@property (nonatomic, weak, nullable) id<QLHelpWindowControllerDelegate> delegate;

@property (nonatomic, readonly, copy) NSString *selectedTopicIdentifier;
@property (nonatomic, readonly, copy) NSArray<NSString *> *topicIdentifiers;
@property (nonatomic, readonly, copy) NSArray<NSString *> *visibleTopicIdentifiers;
@property (nonatomic, readonly, copy) NSString *currentContentText;

- (void)showTopicWithIdentifier:(NSString *)identifier;
- (BOOL)selectTopicWithIdentifier:(NSString *)identifier;
- (void)searchForText:(NSString *)query;
- (void)focusSearch;

/// Handles links of the form qlhelp://topic/…, qlhelp://preset?…, and
/// qlhelp://action/clear-search. Returns NO for an unsupported link.
- (BOOL)handleHelpURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
