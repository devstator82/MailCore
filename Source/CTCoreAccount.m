/*
 * MailCore
 *
 * Copyright (C) 2007 - Matt Ronge
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the MailCore project nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#import "CTCoreAccount.h"
#import "CTCoreFolder.h"
#import "MailCoreTypes.h"

@interface CTCoreAccount (Private)
@end


@implementation CTCoreAccount

@synthesize accountType;

- (id)init {
	self = [super init];
	if (self) {
		connected = NO;
		myStorage = mailstorage_new(NULL);
		assert(myStorage != NULL);	
	}
	return self;
}


- (void)dealloc {
	mailstorage_disconnect(myStorage);
	mailstorage_free(myStorage);
	[super dealloc]; 
}


- (BOOL)isConnected {
	return connected;
}


//TODO, should I use the cache?
- (void)connectToServer:(NSString *)server port:(int)port 
		connectionType:(int)conType authType:(int)authType
		accountType:(CTCoreAccountType)accType
		login:(NSString *)login password:(NSString *)password {
	int err = 0;
	int cached = 0;
	const char* auth_type_to_pass = NULL;
    accountType = accType;
    

	
	if (accType == CT_CORE_ACCOUNT_IMAP) {
	    if(authType == IMAP_AUTH_TYPE_SASL_CRAM_MD5) {
		    auth_type_to_pass = "CRAM-MD5";
	    }
	
	    err = imap_mailstorage_init_sasl(myStorage,
									 (char *)[server cStringUsingEncoding:NSUTF8StringEncoding],
									 (uint16_t)port, NULL,
									 conType,
									 auth_type_to_pass,
									 NULL,
									 NULL, NULL,
									 (char *)[login cStringUsingEncoding:NSUTF8StringEncoding], (char *)[login cStringUsingEncoding:NSUTF8StringEncoding],
									 (char *)[password cStringUsingEncoding:NSUTF8StringEncoding], NULL,
									 cached, NULL);
	} else if (accType == CT_CORE_ACCOUNT_POP3) {
	    err = pop3_mailstorage_init_sasl(myStorage,
                                         (char *)[server cStringUsingEncoding:NSUTF8StringEncoding],
                                         (uint16_t)port, NULL, conType, auth_type_to_pass,
                                         NULL, NULL, NULL,
                                         (char *)[login cStringUsingEncoding:NSUTF8StringEncoding], (char *)[login cStringUsingEncoding:NSUTF8StringEncoding],
                                         (char *)[password cStringUsingEncoding:NSUTF8StringEncoding], NULL,
                                         cached, NULL, NULL);
    } else {
		NSException *exception = [NSException exceptionWithName:CTUnknownError
                                              reason:[NSString stringWithFormat:@"Invalid account type: %d", accType]
                                              userInfo:nil];
		[exception raise];
    }
		    
	if (err != MAIL_NO_ERROR) {
		NSException *exception = [NSException
		        exceptionWithName:CTMemoryError
		        reason:CTMemoryErrorDesc
		        userInfo:nil];
		[exception raise];
	}
						
	err = mailstorage_connect(myStorage);
	if (err == MAIL_ERROR_LOGIN) {
		NSException *exception = [NSException
		        exceptionWithName:CTLoginError
		        reason:CTLoginErrorDesc
		        userInfo:nil];
		[exception raise];
	}
	else if (err != MAIL_NO_ERROR) {
		NSException *exception = [NSException
		        exceptionWithName:CTUnknownError
		        reason:[NSString stringWithFormat:@"Error number: %d",err]
		        userInfo:nil];
		[exception raise];
	}
	else	
		connected = YES;
}

- (void)idle {
    int err = mailimap_idle([self session]);
    
    if (err != 0) {
		NSException *exception = [NSException
                                  exceptionWithName:CTUnknownError
                                  reason:[NSString stringWithFormat:@"Error number: %d", err]
                                  userInfo:nil];
		[exception raise];
    }
}

- (NSString*)read {
    char * buf = mailimap_read_line([self session]);
    
    if (buf == NULL) {
        return nil;
    }
    
    return [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
}

- (void)done {
    int r = mailimap_token_send([self session]->imap_stream, "DONE");
    if (r != MAILIMAP_NO_ERROR)
        return;
    
    r = mailimap_crlf_send([self session]->imap_stream);
    if (r != MAILIMAP_NO_ERROR)
        return;
    
    r = (mailstream_flush([self session]->imap_stream));
    
    if (r != 0) {
		NSException *exception = [NSException
                                  exceptionWithName:CTUnknownError
                                  reason:[NSString stringWithFormat:@"Error number: %d", r]
                                  userInfo:nil];
		[exception raise];
    }
}

- (void)disconnect {
	connected = NO;
	mailstorage_disconnect(myStorage);
}

- (CTCoreFolder *)folderWithPath:(NSString *)path {
	CTCoreFolder *folder = [[CTCoreFolder alloc] initWithPath:path inAccount:self];
	return [folder autorelease];
}


- (mailimap *)session {
    if (accountType == CT_CORE_ACCOUNT_POP3) {
        return nil;
    }
    
	struct imap_cached_session_state_data * cached_data;
	struct imap_session_state_data * data;
	mailsession *session;
   
	session = myStorage->sto_session;
	if(session == nil) {
		return nil;
	}
	if (strcasecmp(session->sess_driver->sess_name, "imap-cached") == 0) {
    	cached_data = session->sess_data;
    	session = cached_data->imap_ancestor;
  	}

	data = session->sess_data;
	return data->imap_session;
}


- (struct mailstorage *)storageStruct {
	return myStorage;
}


- (NSSet *)subscribedFolders {
    if (accountType == CT_CORE_ACCOUNT_POP3) {
        return [self allFolders];
    }
    
	struct mailimap_mailbox_list * mailboxStruct;
	clist *subscribedList;
	clistiter *cur;
	
	NSString *mailboxNameObject;
	char *mailboxName;
	int err;
	
	NSMutableSet *subscribedFolders = [NSMutableSet set];	
	
	//Fill the subscribed folder array
	err = mailimap_lsub([self session], "", "*", &subscribedList);
	if (err != MAIL_NO_ERROR) {
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",err]
			        userInfo:nil];
		[exception raise];
	}
	else if (clist_isempty(subscribedList)) {
		NSException *exception = [NSException
			        exceptionWithName:CTNoSubscribedFolders
			        reason:CTNoSubscribedFoldersDesc
			        userInfo:nil];
		[exception raise];
	}
	for(cur = clist_begin(subscribedList); cur != NULL; cur = cur->next) {
		mailboxStruct = cur->data;
		mailboxName = mailboxStruct->mb_name;
		mailboxNameObject = [NSString stringWithCString:mailboxName encoding:NSUTF8StringEncoding];
		[subscribedFolders addObject:mailboxNameObject];
	}
	mailimap_list_result_free(subscribedList);
	return subscribedFolders;
}

- (NSSet *)allFolders {
    if (accountType == CT_CORE_ACCOUNT_POP3) {
        NSSet* result = [NSSet setWithObjects:@"INBOX", nil];
        return result;
    }
    
	struct mailimap_mailbox_list * mailboxStruct;
    struct mailimap_mbx_list_flags * mailboxFlagsStruct;
    struct mailimap_mbx_list_oflag * mailboxFlagStruct;
    
	clist *allList;
	clistiter *cur;
    clistiter *cur2;
	
	NSString *mailboxNameObject;
	char *mailboxName;
	int err;
	
	NSMutableSet *allFolders = [NSMutableSet set];

	//Now, fill the all folders array
	//TODO Fix this so it doesn't use *
	err = mailimap_xlist([self session], "", "*", &allList);		
	if (err != MAIL_NO_ERROR)
	{
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",err]
			        userInfo:nil];
		[exception raise];
	}
	else if (clist_isempty(allList))
	{
		NSException *exception = [NSException
			        exceptionWithName:CTNoFolders
			        reason:CTNoFoldersDesc
			        userInfo:nil];
		[exception raise];
	}
	for(cur = clist_begin(allList); cur != NULL; cur = cur->next)
	{
		mailboxStruct = cur->data;
		mailboxName = mailboxStruct->mb_name;
        mailboxFlagsStruct = mailboxStruct->mb_flag;
        
        NSString* flagName = nil;
        
        if (!clist_isempty(mailboxFlagsStruct->mbf_oflags))
        {
           for(cur2 = clist_begin(mailboxFlagsStruct->mbf_oflags); cur2 != NULL; cur2 = cur2->next) 
           {
               mailboxFlagStruct = cur2->data;
               flagName = [NSString stringWithCString:mailboxFlagStruct->of_flag_ext encoding:NSUTF8StringEncoding];
               
               if ([flagName isEqualToString:@"HasNoChildren"] || [flagName isEqualToString:@"HasChildren"])
               {
                   flagName = nil;
               }
           }
        }
        
        // GMail doesn't allow selecting the localized inbox folder
		mailboxNameObject = [flagName isEqualToString:@"Inbox"] ? @"INBOX" : [NSString stringWithCString:mailboxName encoding:NSUTF8StringEncoding];

        // Folders marked with /NoSelect have mbf_type 0, so ignore those (for ex. the root [GMail] virtual folder)
        if (mailboxFlagsStruct->mbf_type != 0)
        {
            CTCoreFolder* folder = [[CTCoreFolder alloc] initWithPath:mailboxNameObject inAccount:self withType:flagName];
            
            [allFolders addObject:folder];
        }
	}
	mailimap_list_result_free(allList);
	return allFolders;
}
@end
