/*
 *  @file NSXMLElement+BExtensions.h
 *  Elements
 *
 *  Copyright 2007 Blacktree. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

/**
 *  @brief Elements category on NSXMLElement for attributes handling.
 */
@interface NSXMLElement (BExtensions)

/**
 *  @brief Returns the reciever as a dictionary.
 */
- (NSDictionary *)attributesAsDictionary;

/**
 *  @brief Return the first element with the specified name.
 */
- (NSXMLElement *)firstElementWithName:(NSString *)name;

/**
 *  @brief Return the first value with the specified name.
 */
- (id)firstValueForName:(NSString *)name;

/**
 *  @brief Return the first node for XPath.
 */
- (NSXMLNode *)firstNodeForXPath:(NSString *)xpath error:(NSError **)error;

/**
 *  @brief Return the first value for XPath.
 */
- (id)firstValueForXPath:(NSString *)xpath error:(NSError **)error;

/**
 *  @brief Return all values for XPath.
 */
- (id)valuesForXPath:(NSString *)xpath error:(NSError **)error;
	
@end
