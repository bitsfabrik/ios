/*
 * Licensed Materials - Property of IBM
 *
 * 5725E28, 5725I03
 *
 * © Copyright IBM Corp. 2011, 2017
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
#import "MainVC.h"
#import <IBMMobilePush/IBMMobilePush.h>

@interface MainVC ()
@property (nonatomic, strong) id previewingContext;
@end

@implementation MainVC

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self inboxUpdate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [version setText: MCESdk.sharedInstance.sdkVersion];
    
    if ([self isForceTouchAvailable]) {
        self.previewingContext = [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }
    
    // Show Inbox counts on main page
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inboxUpdate) name:@"MCESyncDatabase" object:nil];
    if(MCERegistrationDetails.sharedInstance.mceRegistered)
    {
        [[MCEInboxQueueManager sharedInstance] syncInbox];
    }
    else
    {
        [NSNotificationCenter.defaultCenter addObserverForName: MCERegisteredNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
            [[MCEInboxQueueManager sharedInstance] syncInbox];
        }];
    }
}

// Show Inbox counts on main page
-(void)inboxUpdate
{
    NSArray * messages = [[MCEInboxDatabase sharedInstance] inboxMessagesAscending: true];
    int unreadCount = 0;
    for(MCEInboxMessage * message in messages)
    {
        if(!message.isRead)
        {
            unreadCount += 1;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString * subtitle = @"";
        if(MCERegistrationDetails.sharedInstance.mceRegistered)
        {
            subtitle = [NSString stringWithFormat:@"%lu messages, %d unread", messages.count, unreadCount];
        }
        inboxCell.detailTextLabel.text = subtitle;
        altInboxCell.detailTextLabel.text = subtitle;
        [self.tableView reloadData];
    });
}

- (BOOL)isForceTouchAvailable
{
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)]) {
        return self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable;
    }
    return NO;
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location{
    
    CGPoint cellPostion = [self.tableView convertPoint:location fromView:self.view];
    NSIndexPath *path = [self.tableView indexPathForRowAtPoint:cellPostion];
    
    if (path) {
        UITableViewCell *tableCell = [self.tableView cellForRowAtIndexPath:path];
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        
        if(tableCell.restorationIdentifier)
        {
            UIViewController *previewController = [storyboard instantiateViewControllerWithIdentifier: tableCell.restorationIdentifier];
            if(previewController)
            {
                previewingContext.sourceRect = [self.view convertRect:tableCell.frame fromView:self.tableView];
                return previewController;
            }
        }
    }
    return nil;
}

-(void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    [self.navigationController pushViewController:viewControllerToCommit animated:TRUE];
}

@end

