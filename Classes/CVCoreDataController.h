//
//  CVCoreDataController.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Bolts/Bolts.h>

/**
 * The core data controller to manage Core Data stack
 */
@interface CVCoreDataController : NSObject

// The managed object context to perform CRUD operations
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
// Indicates whether core data stack was already initialized
@property (nonatomic, assign, readonly) BOOL initialized;




/**
 * Method to synchronize managed obect context with underlying data store. It should be invoked
 * upon application lifecycle change events in order to guarantee that everything user changed
 * is persisted
 */
- (void) saveContext;

@end
