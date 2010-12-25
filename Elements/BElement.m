//
//  BElement.m
//  Elements
//
//  Copyright 2007 Elements. All rights reserved.
//

#import "BElement.h"
#import "BLog.h"
#import "NSXMLElement+BExtensions.h"

@implementation BElement

- (NSString *)description {
	return [self identifier];	
}

- (NSString *)elementClassName {
    return [self primitiveValueForKey:@"objcClass"];
}

- (Class)elementClass {
    if (!elementClass) {
        NSError *error = nil;
		@try {
			if ([[self plugin] load:&error]) {
				elementClass = NSClassFromString([self elementClassName]);
			} else {
				BLogError(@"Failed to load plugin %@ => %@", [self plugin], error);
			}
			
			if (!elementClass) {
				BLogError(@"Failed to load element class %@", [self elementClassName]);
			} else {
				//BLogDebug(@"Loaded %@", [self elementClassName]);
			}
		} @catch (NSException *e) {
			BLogErrorWithException(e, @"threw exception %@ while loading class of element %@", e, self);
		}
    }
    return elementClass;
}

- (id)elementInstance {
    if (!elementInstance) {
        // instances persist for the life of the element
        elementInstance = [[self elementNewInstance] retain];
    }
    return elementInstance;
}

- (void)didTurnIntoFault {
    [elementInstance release];
    [super didTurnIntoFault];
}

- (id)elementNewInstance {
 
	id newElementInstance = nil;
	if (![self elementClassName]) return nil;
	@try {
		Class aClass = [self elementClass];
        
        if ([aClass conformsToProtocol:@protocol(BExecutableExtension)]) {
            Class <BExecutableExtension> execClass = aClass;
            newElementInstance = [execClass instanceWithElement:self];
        } else if ([aClass respondsToSelector:@selector(sharedInstance)]) {
		 	newElementInstance = [aClass sharedInstance];
		} else {
			newElementInstance = [[[aClass alloc] init] autorelease];
		}
	} @catch (NSException *e) {
		BLogErrorWithException(e, @"threw exception %@ while loading instance of element %@", e, self);
		[newElementInstance release];
		newElementInstance = nil;
	}
	
	if (!newElementInstance) {
		BLogError(@"Failed to load element instance of class %@", [self elementClassName]);
	} else {
		BLogDebug(@"Created instance %@ %p", newElementInstance, self);
	}
	
	return newElementInstance;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{
	if ([key isEqualToString:@"class"]) {
		key = @"objcClass";	
		[self setValue:value forKey:key];
	} else {
		BLogInfo(@"Element %@ could not set value %@ to %@", self,  key, value);	
		return;
	}
}

@end
