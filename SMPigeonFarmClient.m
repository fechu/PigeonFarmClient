/**
 *
 * @file SMPigeonFarmClient.h
 * @author Sandro Meier <sandro.meier@fidelisfactory.ch>
 *
 */

#import "SMPigeonFarmClient.h"

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
 * Checks that the given data is valid message data. I.e. it checks that it contains all the required keys.
 * Refer to the README for an example of a full message.
 */
- (BOOL)validateMessageData:(NSDictionary *)data;

/**
 * Shows a UIAlertView with the specified data.
 */
- (void)showMessageWithTitle:(NSString *)title 
                     message:(NSString *)message 
                  andButtons:(NSArray *)buttonTitles;

/**
 * Handles the received data and shows a message if necessary.
 */
- (void)handleReceivedData:(NSData *)data;

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
    
    /**
     * The parsed message data.
     */
    NSDictionary *messageData;

    /**
     * The view controller in which the messages should be shown once loaded.
     */
    UIViewController *viewController;
}

@synthesize url;
@synthesize lastID;
@synthesize showOnFirstLaunch;

- (id)init
{
    self = [super init];
    if (self) {
        lastID = -1;
        showOnFirstLaunch = NO;
    }
    return self;
}

- (void)showMessageInViewController:(UIViewController *)aViewController
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

    // Remember the view controller for later.
    viewController = aViewController;
    
    // Create the request and start it.
    NSURL *messageUrl = [self assembledURL];
    NSLog(@"SMPigeonFarmClient: Check for new message at url: %@", messageUrl);
    NSURLSession *session = [NSURLSession sharedSession];
    void (^completionHandler)(NSData * _Nullable,
                              NSURLResponse * _Nullable,
                              NSError * _Nullable) = ^void(NSData * _Nullable data,
                                                           NSURLResponse * _Nullable response,
                                                           NSError * _Nullable error) {
        if (error == nil) {
            [self handleReceivedData:data];
        }
        else {
            NSLog(@"SMPigeonFarmClient: Failure loading data from: %@", error);
        }
    };
    NSURLSessionDataTask *task = [session dataTaskWithURL:messageUrl
                                        completionHandler:completionHandler];
    [task resume];
}

#pragma mark - Private Methods

- (BOOL)validateMessageData:(NSDictionary *)data
{
    if (![data isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    
    if ([data objectForKey:@"title"] && [data objectForKey:@"id"] && [data objectForKey:@"message"] && [data objectForKey:@"buttons"]) {
        // Check all the buttons
        if (![[data objectForKey:@"buttons"] isKindOfClass:[NSArray class]]) {
            return NO;
        }
        NSArray *buttons = [data objectForKey:@"buttons"];
        
        for (NSDictionary *buttonData in buttons) {
            if (![buttonData isKindOfClass:[NSDictionary class]]) {
                return NO;
            }
            // Required keys for buttons
            if (!([buttonData objectForKey:@"title"] && [buttonData objectForKey:@"action"])) {
                return NO;
            }
            
            // If the action is URL we also need a "url" field
            if ([[buttonData objectForKey:@"action"]  isEqual: @"url"] && ![buttonData objectForKey:@"url"]) {
                return NO;
            }
        }
    } else {
        return NO;
    }
    
    return YES;
}

- (void)showMessageWithTitle:(NSString *)title
                     message:(NSString *)message
                  andButtons:(NSArray *)buttonTitles
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    // Add the buttons
    int i = 0;
    for (NSString *buttonTitle in buttonTitles) {
        void (^handler)(UIAlertAction * action) = ^void(UIAlertAction *action) {
            NSArray *buttons = self->messageData[@"buttons"];
            NSDictionary *button = [buttons objectAtIndex:i];
            
            // Call the block that a button was clicked
            if (self.buttonTouchedBlock) {
                self.buttonTouchedBlock([self->messageData[@"id"] intValue], button);
            }
            
            if ([button[@"action"] isEqualToString:@"url"]) {
                // Open the url
                NSURL *openUrl = [NSURL URLWithString:button[@"url"]];
                [[UIApplication sharedApplication] openURL:openUrl options:@{} completionHandler: nil];
            }
        };
        
        UIAlertAction *action = [UIAlertAction actionWithTitle:buttonTitle
                                                         style:UIAlertActionStyleDefault
                                                       handler:handler];
        [alert addAction:action];
        i++;
    }
    
    // Show the alert
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController presentViewController:alert
                                     animated:true
                                   completion:NULL];
    });

    // Call the block that the alert was shown.
    if (self.showMessageBlock) {
        self.showMessageBlock([messageData[@"id"] intValue]);
    }
}

- (void)handleReceivedData:(NSData *)data
{
    // We finished loading.
    // Parse the json.
    NSError *error = nil;
    messageData = [NSJSONSerialization JSONObjectWithData:data
                                                  options:NSJSONReadingMutableLeaves
                                                    error:&error];
    if (messageData == nil) {
        NSLog(@"SMPigeonFarmClient: Received data could not be parsed");
        return;
    }
    
    // Check the messageData before processing.
    if (![self validateMessageData:messageData]) {
        NSLog(@"SMPigeonFarmClient: Received data is not a valid message");
        NSLog(@"SMPigeonFarmClient: %@", messageData);
        return;
    }

    // Show the message if its a new message
    if ([[messageData objectForKey:@"id"] intValue] != self.lastID) {
        // Get the data
        NSString *title = messageData[@"title"];
        NSString *message = messageData[@"message"];
        NSArray *buttons = messageData[@"buttons"];
        
        // Get the button names
        NSMutableArray *buttonNames = [NSMutableArray array];
        for (NSDictionary *buttonDic in buttons) {
            [buttonNames addObject:buttonDic[@"title"]];
        }
        
        [self showMessageWithTitle:title message:message andButtons:buttonNames];
        
        // Update the id.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:messageData[@"id"] forKey:LAST_ID_KEY];
    }
    else {
        NSLog(@"SMPigeonFarmClient: Message with id %d already shown!", self.lastID);
    }
}

#pragma Getter

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
