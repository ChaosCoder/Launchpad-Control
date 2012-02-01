//
//  Launchpad_Control.h
//  Launchpad-Control
//
//  Created by Andreas Ganske on 28.07.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <sqlite3.h>
#import "Item.h"

@interface Launchpad_Control : NSPreferencePane <NSOutlineViewDataSource,NSOutlineViewDelegate> {
	NSString *databasePath;
	NSString *databaseBackupPath;
	
	NSOutlineView *tableView;
	
	NSButton *updateButton;
	NSButton *donateButton;
	NSButton *tweetButton;
	
	NSButton *refreshButton;
	NSButton *resetButton;
	
	NSButton *applyButton;
	
	NSTextFieldCell *currentVersionField;
	
	Item *rootItem;
    NSMutableArray *items;
	
	sqlite3 *db;
	BOOL dbOpened;
	BOOL changedData;
	
	NSMutableData *receivedData;
}

- (void)mainViewDidLoad;

-(void)reload;

-(BOOL)openDatabase;
-(void)closeDatabase;

-(BOOL)fetchItems;
-(void)setVisible:(BOOL)visible forItem:(Item *)item;

-(void)applySettings;
-(void)restartDock;

-(void)refreshDatabase;
-(void)removeDatabase;

-(void)setDatabaseVersion;
-(NSString *)getDatabaseVersion;

-(void)databaseIsCorrupt;

-(void)dropTriggers;
-(void)createTriggers;

-(IBAction)buttonPressed:(id)sender;

@property (assign) IBOutlet NSOutlineView *tableView;

@property (assign) IBOutlet NSButton *updateButton;
@property (assign) IBOutlet NSButton *donateButton;
@property (assign) IBOutlet NSButton *tweetButton;

@property (assign) IBOutlet NSButton *resetButton;

@property (assign) IBOutlet NSButton *refreshButton;
@property (assign) IBOutlet NSButton *applyButton;

@property (assign) IBOutlet NSTextFieldCell *currentVersionField;

@end
