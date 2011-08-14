//
//  Launchpad_Control.m
//  Launchpad-Control
//
//  Created by Andreas Ganske on 28.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Launchpad_Control.h"
#import "App.h"

enum kItemType {
	kItemApp = 1,
	kItemGroup = 2
};

@implementation Launchpad_Control

@synthesize tableView, donateButton, checkForUpdatesButton, showAllButton, hideAllButton, fullResetButton, applyButton;

- (void)mainViewDidLoad
{
	apps = [[NSMutableArray alloc] init];
	[self reload];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
    return [apps count];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSButtonCell *cell=[[NSButtonCell alloc] init];
	[cell setButtonType:NSSwitchButton];
	App *app = [apps objectAtIndex:row];
	NSString *appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[app bundleID]];
	[cell setTitle:[[app name] stringByAppendingFormat:@" (%@)",appPath]];
	return cell;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	BOOL value = [(App *)[apps objectAtIndex:row] newIdentifier] >= 0;
	return [NSNumber numberWithInteger:(value ? NSOnState : NSOffState)];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)value forTableColumn:(NSTableColumn *)column row:(NSInteger)row 
{
	App *app = (App *)[apps objectAtIndex:row];
	
	if ([value boolValue]) 
	{
		[app setNewIdentifier:labs([app identifier])];
	} else {
		[app setNewIdentifier:-labs([app identifier])];
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
			[NSException raise:@"DatabaseNotFoundException" format:@"Could not find any database file for Launchpad."];
		
		
		//check if file is already there
		for (NSString *fileName in files) {
			if ([[fileName pathExtension] isEqualToString:@"db"]) {
				
				databasePath = [directory stringByAppendingPathComponent:fileName];
				databaseBackupPath = [databasePath stringByAppendingPathExtension:@"backup"];
				
				if (![fileManager fileExistsAtPath:databaseBackupPath]){
					[fileManager copyItemAtPath:databasePath toPath:databaseBackupPath error:&error];
					
				}
				
				if (error)
					[NSException raise:@"CouldNotCreateBackupException" format:@"Could not backup original Launchpad database.~nBe careful!"];
				
				if([fileManager fileExistsAtPath:databasePath])
				{
					if(sqlite3_open([databasePath UTF8String], &db) == SQLITE_OK)
					{
						dbOpened = YES;
						return YES;
					}
				}
				
				[NSException raise:@"CannotOpenDatabaseException" format:@"Could not open the database file for Launchpad."];
			}
		}
		
		[NSException raise:@"DatabaseNotFoundException" format:@"Could not find any database file for Launchpad."];
	}
	@catch (NSException *exception) {
		[[NSAlert alertWithMessageText:@"Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:[exception reason]] runModal];
		return NO;
	}
}

-(BOOL)removeDuplicates
{
	return NO;
	
	if (!dbOpened)
		return NO;
	
	NSString *sqlString = [NSString stringWithFormat:@"SELECT bad_rows.item_id FROM apps AS good_rows INNER JOIN apps AS bad_rows ON bad_rows.bundleid=good_rows.bundleid AND bad_rows.item_id>good_rows.item_id;"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		while(sqlite3_step(statement) == SQLITE_ROW) 
		{
			NSString *deleteSQLString = [NSString stringWithFormat:@"DELETE FROM apps WHERE item_id=%i",sqlite3_column_int(statement, 0)];
			const char *deleteSQL = [deleteSQLString cStringUsingEncoding:NSUTF8StringEncoding];
			sqlite3_exec(db, deleteSQL, NULL, NULL, NULL);
		}
	}
	sqlite3_finalize(statement);
	
	return YES;
}

-(BOOL)fetchApplications
{
	if(!dbOpened)
		return NO;
	
	NSString *sqlString = [NSString stringWithFormat:@"SELECT item_id,title,bundleid FROM apps"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		while(sqlite3_step(statement) == SQLITE_ROW) 
		{
			App *app = [[App alloc] initWithIdentifier:sqlite3_column_int(statement, 0) andName:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 1)] andBundleID:[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 2)] type:kItemApp];
			[apps addObject:app];
			[app release];
		}
	}
	sqlite3_finalize(statement);
	
	return YES;
}

-(BOOL)fetchGroups
{
	if(!dbOpened)
		return NO;
	
	NSString *sqlString = [NSString stringWithFormat:@"SELECT item_id,title FROM groups"];
	const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
	sqlite3_stmt *statement;
	
	if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
	{
		while(sqlite3_step(statement) == SQLITE_ROW) 
		{
			@try {
				App *app = [[App alloc] initWithIdentifier:sqlite3_column_int(statement, 0) andName:[NSString stringWithFormat:@"Group: %@",[NSString stringWithUTF8String:(char *)sqlite3_column_text(statement, 1)]] type:kItemGroup];
				[apps addObject:app];
				[app release];
			}
			@catch (NSException *exception) {
			}
		}
	}
	sqlite3_finalize(statement);
	
	return YES;
}

-(void)sortApps
{
	NSSortDescriptor *typeDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"type" ascending:NO] autorelease];
	NSSortDescriptor *nameDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
	NSArray *sortDescriptors = [NSArray arrayWithObjects:typeDescriptor,nameDescriptor,nil];
	[apps sortUsingDescriptors:sortDescriptors];
}

-(IBAction)buttonPressed:(id)sender
{
	if (sender == checkForUpdatesButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://chaosspace.de/launchpad-control"]];
	}else if (sender == applyButton) {
		[self applySettings];
	}else if (sender == showAllButton) {
		[self showAll];
		[tableView reloadData];
	}else if (sender == hideAllButton) {
		[self hideAll];
		[tableView reloadData];
	}else if (sender == fullResetButton) {
		[self removeDatabase];
	}else if (sender == donateButton) {
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CHBAEUQVBUYTL"]];
	}
}

-(void)applySettings
{
	for (App *app in apps) {
		NSString *table;
		switch ([app type]) {
			case kItemApp:
				table = @"apps";
				break;
				
			case kItemGroup:
				table = @"groups";
				break;
		}
		
		NSString *sqlString = [NSString stringWithFormat:@"UPDATE %@ SET item_id = %i WHERE item_id = %i", table, [app newIdentifier],[app identifier]];
		const char *sql = [sqlString cStringUsingEncoding:NSUTF8StringEncoding];
		
		sqlite3_stmt *statement;
		if (sqlite3_prepare_v2(db, sql, -1, &statement, NULL) == SQLITE_OK)
		{
			sqlite3_step(statement);
			sqlite3_finalize(statement);
		}
		
		[app setIdentifier:[app newIdentifier]];
	}
	[self restartDock];
}

-(void)restartDock
{
	system("killall Dock");
}

-(void)removeDatabase
{
	if ([[NSAlert alertWithMessageText:@"Are you sure?" 
						 defaultButton:@"Yes" 
					   alternateButton:@"No" 
						   otherButton:nil 
			 informativeTextWithFormat:@"A full reset will remove the database file used by Launchpad. Launchpad will then create a new database. Any custom changes (custom groups, etc.) will be gone."] runModal])
	{
		[self closeDatabase];
		[[NSFileManager defaultManager] removeItemAtPath:databasePath error:nil];
		[self restartDock];
		system("open /Applications/Launchpad.app");
		[[NSApplication sharedApplication] terminate:self];
	}
}

-(void)closeDatabase
{
	dbOpened = NO;
	sqlite3_close(db);
}

-(void)reload
{
	if (dbOpened)
		[self closeDatabase];
	
	[self openDatabase];
	[self removeDuplicates];
	[self fetchApplications];
	[self fetchGroups];
	[self sortApps];
	[tableView reloadData];
}

-(void)showAll
{
	for (App *app in apps) {
		[app setNewIdentifier:labs([app identifier])];
	}
}

-(void)hideAll
{
	for (App *app in apps) {
		[app setNewIdentifier:-labs([app identifier])];
	}
}

@end
