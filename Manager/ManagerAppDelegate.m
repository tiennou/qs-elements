#import "Elements.h"
#import "ManagerAppDelegate.h"
#import "BRegistryViewController.h"

@implementation ManagerAppDelegate
+ (void) initialize {
    NSLog(@"Init");
	[BLogManager setLoggingLevel:BLoggingDebug];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification {
    BRegistryViewController *viewer = [BRegistryViewController sharedController];
    [viewer showWindow:nil];
    BLogDebug(@"Load Registry");
	BRegistry *registry = [BRegistry sharedInstance];
    BLogDebug(@"Scan Plugins");
	[registry scanPlugins];
    BLogDebug(@"Loading main extension");
	[registry loadMainExtension];
    BLogDebug(@"Logging Registry");
	[registry logRegistry];
    BLogDebug(@"Re-Logging Registry");
	[registry logRegistry];
    BLogDebug(@"Done");
    NSDictionary *interfaces = [registry elementsByIDForPointID:@"org.quicksilver.interfaces"];
    BLogDebug(@"Interfaces: %@", interfaces);
    id instance = [registry instanceForPointID:@"org.quicksilver.interfaces" withID:@"org.quicksilver.interfaces.core"];
    BLogDebug(@"Instance: %@", instance);
    BExtension *extension = [[registry extensions] lastObject];
    BLogDebug(@"Extension: %@", extension);
    BLogDebug(@"point: %@", [extension extensionPoint]);
    BLogDebug(@"Loading everything");
    [registry loadPlugins];
    BLogDebug(@"We're good");
}


/**
 *  Implementation of the applicationShouldTerminate: method, used here to
 *  handle the saving of changes in the application managed object context
 *  before the application terminates.
 */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	
    NSError *error = nil;
    int reply = NSTerminateNow;
    
    if (![(BRegistry *)[BRegistry sharedInstance] save:&error]) {
        
        // This error handling simply presents error information in a panel with an 
        // "Ok" button, which does not include any attempt at error recovery (meaning, 
        // attempting to fix the error.)  As a result, this implementation will 
        // present the information to the user and then follow up with a panel asking 
        // if the user wishes to "Quit Anyway", without saving the changes.
        
        // Typically, this process should be altered to include application-specific 
        // recovery steps.  
        
        BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
        
        if (errorResult == YES) {
            reply = NSTerminateCancel;
        } else {
            int alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
            if (alertReturn == NSAlertAlternateReturn) {
                reply = NSTerminateCancel;	
            }
        }
    }
    
    return reply;
}

- (BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename {
    return NO;
}

- (IBAction)clearAllCaches:(id)sender {
    [[BRegistry sharedInstance] releaseAllCaches];
}

- (IBAction)clearOldCaches:(id)sender {
    [[BRegistry sharedInstance] releaseCaches];
}


@end
