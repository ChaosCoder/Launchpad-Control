//
//  Launchpad_Control.m
//  Launchpad-Control
//
//  Created by Andreas Ganske on 28.07.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import "LaunchpadControl.h"
#import "Item.h"
#import "CCUtils.h"

@implementation LaunchpadControl

static NSString *zipContentsPath = @"/tmp/lcbackup/";
static NSString *databaseFileName = @"database.db";
static NSString *plistFileName = @"LaunchPadLayout.plist";
static NSString *plistBackupFileName = @"LaunchPadLayout.plist";
static NSString *plistPath = @"/System/Library/CoreServices/Dock.app/Contents/Resources";
static NSString *plistTemporaryPath = @"/tmp";
static NSString *currentVersion;
static NSString *updateURLString = @"http://chaosspace.de/download.php?id=Launchpad-Control";

static NSInteger maximumItemsPerPage = 40;
static NSInteger maximumItemsPerGroup = 32;

static id _shared = nil;

#define MyPrivateTableViewDataType @"MyPrivateTableViewDataType"

+(id)shared
{
	return _shared;
}

#pragma mark Load

-(id)initWithBundle:(NSBundle *)bundle
{
    if (self = [super initWithBundle:bundle]) {
        _shared = self;
    }
	
	return self;
}

-(void)mainViewDidLoad
{
	self.databaseDirectoryPath = [@"~/Library/Application Support/Dock/" stringByStandardizingPath];
	currentVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleVersion"];
	[self.outlineView registerForDraggedTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType]];
	
	[self.helpFieldCell setTitle:CCLocalized(@"Help")];
	[self.descriptionFieldCell setTitle:CCLocalized(@"This app allows you to easily hide/unhide and reorder apps in Launchpad.~nFor detailed instructions please click the 'Help'-button at the top.")];
	[self.resetDatabaseButton setTitle:CCLocalized(@"Reset")];
	[self.refreshButton setTitle:CCLocalized(@"Refresh")];
	[self.applyButton setTitle:CCLocalized(@"Apply")];
	[self.currentVersionField setTitle:[NSString stringWithFormat:@"v%@",currentVersion]];
	
	[self.allItemsFieldCell setTitle:CCLocalized(@"All items")];
	[self.sortAllButton setTitle:CCLocalized(@"Sort all items A-Z")];
	[self.selectedItemFieldCell setTitle:CCLocalized(@"Selected item")];
	[self.renameItemButton setTitle:CCLocalized(@"Rename")];
	[self.sortItemButton setTitle:CCLocalized(@"Sort children A-Z")];
	[self.databaseFieldCell setTitle:CCLocalized(@"Database")];
	[self.backupDatabaseButton setTitle:CCLocalized(@"Backup")];
	[self.restoreDatabaseButton setTitle:CCLocalized(@"Restore")];
	[self.resetDatabaseButton setTitle:CCLocalized(@"Reset")];
	[self.authorFieldCell setTitle:CCLocalized(@"Footer")];
	
	self.items = [[NSMutableArray alloc] init];
	
	[self setupRights];
	[self loadPlist];
	[self openDatabase];
	
	[self reload];
	
	[self performSelector:@selector(checkForUpdates) withObject:nil afterDelay:3.0f];
}

-(void)setupRights
{
	AuthorizationItem authorizationItems = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights authorizationRights = {1, &authorizationItems};
    [self.authView setAuthorizationRights:&authorizationRights];
    self.authView.delegate = self;
    [self.authView updateStatus:nil];
}

-(void)loadPlist
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.databaseDirectoryPath stringByAppendingPathComponent:plistBackupFileName]])
        [[NSFileManager defaultManager] copyItemAtPath:[plistPath stringByAppendingPathComponent:plistFileName]
                                                toPath:[self.databaseDirectoryPath stringByAppendingPathComponent:plistBackupFileName]
                                                 error:nil];
    
    
	self.plist = [[NSMutableDictionary alloc] initWithContentsOfFile:[plistPath stringByAppendingPathComponent:plistFileName]];
	self.ignoredBundles = [self.plist objectForKey:@"ignore"];
}

#pragma mark - Button actions

-(IBAction)buttonPressed:(id)sender
{
	if (sender == self.updateButton) {
		//[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://chaosspace.de/launchpad-control/update"]];
		[self update];
	}else if (sender == self.refreshButton) {
		[self refreshDatabase];
	}else if (sender == self.applyButton) {
		[self restartLaunchpad];
	}else if (sender == self.resetDatabaseButton) {
		[self removeDatabase];
	}else if (sender == self.donateButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CHBAEUQVBUYTL"]];
	}else if (sender == self.backupDatabaseButton) {
		[self backupDatabase];
	}else if (sender == self.restoreDatabaseButton) {
		[self restoreDatabase];
	}else if (sender == self.sortAllButton) {
		[self sortAllItems];
	}else if (sender == self.sortItemButton) {
		[self sortSelectedItem];
	}else if (sender == self.renameItemButton) {
		[self renameSelectedItem];
	}else if (sender == self.helpButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://chaosspace.de/launchpad-control/help"]];
	}
}

-(void)setSidebarItemActionsEnabled:(BOOL)enabled forItem:(Item *)item
{
	[self.sortItemButton setEnabled:enabled && [[item children] count]>0];
	[self.renameItemButton setEnabled:enabled];
}

#pragma mark - SFAuthorizationView Delegate

- (BOOL)isUnlocked {
    return [self.authView authorizationState] == SFAuthorizationViewUnlockedState;
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view {
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view {
}

#pragma mark - automatic updates

-(void)checkForUpdates
{
	NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://chaosspace.de/server/launchpad-control/version"]
											  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
										  timeoutInterval:60.0];
	// create the connection with the request
	// and start loading the data
	NSURLConnection *theConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (theConnection) {
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
        self.receivedData = [NSMutableData data];
	} else {
		// Inform the user that the connection failed.
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *newVersionString = [[NSString alloc] initWithData:self.receivedData encoding:NSASCIIStringEncoding];
	
	if ([newVersionString floatValue] > [currentVersion floatValue]) {
		[self.updateButton setTitle:[NSString stringWithFormat:CCLocalized(@"Get v%@ now!"),newVersionString]];
		[self.updateButton setHidden:NO];
		
		if ([[NSAlert alertWithMessageText:[NSString stringWithFormat:CCLocalized(@"Get v%@ now!"),newVersionString]
							 defaultButton:CCLocalized(@"Download")
						   alternateButton:CCLocalized(@"Later")
							   otherButton:nil 
				 informativeTextWithFormat:CCLocalized(@"Version %@ of Launchpad-Control is available (You have %@). You can download it now or later by clicking on the button at the top."),newVersionString,currentVersion] runModal])
		{
			[self buttonPressed:self.updateButton];
		}
	}
}

#pragma mark - NSOutlineView delegate and data source methods

-(BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return [(Item *)item type]==2 || [(Item *)item type]==3;
}

-(NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return item==nil ? [[self.rootItem children] count] : [[item children] count];
}

-(id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	return item==nil ? [[self.rootItem children] objectAtIndex:index] : [[(Item *)item children] objectAtIndex:index];
}

-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [[item children] count]>0;
}

-(void)outlineView:(NSOutlineView *)_outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    [self setVisible:[object boolValue] forItem:(Item *)item];
	[self.outlineView reloadItem:item reloadChildren:YES];
}

-(NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *cell;
	switch ([(Item *)item type]) 
	{
		case kItemRoot:
		{
			cell = [[NSCell alloc] initTextCell:[item name]];
			
			break;
		}
			
		case kItemGroup:
		case kItemPage: 
		case kItemApp:
		{
			cell = [[NSButtonCell alloc] init];
			[(NSButtonCell *)cell setButtonType:NSSwitchButton];
			[cell setEditable:YES];
			[cell setSelectable:YES];
			
			if ([[item bundleIdentifier] isEqualToString:@""])
				[cell setEnabled:NO];
			
			[cell setTitle:[item description]];
			
			break;
		}
	}
	
	return cell;
}

-(id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item 
{
	switch ([(Item *)item type]) {
		case kItemRoot:
			return [item name];
			break;
			
		case kItemGroup:
		case kItemPage:
		case kItemApp:
			return [NSNumber numberWithInteger:([(Item *)item visible] ? NSOnState : NSOffState)];
			break;
	}
	return nil;
}

-(void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	Item *item = [self.outlineView itemAtRow:[self.outlineView selectedRow]];
	[self setSidebarItemActionsEnabled:item!=nil forItem:item];
}

#pragma mark Drag'n'Drop

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)_items toPasteboard:(NSPasteboard *)pasteboard
{
	// Copy the row numbers to the pasteboard.
	//NSData *zNSIndexSetData = [NSKeyedArchiver archivedDataWithRootObject:_items];
	//[pasteboard declareTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType] owner:self];
	//[pasteboard setData:zNSIndexSetData forType:MyPrivateTableViewDataType];
	//[pasteboard declareTypes:MyPrivateTableViewDataType owner:self ];
	
	self.draggedItem = [_items objectAtIndex:0];
	
	NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:self.draggedItem];
	[pasteboard declareTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType] owner:self];
	[pasteboard setData:itemData forType:MyPrivateTableViewDataType];
	
	return YES;
}

-(NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	if (self.draggedItem.type == kItemPage && item) // Page not in Root
		return NO;
	
	if (self.draggedItem.type == kItemGroup && [(Item *)item type]!=kItemPage) // Group not in Page
		return NO;
	
	if (self.draggedItem.type == kItemApp && [(Item *)item type]==kItemGroup && [[(Item *)item children] count]>=maximumItemsPerGroup) // App in full group
		return NO;
	
	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)_outlineView acceptDrop:(id<NSDraggingInfo>)info item:(Item *)parentItem childIndex:(NSInteger)dropRow 
{
	if (parentItem == nil) 
		parentItem = self.rootItem;
	
	NSInteger dragRow = [[[self.draggedItem parent] children] indexOfObject:self.draggedItem];
	
	if (dropRow>=0 || [(Item *)parentItem type] == kItemGroup) 
	{
		if (dropRow<0)
			dropRow = 0;
		
		if ([self.draggedItem parent] == parentItem) {
			if (dragRow < dropRow) {
				dropRow--;
			}
		}
		
		for (Item *child in [[self.draggedItem parent] children]) {
			if (child == self.draggedItem) continue;
			
			if (child.ordering>=self.draggedItem.ordering)
				child.ordering--;
		}
		
		Item *oldParent = [self.draggedItem parent];
		
		[self.draggedItem setParent:parentItem updateDatabase:YES];
		[self.draggedItem setOrdering:dropRow+(self.draggedItem.type == kItemPage ? 1 : 0) updateDatabase:YES];
		
		for (Item *child in [[self.draggedItem parent] children]) {
			if (child == self.draggedItem) continue;
			
			if (child.ordering>=self.draggedItem.ordering)
				child.ordering++;
		}
		
		if ([[oldParent children] count]==0) {
			NSString *itemType = oldParent.type==kItemGroup?CCLocalized(@"group"):CCLocalized(@"page");
			if ([[NSAlert alertWithMessageText:[NSString stringWithFormat:CCLocalized(@"Empty %@!"),itemType] 
								 defaultButton:CCLocalized(@"Yes") 
							   alternateButton:CCLocalized(@"No") 
								   otherButton:nil
					 informativeTextWithFormat:CCLocalized(@"You've got the empty %@ '%@' because you moved the only item '%@' out of it. Would you like to remove the %@ from Launchpad?"), itemType, [oldParent name],[self.draggedItem name], itemType] runModal])
			{
				[self removeItem:oldParent];
			}
		}
		
		[parentItem updateChildren];
		
		[self updatePages];
	}else{ // dropped an app on an app
		NSString *groupName = [self input:[NSString stringWithFormat:CCLocalized(@"You are about to merge two apps:\n\n• %@\n• %@\n\nPlease type in the name of this new group:"),[self.draggedItem name],[parentItem name]] defaultValue:@""];
		
		if (groupName) {
			groupName = [groupName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if ([groupName isNotEqualTo:@""]) 
			{
				if ([self.draggedItem parent] == parentItem) {
					if (dragRow < dropRow) {
						dropRow--;
					}
				}
				
				for (Item *child in [[self.draggedItem parent] children]) {
					if (child == self.draggedItem) continue;
					
					if (child.ordering>=self.draggedItem.ordering)
						child.ordering--;
				}
				
				Item *group = [self createNewGroup:groupName onPage:[parentItem parent] withOrdering:[parentItem ordering]];
				[parentItem setParent:group updateDatabase:YES];
				[self.draggedItem setParent:group updateDatabase:YES];
				[parentItem setOrdering:0];
				[self.draggedItem setOrdering:1];
				
				[[group parent] updateChildren];
			}
		}
	}
	
	[self.outlineView noteNumberOfRowsChanged];
	[self.outlineView reloadData];
	
	return YES;
}

#pragma mark - Database

-(BOOL)openDatabase
{	
	NSError *error = nil;
	
	@try {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *directory = [self.databaseDirectoryPath stringByStandardizingPath];
		
		NSArray *files = [fileManager contentsOfDirectoryAtPath:directory error:&error];
		
		if (error || !files || [files count]==0)
			[NSException raise:@"DatabaseNotFoundException" format:@"%@", CCLocalized(@"Could not find any database file for Launchpad.")];
		
		
		//check if file is already there
		for (NSString *fileName in files) {
			if ([[fileName pathExtension] isEqualToString:@"db"]) {
				
				self.databasePath = [directory stringByAppendingPathComponent:fileName];
				self.databaseBackupPath = [self.databasePath stringByAppendingPathExtension:@"backup"];
				
				if (![fileManager fileExistsAtPath:self.databaseBackupPath]){
					[fileManager copyItemAtPath:self.databasePath toPath:self.databaseBackupPath error:&error];
					
				}
				
				if (error)
					[NSException raise:@"CouldNotCreateBackupException" format:@"%@", CCLocalized(@"Could not backup original Launchpad database.~nBe careful!")];
				
				if([fileManager fileExistsAtPath:self.databasePath])
				{
                    sqlite3 *db = self.db;
					if(sqlite3_open([self.databasePath UTF8String], &db) == SQLITE_OK)
					{
                        self.db = db;
						self.dbOpened = YES;
						NSString *databaseVersion = [self getDatabaseVersion];
						if ([databaseVersion floatValue]>[currentVersion floatValue] && [[NSAlert alertWithMessageText:CCLocalized(@"Error") defaultButton:CCLocalized(@"Yes") alternateButton:@"No" otherButton:nil informativeTextWithFormat:@"%@", CCLocalized(@"The database was modified with a newer version from Launchpad-Control. Downgrading to an older version could result in massive bugs.\n\nDo you really want to load the database?")] runModal]) {
							return YES;
						}
						if (![databaseVersion isEqualToString:currentVersion]) {
							[self migrateFrom:databaseVersion];
						}
						return YES;
					}
				}
				
				[NSException raise:@"CannotOpenDatabaseException" format:@"%@", CCLocalized(@"Could not open the database file for Launchpad.")];
			}
		}
		
		[NSException raise:@"DatabaseNotFoundException" format:@"%@", CCLocalized(@"Could not find any database file for Launchpad.")];
	}
	@catch (NSException *exception) {
		[[NSAlert alertWithMessageText:CCLocalized(@"Error") defaultButton:CCLocalized(@"Okay") alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", [exception reason]] runModal];
		return NO;
	}
}

-(BOOL)fetchItems
{
	if(!self.dbOpened)
		return NO;
	
	if (self.items)
		[self.items removeAllObjects];
	
	NSString *sqlString = [NSString stringWithFormat:@"\
						   SELECT rowid,parent_id,uuid,flags,type,ordering,apps.title,groups.title,apps.bundleid \
						   FROM items \
						   LEFT JOIN apps ON ABS(rowid) = apps.item_id \
						   LEFT JOIN groups ON ABS(rowid) = groups.item_id \
						   ORDER BY parent_id,ordering;"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	if (sqlite3_prepare_v2(self.db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		NSInteger pageCount = 0;
		
		while(sqlite3_step(statement) == SQLITE_ROW) 
		{
			int rowid = sqlite3_column_int(statement, 0);
			int parent_id = sqlite3_column_int(statement, 1);
			NSString *uuid = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 2)];
			int flags = sqlite3_column_int(statement, 3);
			int type = sqlite3_column_int(statement, 4);
			NSInteger ordering = sqlite3_column_int(statement, 5);
			
			NSString *name = nil;
			NSString *bundleID = nil;
			
			switch (type) {
				case kItemRoot:
					name = @"ROOT";
					break;
				
				case kItemGroup:
					if (sqlite3_column_text(statement, 7))
						name = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 7)];
					else
						name = uuid;
					break;
					
				case kItemPage:
					if ([uuid isEqualToString:@"HOLDINGPAGE"] || [uuid isEqualToString:@"HOLDINGPAGE_DB"])
						continue;
					else
                        name = [CCLocalized(@"PAGE") stringByAppendingFormat:@" %li",(long)++pageCount];
					break;
					
				case kItemApp:
					if (sqlite3_column_text(statement, 6)) {
						name = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 6)];
						bundleID = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 8)];
					}else{
						name = uuid;
					}
					
					break;
					
				default:
					continue;
					break;
			}
			
			Item *parent = nil;
			
			if (parent_id != 0) {
				for (Item *otherItem in self.items) {
					if ([otherItem identifier] == labs(parent_id) ) {
						parent = otherItem;
						break;
					}
				}
				if (!parent) {
					parent = [[Item alloc] initWithID:parent_id name:nil parent:nil uuid:nil flags:0 type:2 ordering:0 visible:YES];
					[self.items addObject:parent];
				}
			}
			
			Item *item = nil;
			for (Item *otherItem in self.items) {
				if ([otherItem identifier] == labs(rowid) ) {
					item = otherItem;
				}
			}
			
			if (!item) {
				item = [[Item alloc] initWithID:labs(rowid)
										   name:name
										 parent:parent 
										   uuid:uuid 
										  flags:flags
										   type:type 
									   ordering:ordering
										visible:rowid>0];
			}else{
				[item setName:name];
				[item setParent:parent];
				[item setUuid:uuid];
				[item setFlags:flags];
				[item setType:type];
				[item setOrdering:ordering];
				[item setVisible:rowid>0];
			}
			
			[item setBundleIdentifier:bundleID];
	
			[self.items addObject:item];
			
			if (rowid == 1)
				self.rootItem = item;
			
			if (type==kItemApp && rowid<0 && ![self.ignoredBundles containsObject:bundleID]) {
				[self addIgnoredBundle:bundleID];
			}
		}
	}
	sqlite3_finalize(statement);
	
	return YES;
}

-(void)checkDatabase
{
	NSString *sqlString = [NSString stringWithFormat:@"SELECT COUNT(item_id) FROM apps WHERE item_id<0;"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	if (sqlite3_prepare_v2(self.db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		if(sqlite3_step(statement) == SQLITE_ROW){
			if (sqlite3_column_int(statement, 0)>0) {
				[self databaseIsCorrupt];
			}
		}
	}
	sqlite3_finalize(statement);
}

-(BOOL)backupDatabase
{	
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"lcb"]];
	
	NSInteger savePanelResult	= [savePanel runModal];
	
	if(savePanelResult == NSOKButton)
	{
		NSURL *directoryURL = [savePanel directoryURL];
		NSURL *fileURL = [savePanel URL];
		
		NSError *error = nil;
		
		@try 
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:zipContentsPath])
				[[NSFileManager defaultManager] removeItemAtPath:zipContentsPath error:&error];
			
			[[NSFileManager defaultManager] createDirectoryAtPath:zipContentsPath withIntermediateDirectories:YES attributes:nil error:&error];
			
			if(![[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error] || error)
				[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			
			if(![[NSFileManager defaultManager] createDirectoryAtPath:zipContentsPath withIntermediateDirectories:YES attributes:nil error:&error] || error)
				[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			
			if (![[NSFileManager defaultManager] copyItemAtPath:[plistPath stringByAppendingPathComponent:plistFileName] 
														 toPath:[zipContentsPath stringByAppendingPathComponent:plistFileName] 
														  error:&error] || error)
				[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			
			if (![[NSFileManager defaultManager] copyItemAtPath:self.databasePath
														 toPath:[zipContentsPath stringByAppendingPathComponent:@"lp.db"] 
														  error:&error] || error)
				[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			
			NSTask *task = [[NSTask alloc] init];
			[task setCurrentDirectoryPath:zipContentsPath];
			[task setLaunchPath:@"/usr/bin/zip"];
			NSArray *argsArray = [NSArray arrayWithObjects:[fileURL lastPathComponent], plistFileName, @"lp.db", nil];
			[task setArguments:argsArray];
			[task launch];
			[task waitUntilExit];
			
			NSURL *temporaryFileURL = [NSURL fileURLWithPath:[zipContentsPath stringByAppendingPathComponent:[fileURL lastPathComponent]]];
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
				if(![[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error] || error)
					[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			}
			
			if(![[NSFileManager defaultManager] moveItemAtURL:temporaryFileURL toURL:fileURL error:&error] || error) 
				[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			
			if (error)
				[NSException raise:@"CouldNotBackupDatabaseException" format:CCLocalized(@"There was an error backupping the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
			
		}@catch (NSException *exception) {
			[[NSAlert alertWithMessageText:CCLocalized(@"Error") 
							 defaultButton:CCLocalized(@"Okay") 
						   alternateButton:nil
							   otherButton:nil
				 informativeTextWithFormat:@"%@", [exception reason]] runModal];
			return false;
		}
	}else{
		return false;
	}
	
	[[NSAlert alertWithMessageText:CCLocalized(@"Backup successfully") 
					 defaultButton:CCLocalized(@"Okay") 
				   alternateButton:nil
					   otherButton:nil
		 informativeTextWithFormat:@"%@", CCLocalized(@"The backup was successfully created and saved.")] runModal];
	
	return true;
}

-(BOOL)restoreDatabase
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"lcb"]];
	
	NSInteger openPanelResult = [openPanel runModal];
	
	if (openPanelResult == NSOKButton) 
	{
		NSURL *fileURL = [openPanel URL];
		NSString *fileName = [fileURL lastPathComponent];
		
		NSError *error = nil;
		
		@try
		{
			if ([[fileURL pathExtension] isEqualToString:@"lcb"]) 
			{
				[[NSFileManager defaultManager] removeItemAtPath:zipContentsPath error:&error];
				[[NSFileManager defaultManager] createDirectoryAtPath:zipContentsPath withIntermediateDirectories:YES attributes:nil error:&error];
				
				[[NSFileManager defaultManager] copyItemAtURL:fileURL toURL:[NSURL fileURLWithPath:[zipContentsPath stringByAppendingPathComponent:fileName]] error:&error];
				
				if (error)
					[NSException raise:@"CouldNotRestoreDatabaseException" format:CCLocalized(@"There was an error restoring the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
				
				NSTask *task = [[NSTask alloc] init];
				[task setCurrentDirectoryPath:zipContentsPath];
				[task setLaunchPath:@"/usr/bin/unzip"];
				NSArray *argsArray = [NSArray arrayWithObject:fileName];
				[task setArguments:argsArray];
				[task launch];
				[task waitUntilExit];
				
				[[NSFileManager defaultManager] moveItemAtPath:[zipContentsPath stringByAppendingPathComponent:plistFileName] toPath:[plistTemporaryPath stringByAppendingPathComponent:plistFileName] error:&error];
				if (!error && [self movePlistWithRights]) {
					[[NSFileManager defaultManager] removeItemAtPath:self.databaseBackupPath error:&error];
					[[NSFileManager defaultManager] moveItemAtPath:self.databasePath toPath:self.databaseBackupPath error:&error];
					[[NSFileManager defaultManager] moveItemAtPath:[zipContentsPath stringByAppendingPathComponent:@"lp.db"] toPath:self.databasePath error:&error];
					
					[self closeDatabase];
					[self openDatabase];
					[self reload];
					
					if (error)
						[NSException raise:@"CouldNotRestoreDatabaseException" format:CCLocalized(@"There was an error restoring the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
					
				}else if(error){
					[NSException raise:@"CouldNotRestoreDatabaseException" format:CCLocalized(@"There was an error restoring the database:\n\nError Code: %@\nDescription: %@"), [error code], [error localizedDescription]];
				}else{
					[NSException raise:@"CouldNotRestoreDatabaseException" format:@"%@", CCLocalized(@"You have to grant this application admin rights to be able to restore the database.")];
				}
			}
		}@catch (NSException *exception) {
			[[NSAlert alertWithMessageText:CCLocalized(@"Error") 
							 defaultButton:CCLocalized(@"Okay") 
						   alternateButton:nil
							   otherButton:nil
				 informativeTextWithFormat:@"%@", [exception reason]] runModal];
			return false;
		}
	}
	
	[[NSAlert alertWithMessageText:CCLocalized(@"Restore successfully") 
					 defaultButton:CCLocalized(@"Okay") 
				   alternateButton:nil
					   otherButton:nil
		 informativeTextWithFormat:@"%@", CCLocalized(@"The database was successfully restored and loaded.")] runModal];
	
	return true;
}

-(void)restartLaunchpad
{
	[self restartDock];
	[self reload];
}

-(void)restartDock
{
	system("killall Dock");
}

-(void)removeDatabase
{
	if ([[NSAlert alertWithMessageText:CCLocalized(@"Are you sure?") 
						 defaultButton:CCLocalized(@"Yes") 
					   alternateButton:CCLocalized(@"No") 
						   otherButton:nil 
			 informativeTextWithFormat:@"%@", CCLocalized(@"A full reset will remove the database file used by Launchpad. Launchpad will then create a new database. Any custom groups or manually added apps will be gone.")] runModal])
	{
		[self closeDatabase];
		/*if ([self moveFileWithRightsFrom:[databaseDirectoryPath stringByAppendingPathComponent:plistBackupFileName] to:[plistPath stringByAppendingPathComponent:plistFileName]])
			[[NSFileManager defaultManager] removeItemAtPath:databasePath error:nil];
		else {
			[[NSAlert alertWithMessageText:CCLocalized(@"Error") 
							 defaultButton:CCLocalized(@"Okay") 
						   alternateButton:nil
							   otherButton:nil 
				 informativeTextWithFormat:CCLocalized(@"Could not reset the file %@. Please copy the backup from %@ manually."),[plistPath stringByAppendingPathComponent:plistFileName],[databaseDirectoryPath stringByAppendingPathComponent:plistBackupFileName]] runModal];
		}*/
		
		if (![self resetIgnoredBundles]) {
			[[NSAlert alertWithMessageText:CCLocalized(@"Error") 
							 defaultButton:CCLocalized(@"Okay") 
						   alternateButton:nil
							   otherButton:nil 
				 informativeTextWithFormat:CCLocalized(@"Could not reset the file %@. Please see http://chaosspace.de/launchpad-control/faq/"),[plistPath stringByAppendingPathComponent:plistFileName]] runModal];
		}else{
			[[NSFileManager defaultManager] removeItemAtPath:self.databasePath error:nil];
		}
		
		[self restartDock];
		system("open /Applications/Launchpad.app");
		
		if ([[NSAlert alertWithMessageText:CCLocalized(@"Do you want Launchpad-Control to load the new database?") 
						defaultButton:CCLocalized(@"Yes") 
					  alternateButton:CCLocalized(@"No") 
						  otherButton:nil 
				 informativeTextWithFormat:@"%@", CCLocalized(@"If you want to edit your database click 'Yes'. Click 'No' if you don't want Launchpad-Control to load and edit your new database. Launchpad-Control will then close itself.")] runModal])
		{
			while (![self openDatabase]) {
				if ([[NSAlert alertWithMessageText:CCLocalized(@"Could not find any database.") 
									 defaultButton:CCLocalized(@"Refresh") 
								   alternateButton:CCLocalized(@"Quit") 
									   otherButton:nil 
						 informativeTextWithFormat:@"%@", CCLocalized(@"Please wait while Launchpad refreshes its database. \nOnce it is done click 'Refresh'. If this error still exists after some time press 'Quit'.")] runModal]) {
				}else{
					[[NSApplication sharedApplication] terminate:self];
				}
			}
			[self reload];
		}else{
			[[NSApplication sharedApplication] terminate:self];
		}
	}
}

-(NSString *)getDatabaseVersion
{ 
	NSString *sqlString = @"SELECT value FROM dbinfo WHERE key='launchpad-control' LIMIT 1;";
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	NSString *version = @"";
	
	if (sqlite3_prepare_v2(self.db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		sqlite3_step(statement);
		
		if (sqlite3_column_text(statement, 0)) {
			version = [NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 0)];
		}
		
		sqlite3_finalize(statement);
	}
	
	return version;
}

-(void)setDatabaseVersion
{
	NSString *sqlString;
	if ([[self getDatabaseVersion] isEqualToString:@""]) {
		sqlString = [NSString stringWithFormat:@"INSERT INTO `dbinfo` VALUES ('launchpad-control','%@')",currentVersion];
	}else{
		sqlString = [NSString stringWithFormat:@"UPDATE dbinfo SET value='%@' WHERE key='launchpad-control'",currentVersion];
	}
	
	[self executeSQL:sqlString];
}

-(void)dropTriggers
{
	NSString *sqlString = [NSString stringWithFormat:@"DROP TRIGGER insert_item; DROP TRIGGER item_deleted; DROP TRIGGER update_item_parent; DROP TRIGGER update_items_order; DROP TRIGGER update_items_order_backwards;"];
	
	[self executeSQL:sqlString];
}
	
-(void)createTriggers
{
	NSString *sqlString = [NSString stringWithFormat:@"CREATE TRIGGER insert_item AFTER INSERT on items WHEN 0 == (SELECT value FROM dbinfo WHERE key='ignore_items_update_triggers') \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = (SELECT ifnull(MAX(ordering),0)+1 FROM items WHERE parent_id=new.parent_id) WHERE ABS(rowid)=ABS(new.rowid); \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END; \n\
\n\
CREATE TRIGGER item_deleted AFTER DELETE ON items \n\
BEGIN \n\
DELETE FROM apps WHERE ABS(rowid)=ABS(old.rowid); \n\
DELETE FROM groups WHERE ABS(item_id)=ABS(old.rowid); \n\
DELETE FROM downloading_apps WHERE ABS(item_id)=ABS(old.rowid); \n\
UPDATE items SET ordering = ordering - 1 WHERE old.parent_id = parent_id AND ordering > old.ordering; \n\
END; \n\
\n\
CREATE TRIGGER update_item_parent AFTER UPDATE OF parent_id ON items \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = (SELECT ifnull(MAX(ordering),0)+1 FROM items WHERE parent_id=new.parent_id AND ABS(ROWID)!=ABS(old.rowid)) WHERE ABS(ROWID)=ABS(old.rowid); \n\
UPDATE items SET ordering = ordering - 1 WHERE parent_id = old.parent_id and ordering > old.ordering; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END; \n\
\n\
CREATE TRIGGER update_items_order BEFORE UPDATE OF ordering ON items WHEN new.ordering > old.ordering AND 0 == (SELECT value FROM dbinfo WHERE key='ignore_items_update_triggers') \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = ordering - 1 WHERE parent_id = old.parent_id AND ordering BETWEEN old.ordering and new.ordering; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END; \n\
\n\
CREATE TRIGGER update_items_order_backwards BEFORE UPDATE OF ordering ON items WHEN new.ordering < old.ordering AND 0 == (SELECT value FROM dbinfo WHERE key='ignore_items_update_triggers') \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = ordering + 1 WHERE parent_id = old.parent_id AND ordering BETWEEN new.ordering and old.ordering; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END;"];
	
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
}

-(void)databaseIsCorrupt
{
	if ([[NSAlert alertWithMessageText:CCLocalized(@"Corrupt database detected!") 
						 defaultButton:CCLocalized(@"Okay") 
					   alternateButton:CCLocalized(@"Cancel") 
						   otherButton:nil 
			 informativeTextWithFormat:@"%@", CCLocalized(@"Your database file seems to be corrupt. A Launchpad-Control version prior 1.2 could have done that.\nYou have to do a full reset of your database to use this new version of Launchpad-Control. Any custom groups or manually added apps will be gone.")] runModal])
	{
		[self closeDatabase];
		[[NSFileManager defaultManager] removeItemAtPath:self.databasePath error:nil];
		[self restartDock];
		system("open /Applications/Launchpad.app");
		
		[[NSAlert alertWithMessageText:CCLocalized(@"Refreshing database...") 
						defaultButton:CCLocalized(@"Okay") 
					  alternateButton:nil 
						  otherButton:nil 
			informativeTextWithFormat:@"%@", CCLocalized(@"Please wait while Launchpad refreshes its database. \nOnce it is done click 'Okay'. Launchpad-Control will then reload the new database.")] runModal];
		
		while (![self openDatabase]) {
			if ([[NSAlert alertWithMessageText:CCLocalized(@"Could not find any database.") 
								 defaultButton:CCLocalized(@"Refresh") 
							   alternateButton:CCLocalized(@"Quit") 
								   otherButton:nil 
					 informativeTextWithFormat:@"%@", CCLocalized(@"Please wait while Launchpad refreshes its database. \nOnce it is done click 'Refresh'. If this error still exists after some minutes press 'Quit'.")] runModal]) {
			}else{
				[[NSApplication sharedApplication] terminate:self];
			}
		}
		[self reload];
	}else{
		[[NSApplication sharedApplication] terminate:self];
	}
}

-(void)refreshDatabase
{
	[self reload];
}

-(void)migrateFrom:(NSString *)oldVersion
{
	if ([oldVersion isEqualToString:@"1.3"]) {
		[self dropTriggers];
		[self createTriggers];
	}else if([oldVersion isEqualToString:@"1.4"]) {
		NSString *sqlString = [NSString stringWithFormat: @"UPDATE items SET rowid=ABS(rowid), parent_id=ABS(parent_id) WHERE parent_id>0;\n\
															UPDATE items SET rowid=-ABS(rowid), parent_id=ABS(parent_id) WHERE parent_id<0;"];
		const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
		sqlite3_exec(self.db, sql, NULL, NULL, NULL);
		
		[self dropTriggers];
		[self createTriggers];
	}else if([oldVersion isEqualToString:@"1.5"]) {
		[self moveFileWithRightsFrom:[self.databaseDirectoryPath stringByAppendingPathComponent:plistBackupFileName] to:[plistPath stringByAppendingPathComponent:plistFileName]];
		[self loadPlist];
	}
	
	[self setDatabaseVersion];
}

-(void)closeDatabase
{
	self.dbOpened = NO;
	sqlite3_close(self.db);
}

-(void)reload
{
	[self checkDatabase];
	[self fetchItems];
	[self.outlineView reloadData];
	
	for (Item *child in [self.rootItem children]) {
		[self.outlineView expandItem:child expandChildren:NO];
	}
	
	self.changedData = NO;
}

-(Item *)createNewPage 
{
	NSString *uuid = [self generateUUIDString];
	NSInteger ordering = [[self.rootItem children] count];
	
    NSString *sqlQuery = [NSString stringWithFormat:@"INSERT INTO items (uuid, flags, type, parent_id, ordering) VALUES ('%@',0,3,%li,%li);", uuid, (long)[self.rootItem identifier], (long)ordering];
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
	
	NSInteger rowid = sqlite3_last_insert_rowid(self.db);
	sqlQuery = [NSString stringWithFormat:@"INSERT INTO groups (item_id, category_id, title) VALUES (%li,NULL,NULL);", (long)rowid];
	sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
	
    Item *page = [[Item alloc] initWithID:rowid name:[NSString stringWithFormat:@"%@ %li",CCLocalized(@"PAGE"),(long)ordering] parent:self.rootItem uuid:uuid flags:0 type:3 ordering:(int)ordering visible:YES];
	
	return page;
}

-(Item *)createNewGroup:(NSString *)title onPage:(Item *)page withOrdering:(NSInteger)ordering
{
	NSString *uuid = [self generateUUIDString];
	
    NSString *sqlQuery = [NSString stringWithFormat:@"INSERT INTO items (uuid, flags, type, parent_id, ordering) VALUES ('%@',0,2,%li,%li);", uuid, (long)[page identifier], (long)ordering];
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
	
	NSInteger rowid = sqlite3_last_insert_rowid(self.db);
    sqlQuery = [NSString stringWithFormat:@"INSERT INTO groups (item_id, category_id, title) VALUES (%li,NULL,'%@');", (long)rowid, title];
	sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
	
	Item *group = [[Item alloc] initWithID:rowid name:title parent:page uuid:uuid flags:0 type:2 ordering:ordering visible:YES];
	
	return group;
}

-(void)executeSQL:(NSString *)sqlQuery
{
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
}

#pragma mark - Item actions

-(void)setVisible:(BOOL)visible forItem:(Item *)item
{
	if([item setVisible:visible updateDatabase:YES]) {
		for (Item *child in [item children]) {
			[self setVisible:visible forItem:child];
		}
	}else{
		[[NSAlert alertWithMessageText:CCLocalized(@"Error")
						defaultButton:CCLocalized(@"Okay")
					  alternateButton:nil
						  otherButton:nil
             informativeTextWithFormat:CCLocalized(@"Couln't hide/unhide the item '%@'. Permission denied?"),[item name]] runModal];
	}
}

-(void)sortAllItems
{
	/*
	for (Item *item in [rootItem children]) {
		[item sortChildrenAlphabetically:YES];
	}
	[self reload];
	 */
	
	NSMutableArray *appsAndGroups = [[NSMutableArray alloc] initWithCapacity:[self.items count]];
	for (Item *item in self.items) {
		if (([item type] == kItemApp || [item type] == kItemGroup) && [[item parent] type] == kItemPage) {
			[appsAndGroups addObject:item];
		}
	}
	
    NSSortDescriptor* sortOrder = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)];
	[appsAndGroups sortUsingDescriptors:[NSArray arrayWithObject: sortOrder]];
	
	int currentPage = 0;
	for (int i=0; i<[appsAndGroups count]; i++) 
	{
		Item *item = [appsAndGroups objectAtIndex:i];
		
		[item setParent:[[self.rootItem children] objectAtIndex:currentPage] updateDatabase:YES];
		[item setOrdering:i%maximumItemsPerPage updateDatabase:YES];
		
		if (i%maximumItemsPerPage==maximumItemsPerPage-1) {
			currentPage++;
		}
	}
	
	[self reload];
}

-(void)sortSelectedItem
{
	Item *item = [self.outlineView itemAtRow:[self.outlineView selectedRow]];
	[item sortChildrenAlphabetically:NO];
	
	[self reload];
}

-(void)renameSelectedItem
{
	Item *item = [self.outlineView itemAtRow:[self.outlineView selectedRow]];
	
	NSString *itemName = [self input:[NSString stringWithFormat:CCLocalized(@"You are about to rename '%@'.\nPlease type in the new name:"),[item name]] defaultValue:[item name]];
	
	if (itemName) {
		itemName = [itemName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([itemName isNotEqualTo:@""]) 
		{
			[item setName:itemName updateDatabase:YES];
			[self reload];
		}
	}
}

-(void)removeItem:(Item *)item
{
	for (Item *child in [[item parent] children]) {
		if (child == item) continue;
		
		if (child.ordering>=item.ordering)
			child.ordering--;
	}
	
	[item setParent:nil];
	
    NSString *sqlQuery = [NSString stringWithFormat:@"DELETE FROM items WHERE rowid=%li;", (long)item.identifier];
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(self.db, sql, NULL, NULL, NULL);
}

-(void)updatePages
{
	NSMutableArray *overflow = [[NSMutableArray alloc] initWithCapacity:1];
	for (Item *page in [self.rootItem children]) {
		if ([overflow count]>0) {
			int i = 0;
			for (Item *item in overflow) {
				[item setParent:page updateDatabase:YES];
				[item setOrdering:i++ updateDatabase:YES];
			}
		}
		[overflow removeAllObjects];
		
		for (NSInteger i=maximumItemsPerPage; i<[[page children] count]; i++) {
			[overflow addObject:[[page children] objectAtIndex:i]];
		}
	}
	
	if ([overflow count]>0) { // Last page had more elements than 40
		Item *page = [self createNewPage];
		int i = 0;
		for (Item *item in overflow) {
			[item setParent:page updateDatabase:YES];
			[item setOrdering:i++ updateDatabase:YES];
		}
	}
}

-(BOOL)addIgnoredBundle:(NSString *)bundleIdentifier
{
	if (!bundleIdentifier || [bundleIdentifier isEqualTo:@""])
		return true;
	
	[self.ignoredBundles addObject:bundleIdentifier];
	
	[self.plist writeToFile:[plistTemporaryPath stringByAppendingPathComponent:plistFileName] atomically:YES];
	
	return [self movePlistWithRights];
}

-(BOOL)removeIgnoredBundle:(NSString *)bundleIdentifier
{
	if ([bundleIdentifier isEqualTo:@""])
		return true;
	
	[self.ignoredBundles removeObject:bundleIdentifier];
	
	[self.plist writeToFile:[plistTemporaryPath stringByAppendingPathComponent:plistFileName] atomically:YES];
	
	return [self movePlistWithRights];
}

-(BOOL)resetIgnoredBundles
{
	[self.ignoredBundles removeAllObjects];
	return [self addIgnoredBundle:@"com.apple.launchpad.launcher"];
}

#pragma mark - System control

- (NSString *)generateUUIDString
{
	return [[NSUUID UUID] UUIDString];
}

-(BOOL)movePlistWithRights
{
	return [self moveFileWithRightsFrom:[plistTemporaryPath stringByAppendingPathComponent:plistFileName] to:[plistPath stringByAppendingPathComponent:plistFileName]];
}

-(BOOL)moveFileWithRightsFrom:(NSString *)source to:(NSString *)destination
{
	return [self runCommandWithRights:[NSString stringWithFormat:@" mv -f \"%@\" \"%@\"",source,destination]];
}

-(void)runCommand:(NSString *)command withArguments:(NSArray *)arguments
{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:command];
	[task setArguments:arguments];
	[task launch];
	[task waitUntilExit];
}

-(BOOL)runCommandWithRights:(NSString *)command
{
	NSMutableArray *args = [NSMutableArray array];
	[args addObject:@"-c"];
	[args addObject:command];
	// Convert array into void-* array.
	const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
	int argvIndex = 0;
	for (NSString *string in args) {
		argv[argvIndex] = [string UTF8String];
		argvIndex++;
	}
	argv[argvIndex] = nil;
	
	OSErr processError = AuthorizationExecuteWithPrivileges([[self.authView authorization] authorizationRef], [@"/bin/sh" UTF8String],
															kAuthorizationFlagDefaults, (char *const *)argv, nil);
	free(argv);
	
	if (processError != errAuthorizationSuccess)
		return false;
	
	return true;
}

-(NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue {
	NSAlert *alert = [NSAlert alertWithMessageText:prompt
									 defaultButton:CCLocalized(@"Okay")
								   alternateButton:CCLocalized(@"Cancel")
									   otherButton:nil
						 informativeTextWithFormat:@""];
	
	NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
	[input setStringValue:defaultValue];
	[alert setAccessoryView:input];
	NSInteger button = [alert runModal];
	if (button == NSAlertDefaultReturn) {
		[input validateEditing];
		return [input stringValue];
	} else if (button == NSAlertAlternateReturn) {
		return nil;
	} else {
		return nil;
	}
}

-(void)update
{
	NSURL *remoteURL = [NSURL URLWithString:updateURLString];
	NSString *temporaryZipPath = [plistTemporaryPath stringByAppendingPathComponent:@"Launchpad-Control.zip"];
	[[NSData dataWithContentsOfURL:remoteURL] writeToFile:temporaryZipPath atomically:TRUE];
	
	sleep(1);
	
	[self runCommand:@"/usr/bin/unzip" withArguments:[NSArray arrayWithObjects:@"-qo", [NSString stringWithFormat:@"%@", temporaryZipPath], @"-d /tmp/", nil]];
	[[NSWorkspace sharedWorkspace] openFile:@"/tmp/Launchpad-Control.prefPane"];
}

@end
