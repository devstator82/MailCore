//
//  CTCoreHeader.h
//  MailCore
//
//  Created by Waseem Sadiq on 10/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTCoreFolder;

@interface CTCoreHeader : NSObject
{
    CTCoreFolder* folder;
    NSString* uid;
    NSString* gmail_id;
    NSString* gmail_thread_id;
    BOOL isRead;
    BOOL isStarred;    
}

@property (nonatomic, retain) CTCoreFolder *folder;
@property (nonatomic, retain) NSString *uid;
@property (nonatomic, retain) NSString *gmail_id;
@property (nonatomic, retain) NSString *gmail_thread_id;
@property (nonatomic, assign) BOOL isRead;
@property (nonatomic, assign) BOOL isStarred;

- (id)initWithString:(NSString*)data;

@end
