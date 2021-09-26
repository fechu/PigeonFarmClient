/**
 *
 * @file UIApplication+ViewController.m
 * @author Sandro Meier <sandro.meier@fidelisfactory.ch>
 *
 */

#import "UIApplication+ViewController.h"

@implementation UIApplication (ViewController)

+ (UIViewController *)topMostViewController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    if ([topController isKindOfClass:[UINavigationController class]]) {
        topController = [(UINavigationController *)topController visibleViewController];
    }
    
    return topController;
}

@end
