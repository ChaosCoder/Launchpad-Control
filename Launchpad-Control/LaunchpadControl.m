//
//  Launchpad_Control.m
//  Launchpad-Control
//
//  Created by Andreas Ganske on 28.07.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import "LaunchpadControl.h"
#import "CCUtils.h"

@implementation LaunchpadControl

static NSString *plistPath = @"/System/Library/CoreServices/Dock.app/Contents/Resources/LaunchPadLayout.plist";
static NSString *plistTemporaryPath = @"/tmp/LaunchPadLayout.plist";
static NSString *currentVersion;

static NSInteger maximumItemsPerPage = 40;
static NSInteger maximumItemsPerGroup = 32;

static id _shared = nil;

#define MyPrivateTableViewDataType @"MyPrivateTableViewDataType"

@synthesize tableView, donateButton, tweetButton, updateButton, resetButton, refreshButton, applyButton, currentVersionField, descriptionFieldCell;

#pragma mark Loading

-(id)initWithBundle:(NSBundle *)bundle
{
	[super initWithBundle:bundle];
	
	_shared = self;
	
	return self;
}

+(id)shared
{
	return _shared;
}

- (void)mainViewDidLoad
{
	currentVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleVersion"];
	[tableView registerForDraggedTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType]];
	
	[descriptionFieldCell setTitle:CCLocalized("This app allows you to easily hide apps or groups from Launchpad.~nTo hide an app just uncheck it and click 'Apply'.")];
	[resetButton setTitle:CCLocalized("Reset")];
	[refreshButton setTitle:CCLocalized("Refresh")];
	[applyButton setTitle:CCLocalized("Apply")];
	[currentVersionField setTitle:[NSString stringWithFormat:@"v%@",currentVersion]];
	
	items = [[NSMutableArray alloc] init];
	
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
    [authView setAuthorizationRights:&authorizationRights];
    authView.delegate = self;
    [authView updateStatus:nil];
}

//
// SFAuthorization delegates
//

- (BOOL)isUnlocked {
    return [authView authorizationState] == SFAuthorizationViewUnlockedState;
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view {
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view {
}

-(void)loadPlist
{
	plist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
	ignoredBundles = [plist objectForKey:@"ignore"];
}

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
		receivedData = [[NSMutableData data] retain];
	} else {
		// Inform the user that the connection failed.
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *newVersionString = [[NSString alloc] initWithData:receivedData encoding:NSASCIIStringEncoding];
	
	if ([newVersionString floatValue] > [currentVersion floatValue]) {
		[updateButton setTitle:[NSString stringWithFormat:CCLocalized("Get v%@ now!"),newVersionString]];
		[updateButton setHidden:NO];
		
		if ([[NSAlert alertWithMessageText:CCLocalized("Get v%@ now!")
							 defaultButton:CCLocalized("Download")
						   alternateButton:CCLocalized("Later")
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:CCLocalized("Version %@ of Launchpad-Control is available (You have %@). You can download it now or later by clicking on the button at the top."),newVersionString,currentVersion]] runModal])
		{
			[self buttonPressed:updateButton];
		}
	}
	
    [connection release];
    [receivedData release];
}

-(BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return [[item children] count]>0;
}

-(NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return item==nil ? [[rootItem children] count] : [[item children] count];
}

-(id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	return item==nil ? [[rootItem children] objectAtIndex:index] : [[(Item *)item children] objectAtIndex:index];
}

-(BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [[item children] count]>0;
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

-(void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	[self setVisible:[object boolValue] forItem:(Item *)item];
	[tableView reloadItem:item reloadChildren:YES];
}

-(void)setVisible:(BOOL)visible forItem:(Item *)item
{
	//changedData = YES;
	if([item setVisible:visible updateDatabase:YES]) {
		for (Item *child in [item children]) {
			[self setVisible:visible forItem:child];
		}
	}
}

-(BOOL)openDatabase
{	
	NSError *error = nil;
	
	@try {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *directory = [@"~/Library/Application Support/Dock/" stringByStandardizingPath];
		
		NSArray *files = [fileManager contentsOfDirectoryAtPath:directory error:&error];
		
		if (error || !files || [files count]==0)
			[NSException raise:@"DatabaseNotFoundException" format:CCLocalized("Could not find any database file for Launchpad.")];
		
		
		//check if file is already there
		for (NSString *fileName in files) {
			if ([[fileName pathExtension] isEqualToString:@"db"]) {
				
				databasePath = [directory stringByAppendingPathComponent:fileName];
				databaseBackupPath = [databasePath stringByAppendingPathExtension:@"backup"];
				
				if (![fileManager fileExistsAtPath:databaseBackupPath]){
					[fileManager copyItemAtPath:databasePath toPath:databaseBackupPath error:&error];
					
				}
				
				if (error)
					[NSException raise:@"CouldNotCreateBackupException" format:CCLocalized("Could not backup original Launchpad database.~nBe careful!")];
				
				if([fileManager fileExistsAtPath:databasePath])
				{
					if(sqlite3_open([databasePath UTF8String], &db) == SQLITE_OK)
					{
						dbOpened = YES;
						NSString *databaseVersion = [self getDatabaseVersion];
						if (![databaseVersion isEqualToString:currentVersion]) {
							[self migrateFrom:databaseVersion];
						}
						return YES;
					}
				}
				
				[NSException raise:@"CannotOpenDatabaseException" format:CCLocalized("Could not open the database file for Launchpad.")];
			}
		}
		
		[NSException raise:@"DatabaseNotFoundException" format:CCLocalized("Could not find any database file for Launchpad.")];
	}
	@catch (NSException *exception) {
		[[NSAlert alertWithMessageText:CCLocalized("Error") defaultButton:CCLocalized("Okay") alternateButton:nil otherButton:nil informativeTextWithFormat:[exception reason]] runModal];
		return NO;
	}
}

-(BOOL)fetchItems
{
	if(!dbOpened)
		return NO;
	
	if (items)
		[items removeAllObjects];
	
	NSString *sqlString = [NSString stringWithFormat:@"\
						   SELECT rowid,parent_id,uuid,flags,type,ordering,apps.title,groups.title,apps.bundleid \
						   FROM items \
						   LEFT JOIN apps ON ABS(rowid) = apps.item_id \
						   LEFT JOIN groups ON ABS(rowid) = groups.item_id \
						   ORDER BY parent_id,ordering;"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
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
					if ([uuid isEqualToString:@"HOLDINGPAGE"])
						continue;
					else
						name = [CCLocalized("PAGE") stringByAppendingFormat:@" %i",++pageCount];
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
				for (Item *otherItem in items) {
					if ([otherItem identifier] == labs(parent_id) ) {
						parent = otherItem;
						break;
					}
				}
				if (!parent) {
					parent = [[Item alloc] initWithID:parent_id name:nil parent:nil uuid:nil flags:0 type:2 ordering:0 visible:YES];
					[items addObject:parent];
				}
			}
			
			Item *item = nil;
			for (Item *otherItem in items) {
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
	
			[items addObject:item];
			
			if (rowid == 1)
				rootItem = item;
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
	
	if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		if(sqlite3_step(statement) == SQLITE_ROW){
			if (sqlite3_column_int(statement, 0)>0) {
				[self databaseIsCorrupt];
			}
		}
	}
	sqlite3_finalize(statement);
}

-(IBAction)buttonPressed:(id)sender
{
	if (sender == updateButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://chaosspace.de/launchpad-control/update"]];
	}else if (sender == refreshButton) {
		[self refreshDatabase];
	}else if (sender == applyButton) {
		[self applySettings];
	}else if (sender == resetButton) {
		[self removeDatabase];
	}else if (sender == donateButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CHBAEUQVBUYTL"]];
	}else if (sender == tweetButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:CCLocalized("http://twitter.com/home?status=Clean%20up%20your%20Launchpad!%20Check%20out%20Launchpad-Control%20http%3A%2F%2Fchaosspace.de%2Flaunchpad-control")]];
	}
}

-(BOOL)movePlistWithRights
{
	NSMutableArray *args = [NSMutableArray array];
	[args addObject:@"-c"];
	[args addObject:[NSString stringWithFormat:@" mv -f %@ %@",plistTemporaryPath,plistPath]];
	// Convert array into void-* array.
	const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
	int argvIndex = 0;
	for (NSString *string in args) {
		argv[argvIndex] = [string UTF8String];
		argvIndex++;
	}
	argv[argvIndex] = nil;
	
	OSErr processError = AuthorizationExecuteWithPrivileges([[authView authorization] authorizationRef], [@"/bin/sh" UTF8String],
															kAuthorizationFlagDefaults, (char *const *)argv, nil);
	free(argv);
	
	if (processError != errAuthorizationSuccess)
		return false;
	
	return true;
}

-(void)applySettings
{
/*
	NSMutableArray *sqlQueries = [NSMutableArray array];
	bool oldChangedData = changedData;
	changedData = NO;
	for (Item *item in items) {
		if (item == rootItem)
			continue;
		
		[sqlQueries addObject:[NSString stringWithFormat:@"UPDATE items SET rowid = %i WHERE ABS(rowid) = %i;", [item identifier] * ([item visible] ? 1 : -1), [item identifier]]];
		
		if (item.newParent)
			[sqlQueries addObject:[NSString stringWithFormat:@"UPDATE items SET parent_id = %i WHERE ABS(rowid) = %i;", [[item parent] identifier], [item identifier]]];
		
		if (item.newOrder)
			[sqlQueries addObject:[NSString stringWithFormat:@"UPDATE items SET ordering = %i WHERE ABS(rowid) = %i;", [item ordering], [item identifier]]];
		
		item.newParent = NO;
		item.newOrder = NO;
		
		if (item.type==kItemApp && item.bundleIdentifier && [item.bundleIdentifier isNotEqualTo:@""]) {
			if ([item visible]) {
				[ignoredBundles removeObject:item.bundleIdentifier];
			}else if(![ignoredBundles containsObject:item.bundleIdentifier]){
				[ignoredBundles addObject:item.bundleIdentifier];
			}
		}
	}
	
	[plist writeToFile:plistTemporaryPath atomically:YES];
	
	if([self movePlistWithRights]) 
	{
		for (NSString *sqlQuery in sqlQueries) {
			const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
			sqlite3_exec(db, sql, NULL, NULL, NULL);
		}
		
		
	}else{
		changedData = oldChangedData;
	}
 */
	
	[self restartDock];
	[self reload];
	
}

-(void)restartDock
{
	system("killall Dock");
}

-(void)removeDatabase
{
	if ([[NSAlert alertWithMessageText:CCLocalized("Are you sure?") 
						 defaultButton:CCLocalized("Yes") 
					   alternateButton:CCLocalized("No") 
						   otherButton:nil 
			 informativeTextWithFormat:CCLocalized("A full reset will remove the database file used by Launchpad. Launchpad will then create a new database. Any custom groups or manually added apps will be gone.")] runModal])
	{
		[self closeDatabase];
		[[NSFileManager defaultManager] removeItemAtPath:databasePath error:nil];
		[self restartDock];
		system("open /Applications/Launchpad.app");
		
		if ([[NSAlert alertWithMessageText:CCLocalized("Do you want Launchpad-Control to load the new database?") 
						defaultButton:CCLocalized("Yes") 
					  alternateButton:CCLocalized("No") 
						  otherButton:nil 
				 informativeTextWithFormat:CCLocalized("If you want to edit your database click 'Yes'. Click 'No' if you don't want Launchpad-Control to load and edit your new database. Launchpad-Control will then close itself.")] runModal]) 
		{
			while (![self openDatabase]) {
				if ([[NSAlert alertWithMessageText:CCLocalized("Could not find any database.") 
									 defaultButton:CCLocalized("Refresh") 
								   alternateButton:CCLocalized("Quit") 
									   otherButton:nil 
						 informativeTextWithFormat:CCLocalized("Please wait while Launchpad refreshes its database. \nOnce it is done click 'Refresh'. If this error still exists after some time press 'Quit'.")] runModal]) {
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
	
	if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
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
	
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
}

-(void)dropTriggers
{
	NSString *sqlString = [NSString stringWithFormat:@"DROP TRIGGER insert_item; DROP TRIGGER item_deleted; DROP TRIGGER update_item_parent; DROP TRIGGER update_items_order; DROP TRIGGER update_items_order_backwards;"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
}
	
-(void)createTriggers
{
	NSString *sqlString = [NSString stringWithFormat:@"CREATE TRIGGER insert_item AFTER INSERT on items WHEN 0 == (SELECT value FROM dbinfo WHERE key='ignore_items_update_triggers') \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = (SELECT ifnull(MAX(ordering),0)+1 FROM items WHERE ABS(parent_id)=ABS(new.parent_id)) WHERE ROWID=new.rowid; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END; \n\
\n\
CREATE TRIGGER item_deleted AFTER DELETE ON items \n\
BEGIN \n\
DELETE FROM apps WHERE rowid=old.rowid; \n\
DELETE FROM groups WHERE item_id=old.rowid; \n\
DELETE FROM downloading_apps WHERE item_id=old.rowid; \n\
UPDATE items SET ordering = ordering - 1 WHERE ABS(old.parent_id) = ABS(parent_id) AND ordering > old.ordering; \n\
END; \n\
\n\
CREATE TRIGGER update_item_parent AFTER UPDATE OF parent_id ON items \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = (SELECT ifnull(MAX(ordering),0)+1 FROM items WHERE ABS(parent_id)=ABS(new.parent_id) AND ROWID!=old.rowid) WHERE ROWID=old.rowid; \n\
UPDATE items SET ordering = ordering - 1 WHERE ABS(parent_id) = ABS(old.parent_id) and ordering > old.ordering; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END; \n\
\n\
CREATE TRIGGER update_items_order BEFORE UPDATE OF ordering ON items WHEN new.ordering > old.ordering AND 0 == (SELECT value FROM dbinfo WHERE key='ignore_items_update_triggers') \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = ordering - 1 WHERE ABS(parent_id) = ABS(old.parent_id) AND ordering BETWEEN old.ordering and new.ordering; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END; \n\
\n\
CREATE TRIGGER update_items_order_backwards BEFORE UPDATE OF ordering ON items WHEN new.ordering < old.ordering AND 0 == (SELECT value FROM dbinfo WHERE key='ignore_items_update_triggers') \n\
BEGIN \n\
UPDATE dbinfo SET value=1 WHERE key='ignore_items_update_triggers'; \n\
UPDATE items SET ordering = ordering + 1 WHERE ABS(parent_id) = ABS(old.parent_id) AND ordering BETWEEN new.ordering and old.ordering; \n\
UPDATE dbinfo SET value=0 WHERE key='ignore_items_update_triggers'; \n\
END;"];
	
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);	
}

-(void)databaseIsCorrupt
{
	if ([[NSAlert alertWithMessageText:CCLocalized("Corrupt database detected!") 
						 defaultButton:CCLocalized("Okay") 
					   alternateButton:CCLocalized("Cancel") 
						   otherButton:nil 
			 informativeTextWithFormat:CCLocalized("Your database file seems to be corrupt. A Launchpad-Control version prior 1.2 could have done that.\nYou have to do a full reset of your database to use this new version of Launchpad-Control. Any custom groups or manually added apps will be gone.")] runModal])
	{
		[self closeDatabase];
		[[NSFileManager defaultManager] removeItemAtPath:databasePath error:nil];
		[self restartDock];
		system("open /Applications/Launchpad.app");
		
		[[NSAlert alertWithMessageText:CCLocalized("Refreshing database...") 
						defaultButton:CCLocalized("Okay") 
					  alternateButton:nil 
						  otherButton:nil 
			informativeTextWithFormat:CCLocalized("Please wait while Launchpad refreshes its database. \nOnce it is done click 'Okay'. Launchpad-Control will then reload the new database.")] runModal];
		
		while (![self openDatabase]) {
			if ([[NSAlert alertWithMessageText:CCLocalized("Could not find any database.") 
								 defaultButton:CCLocalized("Refresh") 
							   alternateButton:CCLocalized("Quit") 
								   otherButton:nil 
					 informativeTextWithFormat:CCLocalized("Please wait while Launchpad refreshes its database. \nOnce it is done click 'Refresh'. If this error still exists after some minutes press 'Quit'.")] runModal]) {
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
	if (changedData) {
		if ([[NSAlert alertWithMessageText:CCLocalized("Unsaved changes!") 
							 defaultButton:CCLocalized("Apply") 
						   alternateButton:CCLocalized("Refresh") 
							   otherButton:nil
				 informativeTextWithFormat:CCLocalized("You seem to have made changes but you have not applied them. A refresh will undo these changes. \nWhat do you want to do?")] runModal])
		{
			[self applySettings];
		}else{
			[self reload];
		}
	}else{
		[self reload];
	}
}

-(void)migrateFrom:(NSString *)oldVersion
{
	if ([oldVersion isEqualToString:@"1.3"]) {
		//[self dropTriggers];
		//[self createTriggers];
	}else if([oldVersion isEqualToString:@"1.4"]) {
		NSString *sqlString = [NSString stringWithFormat: @"UPDATE items SET rowid=ABS(rowid), parent_id=ABS(parent_id) WHERE parent_id>0; \n\
															UPDATE items SET rowid=-ABS(rowid), parent_id=ABS(parent_id) WHERE parent_id<0;"];
		const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
		sqlite3_exec(db, sql, NULL, NULL, NULL);
	}
	
	[self setDatabaseVersion];
}

-(void)closeDatabase
{
	dbOpened = NO;
	sqlite3_close(db);
}

-(void)reload
{
	[self checkDatabase];
	[self fetchItems];
	[tableView reloadData];
	
	for (Item *child in [rootItem children]) {
		[tableView expandItem:child expandChildren:NO];
	}
	
	changedData = NO;
}

#pragma mark - Reodering

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)_items toPasteboard:(NSPasteboard *)pasteboard
{
	// Copy the row numbers to the pasteboard.
	//NSData *zNSIndexSetData = [NSKeyedArchiver archivedDataWithRootObject:_items];
	//[pasteboard declareTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType] owner:self];
	//[pasteboard setData:zNSIndexSetData forType:MyPrivateTableViewDataType];
	//[pasteboard declareTypes:MyPrivateTableViewDataType owner:self ];
	
	draggedItem = [_items objectAtIndex:0];
	
	NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:draggedItem];
	[pasteboard declareTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType] owner:self];
	[pasteboard setData:itemData forType:MyPrivateTableViewDataType];
	
	return YES;
}

-(NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	if (draggedItem.type == kItemPage && item) // Page not in Root
		return NO;
	
	if (draggedItem.type == kItemGroup && [(Item *)item type]!=kItemPage) // Group not in Page
		return NO;
	
	if (draggedItem.type == kItemApp && [(Item *)item type]==kItemGroup && [[(Item *)item children] count]>=maximumItemsPerGroup) // App in full group
		return NO;
	
	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)parentItem childIndex:(NSInteger)dropRow 
{
	if (parentItem == nil) 
		parentItem = rootItem;
	
	NSInteger dragRow = [[[draggedItem parent] children] indexOfObject:draggedItem];
	
	[draggedItem retain];
	
	if ([draggedItem parent] == parentItem) {
		if (dragRow < dropRow) {
			dropRow--;
		}
	}
	
	for (Item *child in [[draggedItem parent] children]) {
		if (child == draggedItem) continue;
		
		if (child.ordering>=draggedItem.ordering)
			child.ordering--;
	}
	
	if (dropRow>=0) {
		[draggedItem setParent:parentItem updateDatabase:YES];
		[draggedItem setOrdering:dropRow+(draggedItem.type == kItemPage ? 1 : 0) updateDatabase:YES];
		
		for (Item *child in [[draggedItem parent] children]) {
			if (child == draggedItem) continue;
			
			if (child.ordering>=draggedItem.ordering)
				child.ordering++;
		}
		
		[parentItem updateChildren];
		
		[self updatePages];
	}else{ // dropped an app on an app
		NSString *groupName = [self input:[NSString stringWithFormat:CCLocalized("You are about to merge two apps (%@ and %@) in to a new group.\nPlease type in the group's name."),[draggedItem name],[parentItem name]] defaultValue:@""];
		Item *group = [self createNewGroup:groupName onPage:[parentItem parent] withOrdering:[parentItem ordering]];
		[parentItem setParent:group updateDatabase:YES];
		[draggedItem setParent:group updateDatabase:YES];
		[parentItem setOrdering:0];
		[draggedItem setOrdering:1];
		
		[[group parent] updateChildren];
	}
	
	[draggedItem release];
	
	[outlineView noteNumberOfRowsChanged];
	[outlineView reloadData];
		
	return YES;
}

-(void)updatePages
{
	NSMutableArray *overflow = [[NSMutableArray alloc] initWithCapacity:1];
	for (Item *page in [rootItem children]) {
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

// return a new autoreleased UUID string
- (NSString *)generateUUIDString
{
	// create a new UUID which you own
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	
	// create a new CFStringRef (toll-free bridged to NSString)
	// that you own
	NSString *uuidString = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
	
	// transfer ownership of the string
	// to the autorelease pool
	[uuidString autorelease];
	
	// release the UUID
	CFRelease(uuid);
	
	return uuidString;
}

-(NSString *)input:(NSString *)prompt defaultValue:(NSString *)defaultValue {
	NSAlert *alert = [NSAlert alertWithMessageText:prompt
									 defaultButton:CCLocalized("Okay")
								   alternateButton:CCLocalized("Cancel")
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
		NSAssert1(NO, @"Invalid input dialog button %d", button);
		return nil;
	}
}

-(Item *)createNewPage {
	NSString *uuid = [self generateUUIDString];
	NSInteger ordering = [[rootItem children] count];
	
	NSString *sqlQuery = [NSString stringWithFormat:@"INSERT INTO items (uuid, flags, type, parent_id, ordering) VALUES ('%@',0,3,%i,%i);", uuid, [rootItem identifier], ordering];
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
	
	NSInteger rowid = sqlite3_last_insert_rowid(db);
	sqlQuery = [NSString stringWithFormat:@"INSERT INTO groups (item_id, category_id, title) VALUES (%i,NULL,NULL);", rowid];
	sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
	
	Item *page = [[Item alloc] initWithID:rowid name:[NSString stringWithFormat:@"%@ %i",CCLocalized("PAGE"),ordering] parent:rootItem uuid:uuid flags:0 type:3 ordering:(int)ordering visible:YES];
	
	return page;
}

-(Item *)createNewGroup:(NSString *)title onPage:(Item *)page withOrdering:(NSInteger)ordering
{
	NSString *uuid = [self generateUUIDString];
	
	NSString *sqlQuery = [NSString stringWithFormat:@"INSERT INTO items (uuid, flags, type, parent_id, ordering) VALUES ('%@',0,2,%i,%i);", uuid, [page identifier], ordering];
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
	
	NSInteger rowid = sqlite3_last_insert_rowid(db);
	sqlQuery = [NSString stringWithFormat:@"INSERT INTO groups (item_id, category_id, title) VALUES (%i,NULL,'%@');", rowid, title];
	sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
	
	Item *group = [[Item alloc] initWithID:rowid name:title parent:page uuid:uuid flags:0 type:2 ordering:ordering visible:YES];
	
	return group;
}

-(void)executeSQL:(NSString *)sqlQuery
{
	const char *sql = [sqlQuery cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_exec(db, sql, NULL, NULL, NULL);
}

-(BOOL)addIgnoredBundle:(NSString *)bundleIdentifier
{
	if ([bundleIdentifier isEqualTo:@""])
		return false;
	
	[ignoredBundles addObject:bundleIdentifier];

	[plist writeToFile:plistTemporaryPath atomically:YES];

	return [self movePlistWithRights];
}

-(BOOL)removeIgnoredBundle:(NSString *)bundleIdentifier
{
	if ([bundleIdentifier isEqualTo:@""])
		return false;
	
	[ignoredBundles removeObject:bundleIdentifier];
	
	[plist writeToFile:plistTemporaryPath atomically:YES];
	
	return [self movePlistWithRights];

}

@end
