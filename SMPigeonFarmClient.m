/**
 *
 * @file SMPigeonFarmClient.h
 * @author Sandro Meier <sandro.meier@fidelisfactory.ch>
 *
 */

#import "SMPigeonFarmClient.h"
#import "UIApplication+ViewController.h"

/**
 *  The key used the defaults (NSUserDefaults) to store the ID that was last shown.
 *  @note Cannot be renamed due to backwards compatibility.
 */
#define LAST_ID_KEY @"SMUpdateMessageLastID"
/**
 *  Key that is used to store if this is the first launch in the user defaults. 
 *  This does not store the value of the `showOnFirstLaunch` but rather if it is the first launch.
 */
#define LAUNCHED_BEFORE_KEY @"SMPigeonFarmClientLaunchedBefore"

@interface SMPigeonFarmClient ()

/**
 * Shows a UIAlertView with the specified data.
 */
- (void)showMessageWithTitle:(NSString *)title 
                     message:(NSString *)message 
                  andButtons:(NSArray *)buttonData;

/**
 *  Assembles the URL
 *
 *  Takes the given URL and assembles the URL. Also replaces all the placeholders with the actual values.
 *
 *  @return The assembled urls which includes no more placeholders.
 */
- (NSURL *)assembledURL;

/**
 * Is this the first launch of the application. 
 * This is used together with the `showOnFirstLaunch` property.
 */
- (BOOL)isFirstLaunch;

@end

@implementation SMPigeonFarmClient {
    NSDictionary *messageData;
}

@synthesize url;
@synthesize lastID;
@synthesize showOnFirstLaunch;

#pragma mark Public Interface

- (id)init
{
    self = [super init];
    if (self) {
        lastID = -1;
        showOnFirstLaunch = NO;
    }
    return self;
}

- (void)showMessage
{
    if (url == nil) {
        // Raise an exception if no url is given.
        [[NSException exceptionWithName:@"InvalidURLException"
                                 reason:@"No URL was set in SMPigeonFarmClient"
                               userInfo:nil] raise];
    }
    
    // Let's check if this is the first launch, and if yes if we even should show a message
    if ([self isFirstLaunch]) {
        // We store that this was the first launch and that we later want to show messages.
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:LAUNCHED_BEFORE_KEY];
        
        // This is the first launch? Does the client want that we show the message?
        if (!showOnFirstLaunch) {
            NSLog(@"SMPigeonFarmClient: Skipping message because of first launch");
            return;
        }
    }
    
    // Load the data from the URL
    NSURL *messageUrl = [self assembledURL];
    NSLog(@"SMPigeonFarmClient: Check for new message at url: %@", messageUrl);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:messageUrl completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // We finished loading.
        if (error) {
            NSLog(@"SMPigeonFarmClient: Failed to contact server: %@", error);
            return;
        }
        
        // Parse the json.
        NSError *jsonError = nil;
        messageData = [NSJSONSerialization JSONObjectWithData:data
                                                      options:NSJSONReadingMutableLeaves
                                                        error:&jsonError];
        if (messageData == nil) {
            NSLog(@"SMPigeonFarmClient: Received data could not be parsed");
            NSLog(@"SMPigeonFarmClient: %@", jsonError);
            return;
        }
        
        /// TODO: Check the messageData before processing.
        /// Right now the application will crash if required data is missing.
        
        // Show the message if its a new message
        if ([[messageData objectForKey:@"id"] intValue] != self.lastID) {
            // Get the data
            NSString *title = messageData[@"title"];
            NSString *message = messageData[@"message"];
            NSArray *buttons = messageData[@"buttons"];
            
            [self showMessageWithTitle:title message:message andButtons:buttons];
            
            // Update the id.
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:messageData[@"id"] forKey:LAST_ID_KEY];
        }
        else {
            NSLog(@"SMPigeonFarmClient: Message with id %d already shown!", self.lastID);
        }
    }];
    [task resume];
}

#pragma mark Getter

- (int)lastID
{
    if (lastID == -1) {
         // Load the last ID.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        lastID = [[defaults objectForKey:LAST_ID_KEY] intValue];
    }
    
    return lastID;
}

#pragma mark - Private Methods

- (void)showMessageWithTitle:(NSString *)title
                     message:(NSString *)message
                  andButtons:(NSArray *)buttonData
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    // Add the buttons
    for (NSDictionary *button in buttonData) {
        NSString *title = button[@"title"];
        
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            // Call the block that a button was clicked
            if (self.buttonTouchedBlock) {
                self.buttonTouchedBlock([messageData[@"id"] intValue], button);
            }
            
            if ([button[@"action"] isEqualToString:@"url"]) {
                // Open the url
                NSURL *openUrl = [NSURL URLWithString:button[@"url"]];
                [[UIApplication sharedApplication] openURL:openUrl options:@{} completionHandler:nil];
                
            }
        }];
        [alert addAction:action];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Show the alert
        UIViewController *topViewController = [UIApplication topMostViewController];
        [topViewController presentViewController:alert animated:YES completion:nil];
    });
    
    // Call the block that the alert was shown.
    if (self.showMessageBlock) {
        self.showMessageBlock([messageData[@"id"] intValue]);
    }
}


- (NSURL *)assembledURL
{
    // Replace __VERSION__ in the url
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = infoDic[@"CFBundleShortVersionString"];
    NSString *urlString = [url stringByReplacingOccurrencesOfString:@"__VERSION__"
                                                         withString:appVersion];
    
    // Replace __LANGUAGE__ in the url
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"__LANGUAGE__"
                                                     withString:language];
    
    return [NSURL URLWithString:urlString];
}

- (BOOL)isFirstLaunch
{
    // Check the user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL launchedBefore = [defaults boolForKey:LAUNCHED_BEFORE_KEY];
    
    return !launchedBefore;
}

@end
