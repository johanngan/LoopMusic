//
//  LoopMusicAppDelegate.m
//  LoopMusic
//
//  Created by Cheng Hann Gan on 12/24/13.
//  Copyright (c) 2013 Cheng Hann Gan. All rights reserved.
//

#import "LoopMusicAppDelegate.h"
#import "LoopMusicViewController.h"

@implementation LoopMusicAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    LoopMusicViewController *rootViewController = window.rootViewController;
    [rootViewController dim];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*UIWindow *window = [UIApplication sharedApplication].keyWindow;
    LoopMusicViewController *rootViewController = window.rootViewController;
    [rootViewController setInitBright:([UIScreen mainScreen].brightness)];*/
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    
    
    /*UIWindow *window = [UIApplication sharedApplication].keyWindow;
    LoopMusicViewController *rootViewController = window.rootViewController;
    [UIScreen mainScreen].brightness = [rootViewController getInitBright];*/
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
