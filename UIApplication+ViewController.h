/**
 *
 * @file UIApplication+ViewController.h
 * @author Sandro Meier <sandro.meier@fidelisfactory.ch>
 *
 */

#import <UIKit/UIKit.h>

@interface UIApplication (ViewController)

/**
 *  Finds and returns the top most view controller.
 *  This method will not return a UINavigationController. If the topmost viewcontroller is a 
 *  UINavigationController, its visible viewcontroller will be returned. 
 *
 *  @return The top most view controller
 */
+ (UIViewController *)topMostViewController;

@end
