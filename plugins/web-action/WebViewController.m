/*
 * Licensed Materials - Property of IBM
 *
 * 5725E28, 5725I03
 *
 * © Copyright IBM Corp. 2014, 2018
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

#import "WebViewController.h"

@interface WebViewController ()

@end

@implementation WebViewController

-(instancetype)initWithURL:(NSURL*)url;
{
    if(self=[super init])
    {
        const NSInteger toolbarHeight = 44;
        UIScreen * screen = [UIScreen mainScreen];
        NSInteger statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        NSInteger webVerticalOffset = statusHeight + toolbarHeight;

        CGRect toolbarFrame = screen.bounds;
        toolbarFrame.size.height = toolbarHeight;
        toolbarFrame.origin.y = statusHeight;

        UIToolbar * toolbar = [[UIToolbar alloc] initWithFrame: toolbarFrame];
        [self.view addSubview:toolbar];

        UIBarButtonItem * dismiss = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action: @selector(dismiss:)];
        toolbar.items = @[dismiss];
        
        CGRect webFrame = screen.bounds;
        webFrame.origin.y += webVerticalOffset;
        webFrame.size.height -= webVerticalOffset;

        UIWebView * webView = [[UIWebView alloc] initWithFrame:webFrame];
        [webView loadRequest: [NSURLRequest requestWithURL: url]];
        [self.view addSubview:webView];
        webView.delegate=self;
        
        self.view.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

-(IBAction)dismiss:(id)sender
{
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

@end
