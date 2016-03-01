//
//  CVCoreDataController.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import "CVCoreDataController.h"

#import "SharedDataUtils.h"
#import "CVMediaRecordMO+CoreDataProperties.h"
#import "CVGenreMO+CoreDataProperties.h"

static NSString *const kCoreDataAccessErrorName = @"CoreDataAccessError";

@interface CVCoreDataController()

@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

@implementation CVCoreDataController

@synthesize managedObjectModel=_managedObjectModel, managedObjectContext=_managedObjectContext, persistentStoreCoordinator=_persistentStoreCoordinator;


- (BFTask *) saveAsyncWithURL: (NSURL *)mediaURL
                        title: (NSString *)title
                  description: (NSString *)description
                        genre: (NSString *)genre
                     subGenre: (NSString *)subGenre {
    BFTask *res = [BFTask taskFromExecutor:[BFExecutor defaultExecutor] withBlock:^id _Nonnull{
        // read genre
        CVGenreMO *genreMO = [self findOrCreateGenre:genre];
        if (!genreMO) {
            NSException *ex = [[NSException alloc]initWithName: kCoreDataAccessErrorName
                                                        reason: [NSString stringWithFormat:@"Failed to find Main Genre info for name: %@", genre]
                                                      userInfo: nil];
            @throw ex;
        }
        CVGenreMO *subGenreMO = [self findOrCreateGenre:genre];
        if (!genreMO) {
            NSException *ex = [[NSException alloc]initWithName: kCoreDataAccessErrorName
                                                        reason: [NSString stringWithFormat:@"Failed to find Sub Genre info for name: %@", genre]
                                                      userInfo: nil];
            @throw ex;
        }
        
        // create new media record
        CVMediaRecordMO *record = [NSEntityDescription insertNewObjectForEntityForName: kMediaRecordEntityName
                                                                inManagedObjectContext: [self managedObjectContext]];
        [record addGenres:[NSSet setWithArray:@[genreMO, subGenreMO]]];
        record.dateAdded = [NSDate new];
        record.title = title;
        record.details = description;
        record.pageUrl = [mediaURL absoluteString];
        return record;
    }];
    return res;
}

- (void) saveContext {
    NSError *error;
    if (_managedObjectContext != nil) {
        if ([_managedObjectContext hasChanges] && ![_managedObjectContext save:&error]) {
            NSLog(@"Error saving managed objects context: %@\n%@", [error localizedDescription], [error userInfo]);
        }
    }
}

#pragma mark - Core Data stack

/**
 * Returns the managed object context for the application.
 * If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *) managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return _managedObjectContext;
}

/**
 * Returns the managed object model for the application.
 * If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"MediaRecords" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

/**
 * Returns the persistent store coordinator for the application.
 * If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [SharedDataUtils pathToMediaRecordsDB];
    
    /*
     Set up the store.
     For the sake of illustration, provide a pre-populated default store.
     */
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // If the expected store doesn't exist, copy the default store.
    if (![fileManager fileExistsAtPath:[storeURL path]]) {
        NSURL *defaultStoreURL = [[NSBundle mainBundle] URLForResource:kMediaRecordsDBFile withExtension:kMediaRecordsDBFileExtension];
        if (defaultStoreURL) {
            NSError *error;
            BOOL res = [fileManager copyItemAtURL:defaultStoreURL toURL:storeURL error:&error];
            if (!res) {
                NSLog(@"Failed to copy pre-populated default database, reason: %@, %@", error, [error userInfo]);
            }
        }
    }
    
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES};
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    
    NSError *error;
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeURL
                                                         options:options
                                                           error:&error]) {
        NSLog(@"Failed to initialize persisten store coordinator %@, %@", error, [error userInfo]);
    }
    _initialized = YES;
    
    return _persistentStoreCoordinator;
}

#pragma mark - private methods
- (CVGenreMO *) findGenreByName: (NSString *) name {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGenreEntityName];
    [request setPredicate:[NSPredicate predicateWithFormat:@"name == %@", name]];
    NSError *error = nil;
    NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
    if (!results) {
        NSLog(@"Error fetching Employee objects: %@\n%@", [error localizedDescription], [error userInfo]);
        return nil;
    }
    return [results objectAtIndex:0];
}

- (CVGenreMO *) findOrCreateGenre:(NSString *) name {
    CVGenreMO *genre = [self findGenreByName:name];
    if (!genre) {
        // create new genre record
        genre = [NSEntityDescription insertNewObjectForEntityForName:kGenreEntityName
                                              inManagedObjectContext:[self managedObjectContext]];
        genre.name = name;
    }
    return genre;
}

@end
