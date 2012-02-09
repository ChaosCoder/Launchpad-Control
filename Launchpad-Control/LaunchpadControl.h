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
#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>

@interface LaunchpadControl : NSPreferencePane <NSOutlineViewDataSource,NSOutlineViewDelegate> {
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
	
	BOOL dbOpened;
	BOOL changedData;
	NSMutableDictionary *plist;
	NSMutableArray *ignoredBundles;
	
	NSMutableData *receivedData;
	
	Item *draggedItem;
	IBOutlet SFAuthorizationView *authView;
	
	sqlite3 *db;
}

+(id)shared;

#pragma mark - Load
-(void)mainViewDidLoad;
-(void)loadPlist;
-(void)reload;

-(BOOL)openDatabase;
-(void)closeDatabase;

-(BOOL)fetchItems;
-(void)setVisible:(BOOL)visible forItem:(Item *)item;

-(void)setupRights;
-(void)applySettings;
-(void)restartDock;

-(void)refreshDatabase;
-(void)removeDatabase;

-(void)setDatabaseVersion;
-(NSString *)getDatabaseVersion;

-(void)databaseIsCorrupt;

-(void)dropTriggers;
-(void)createTriggers;

-(void)migrateFrom:(NSString *)version;

-(IBAction)buttonPressed:(id)sender;

-(void)executeSQL:(NSString *)sqlQuery;
-(BOOL)addIgnoredBundle:(NSString *)bundleIdentifier;
-(BOOL)removeIgnoredBundle:(NSString *)bundleIdentifier;

@property (nonatomic, weak) IBOutlet NSOutlineView *tableView;

@property (nonatomic, weak) IBOutlet NSTextFieldCell *descriptionFieldCell;

@property (nonatomic, weak) IBOutlet NSButton *updateButton;
@property (nonatomic, weak) IBOutlet NSButton *donateButton;
@property (nonatomic, weak) IBOutlet NSButton *tweetButton;

@property (nonatomic, weak) IBOutlet NSButton *resetButton;

@property (nonatomic, weak) IBOutlet NSButton *refreshButton;
@property (nonatomic, weak) IBOutlet NSButton *applyButton;

@property (nonatomic, weak) IBOutlet NSTextFieldCell *currentVersionField;

@end
