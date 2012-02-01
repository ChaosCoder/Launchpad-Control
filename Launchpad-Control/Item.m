//
//  Item.m
//  Launchpad-Control
//
//  Created by Andreas Ganske on 17.08.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import "Item.h"

@implementation Item

@synthesize identifier,name,parent=_parent,children,uuid,flags,type,ordering,visible,bundleIdentifier;

-(id)initWithID:(NSInteger)anIdentifier name:(NSString *)aName parent:(Item *)aParent uuid:(NSString *)anUUID flags:(Byte)aFlags type:(Byte)aType ordering:(NSInteger)anOrdering visible:(BOOL)isVisible
{
	if ( (self = [super init]) ) {
		self.identifier = anIdentifier;
		self.name = aName;
		self.parent = aParent;
		self.uuid = anUUID;
		self.flags = aFlags;
		self.type = aType;
		self.ordering = anOrdering;
		self.visible = isVisible;
		
		self.children = [NSMutableArray array];
	}
	return self;
}

-(void)addChild:(Item *)item
{
	[children addObject:item];
}

-(void)setParent:(Item *)aParent
{
	_parent = aParent;
	
	if (_parent)
		[_parent addChild:self];
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@",name];
}

@end
