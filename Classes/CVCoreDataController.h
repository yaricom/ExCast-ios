//
//  CVCoreDataController.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <Bolts/Bolts.h>

#import "ExMedia.h"

// The name of error raised when failed to perform Core data Access operation
static NSString *const kCoreDataAccessErrorName;

/*!
 The core data controller to manage Core Data stack
 */
@interface CVCoreDataController : NSObject

// The managed object context to perform CRUD operations
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
// Indicates whether core data stack was already initialized
@property (nonatomic, assign, readonly) BOOL initialized;

/*!
 Method to save provided media object asynchronously
 @return BFTask object encapsulating operation results
 */
- (BFTask *) saveAsyncWithURL: (NSURL *)mediaURL
                        title: (NSString *)title
                  description: (NSString *)description
                        genre: (NSString *)genre
                     subGenre: (NSString *)subGenre;

/*!
 Method to synchronize managed obect context with underlying data store. It should be invoked
 upon application lifecycle change events in order to guarantee that everything user changed
 is persisted
 */
- (void) saveContext;

@end
