//
//  CCUtils.h
//  CCLibrary
//
//  Created by Andreas Ganske on 01.02.12.
//  Copyright (c) 2012 Andreas Ganske. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CCLocalized( X ) (NSLocalizedStringFromTableInBundle(X, nil, [NSBundle bundleForClass:[self class]], nil))

@interface CCUtils : NSObject

#ifdef __PLATFORM_IOS
+(CGSize)screenSize:(UIInterfaceOrientation)interfaceOrientation;
#endif

+(void)setAssociatedObject:(id)objectA forObject:(id)objectB;
+(id)associatedObjectFor:(id)object;

@end
