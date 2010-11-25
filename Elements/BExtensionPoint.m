//
//  BExtensionPoint.m
//  Elements
//
//
//  Copyright 2006 Elements. All rights reserved.
//

@implementation BExtensionPoint

- (void)fetchAllElements {
    elements = [[NSMutableArray alloc] init];
    
    NSString *extensionPointID = [self identifier];
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"element" inManagedObjectContext:moc];
    
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:entityDescription];
    // Set example predicate and sort orderings...
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"point == %@", extensionPointID];
    [request setPredicate:predicate];
    NSError *error = nil;
    [elements addObjectsFromArray:[moc executeFetchRequest:request error:&error]];
    //BLog(@"array %@ %@, predicate %@", array, error, predicate);  
}

- (NSArray *)elements {
    if (!elements) {
        [self performSelectorOnMainThread:@selector(fetchAllElements) withObject:nil waitUntilDone:YES];
    }
	return elements;
}

- (void)releaseCaches {
    [elements removeAllObjects];
    [elementsByID removeAllObjects];
}

- (void)didTurnIntoFault {
    [self releaseCaches];
    [super didTurnIntoFault];
}

- (NSDictionary *)elementsByID {
    NSArray *elem = [self elements];
	NSDictionary *dict = [NSDictionary dictionaryWithObjects:elem forKeys:[elem valueForKey:@"id"]];
	return dict;
}

- (void)fetchElementWithID:(NSString *)elementID {
    NSString *extensionPointID = [self valueForKey:@"id"];
    
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"element"
                                                         inManagedObjectContext:moc];
    
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:entityDescription];
    // Set example predicate and sort orderings...
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                              @"point == %@ && id == %@", extensionPointID, elementID];
    [request setFetchLimit:1];
    [request setPredicate:predicate];
    NSError *error = nil;
    NSArray *array = [moc executeFetchRequest:request error:&error];
    BElement *element = nil;
    if ([array count]) element = [array lastObject];
    
    if (!elementsByID) elementsByID = [[NSMutableDictionary alloc] init];
    
    if (element) {
        [elementsByID setValue:element forKey:elementID];
        BLogDebug(@"Fetched %@/%@ %@", extensionPointID, elementID, element);
    } else {
        [elementsByID setValue:[NSNull null] forKey:elementID];
        BLogDebug(@"Could not find %@/%@", extensionPointID, elementID);
    }
}

- (BElement *)elementWithID:(NSString *)elementID {
    if (!elementID) return nil;
    
    BElement *element = [elementsByID objectForKey:elementID];
    
    // Perform the fetch in the main thread
    if (!element)
        [self performSelectorOnMainThread:@selector(fetchElementWithID:) withObject:elementID waitUntilDone:YES];
    
    element = [elementsByID objectForKey:elementID];
    if ([element isKindOfClass:[NSNull class]]) return nil;
    
    return element;
}

- (NSArray *)loadedElements {
	if (!loadedElements) {
		NSEnumerator *enumerator = [[self valueForKey:@"elements"] objectEnumerator];
		BElement *each;
		
		loadedElements = [[NSMutableArray alloc] init];
		
		while ((each = [enumerator nextObject])) {
			if ([[each plugin] enabled]) {
                //				Class elementClass = [each elementClass];
				if (1) { // [elementClass conformsToProtocol:protocol]) {
					[loadedElements addObject:each];
				} else {
					BLogError(@"extension %@ doesn't conform to protocol, skipping", each);
				}
			}
		}
		
		[loadedElements sortUsingSelector:@selector(compareDeclarationOrder:)];
	}
	
	return loadedElements;
}

@end
