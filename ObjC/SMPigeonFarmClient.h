/**
 *
 * @file SMPigeonFarmClient.h
 * @author Sandro Meier <sandro.meier@fidelisfactory.ch>
 *
 */

#import <Foundation/Foundation.h>

/**
 *  A block that can be used as a callback when a message is shown.
 *
 *  @param messageId The id of the message that is shown.
 */
typedef void(^SMPigeonFarmClientShowMessageBlock)(int messageId);

/**
 *  A block that can be used as a callback when a button is pressed in alert view.
 *
 *  @param messageId The id of the message that is shown.
 *  @param button    The button data of the button that was touched. This is exactly the same 
 *                   dictionary as the one received from the server for this button.
 */
typedef void(^SMPigeonFarmClientButtonTouchedBlock)(int messageId, NSDictionary *button);

@interface SMPigeonFarmClient : NSObject <NSURLConnectionDataDelegate, UIAlertViewDelegate>

/**
 * The location where the JSON data containing the message can be found.
 * The URL will have approximatly look like the following: "http://www.example.com/news.json"
 * 
 * Placeholders: 
 *  - __VERSION__ : The version of the application
 *  - __LANGUAGE__: The language of the device.
 *
 * Example:
 *  http://www.example.com/news.php?version=__VERSION__&language=__LANGUAGE__
 *  If you are using Version 1.0.1 the URL will look like this when called.
 *  http://www.example.com/news.php?version=1.0.1&language=de
 */
@property(nonatomic, strong) NSString *url;

/**
 *  The ID of the last message that was shown.
 */
@property(nonatomic, readonly) int lastID;

/**
 *  A block that gets executed when a message is shown.
 */
@property(nonatomic, copy) SMPigeonFarmClientShowMessageBlock showMessageBlock;

/**
 *  A block that is executed when the user touches a button in a message popup.
 */
@property(nonatomic, copy) SMPigeonFarmClientButtonTouchedBlock buttonTouchedBlock;

/**
 * Downloads the newest messages and shows it.
 */
- (void)showMessage;

@end
