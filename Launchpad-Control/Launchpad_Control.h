//
//  Launchpad_Control.h
//  Launchpad-Control
//
//  Created by Andreas Ganske on 28.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <sqlite3.h>

@interface Launchpad_Control : NSPreferencePane <NSTableViewDataSource> {
	NSString *databasePath;
	NSString *databaseBackupPath;
	
	NSTableView *tableView;
	
	NSButton *checkForUpdatesButton;
	NSButton *donateButton;
	
	NSButton *showAllButton;
	NSButton *hideAllButton;
	
	NSButton *fullResetButton;
	
	NSButton *applyButton;
	
    NSMutableArray *apps;
	
	sqlite3 *db;
	BOOL dbOpened;
}

- (void)mainViewDidLoad;

-(void)reload;

-(BOOL)openDatabase;
-(void)closeDatabase;

-(BOOL)fetchApplications;
-(BOOL)fetchGroups;
-(void)sortApps;

-(void)applySettings;
-(void)restartDock;

-(void)removeDatabase;

-(void)showAll;
-(void)hideAll;

@property (assign) IBOutlet NSTableView *tableView;

@property (assign) IBOutlet NSButton *checkForUpdatesButton;
@property (assign) IBOutlet NSButton *donateButton;

@property (assign) IBOutlet NSButton *showAllButton;
@property (assign) IBOutlet NSButton *hideAllButton;

@property (assign) IBOutlet NSButton *fullResetButton;

@property (assign) IBOutlet NSButton *applyButton;

@end
