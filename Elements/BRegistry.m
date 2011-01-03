//
//  BRegistry.m
//  Elements
//
//
//  Copyright 2006 Elements. All rights reserved.
//

#import "BRegistry.h"
#import "BPlugin.h"
#import "BExtensionPoint.h"
#import "BExtension.h"
#import "BRequirement.h"
#import "BLog.h"

#import "BElement.h"

@interface BRegistry (BPrivate)
- (NSMutableArray *)pluginSearchPaths;
- (void)validatePluginConnections;
- (BOOL)setupRegistry:(NSError **)error;
- (NSString *)applicationSupportFolder;
- (NSManagedObjectContext *)managedObjectContext;
@end

@implementation BRegistry

#pragma mark Class Methods
+ (NSSet *)keyPathsForValuesAffectingExtensions {
    return [NSSet setWithObjects:@"plugins", nil];
}

+ (NSSet *)keyPathsForValuesAffectingElements {
    return [NSSet setWithObjects:@"plugins", nil];
}

+ (NSSet *)keyPathsForValuesAffectingExtensionPoints {
    return [NSSet setWithObjects:@"plugins", nil];
}

static id sharedInstance = nil;
+ (id)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

+ (void)performSelector:(SEL)selector forExtensionPoint:(NSString *)extensionPointID protocol:(Protocol *)protocol {
    BRegistry *pluginRegistry = [BRegistry sharedInstance];
    NSEnumerator *enumerator = [[pluginRegistry loadedElementsForPointID:extensionPointID] objectEnumerator];
    BElement *each;
    
    while ((each = [enumerator nextObject])) {
		@try {
			[[each elementInstance] performSelector:selector];
		} @catch ( NSException *exception ) {
			BLogErrorWithException(exception,([NSString stringWithFormat:@"exception while processing extension point %@ \n %@", extensionPointID, nil]));
		}
    }
}

#pragma mark -
#pragma mark Lifetime
- (id) init {
	self = [super init];
	if (self != nil) {
		BLogInfo(@"Registry init from %@", [self applicationSupportFolder]);
        extensionPointCache = [[NSMutableDictionary alloc] init];
        NSError *error = nil;
        if (![self setupRegistry:&error])
            BLogFatal(@"%@", error);
	}
	return self;
}

- (void)dealloc {
    [self save:NULL];
    
    [managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
    [extensionPointCache release], extensionPointCache = nil;
    
    [super dealloc];
}

#pragma mark Plugin loading

- (NSArray *)pluginPathExtensions {
	return [NSArray arrayWithObject:@"plugin"];
}

- (NSURL *)pluginURLForBundle:(NSBundle *)bundle {
	NSString *path = [bundle pathForResource:@"plugin" ofType:@"xml"];

	if (!path)
        return nil;

	return [NSURL fileURLWithPath:path];
}

- (void)registerPluginWithPath:(NSString *)pluginPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    /* First find the plugin URL */
    NSBundle *bundle = [NSBundle bundleWithPath:pluginPath];
    NSURL *url = [self pluginURLForBundle:bundle];
    if (!url) {
        BLogError(@"Invalid plugin at path %@", pluginPath);
        return;
    }

    /* then the plugin in the loaded plugins */
    BPlugin *plugin = nil; 
    if (bundle)
        plugin = [self pluginWithID:[bundle bundleIdentifier]];
// TODO: compare versions    
//    NSString *version = [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey]; // plain plugins won't check version?

    if (plugin) {
        NSDate *modDate = [[fileManager attributesOfItemAtPath:[url path] error:NULL] fileModificationDate];
        BOOL isValid = [(NSDate *)[plugin valueForKey:@"registrationDate"] compare: modDate] != NSOrderedAscending;	

        if (isValid) {
            BLogDebug(@"Using cache for %p %@", plugin, [(bundle != nil ? [bundle bundlePath] : [url absoluteString]) stringByAbbreviatingWithTildeInPath]);
            return;
        }
        
        if ([plugin isLoaded] && ![bundle isEqual:[NSBundle mainBundle]]) {
            BLogInfo(@"Trying to replace loaded plugin %@", plugin);
            NSAlert *alert = [NSAlert alertWithMessageText:@"Plugin already loaded"
                                             defaultButton:@"Relaunch"
                                           alternateButton:@"Later" 
                                               otherButton:nil 
                                 informativeTextWithFormat:@"An earlier version of this plugin is already loaded. You must relaunch to use the new version"];
            int result = [alert runModal];
            
            if (result == 1)
                [NSApp terminate:nil];

            /* We won't register the plugin, the user doesn't want to restart */
            BLogInfo(@"Restart needed, skipping %@", plugin);
            return;
        }

        BLogInfo(@"Replacing already registered plugin %@", plugin);
    }

    [self willChangeValueForKey:@"plugins"];

    if (plugin)
        [[self managedObjectContext] deleteObject:plugin];
    
    plugin = [[[BPlugin alloc] initWithPluginURL:url
                                          bundle:bundle
                  insertIntoManagedObjectContext:[self managedObjectContext]] autorelease];

    if (!plugin)
        BLogError(@"Failed to create plugin for path: %@", pluginPath);
    
    if (![plugin registerPlugin]) {
        BLogError(@"Failed registration of plugin: %@", plugin);
        [[self managedObjectContext] deleteObject:plugin];
    }

    [self didChangeValueForKey:@"plugins"];
}

- (void)validateExistingPlugins {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // Delete missing plugins
    NSArray *existingPlugins = [self plugins];
    BPlugin *thisPlugin;
    NSEnumerator *pluginEnumerator = [existingPlugins objectEnumerator];
    
    while((thisPlugin = [pluginEnumerator nextObject])) {
        NSString *path = [[thisPlugin pluginURL] path];
        if (![fileManager fileExistsAtPath:path]) {
            BLogDebug(@"Deleting plugin at path %@", path);
			[[self managedObjectContext] deleteObject:thisPlugin];  
        }
    }
}

- (void)scanPlugins {
    [self validateExistingPlugins];
    NSFileManager *fileManager = [NSFileManager defaultManager];

	NSMutableArray *pluginSearchPaths = [NSMutableArray arrayWithArray:[self pluginSearchPaths]];
    NSMutableArray *foundPluginPaths = [NSMutableArray array];
    
    // BLogInfo(@"pluginsSearchPaths: %@", pluginSearchPaths);
	// Find plugin paths
    NSEnumerator *enumerator = [pluginSearchPaths reverseObjectEnumerator];
    for (NSString *eachSearchPath in enumerator) {
        [pluginSearchPaths removeLastObject];
        
        NSArray *pathContents = [fileManager contentsOfDirectoryAtPath:eachSearchPath error:NULL];
        pathContents = [pathContents pathsMatchingExtensions:[self pluginPathExtensions]];
        
        for (NSString *pluginPath in pathContents) {
            pluginPath = [eachSearchPath stringByAppendingPathComponent:pluginPath];
            [foundPluginPaths addObject:pluginPath];

            NSBundle *bundle = [NSBundle bundleWithPath:pluginPath];
            if (bundle) {
                [pluginSearchPaths addObject:[bundle builtInPlugInsPath]]; // search within plugin for more
            }
        }
	}

    // BLogInfo(@"foundPlugins: %@", foundPluginPaths);
	// scan plugin paths
    for (NSString *pluginPath in foundPluginPaths) {
        [self registerPluginWithPath:pluginPath];
	}

	[self validatePluginConnections];
    BLogInfo(@"Registered %d plugin(s) from %@", [[self plugins] count], foundPluginPaths);
    
    NSError *error = nil;
	if (![self save:&error])
        BLogError(@"scanPlugin save %@", error);
}

- (void)loadPlugins {
    for (BPlugin *plugin in [self plugins]) {
        [plugin load:nil];
    }
}

- (void)loadMainExtension {
	NSString *mainID = [[NSBundle mainBundle] bundleIdentifier];
	mainID = [mainID stringByAppendingPathExtension:@"main"];
    
    // FIXME?: For now just load any main functions to allow modification
    [self loadedInstancesForPointID:mainID];
    [self loadedInstancesForPointID:@"global.main"];
    
    //  NSArray *mainElements = [self elementsForPointID:mainID];
    //  BElement *mainElement= [mainElements lastObject];
    //  
    //  if ([mainElements count] > 1) {
    //		BLogWarn(([NSString stringWithFormat:@"found more then one plugin (%@) with a main extension point, loading only one from plugin %@", mainElements, [mainElement plugin]]));
    //  } else if ([mainElements count] == 0) {
    //		BLogWarn(([NSString stringWithFormat:@"failed to find any plugin with a main extension point %@", mainID]));
    //  }
    //  
    //  [mainElement elementInstance];
}

#pragma mark -
#pragma mark Accessors
- (NSArray *)objectsForEntityName:(NSString *)name {
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:name inManagedObjectContext:[self managedObjectContext]]];
	
	NSError *error = nil;
	NSArray *array = [[self managedObjectContext] executeFetchRequest:request error:&error];
    if (!array)
        BLogError(@"%@", error);
	return array;
}

- (id)objectForEntityName:(NSString *)name identifier:(NSString *)identifier{
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:name inManagedObjectContext:[self managedObjectContext]]];
	[request setPredicate:[NSPredicate predicateWithFormat:@"id = %@", identifier]];
	
	NSError *error = nil;
	NSArray *array = [[self managedObjectContext] executeFetchRequest:request error:&error];
    if (!array)
        BLogError(@"%@", error);
    
	if ([array count] == 1)
        return [array lastObject];
	return nil;
}

- (NSArray *)extensionPoints {
	return [self objectsForEntityName:@"extensionPoint"];
}

- (NSArray *)extensions {
	return [self objectsForEntityName:@"extension"];
}

- (NSArray *)elements {
	return [self objectsForEntityName:@"element"];
}

- (NSArray *)plugins {
    return [self objectsForEntityName:@"plugin"];
}

- (void)logRegistry {
    NSLog(@"Plugins: %@", [self plugins]);
    NSLog(@"Points: %@", [self extensionPoints]);	
    NSLog(@"Elements: %@", [self elements]);	
}


#pragma mark Registry Lookup
- (BPlugin *)pluginWithID:(NSString *)pluginID {
    return [self objectForEntityName:@"plugin" identifier:pluginID];
}

- (BPlugin *)pluginWithURL:(NSURL *)pluginURL {
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[NSEntityDescription entityForName:@"plugin" inManagedObjectContext:[self managedObjectContext]]];
	[request setPredicate:[NSPredicate predicateWithFormat:@"url = %@", [pluginURL absoluteString]]];
	
	NSError *error = nil;
	NSArray *array = [[self managedObjectContext] executeFetchRequest:request error:&error];
    if (!array)
        BLogError(@"%@", error);

    return [array count] ? [array lastObject] : nil;
}

- (void)fetchExtensionPoint:(NSString *)extensionPointID {
    BExtensionPoint *point = [self objectForEntityName:@"extensionPoint" identifier:extensionPointID];
    if (extensionPointID)
        [extensionPointCache setValue:point forKey:extensionPointID];
}

- (BExtensionPoint *)extensionPointWithID:(NSString *)extensionPointID {
    BExtensionPoint *point = [extensionPointCache objectForKey:extensionPointID];
    if (!point) {
        [self performSelectorOnMainThread:@selector(fetchExtensionPoint:) withObject:extensionPointID waitUntilDone:YES];
        point = [extensionPointCache objectForKey:extensionPointID];
    }
    return point;
}

- (NSDictionary *)elementsByIDForPointID:(NSString *)extensionPointID {
    return [[self extensionPointWithID:extensionPointID] elementsByID];
}

- (NSArray *)elementsForPointID:(NSString *)extensionPointID {
    return [[self extensionPointWithID:extensionPointID] elements];
}

- (BElement *)elementForPointID:(NSString *)extensionPointID withID:(NSString *)elementID {
    BExtensionPoint *point = [self extensionPointWithID:extensionPointID];
    BElement *element = [point elementWithID:elementID];
    return element;
}

- (BElement *)instanceForPointID:(NSString *)extensionPointID withID:(NSString *)elementID {
    BElement *element = [self elementForPointID:extensionPointID withID:elementID];
	return [element elementInstance];
}

- (NSArray *)loadedValidOrderedExtensionsFor:(NSString *)extensionPointID protocol:(Protocol *)protocol {
	return [self loadedElementsForPointID:extensionPointID];
}

- (NSArray *)loadedInstancesForPointID:(NSString *)extensionPointID {
	return [[self loadedElementsForPointID:extensionPointID] valueForKey:@"elementInstance"];
}

- (NSArray *)loadedElementsForPointID:(NSString *)extensionPointID {
	return [[self extensionPointWithID:extensionPointID] loadedElements];
}

- (NSDictionary *)loadedElementsByIDForPointID:(NSString *)extensionPointID{
    NSArray *elements = [self loadedElementsForPointID:extensionPointID];
    
	return [NSDictionary dictionaryWithObjects:elements forKeys:[elements valueForKey:@"id"]];
}

- (NSDictionary *)loadedInstancesByIDForPointID:(NSString *)extensionPointID {
	NSArray *elements = [self loadedElementsForPointID:extensionPointID];
	NSArray *instances = [elements valueForKey:@"elementInstance"];
    
	return [NSDictionary dictionaryWithObjects:instances forKeys:[elements valueForKey:@"id"]];
}

#pragma mark -
#pragma mark Private
- (NSMutableArray *)pluginSearchPaths {
    NSMutableArray *pluginSearchPaths = [NSMutableArray array];
    NSString *applicationSupportSubpath = [NSString stringWithFormat:@"Application Support/%@/PlugIns", [[NSProcessInfo processInfo] processName]];
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
    
    for (NSString *eachSearchPath in searchPaths) {
        NSString *searchPath = [eachSearchPath stringByAppendingPathComponent:applicationSupportSubpath];
        [pluginSearchPaths addObject:searchPath];
    }
    
    // Add our default paths to the list
	[pluginSearchPaths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	[pluginSearchPaths addObject:[[NSBundle bundleForClass:[self class]] builtInPlugInsPath]];
    
    /* Look everywhere ! */
	for (NSBundle *eachBundle in [NSBundle allBundles]) {
        NSString *searchPath = [eachBundle builtInPlugInsPath];
        [pluginSearchPaths addObject:searchPath];
	}
    
    return pluginSearchPaths;
}

- (void)validatePluginConnections {
    NSEnumerator *pluginEnumerator = [[self plugins] objectEnumerator];
    BPlugin *eachPlugin;
    
    while ((eachPlugin = [pluginEnumerator nextObject])) {
		NSEnumerator *requirementsEnumerator = [[eachPlugin requirements] objectEnumerator];
		BRequirement *eachRequirement;
		
		while ((eachRequirement = [requirementsEnumerator nextObject])) {
			if (![[eachRequirement valueForKey:@"optional"] boolValue]) {
				if (![NSBundle bundleWithIdentifier:[eachRequirement valueForKey:@"bundle"]]) {
					BLogWarn(@"requirement bundle %@ not found for plugin %@", eachRequirement, eachPlugin);
				}
			}
		}
    }
    
    NSEnumerator *extensionsEnumerator = [[self extensions] objectEnumerator];
    BExtension *eachExtension;
    
    while ((eachExtension = [extensionsEnumerator nextObject])) {
		NSString *eachExtensionID = [eachExtension extensionPointID];
		BExtensionPoint *extensionPoint = [self extensionPointWithID:eachExtensionID];
		if (!extensionPoint) {
			BLogWarn(@"no extension point found for plugin %@'s extension %@", [eachExtension plugin], eachExtension);
		}
    }
}

#pragma mark -
#pragma mark Core Data

- (BOOL)setupRegistry:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupportFolder = [self applicationSupportFolder];

    /* Check the existence of our Application Support Directory */
    if (![fileManager createDirectoryAtPath:applicationSupportFolder withIntermediateDirectories:YES attributes:nil error:error])
        return NO;

    /* Now set up our CoreData stack */
    NSArray *allBundles = [NSArray arrayWithObject:[NSBundle bundleForClass:[BRegistry class]]];
    BLogDebug(@"Creating MOM with %@", allBundles);
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:allBundles] retain];

    NSURL *storeURL = [NSURL fileURLWithPath:[applicationSupportFolder stringByAppendingPathComponent: @"block.registry"]];

	persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:error]) {
        /* If an error occurs, try to destroy the store. */
        BLogError(@"Incompatible store, removing: %@", *error);
        if (![fileManager removeItemAtURL:storeURL error:error]) {
            return NO;
        }
        /* Then recreate. */
        if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:error]) {
            return NO;
        }
    }

    if (persistentStoreCoordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: persistentStoreCoordinator];
    }

    return YES;
}

/**
 *  Returns the support folder for the application, used to store the Core Data
 *  store file.  This code uses a folder named after the process name for
 *  the content, either in the NSApplicationSupportDirectory location or (if the
 *  former cannot be found), the system's temporary directory.
 */
- (NSString *)applicationSupportFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];
}

/*
 *  Creates, retains, and returns the managed object model for the application 
 *  by merging all of the models found in the application bundle and all of the 
 *  framework bundles.
 */
- (NSManagedObjectModel *)managedObjectModel {
    return managedObjectModel;
}

/**
 *  Returns the persistent store coordinator for the application.  This 
 *  implementation will create and return a coordinator, having added the 
 *  store for the application to it.  (The folder for the store is created, 
 *  if necessary.)
 */
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	return persistentStoreCoordinator;
}

- (NSManagedObjectContext *) managedObjectContext {
    return managedObjectContext;
}

- (BOOL)save:(NSError **)error {
    if (![[self managedObjectContext] commitEditing]) {
        return NO;
    }
    @try {
        if ([[self managedObjectContext] hasChanges] && ![[self managedObjectContext] save:error]) {
            NSArray *errors = [[*error userInfo] objectForKey:NSDetailedErrorsKey];
            BLogError(@"Error while saving: %@ => %@", *error, errors);
            return NO;
        }
    }
    @catch (NSException *e) {
        BLogErrorWithException(e, @"Save failed !");
        return NO;
    }
    return YES;
}

- (void)releaseCaches {
    [[self extensionPoints] makeObjectsPerformSelector:@selector(releaseCaches)];
}

- (void)releaseAllCaches {
    BLogDebug(@"releaseAllCaches");
    [self releaseCaches];
    [extensionPointCache removeAllObjects];
}

@end