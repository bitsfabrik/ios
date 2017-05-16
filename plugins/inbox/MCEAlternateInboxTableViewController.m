/* IBM Confidential
 * OCO Source Materials
 * 5725E28, 5725S01, 5725I03
 * © Copyright IBM Corp. 2014, 2016
 *
 * The source code for this program is not published or otherwise
 * divested of its trade secrets, irrespective of what has been
 * deposited with the U.S. Copyright Office.
 */

#import "MCEAlternateInboxTableViewController.h"

#import "MCEInboxTableViewController.h"
#import <IBMMobilePush/MCEInboxDatabase.h>
#import <IBMMobilePush/MCETemplateRegistry.h>
#import <IBMMobilePush/MCETemplate.h>
#import <IBMMobilePush/MCEInboxMessage.h>
#import <IBMMobilePush/MCEEventService.h>
#import <IBMMobilePush/MCEInboxQueueManager.h>

@interface MCEAlternateInboxTableViewController ()
@property NSMutableArray * inboxMessages;
@property UIViewController * alternateDisplayViewController;
@end

@interface NSObject (AssociatedObject)
@property (nonatomic, strong) id associatedObject;
@end

@implementation MCEAlternateInboxTableViewController

// The purpose of this method is to smoothly update the list of messages instead of just executing [self.tableView reloadData];
-(void)smartUpdateMessages:(NSMutableArray*)inboxMessages
{
    NSArray * originalMessages = [self.inboxMessages copy];
    
    // create a single unified list of all the messages
    NSMutableArray * allMessages = [inboxMessages mutableCopy];
    for(MCEInboxMessage * message in self.inboxMessages)
    {
        if(![allMessages containsObject:message])
        {
            [allMessages addObject: message];
        }
    }
    
    // Sorted same as the db
    [allMessages sortUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey: @"sendDate" ascending: self.ascending] ]];
    
    if([allMessages isEqual:originalMessages])
    {
        return;
    }
    
    // determine what messages are new
    NSMutableIndexSet * newIndexes = [NSMutableIndexSet indexSet];
    for(MCEInboxMessage * message in allMessages)
    {
        if(![self.inboxMessages containsObject: message])
        {
            NSInteger row = [allMessages indexOfObject: message];
            [newIndexes addIndex: row];
        }
    }
    
    // insert the new messages into the table
    self.inboxMessages = allMessages;
    [self.tableView insertSections:newIndexes withRowAnimation:UITableViewRowAnimationAutomatic];
    
    // find the messages that aren't in the final message list anymore
    NSMutableIndexSet * removedIndexes = [NSMutableIndexSet indexSet];
    for (MCEInboxMessage * message in allMessages) {
        if(![inboxMessages containsObject:message])
        {
            NSInteger row = [allMessages indexOfObject: message];
            [removedIndexes addIndex:row];
        }
    }
    
    // delete the messages that aren't in the final list
    self.inboxMessages = inboxMessages;
    [self.tableView deleteSections:removedIndexes withRowAnimation:UITableViewRowAnimationAutomatic];
    
    
    // find the messages that the isRead status changed
    NSMutableIndexSet * readIndexes = [NSMutableIndexSet indexSet];
    for (MCEInboxMessage * message in self.inboxMessages) {
        if([originalMessages containsObject:message])
        {
            NSInteger row = [originalMessages indexOfObject: message];
            MCEInboxMessage * originalMessage = [originalMessages objectAtIndex: row];
            if(originalMessage.isRead != message.isRead)
            {
                [readIndexes addIndex: row];
            }
        }
    }
    
    // update the rows with isRead status changes
    [self.tableView reloadSections:readIndexes withRowAnimation:UITableViewRowAnimationAutomatic];
    
}

-(void)syncDatabase:(NSNotification*)notification
{
    NSMutableArray * inboxMessages = [[MCEInboxDatabase sharedInstance] inboxMessagesAscending: self.ascending];
    
    if(!inboxMessages)
    {
        NSLog(@"Could not sync database");
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self smartUpdateMessages:inboxMessages];
        [self.refreshControl endRefreshing];
    });
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"setContentViewController" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* note){
        self.alternateDisplayViewController = note.object;
    }];
    
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
    
    // Notification that background server sync is complete
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncDatabase:) name:@"MCESyncDatabase" object:nil];
    
    // Used by user to start a background server sync
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    self.inboxMessages=[NSMutableArray array];
    // Initially, grab contents of database, then start a background server sync
    UIActivityIndicatorView * activity = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [activity startAnimating];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithCustomView:activity];
    
    NSMutableArray * inboxMessages = [[MCEInboxDatabase sharedInstance] inboxMessagesAscending: self.ascending];
    
    if(!inboxMessages)
    {
        NSLog(@"Could not fetch inbox messages");
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self smartUpdateMessages:inboxMessages];
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        [[MCEInboxQueueManager sharedInstance] syncInbox];
    });
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return YES if you want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        //add code here for when you hit delete
        MCEInboxMessage * inboxMessage = self.inboxMessages[indexPath.section];
        inboxMessage.isDeleted=TRUE;
        [self.inboxMessages removeObjectAtIndex: indexPath.section];
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

-(void)refresh:(id)sender
{
    [self.refreshControl beginRefreshing];
    [[MCEInboxQueueManager sharedInstance] syncInbox];
}

-(UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MCEInboxMessage * inboxMessage = self.inboxMessages[indexPath.section];
    id<MCETemplate> template = [[MCETemplateRegistry sharedInstance] handlerForTemplate:inboxMessage.template];
    UITableViewCell* cell = [template cellForTableView: tableView inboxMessage:inboxMessage indexPath: indexPath];
    
    if(!cell)
    {
        NSLog(@"Couldn't get a blank cell for template %@, perhaps it wasn't registered?", template);
        cell = [tableView dequeueReusableCellWithIdentifier:@"oops"];
        if(!cell)
        {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"oops"];
        }
    }
    
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 20;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 1;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        [self.tableView reloadData];
    }];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:TRUE];
    
    MCEInboxMessage * inboxMessage = self.inboxMessages[indexPath.section];
    
    NSString * template = inboxMessage.template;
    id <MCETemplate> templateHandler = [[MCETemplateRegistry sharedInstance] handlerForTemplate: template];
    id <MCETemplateDisplay> displayViewController = [templateHandler displayViewController];
    if(!displayViewController)
    {
        NSLog(@"%@ template requested but not registered", template);
        return;
    }
    
    if([templateHandler shouldDisplayInboxMessage:inboxMessage])
    {
        NSLog(@"%@ template says should display inboxMessageId %@", template, inboxMessage.inboxMessageId);
    }
    else
    {
        NSLog(@"%@ template says should not display inboxMessageId %@", template, inboxMessage.inboxMessageId);
        return;
    }
    
    inboxMessage.isRead=TRUE;
    [[MCEEventService sharedInstance] recordViewForInboxMessage:inboxMessage attribution:inboxMessage.attribution mailingId:inboxMessage.mailingId];
    
    [displayViewController setInboxMessage: inboxMessage];
    [displayViewController setContent];
    
    UIViewController * vc = (UIViewController *)displayViewController;
    
    UIBarButtonItem * spaceButton = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    UIBarButtonItem * previousButton = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"chevron-up"] style:UIBarButtonItemStylePlain target:self action:@selector(previousMessage:)];
    previousButton.associatedObject = indexPath;
    if(indexPath.section == 0)
        previousButton.enabled=FALSE;
    else
        previousButton.enabled=TRUE;
    
    
    UIBarButtonItem * nextButton = [[UIBarButtonItem alloc]initWithImage:[UIImage imageNamed:@"chevron-down"] style:UIBarButtonItemStylePlain target:self action:@selector(nextMessage:)];
    nextButton.associatedObject = indexPath;
    if(indexPath.section == [self.inboxMessages count]-1)
        nextButton.enabled=FALSE;
    else
        nextButton.enabled=TRUE;
    
    UIBarButtonItem * deleteButton = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(delete:)];
    deleteButton.associatedObject = displayViewController;
    vc.navigationItem.rightBarButtonItems = @[deleteButton, spaceButton, nextButton, previousButton];
    
    
    if(self.alternateDisplayViewController)
    {
        [self.alternateDisplayViewController addChildViewController: vc];
        vc.view.frame = self.alternateDisplayViewController.view.frame;
        [self.alternateDisplayViewController.view addSubview: vc.view];
    }
    else
    {
        [self.navigationController pushViewController:vc animated:TRUE];
    }
    
    [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

-(IBAction)delete:(UIBarButtonItem*)sender
{
    if(sender.associatedObject)
    {
        id <MCETemplateDisplay> templateDisplay = (id<MCETemplateDisplay>) sender.associatedObject;
        if(templateDisplay)
        {
            templateDisplay.inboxMessage.isDeleted=TRUE;
            [self syncDatabase:nil];
            [self.navigationController popViewControllerAnimated:TRUE];
        }
    }
}

-(IBAction)previousMessage:(UIBarButtonItem*)sender
{
    if(sender.associatedObject)
    {
        NSIndexPath * indexPath = (NSIndexPath *) sender.associatedObject;
        if(indexPath)
        {
            [self.navigationController popViewControllerAnimated:TRUE];
            NSIndexPath * newIndexPath = [NSIndexPath indexPathForItem:indexPath.item inSection:indexPath.section-1];
            [self tableView: self.tableView didSelectRowAtIndexPath: newIndexPath];
        }
    }
    
}

-(IBAction)nextMessage:(UIBarButtonItem*)sender
{
    if(sender.associatedObject)
    {
        NSIndexPath * indexPath = (NSIndexPath *) sender.associatedObject;
        if(indexPath)
        {
            [self.navigationController popViewControllerAnimated:TRUE];
            NSIndexPath * newIndexPath = [NSIndexPath indexPathForItem:indexPath.item inSection:indexPath.section+1];
            [self tableView: self.tableView didSelectRowAtIndexPath: newIndexPath];
        }
    }
    
}

- (CGFloat)tableView:(UITableView *) tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath
{
    MCEInboxMessage * inboxMessage = self.inboxMessages[indexPath.section];
    id<MCETemplate> template = [[MCETemplateRegistry sharedInstance] handlerForTemplate:inboxMessage.template];
    return [template tableView: tableView heightForRowAtIndexPath:indexPath inboxMessage:inboxMessage];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *) tableView
{
    return [self.inboxMessages count];
}

@end
