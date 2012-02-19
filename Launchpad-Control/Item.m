//
//  Item.m
//  Launchpad-Control
//
//  Created by Andreas Ganske on 17.08.11.
//  Copyright 2011 Andreas Ganske. All rights reserved.
//

#import "LaunchpadControl.h"
#import "Item.h"

@implementation Item

@synthesize identifier = _identifier;

@synthesize name = _name;
@synthesize parent = _parent;
@synthesize uuid = _uuid;
@synthesize flags = _flags;
@synthesize type = _type;
@synthesize ordering = _ordering;
@synthesize visible = _visible;
@synthesize bundleIdentifier = _bundleIdentifier;
@synthesize children;

int signum(int n) { return (n < 0) ? -1 : (n > 0) ? +1 : 0; }

-(id)initWithID:(NSInteger)anIdentifier name:(NSString *)aName parent:(Item *)aParent uuid:(NSString *)anUUID flags:(Byte)aFlags type:(Byte)aType ordering:(NSInteger)anOrdering visible:(BOOL)isVisible
{
	if ( (self = [super init]) ) 
	{
		self.identifier = anIdentifier;
		self.ordering = anOrdering;
		self.name = aName;
		self.uuid = anUUID;
		self.flags = aFlags;
		self.type = aType;
		self.visible = isVisible;
		
		self.children = [[NSMutableArray alloc] init];
		self.parent = aParent;
	}
	
	return self;
}

-(void)setName:(NSString *)aName
{
	[self setName:aName updateDatabase:NO];
}

-(void)setName:(NSString *)aName updateDatabase:(BOOL)updateDatabase
{
	_name = [aName retain];
	
	if (updateDatabase) {
		NSString *sqlString = nil;
		if (_type == kItemApp) {
			sqlString = [NSString stringWithFormat:@"UPDATE apps SET title='%@' WHERE item_id=%i",_name,_identifier];
		}else if(_type == kItemGroup) {
			sqlString = [NSString stringWithFormat:@"UPDATE groups SET title='%@' WHERE item_id=%i",_name,_identifier];
		}
		
		if (sqlString)
			[[LaunchpadControl shared] executeSQL:sqlString];
	}
}

-(void)setVisible:(BOOL)isVisible
{
	[self setVisible:isVisible updateDatabase:NO];
}

-(BOOL)setVisible:(BOOL)isVisible updateDatabase:(BOOL)updateDatabase
{
	if (updateDatabase) {
		bool success;
		if (isVisible) {
			success = [[LaunchpadControl shared] removeIgnoredBundle:_bundleIdentifier];
		}else{
			success = [[LaunchpadControl shared] addIgnoredBundle:_bundleIdentifier];
		}
		
		if (success) {
			NSString *sqlQuery = [NSString stringWithFormat:@"UPDATE items SET rowid = %i WHERE ABS(rowid) = %i", _identifier * (isVisible ? 1 : -1), _identifier];
			[[LaunchpadControl shared] executeSQL:sqlQuery];
			
			_visible = isVisible;
		}
		
		return success;
	}else{
		_visible = isVisible;
	}
	
	return true;
}
	
-(void)setOrdering:(NSInteger)anOrdering
{
	[self setOrdering:anOrdering updateDatabase:NO];
}

-(void)setOrdering:(NSInteger)anOrdering updateDatabase:(BOOL)updateDatabase
{
	_ordering = anOrdering;
	
	if (updateDatabase) {
		NSString *sqlQuery = [NSString stringWithFormat:@"UPDATE items SET ordering = %i WHERE ABS(rowid) = %i;", self.ordering, self.identifier];
		[[LaunchpadControl shared] executeSQL:sqlQuery];
	}
}

-(void)setParent:(Item *)aParent
{
	[self setParent:aParent updateDatabase:NO];
}

-(void)setParent:(Item *)aParent updateDatabase:(BOOL)updateDatabase
{
	if (aParent == _parent)
		return;
	
	if (_parent)
		[_parent removeChild:self];
	
	[_parent release];
	
	if (aParent) {
		_parent = [aParent retain];
		[_parent addChild:self];
		
		if (updateDatabase) {
			NSString *sqlQuery = [NSString stringWithFormat:@"UPDATE items SET parent_id = %i WHERE ABS(rowid) = %i;", [self.parent identifier], self.identifier];
			[[LaunchpadControl shared] executeSQL:sqlQuery];
		}
	}
}

-(void)updateChildren
{
	NSSortDescriptor* sortOrder = [NSSortDescriptor sortDescriptorWithKey:@"ordering" ascending:YES];
	[self.children sortUsingDescriptors:[NSArray arrayWithObject: sortOrder]];
}

-(void)sortChildrenAlphabetically:(BOOL)recursive
{
	if ([children count]>0) {
		NSSortDescriptor* sortOrder = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)] autorelease];
		[self.children sortUsingDescriptors:[NSArray arrayWithObject: sortOrder]];
		
		int i = 0;
		for (Item *child in children) 
		{
			[child setOrdering:i updateDatabase:YES];
			i++;
			
			if (recursive)
				[child sortChildrenAlphabetically:recursive];
		}
	}
}

-(void)addChild:(Item *)item
{
	[children addObject:item];
}

-(void)removeChild:(Item *)item
{
	[children removeObject:item];
}

-(NSString *)description
{
	return self.name;
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeInt64:_identifier forKey:@"identifier"];
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
	if ( (self = [super init]) ) {
		self.identifier = [aDecoder decodeInt64ForKey:@"identifier"];
	}
	
	return self;
}

@end
