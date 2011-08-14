//
//  App.m
//  Launchpad-Control
//
//  Created by Andreas Ganske on 26.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "App.h"

@implementation App

@synthesize identifier, newIdentifier, name, bundleID, type;

-(id)initWithIdentifier:(NSInteger)_identifier andName:(NSString *)_name andBundleID:(NSString *)_bundleID type:(NSInteger)_type
{
	self = [super init];
    if (self) {
        self.identifier = _identifier;
		self.newIdentifier = identifier;
		self.name = _name;
		self.bundleID = _bundleID;
		self.type = _type;
    }
    
    return self;
}

@end
