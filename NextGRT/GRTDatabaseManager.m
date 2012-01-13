//
//  GRTDatabaseManager.m
//  GRTEasyGo
//
//  Created by Yuanfeng on 11-05-27.
//  Copyright Elton(Yuanfeng) Gao 2011. All rights reserved.
//

#import "GRTDatabaseManager.h"
#import <sqlite3.h>
#import "Stop.h"
#import "BusRoute.h"
#import <CoreLocation/CoreLocation.h>

static GRTDatabaseManager* sharedManager = nil;

@implementation GRTDatabaseManager

@synthesize databasePath = databasePath_, delegate;

+ (id) sharedManager {
    @synchronized(self) {
        if( sharedManager == nil ) {
            sharedManager = [[GRTDatabaseManager alloc] init];
        }
    }
    return sharedManager;
}

- (id) init {
    self = [super init];
    if( self ) {
        // Setup some globals
        databaseName_ = kDatabaseName;
        
        // Get the path to the documents directory and append the databaseName
        NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDir = [documentPaths objectAtIndex:0];
        self.databasePath = [documentsDir stringByAppendingPathComponent:databaseName_];
        
        //load database
        // Check if the SQL database has already been saved to the users phone, if not then copy it over
        BOOL success;
        
        // Create a FileManager object, we will use this to check the status
        // of the database and to copy it over if required
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Check if the database has already been created in the users filesystem
        success = [fileManager fileExistsAtPath:self.databasePath];
        
        // If the database already exists then return without doing anything
        if( !success ) {
            // If not then proceed to copy the database from the application to the users filesystem
            
            // Get the path to the database in the application package
            NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseName_];
            
            // Copy the database from the package to the users filesystem
            [fileManager copyItemAtPath:databasePathFromApp toPath:self.databasePath error:nil];
            
        }
    }
    return self;
}

/*Notes for Developer:
 The following sqlite queries requires modification to original GRT database, please make sure the following is done so that the app run as expected:
 1. In Calendar Table, make sure no out-dated service_id exists(only allow one service_id), otherwise we can have multiple entry for a same time for same bus/bus stop
 2. In CalendarDate Table, all entris having retired service_id must be deleted
 3. In Stops: stop_lat and stop_lon needs to be DOUBLE or it will not get any result. 
 4. All Stop_id field must be numeric
 5. In Calandar Table, monday, tuesday.... must be NUMERIC 
 if there is any problem, feel free to email to gyfelton@gmail.com
*/

- (void) queryStopIDs:(NSArray*) stopIDs withDelegate:(id)object groupByStopName:(bool) groupByStopname {
    self.delegate = object;
    // Setup the database object
	sqlite3 *database;
    NSMutableArray* results = [[NSMutableArray alloc] init];
    
	// Open the database from the users files sytem
	if(sqlite3_open([self.databasePath UTF8String], &database) == SQLITE_OK) {
        for( NSString* stopID in stopIDs ) {
            
            // Setup the SQL Statement and compile it for faster access
            NSString* completeSQLStmt = [NSString stringWithFormat:kQueryStopIDs, stopID];
            if (groupByStopname) {
                completeSQLStmt = [completeSQLStmt stringByAppendingString:kQueryFilterGroupByStopName];
            }
            
            sqlite3_stmt *compiledStatement;
            if(sqlite3_prepare_v2(database, [completeSQLStmt UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
                // get all results
                while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
                    // Read the data from the result row
                    //TODO check char* return is null or not before format to string
                    float lat = sqlite3_column_double(compiledStatement, 0);
                    float lon = sqlite3_column_double(compiledStatement, 2);
                    
                    NSString *stopID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 3)];
                    NSString *stopName = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 4)];
                    
                    // Create a new animal object with the data from the database
                    Stop* theStop = [[Stop alloc] initWithStopID:stopID AndStopName:stopName Lat:lat Lon:lon];
                    [results addObject:theStop];
                }
            }
            // Release the compiled statement from memory
            sqlite3_finalize(compiledStatement);
        }
	}
	sqlite3_close(database);
    
    //[self.delegate stopInfoArrayReceived:results];
}

- (void) calculateLatLonBaseOffset:(CLLocation*)location {
    //base on 100m and 45 degree bearing, 200m,300m and so on is linear relationship(approximation)
    //6371:earth's radius
    //based on uw's location, there is some offset needed to be added, turns out it is 0.0007
    //source: http://www.movable-type.co.uk/scripts/latlong.html
    
    latLonBaseOffset_ = 0.1 / 6371 * sqrt(2) + 0.0007;
}

- (void) queryNearbyStops:(CLLocation *)location withDelegate:(id)object  withSearchRadiusFactor:(double)factor {
    
    //for debug purpse:
//    NSLog(@"ATTENTION! location is override!");
//    CLLocation* temp = [[[CLLocation alloc] initWithLatitude:43.472617 longitude:-80.541059] autorelease];
//    location = temp;
    
    self.delegate = object;
    
    // Setup the database object
	sqlite3 *database;
    
    //init result array
    NSMutableArray* stops = [[NSMutableArray alloc] init];
    
    NSLog(@"current location -  lat:%f, lon:%f", location.coordinate.latitude, location.coordinate.longitude);
    [self calculateLatLonBaseOffset:location]; //init latLonBaseOffset_
    
	// Open the database from the users files sytem
	if(sqlite3_open([self.databasePath UTF8String], &database) == SQLITE_OK) {
        //calculate radius needed
        double radius = 5 * factor; //500m * factor
        
		// Setup the SQL Statement and compile it for faster access
        NSString* completeSQLStmt = 
            [NSString stringWithFormat:kQueryNearbyStops
                                        , location.coordinate.latitude - latLonBaseOffset_ * radius
                                        , location.coordinate.latitude + latLonBaseOffset_ * radius
                                        , location.coordinate.longitude - latLonBaseOffset_ * radius
                                        , location.coordinate.longitude + latLonBaseOffset_ * radius];
		sqlite3_stmt *compiledStatement;
		if(sqlite3_prepare_v2(database, [completeSQLStmt UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
            while(sqlite3_step(compiledStatement) == SQLITE_ROW) {
				// Read the data from the result row
                //TODO check char* return is null or not before format to string?
                float lat = sqlite3_column_double(compiledStatement, 0);
                float lon = sqlite3_column_double(compiledStatement, 2);
                
                double distance = 0;//[location distanceFromLocation:[[[CLLocation alloc] initWithLatitude:lat longitude:lon] autorelease]];
                
				NSString *stopID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 3)];
				NSString *stopName = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 4)];
				
				// Create a new stop object with the data from the database
				Stop* aStop = [[Stop alloc] initWithStopID:stopID AndStopName:stopName Lat:lat Lon:lon distanceFromCurrPosition:distance];
                [stops addObject:aStop];
			}
		}
		// Release the compiled statement from memory
		sqlite3_finalize(compiledStatement);
	}
	sqlite3_close(database);
    
    //sort the stops here since we gurantee that stops here all have a proper distance data
    [stops sortUsingSelector:@selector(compareDistanceWithStop:)];
    
    //pass the data back to delegate
    [self.delegate nearbyStopsReceived: stops];
}

- (NSString*) dayOfWeekHelper {
    int weekday = [[[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:[NSDate date]] weekday];
    switch (weekday) {
        case 1:
            return [NSString stringWithString:@"sunday"];
            break;
        case 2:
            return [NSString stringWithString:@"monday"];
            break;
        case 3:
            return [NSString stringWithString:@"tuesday"];
            break;
        case 4:
            return [NSString stringWithString:@"wednesday"];
            break;
        case 5:
            return [NSString stringWithString:@"thursday"];
            break;
        case 6:
            return [NSString stringWithString:@"friday"];
            break;
        case 7:
            return [NSString stringWithString:@"saturday"];
            break;
        default:
            return [NSString stringWithString:@"monday"];
            break;
    }
}

- (void) queryBusRoutesForStops:(NSMutableArray*)stops withDelegate:(id)object {
    self.delegate = object;
    
    //generate current time (truncate seconds)
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH':'mm':'00"];
    NSString* currTime = [formatter stringFromDate:[NSDate date]];
    NSLog(@"currTime: %@", currTime);
    
    // Setup the database object
	sqlite3 *database;
    
    // Open the database from the users files sytem
	if(sqlite3_open([self.databasePath UTF8String], &database) == SQLITE_OK) {
        for( Stop* aStop in stops) {
            //to store routes
            NSMutableArray* routes = [NSMutableArray arrayWithCapacity:0];
            
            //TODO handle case on special days
            //Firstly, construct the day of today
            NSString* dayOfWeek = [self dayOfWeekHelper]; 
            
            //The, retrieve serviceID
            NSString* serviceIDQuery = [NSString stringWithFormat:kQueryNormalServiceID, dayOfWeek];
            
            // Setup the SQL Statement and compile it for faster access
            NSString* completeSQLStmt = [NSString stringWithFormat:kQueryRoutesTimes, [aStop stopID], currTime, serviceIDQuery];
            sqlite3_stmt *compiledStatement;
            if(sqlite3_prepare_v2(database, [completeSQLStmt UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
                NSString* currRoute = nil;
                BusRoute* route = nil;
                
                while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
                    // Read the data from the result row
                    NSString* routeNum = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 0)];
                    NSString* departureTime = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 1)];
                    NSString* direction = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 2)];
                    
                    if( currRoute && [currRoute compare:routeNum] == NSOrderedSame ) {
                        //just add the time and direction since it is the same bus
                        [route addNextArrivalTime:departureTime Direction:direction];
                    } else { //we encounter a new route, add route to array
                        if( route ) {
                            [routes addObject:route];
                            //[route release];
                        }
                        currRoute = routeNum;
                        
                        //alloc a new route object for new route
                        route = [[BusRoute alloc] initWithRouteNumber:currRoute routeID:currRoute direction:direction AndTime:departureTime];
                    }
                }
                //add last route to it
                if (route) {
                    [routes addObject:route];
                }
            }
            // Release the compiled statement from memory
            sqlite3_finalize(compiledStatement);
            
            for( BusRoute* route in routes ) {
                [route initNextArrivalCountDownBaesdOnTime:[NSDate date]];
            }
            [aStop assignBusRoutes: routes];
        }
    }
    sqlite3_close(database);
    
    [self.delegate busRoutesForAllStopsReceived];
}

- (NSMutableArray*) queryAllStopsWithStopName:(NSString*)stopName {
    // Setup the database object
	sqlite3 *database;
    NSMutableArray* results = [[NSMutableArray alloc] init];
    
	// Open the database from the users files sytem
	if(sqlite3_open([self.databasePath UTF8String], &database) == SQLITE_OK) {
        // Setup the SQL Statement and compile it for faster access
        NSString* completeSQLStmt = [NSString stringWithFormat:kQueryStopsWithStopName, stopName];

        sqlite3_stmt *compiledStatement;
        if(sqlite3_prepare_v2(database, [completeSQLStmt UTF8String], -1, &compiledStatement, NULL) == SQLITE_OK) {
            // get all results
            while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
                // Read the data from the result row
                //TODO check char* return is null or not before format to string
                float lat = sqlite3_column_double(compiledStatement, 0);
                float lon = sqlite3_column_double(compiledStatement, 2);
                
                NSString *stopID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 3)];
                NSString *stopName = [NSString stringWithUTF8String:(char *)sqlite3_column_text(compiledStatement, 4)];
                
                // Create a new stop object with the data from the database
                Stop* theStop = [[Stop alloc] initWithStopID:stopID AndStopName:stopName Lat:lat Lon:lon];
                [results addObject:theStop];
            }
        }
        // Release the compiled statement from memory
        sqlite3_finalize(compiledStatement);
	}
	sqlite3_close(database);
    
    return results;
}

@end
