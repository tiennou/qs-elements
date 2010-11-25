/**
 *  @file Elements.h
 *  @brief The main header for the Elements framework
 *  The macros declared therein are designed to help localization of Elements plugins.
 *  @see NSLocalizedString
 *
 *  Elements
 *  
 *  Created by Jesse Grosjean on 12/3/04.
 *  Copyright 2004 Elements. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>

#import "BLog.h"
#import "BRegistry.h"
#import "BPlugin.h"
#import "BExtensionPoint.h"
#import "BExtension.h"
#import "BRequirement.h"
#import "BElement.h"
#import "BRegistryViewController.h"

#pragma mark macros

#define BLocalizedString(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]
#define BLocalizedStringFromTable(key, tbl, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:(tbl)]
#define BLocalizedStringFromTableInBundle(key, tbl, bundle, comment) [bundle localizedStringForKey:(key) value:@"" table:(tbl)]
#define BLocalizedStringWithDefaultValue(key, tbl, bundle, val, comment) [bundle localizedStringForKey:(key) value:(val) table:(tbl)]