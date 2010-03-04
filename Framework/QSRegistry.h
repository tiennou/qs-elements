/**
 *  @file QSRegistry.h
 *  @brief The Quicksilver registry.
 *  This class provides a registry-like facility for loading plugins.
 *  
 *  QSElements
 *
 *  Copyright 2007 Blacktree. All rights reserved.
 */

#import <Cocoa/Cocoa.h>
#import <QSElements/Blocks.h>

#define QSReg [QSRegistry sharedInstance]

/**
 * Notification sent when a plugin gets installed
 */
extern NSString *QSPlugInInstalledNotification;

/**
 * Notification sent when a plugin gets loaded
 */
extern NSString *QSPlugInLoadedNotification;

#define kQSActionProviders @"QSActionProviders"
#define kQSFSParsers @"QSFSParsers"
#define kQSObjectSources @"QSObjectSources"
#define kQSObjectHandlers @"QSObjectHandlers"
#define kQSPreferencePanes @"QSPreferencePanes"

/**
 *  @brief The public QSRegistry interface
 */
@interface QSRegistry : BRegistry {
    NSMutableDictionary *prefInstances; //Preferred Instances of tables
}
/**
 *  @brief Returns an instance of a Core ID.
 *  This method does a lookup of the requested Core ID in the "com.blacktree.core" Point ID.
 *  
 *  @param core An NSString containing the requested Core ID.
 *  @return The requested Core ID, or nil if it doesn't exists.
 */
- (id)coreInstanceWithID:(NSString *)core;
@end

