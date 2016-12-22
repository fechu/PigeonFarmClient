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
 * Shows a UIAlertView with the specified data.
 */
- (void)showMessageWithTitle:(NSString *)title 
                     message:(NSString *)message 
                  andButtons:(NSArray *)buttonTitles;

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
    
    NSURLConnection *connection;
    NSMutableData *receivedData;
    NSString *encoding;
    
    NSDictionary *messageData;
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
    
    // Create the request and start it.
    NSURL *messageUrl = [self assembledURL];
    NSLog(@"SMPigeonFarmClient: Check for new message at url: %@", messageUrl);
    NSURLRequest *request = [NSURLRequest requestWithURL:messageUrl];
    receivedData = [NSMutableData data];
    connection = [[NSURLConnection alloc] initWithRequest:request
                                                 delegate:self
                                         startImmediately:YES];
    if (!connection) {
        NSLog(@"SMPigeonFarmClient: No connection to server");
    }
}

- (void)showMessageWithTitle:(NSString *)title
                     message:(NSString *)message
                  andButtons:(NSArray *)buttonTitles
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:nil 
                                          otherButtonTitles:nil];
    
    // Add the buttons
    for (NSString *buttonTitle in buttonTitles) {
        [alert addButtonWithTitle:buttonTitle];
    }
    
    // Show the alert
    [alert show];
    
    // Call the block that the alert was shown.
    if (self.showMessageBlock) {
        self.showMessageBlock([messageData[@"id"] intValue]);
    }
}

#pragma UIAlertViewDelegate Methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSArray *buttons = messageData[@"buttons"];
    NSDictionary *button = [buttons objectAtIndex:buttonIndex];
    
    // Call the block that a button was clicked
    if (self.buttonTouchedBlock) {
        self.buttonTouchedBlock([messageData[@"id"] intValue], button);
    }
    
    if ([button[@"action"] isEqualToString:@"url"]) {
        // Open the url
        NSURL *openUrl = [NSURL URLWithString:button[@"url"]];
        [[UIApplication sharedApplication] openURL:openUrl];
    }
}

#pragma NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // Perhaps a redirection occured. So we reset the received data.
    [receivedData setLength:0];
    
    // Get the encoding. 
    encoding = [response textEncodingName];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the received data.
    [receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // We finished loading. 
    
    // Parse the json.
    NSError *error = nil;
    messageData = [NSJSONSerialization JSONObjectWithData:receivedData
                                                  options:NSJSONReadingMutableLeaves
                                                    error:&error];
    if (messageData == nil) {
        NSLog(@"SMPigeonFarmClient: Received data could not be parsed");
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

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"SMPigeonFarmClient: Connection failed");
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