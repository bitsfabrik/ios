/*
 * Licensed Materials - Property of IBM
 *
 * 5725E28, 5725I03
 *
 * © Copyright IBM Corp. 2011, 2017
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

#if __has_feature(modules)
@import MessageUI;
#else
#import <MessageUI/MessageUI.h>
#endif

#import <IBMMobilePush/IBMMobilePush.h>

@interface MailDelegate : NSObject <MCEActionProtocol, MFMailComposeViewControllerDelegate>
-(void)sendEmail:(NSDictionary*)action;
@end
