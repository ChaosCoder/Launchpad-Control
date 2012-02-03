//
//  Item.h
//  Launchpad-Control
//
//  Created by Andreas Ganske on 17.08.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Item : NSObject <NSCoding> {
	NSInteger identifier;
	NSString *name;
	Item *parent;
	
	NSMutableArray *children;
	
	NSString *uuid;
	NSInteger flags;
	NSInteger type;
	NSInteger ordering;
	BOOL visible;
}

-(id)initWithID:(NSInteger)anIdentifier name:(NSString *)aName parent:(Item *)aParent uuid:(NSString *)anUUID flags:(Byte)aFlags type:(Byte)aType ordering:(NSInteger)anOrdering visible:(BOOL)isVisible;
-(void)addChild:(Item *)item;
-(BOOL)isVisible;

@property (nonatomic) NSInteger identifier;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) Item *parent;
@property (nonatomic, retain) NSMutableArray *children;
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic) NSInteger flags;
@property (nonatomic) NSInteger type;
@property (nonatomic) NSInteger ordering;
@property (nonatomic) BOOL visible;

@property (nonatomic) BOOL newOrder;
@property (nonatomic) BOOL newParent;

@property (nonatomic, retain) NSString *bundleIdentifier;

@end
