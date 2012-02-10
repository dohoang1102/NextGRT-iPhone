//
//  BusRoute.m
//  GRTEasyGo
//
//  Created by Yuanfeng on 11-07-05.
//  Copyright 2011 Elton(Yuanfeng) Gao. All rights reserved.
//

#import "BusRoute.h"
#import "CountDown.h"

@implementation BusRoute

@synthesize fullRouteNumber = fullRouteNumber_, shortRouteNumber = shortRouteNumber_, routeID = routeID_;

//init the route with first direction and its time
- (id) initWithRouteNumber:(NSString*)routeNumber routeID:(NSString*)routeID direction:(NSString*)dir AndTime:(NSString*)time {
    if( [routeNumber compare:@"200"] == NSOrderedSame ) {
        self.shortRouteNumber = @"iXps";
//        self.fullRouteNumber = @"iXpress";
        self.fullRouteNumber = @"";
    } else {
        self.shortRouteNumber = routeNumber;
        if ([routeNumber compare:@"7"] == NSOrderedSame || [routeNumber compare:@"8"] == NSOrderedSame) { //add more stop here for special cases
            self.fullRouteNumber = routeNumber;
        } else
        {
            //add a space to last number to separate route number and description, and iXps will not have a space at the front
            self.fullRouteNumber = [routeNumber stringByAppendingString:@" "];
        }
    }
    
    self.routeID = routeID;
    nextArrivalTimes_ = [[NSMutableArray alloc] initWithObjects:time, nil];
    nextArrivalDirection_ = [[NSMutableArray alloc] initWithObjects:dir, nil];
    nextBusCountDown_ = [[NSMutableArray alloc] initWithObjects: nil];
    
    return self;
}

- (void) addNextArrivalTime:(NSString*)time Direction:(NSString*) direction {
    [nextArrivalTimes_ addObject:time];
    [nextArrivalDirection_ addObject:direction];
}

- (void) refreshCountDownWithSeconds:(NSTimeInterval)seconds {
    //simply modify every countDown object
    for( CountDown* countDown in nextBusCountDown_ ) {
        countDown.countDown = countDown.countDown - seconds;
    }
}

- (NSString*) getArrivalTime:(int) index {
    while( [nextBusCountDown_ count] > index ) { //while there is a count down
        NSTimeInterval countDown = [[nextBusCountDown_ objectAtIndex:index] countDown];
        if( countDown < -30 ) {
            [nextBusCountDown_ removeObjectAtIndex:index];
            //TODO should combine them together so that they don't exist when count down is deleted
            [nextArrivalDirection_ removeObjectAtIndex:index];
            [nextArrivalTimes_ removeObjectAtIndex:index];
        } else if( countDown < 30 ) {
            return [NSString stringWithString:local(@"Arriving")];
        } else {
            return [self parseTimeInterval:countDown];
        }
    }
    //no more buses available;
    return [NSString stringWithString:local(@"No more service")];
}

- (NSString*) getNextBusDirection {
    if( [nextArrivalDirection_ count] > 1 ) {
        return [nextArrivalDirection_ objectAtIndex:0];
    }
    return @"";
}

- (NSString*) getFirstArrivalTime {
    return [self getArrivalTime:0];
}

- (NSString*) getFirstArrivalActualTime {
    if ([nextArrivalTimes_ count] > 0) {
            return [nextArrivalTimes_ objectAtIndex:0];
    }
    return @"";
}

- (NSString*) getSecondArrivalTime {
    NSString* result = [self getArrivalTime:1];
    if( [result compare:[NSString stringWithString:@"No service"]] == NSOrderedSame ) {
        return [NSString stringWithString:local(@"No more service")];
    } else {
        return result;
    }
}

- (NSString*) getSecondArrivalActualTime {
    if ([nextArrivalTimes_ count] > 1) {
        return [nextArrivalTimes_ objectAtIndex:1];
    }
    return @"";
}

- (void) initNextArrivalCountDownBaesdOnTime:(NSDate*)time {
    
    //get time's date and year using dateFormatter
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd"];
    NSString* currDateString = [dateFormat stringFromDate:time];
    
    NSDateFormatter* inputFormatter = [[NSDateFormatter alloc] init];
    [inputFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"]; 
    
    //TODO nextArrival should be nextDeparture
    //loop through every nextArrivalTime and calculate the count down
    for( NSString* nextArrivalTime in nextArrivalTimes_ ) {
        int offset = 0;
        NSString *adjustedTime = [nextArrivalTime copy];
        //Problem: the query actually return with some time as "24:13:00" which whill not be parsed correctly
        //Solution: if we get any hour value > 23, we chop it off and add it back to count down later
        NSArray* timeComponents = [nextArrivalTime componentsSeparatedByString:@":"];
        if( [timeComponents count] > 1 ) {
            NSString* hourComponent = [timeComponents objectAtIndex:0];
            int hour = [hourComponent intValue];
            if( hour > 23 ){
                offset = hour % 23;
                hour = 23; //adjust time to 23:min:sec, then add the missing hours back later
                adjustedTime = [NSString stringWithFormat:@"%d:%@:%@", hour, [timeComponents objectAtIndex:1], [timeComponents objectAtIndex:2]];
                currDateString = [dateFormat stringFromDate:time];
            }
        }
        
        //now combine currDateString with nextBusTime to generate the actual time
        
        NSString* combined = [NSString stringWithFormat:@"%@ %@", currDateString, adjustedTime];
        NSDate* nextArrivalTimeInNSDate = [inputFormatter dateFromString:combined];
        
        if( nextArrivalTimeInNSDate ) {
            //countdown will be negative if next arrival is like 24:14:00
            NSTimeInterval countDown = [nextArrivalTimeInNSDate timeIntervalSinceDate:time];
            countDown += offset * 3600; //add the missing hours back to countDown
            CountDown* c = [[CountDown alloc] initWithTimeInterval:countDown];
            [nextBusCountDown_ addObject: c];
            
            //NSLog(@"time countdown: %f", diff);
        } else {
            NSLog(@"ERROR! invalid nextArrivalTimeInNSDate");
        }   
    }
}

-(NSString*) parseTimeInterval:(NSTimeInterval) diff {
    //manually convert timeInterval to hour min and sec
    int hour = diff/3600;
    int minAndSec = (int)diff % 3600;
    int min = minAndSec / 60;
    int sec = minAndSec % 60;
    if( sec > 30 ) {
        min++; //count sec as a min
    }
    NSString* result;
    if( hour != 0 ) {
        result = [[NSString alloc] initWithFormat:@"%d%@%02d%@", hour, local(@"h"), min, local(@"m")]; //%02dh%02dm
    } else {
        //just output hour
        result = [[NSString alloc] initWithFormat:@"%d%@", min, local(@"min")];
    }
    return result;
}

- (void)dealloc {
//    [fullRouteNumber_ release];
//    [shortRouteNumber_ release];    
//    [routeID_ release];  
//    [direction_ release];      
//    [nextArrivalTimes_ release];  
//    [nextArrivalDirection_ release];  
//    [nextBusCountDown_ release];  
//    [super dealloc];
}

@end
