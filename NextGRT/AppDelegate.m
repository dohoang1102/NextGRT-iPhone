//
//  AppDelegate.m
//  NextGRT
//
//  Created by Yuanfeng on 12-01-13.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

#import "FavouritesViewController.h"

#import "SearchViewController.h"

#import "MoreViewController.h"

@implementation AppDelegate

@synthesize locationServiceBecomeActive;
@synthesize tabBarController = _tabBarController;

+ (CLLocationManager*)sharedLocationManager {
    static CLLocationManager* locationManager_;
    
    @synchronized (self) {
        if( !locationManager_ ) {
            locationManager_ = [[CLLocationManager alloc] init];
            locationManager_.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        }
    }
    return locationManager_;
}

void uncaughtExceptionHandler(NSException *exception) {
    NSArray *arr = [exception callStackSymbols];
    NSString *reason = [exception reason];
    NSString *name = [exception name];
    NSString *intro = local(@"NextGRT crash report&body=NextGRT just crashed, please help us improve it by sending this crash report :-)<br>Please also indicate below what is the operation causing the crash (such as 'click at a bus stop'):");
    NSString *urlStr = [NSString stringWithFormat:@"mailto:gyfelton@gmail.com?subject=%@<br>"
                        "Detail info:<br>%@<br>--------------------------<br>%@<br>---------------------<br>%@", 
                        intro, name,reason,[arr componentsJoinedByString:@"<br>"]];
    
    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [[UIApplication sharedApplication] openURL:url];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (![super application:application didFinishLaunchingWithOptions:launchOptions])
    {
        return NO; //super is not ready, we cannot continue launch
    }
    
    // Override point for customization after application launch.
 
    NSSetUncaughtExceptionHandler (&uncaughtExceptionHandler);
    
    UIViewController *viewController1 = [[FavouritesViewController alloc] initWithNibName:@"FavouritesViewController" bundle:nil];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:viewController1];
//    viewController1.navigationController.navigationBar.tintColor = [UIColor colorWithRed:49/255 green:92/255 blue:152/255 alpha:1.0f];
    
    UIViewController *viewController2 = [[SearchViewController alloc] initWithNibName:@"SearchViewController" bundle:nil];
    
    UIViewController *viewController3 = [[MoreViewController alloc] initWithNibName:@"MoreViewController" bundle:nil];
    UINavigationController *nav3 = [[UINavigationController alloc] initWithRootViewController:viewController3];
    
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = [NSArray arrayWithObjects:nav1, viewController2, nav3, nil];

    self.window.rootViewController = self.tabBarController;
//    self.window.backgroundColor = UITableBackgroundColor;
    [self.window makeKeyAndVisible];
    
    //set to YES for countdown if never set before
    NSDictionary *countDown = [[NSUserDefaults standardUserDefaults] dictionaryForKey:USER_DEFAULT_KEY_COUNTDOWN];
    if (!countDown) { 
        [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"bool"] forKey:USER_DEFAULT_KEY_COUNTDOWN];
    }
    
    //set YES to show actual time if never set before
    NSDictionary *actualTime = [[NSUserDefaults standardUserDefaults] dictionaryForKey:USER_DEFAULT_KEY_ACTUAL_TIME];
    if (!actualTime) { 
        [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"bool"] forKey:USER_DEFAULT_KEY_ACTUAL_TIME];
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
}
*/

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed
{
}
*/

@end
