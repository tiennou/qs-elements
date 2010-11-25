/**
 *  @file BRegistryViewController.h
 *  @brief A NSViewController subclass with singleton
 *  Elements
 *
 *  Created by Nicholas Jitkoff on 12/23/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

/**
 *  @brief The BRegistryViewController public interface
 */
@interface BRegistryViewController : NSViewController {

}
/**
 *  @brief A BRegistryViewController singleton
 *  Returns a singleton.
 */
+ (id) sharedController;
/**
 *  @brief Show the controlled view's window.
 *  Shows the window associated with the reciever.
 *  
 *  @param sender The sender of the message. Can be nil.
 */
- (void) showWindow:(id)sender;
@end
