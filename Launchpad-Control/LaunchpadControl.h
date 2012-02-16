//
//  Launchpad_Control.h
//  Launchpad-Control
//
//  Created by Andreas Ganske on 28.07.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import <sqlite3.h>

@class Item;

@interface LaunchpadControl : NSPreferencePane <NSOutlineViewDataSource,NSOutlineViewDelegate> 
{
	Item *rootItem;
	NSMutableArray *items;
	
	Item *draggedItem;
	
	sqlite3 *db;
	NSString *databasePath;
	NSString *databaseBackupPath;
	
	BOOL dbOpened;
	BOOL changedData;
	
	NSMutableDictionary *plist;
	NSMutableArray *ignoredBundles;
	
	NSMutableData *receivedData;
}

#pragma mark - Properties
#pragma mark - Outlets - Labels
@property (nonatomic, weak) IBOutlet NSTextFieldCell *titleFieldCell;
@property (nonatomic, weak) IBOutlet NSTextFieldCell *currentVersionField;
@property (nonatomic, weak) IBOutlet NSTextFieldCell *helpFieldCell;
@property (nonatomic, weak) IBOutlet NSTextFieldCell *descriptionFieldCell;
@property (nonatomic, weak) IBOutlet NSTextFieldCell *authorFieldCell;

#pragma mark - Outlets - Labels - Sidebar
@property (nonatomic, weak) IBOutlet NSTextFieldCell *allItemsFieldCell;
@property (nonatomic, weak) IBOutlet NSTextFieldCell *selectedItemFieldCell;
@property (nonatomic, weak) IBOutlet NSTextFieldCell *databaseFieldCell;

#pragma mark - Outlets - Buttons
@property (nonatomic, weak) IBOutlet NSButton *updateButton;
@property (nonatomic, weak) IBOutlet NSButton *helpButton;
@property (nonatomic, weak) IBOutlet NSButton *tweetButton;
@property (nonatomic, weak) IBOutlet NSButton *donateButton;

@property (nonatomic, weak) IBOutlet NSButton *applyButton;

#pragma mark - Outlets - Sidebar-Buttons

#pragma mark All Items
@property (nonatomic, weak) IBOutlet NSButton *refreshButton;
@property (nonatomic, weak) IBOutlet NSButton *sortAllButton;

#pragma mark Selected Item
@property (nonatomic, weak) IBOutlet NSButton *renameItemButton;
@property (nonatomic, weak) IBOutlet NSButton *sortItemButton;

#pragma mark Database
@property (nonatomic, weak) IBOutlet NSButton *backupDatabaseButton;
@property (nonatomic, weak) IBOutlet NSButton *restoreDatabaseButton;
@property (nonatomic, weak) IBOutlet NSButton *resetDatabaseButton;

#pragma mark - Outlets - Other Views
@property (nonatomic, weak) IBOutlet NSOutlineView *outlineView;
@property (nonatomic, weak) IBOutlet SFAuthorizationView *authView;


#pragma mark - Methods

+(id)shared;

#pragma mark - Load
-(void)mainViewDidLoad;
-(void)loadPlist;
-(void)reload;
-(void)setupRights;
-(void)migrateFrom:(NSString *)version;

#pragma mark - Database
-(BOOL)openDatabase;
-(void)closeDatabase;

-(void)refreshDatabase;
-(void)removeDatabase;

-(void)setDatabaseVersion;
-(NSString *)getDatabaseVersion;

-(void)databaseIsCorrupt;

-(void)dropTriggers;
-(void)createTriggers;

-(BOOL)fetchItems;

-(void)executeSQL:(NSString *)sqlQuery;

#pragma mark - Item actions
-(void)setVisible:(BOOL)visible forItem:(Item *)item;
-(void)sortAllItems;
-(void)sortSelectedItem;
-(void)renameSelectedItem;

-(BOOL)addIgnoredBundle:(NSString *)bundleIdentifier;
-(BOOL)removeIgnoredBundle:(NSString *)bundleIdentifier;

#pragma mark - Actions
-(IBAction)buttonPressed:(id)sender;

#pragma mark - System Control
-(void)restartLaunchpad;
-(void)restartDock;
-(BOOL)movePlistWithRights;

@end
