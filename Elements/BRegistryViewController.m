//
//  BRegistryViewController.m
//  Elements
//
//  Created by Nicholas Jitkoff on 12/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BRegistryViewController.h"


@implementation BRegistryViewController

static id sharedInstance = nil;
+ (id)sharedController {
    if( sharedInstance == nil ) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

- (id)init {
    return [super initWithNibName:@"ElementsManager" bundle:[NSBundle bundleForClass:[self class]]];
}

- (id)registry {
    return [BRegistry sharedInstance];
}

- (void)showWindow:(id)sender {
    [self loadView]; 
    [[[self view] window] makeKeyAndOrderFront:nil];
}

- (NSArray *)nameSortDescriptors {
	return [NSArray arrayWithObjects:
            [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES] autorelease],
            [[[NSSortDescriptor alloc] initWithKey:@"id" ascending:YES] autorelease],
            nil];
}

@end
