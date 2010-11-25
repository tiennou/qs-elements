#import "ManagerAppDelegate.h"
#import <Elements/Elements.h>

@implementation ManagerAppDelegate
+ (void) initialize {
    NSLog(@"Init");
	[BLogManager setLoggingLevel:BLoggingDebug];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
    BRegistryViewController *viewer = [BRegistryViewController sharedController];
    [viewer showWindow:self];
    NSLog(@"Load Registry");
	BRegistry *registry = [BRegistry sharedInstance];
    NSLog(@"Scan Plugins");
	[registry scanPlugins];
  
	[registry loadMainExtension];
    NSLog(@"Done");
	[registry logRegistry];
}

- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename {
  [[BRegistry sharedInstance] registerPluginWithPath:filename];
  return NO;
}

@end
