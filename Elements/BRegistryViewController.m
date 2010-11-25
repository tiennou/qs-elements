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
+ (id) sharedController {
    if( sharedInstance == nil ) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

- (id) init {
    self = [super initWithNibName:@"ElementsManager" bundle:[NSBundle bundleForClass:[self class]]];
    if( self ) {
    }
    return self;
}

- (id) registry
{
    return [BRegistry sharedInstance];
}

- (void) showWindow:(id)sender {
    [self loadView]; 
    [[[self view] window] makeKeyAndOrderFront:nil];
}

@end
