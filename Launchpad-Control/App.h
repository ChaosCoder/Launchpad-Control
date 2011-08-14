//
//  App.h
//  Launchpad-Control
//
//  Created by Andreas Ganske on 26.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface App : NSObject {
	NSInteger newIdentifier;
	NSInteger identifier;
	NSString *name;
	NSString *bundleID;
	NSInteger type;
}

-(id)initWithIdentifier:(NSInteger)_identifier andName:(NSString *)_name andBundleID:(NSString *)_bundleID type:(NSInteger)_type;

@property (nonatomic, assign) NSInteger newIdentifier;
@property (nonatomic, assign) NSInteger identifier;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *bundleID;
@property (nonatomic, assign) NSInteger type;

@end
