//
//  BRequirement.m
//  Elements
//
//
//  Copyright 2006 Elements. All rights reserved.
//

#import "BRequirement.h"
#import "BRegistry.h"
#import "BPlugin.h"
#import "BLog.h"


@implementation BRequirement

#pragma mark Lifetime

- (id)initWithIdentifier:(NSString *)identifier version:(NSString *)version optional:(BOOL)isOptional {
	if ((self = [super init])) {
        [self setValue:identifier forKey:@"identifier"];
        [self setValue:version forKey:@"version"];
        [self setValue:[NSNumber numberWithBool:isOptional] forKey:@"optional"];
	}
	return self;
}

#pragma mark Accessors

- (NSString *)description {
    return [NSString stringWithFormat:@"bundleIdentifier: %@ optional: %@", [self valueForKey:@"bundle"], [self optional] ? @"YES" : @"NO"];
}

- (BPlugin *)requiredPlugin {
	return [[BRegistry sharedInstance] pluginWithID:[self valueForKey:@"bundle"]];
}

- (NSBundle *)requiredBundle {
	return [NSBundle bundleWithIdentifier:[self valueForKey:@"bundle"]];
}

- (BOOL)optional {
    return [[self primitiveValueForKey:@"optional"] boolValue];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{
	BLog(@"Requirement %@ could not set value %@ to %@", self,  key, value);	
}

#pragma mark Loading

- (BOOL)isLoaded {
	BPlugin *plugin = [self requiredPlugin];
	if (plugin) return [plugin isLoaded];
	NSBundle *bundle = [self requiredBundle];
	if (bundle) return [bundle isLoaded];
	return NO;
}

- (BOOL)load:(NSError **)error {        
    /* We might be a requirement for another plugin,
     * or a requirement for a bundle in general
     * Check in this order to guarantee we will get plugin requirements correctly
     */
	BPlugin *plugin = [self requiredPlugin];
	if (plugin)
        return [plugin load:error];

	NSBundle *bundle = [self requiredBundle];
	if (bundle)
        return [bundle loadAndReturnError:error];
	return NO;
}

@end
