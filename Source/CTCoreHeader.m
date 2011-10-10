//
//  CTCoreHeader.m
//  MailCore
//
//  Created by Waseem Sadiq on 10/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CTCoreHeader.h"

@implementation CTCoreHeader

@synthesize folder;
@synthesize uid;
@synthesize gmail_id;
@synthesize gmail_thread_id;
@synthesize isRead;
@synthesize isStarred;

- (id)initWithString:(NSString*)data
{
    if ((self = [super init]))
    {
        NSString* token;
        int fieldCount = 0;
        
        NSScanner* scanner = [NSScanner scannerWithString:data];
        [scanner scanUpToString:@" (" intoString:&token];
        [scanner setScanLocation:scanner.scanLocation +2];
        
        while (fieldCount < 4) {
            [scanner scanUpToString:@" " intoString:&token];
            
            if ([token isEqualToString:@"X-GM-THRID"]) {
                [scanner scanUpToString:@" " intoString:&token];
                self.gmail_thread_id = token;
                fieldCount++;
            }
            else if ([token isEqualToString:@"X-GM-MSGID"]) {
                [scanner scanUpToString:@" " intoString:&token];
                self.gmail_id = token;
                fieldCount++;
            }
            else if ([token isEqualToString:@"UID"]) {
                [scanner scanUpToString:@" " intoString:&token];
                self.uid = token;
                fieldCount++;
            }
            else if ([token isEqualToString:@"FLAGS"]) {
                [scanner scanUpToString:@"(" intoString:&token];
                [scanner scanUpToString:@")" intoString:&token];
                
                token = [token lowercaseString];

                if ([token rangeOfString:@"seen"].location != NSNotFound)
                    self.isRead = YES;
                
                if ([token rangeOfString:@"flagged"].location != NSNotFound)
                    self.isStarred = YES;
                
                fieldCount++;
            }
        }
    }
    
    return self;
}

- (void)dealloc
{
    [folder release];
    [uid release];
    [gmail_id release];
    [gmail_thread_id release];
    
    [super dealloc];
}

@end
