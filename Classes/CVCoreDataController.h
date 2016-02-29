//
//  CVCoreDataController.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

static const NSString *kDefaultSoreFile;

/**
 * The core data controller to manage Core Data stack
 */
@interface CVCoreDataController : NSObject

// The managed object context to perform CRUD operations
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;



@end
