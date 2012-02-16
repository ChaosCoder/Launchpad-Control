//
//  Item.h
//  Launchpad-Control
//
//  Created by Andreas Ganske on 17.08.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import <Foundation/Foundation.h>

enum kItemType {
	kItemRoot = 1,
	kItemGroup = 2,
	kItemPage = 3,
	kItemApp = 4
};

int signum(int n);

@interface Item : NSObject <NSCoding>

#pragma mark - Attributes

@property (nonatomic) NSInteger identifier;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) Item *parent;
@property (nonatomic, retain) NSMutableArray *children;
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic) Byte flags;
@property (nonatomic) Byte type;
@property (nonatomic) NSInteger ordering;
@property (nonatomic) BOOL visible;

@property (nonatomic, retain) NSString *bundleIdentifier;

#pragma mark - Methods

-(id)initWithID:(NSInteger)anIdentifier name:(NSString *)aName parent:(Item *)aParent uuid:(NSString *)anUUID flags:(Byte)aFlags type:(Byte)aType ordering:(NSInteger)anOrdering visible:(BOOL)isVisible;

-(void)setName:(NSString *)aName updateDatabase:(BOOL)updateDatabase;
-(BOOL)setVisible:(BOOL)visible updateDatabase:(BOOL)updateDatabase;
-(void)setOrdering:(NSInteger)ordering updateDatabase:(BOOL)updateDatabase;
-(void)setParent:(Item *)parent updateDatabase:(BOOL)updateDatabase;

-(void)addChild:(Item *)item;
-(void)removeChild:(Item *)item;
-(void)updateChildren;
-(void)sortChildrenAlphabetically:(BOOL)recursive;

@end
