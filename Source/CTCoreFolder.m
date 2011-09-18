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

#import "CTCoreFolder.h"
#import <libetpan/libetpan.h>
#import "CTCoreMessage.h"
#import "CTCoreAccount.h"
#import "MailCoreTypes.h"
#import "CTBareMessage.h"

@interface CTCoreFolder (Private)
@end
	
@implementation CTCoreFolder
- (id)initWithPath:(NSString *)path inAccount:(CTCoreAccount *)account; {
	struct mailstorage *storage = (struct mailstorage *)[account storageStruct];
	self = [super init];
	if (self)
	{
		myPath = [path retain];
		connected = NO;
		myAccount = [account retain];
		myFolder = mailfolder_new(storage, (char *)[myPath cStringUsingEncoding:NSUTF8StringEncoding], NULL);	
		assert(myFolder != NULL);
	}
	return self;
}

- (id)initWithPath:(NSString *)path inAccount:(CTCoreAccount *)account withType:(NSString*)folderType
{
    self = [self initWithPath:path inAccount:account];
    
    if (self)
    {
        myFolderType = folderType;
    }
    return self;
}


- (void)dealloc {	
	if (connected)
		[self disconnect];
		
	mailfolder_free(myFolder);
	[myAccount release];
	[myPath release];
	[super dealloc];
}


- (void)connect {
	int err = MAIL_NO_ERROR;
	err =  mailfolder_connect(myFolder);
	IfTrue_RaiseException(err != MAILIMAP_NO_ERROR, CTUnknownError, 
		[NSString stringWithFormat:@"Error number: %d",err]);	
	connected = YES;
}


- (void)disconnect {
	if(connected)
		mailfolder_disconnect(myFolder);
}

- (struct mailfolder *)folderStruct {
	return myFolder;
}

- (NSSet *)messageObjectsFromIndex:(unsigned int)start toIndex:(unsigned int)end {
    NSMutableSet *messages = [NSMutableSet set];
	[self connect];
	
    if (myAccount.accountType == CT_CORE_ACCOUNT_IMAP) {
	struct mailmessage_list * env_list;
	int r;
	struct mailimap_fetch_att * fetch_att;
	struct mailimap_fetch_type * fetch_type;
	struct mailimap_set * set;
	clist * fetch_result;

	set = mailimap_set_new_interval(start, end);
	if (set == NULL) 
		return nil;

	fetch_type = mailimap_fetch_type_new_fetch_att_list_empty();
	fetch_att = mailimap_fetch_att_new_uid();
	r = mailimap_fetch_type_new_fetch_att_list_add(fetch_type, fetch_att);
	if (r != MAILIMAP_NO_ERROR) {
		mailimap_fetch_att_free(fetch_att);
		return nil;
	}

	fetch_att = mailimap_fetch_att_new_rfc822_size();
	if (fetch_att == NULL) {
		mailimap_fetch_type_free(fetch_type);
		return nil;
	}

	r = mailimap_fetch_type_new_fetch_att_list_add(fetch_type, fetch_att);
	if (r != MAILIMAP_NO_ERROR) {
		mailimap_fetch_att_free(fetch_att);
		mailimap_fetch_type_free(fetch_type);
		return nil;
	}
    
    fetch_att = mailimap_fetch_att_new_gmail_message_id();
    if (fetch_att == NULL) {
        mailimap_fetch_type_free(fetch_type);
        return nil;
    }
    
    r = mailimap_fetch_type_new_fetch_att_list_add(fetch_type, fetch_att);
    if (r != MAILIMAP_NO_ERROR) {
        mailimap_fetch_att_free(fetch_att);
        mailimap_fetch_type_free(fetch_type);
        return nil;
    }
        
    fetch_att = mailimap_fetch_att_new_gmail_thread_id();
    if (fetch_att == NULL) {
        mailimap_fetch_type_free(fetch_type);
        return nil;
    }
    
    r = mailimap_fetch_type_new_fetch_att_list_add(fetch_type, fetch_att);
    if (r != MAILIMAP_NO_ERROR) {
        mailimap_fetch_att_free(fetch_att);
        mailimap_fetch_type_free(fetch_type);
        return nil;
    }
        
	r = mailimap_fetch([self imapSession], set, fetch_type, &fetch_result);
	if (r != MAIL_NO_ERROR) {
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",r]
			        userInfo:nil];
		[exception raise];
	}

	mailimap_fetch_type_free(fetch_type);
	mailimap_set_free(set);

	if (r != MAILIMAP_NO_ERROR) 
		return nil; //Add exception

	env_list = NULL;
	r = uid_list_to_env_list(fetch_result, &env_list, [self folderSession], imap_message_driver);
	r = mailfolder_get_envelopes_list(myFolder, env_list);
	if (r != MAIL_NO_ERROR) {
		if ( env_list != NULL )
			mailmessage_list_free(env_list);
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",r]
			        userInfo:nil];
		[exception raise];
	}
	
	int len = carray_count(env_list->msg_tab);
	int i;
	CTCoreMessage *msgObject;
	struct mailmessage *msg;
	clistiter *fetchResultIter = clist_begin(fetch_result);
	for(i=0; i<len; i++) {
		msg = carray_get(env_list->msg_tab, i);
		msgObject = [[CTCoreMessage alloc] initWithMessageStruct:msg];
        msgObject.folder = self;
		struct mailimap_msg_att *msg_att = (struct mailimap_msg_att *)clist_content(fetchResultIter);
		if(msg_att != nil) {
			[msgObject setSequenceNumber:msg_att->att_number];
			[messages addObject:msgObject];
		}
		[msgObject release];
		fetchResultIter = clist_next(fetchResultIter);
	}
	if ( env_list != NULL ) {
		//I am only freeing the message array because the messages themselves are in use
		carray_free(env_list->msg_tab); 
		free(env_list);
	}
	mailimap_fetch_list_free(fetch_result);	
	
	
	} else if (myAccount.accountType == CT_CORE_ACCOUNT_POP3) {
	    
        CTCoreMessage* message;
        struct mailmessage* msg;
        int err;
        size_t i;

        // Get CTCoreMessage objects from the given message numbers
        for (i = start; i <= end; ++i) {
            err = mailfolder_get_message(myFolder, i, &msg);
            if (err != MAIL_NO_ERROR) {
                NSException *exception = [NSException exceptionWithName:CTUnknownError
                                                      reason:[NSString stringWithFormat:@"Error number: %d", err]
                                                      userInfo:nil];
                [exception raise];
            }

            // Note that all we get are the fields, flags aren't supported by the libetpan POP3 driver
            err = mailmessage_fetch_envelope(msg, &(msg->msg_fields));
            if (err != MAIL_NO_ERROR) {
                NSException *exception = [NSException exceptionWithName:CTUnknownError
                                                      reason:[NSString stringWithFormat:@"Error number: %d", err]
                                                      userInfo:nil];
                [exception raise];
            }

            message = [[CTCoreMessage alloc] initWithMessageStruct:msg];
            message.folder = self;
            [message setSequenceNumber:i];
            [messages addObject:message];
            [message release];
        }
    }
    
	return messages;
}


- (CTCoreMessage *)messageWithUID:(NSString *)uid {
	int err;
	struct mailmessage *msgStruct;
	
	[self connect];
	err = mailfolder_get_message_by_uid([self folderStruct], [uid cStringUsingEncoding:NSUTF8StringEncoding], &msgStruct);
	if (err == MAIL_ERROR_MSG_NOT_FOUND) {
		return nil;
	}
	else if (err != MAIL_NO_ERROR) {
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",err]
			        userInfo:nil];
		[exception raise];
	}
	err = mailmessage_fetch_envelope(msgStruct,&(msgStruct->msg_fields));
	if (err != MAIL_NO_ERROR) {
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",err]
			        userInfo:nil];
		[exception raise];
	}
	
	//TODO Fix me, i'm missing alot of things that aren't being downloaded, 
	// I just hacked this in here for the mean time
	if (myAccount.accountType == CT_CORE_ACCOUNT_IMAP) {
	// Only IMAP supports flags, not POP
	err = mailmessage_get_flags(msgStruct, &(msgStruct->msg_flags));
	if (err != MAIL_NO_ERROR) {
		NSException *exception = [NSException
			        exceptionWithName:CTUnknownError
			        reason:[NSString stringWithFormat:@"Error number: %d",err]
			        userInfo:nil];
		[exception raise];
	}
    }
    
	CTCoreMessage* message = [[[CTCoreMessage alloc] initWithMessageStruct:msgStruct] autorelease];
    message.folder = self;    
    
    return message;    
}

- (NSUInteger)totalMessageCount {
	[self connect];			
	
	if (myAccount.accountType == CT_CORE_ACCOUNT_IMAP) {
	    return [self imapSession]->imap_selection_info->sel_exists;
    } else if (myAccount.accountType == CT_CORE_ACCOUNT_POP3) {
        unsigned int messageCount = 0;
        unsigned int junk;
        int err;
	
        err =  mailfolder_status(myFolder, &messageCount, &junk, &junk);
        IfTrue_RaiseException(err != MAILIMAP_NO_ERROR, CTUnknownError, 
                              [NSString stringWithFormat:@"Error number: %d", err]);
        return messageCount;
    } else {
        return 0;
    }
}

- (NSString*)path
{
    return myPath;
}

- (NSString*)folderType
{
    return myFolderType;
}


- (mailsession *)folderSession; {
	return myFolder->fld_session;
}


- (mailimap *)imapSession; {
	struct imap_cached_session_state_data * cached_data;
	struct imap_session_state_data * data;
	mailsession *session;
   
	session = [self folderSession];
	if (strcasecmp(session->sess_driver->sess_name, "imap-cached") == 0) {
    	cached_data = session->sess_data;
    	session = cached_data->imap_ancestor;
  	}

	data = session->sess_data;
	return data->imap_session;	
}

/* 
 From Libetpan source
 Waseem: updated to add gmail specific stuff
 */
int uid_list_to_env_list(clist * fetch_result, struct mailmessage_list ** result, 
						mailsession * session, mailmessage_driver * driver) {
	clistiter * cur;
	struct mailmessage_list * env_list;
	int r;
	int res;
	carray * tab;
	unsigned int i;
	mailmessage * msg;

	tab = carray_new(128);
	if (tab == NULL) {
		res = MAIL_ERROR_MEMORY;
		goto err;
	}

	for(cur = clist_begin(fetch_result); cur != NULL; cur = clist_next(cur)) {
		struct mailimap_msg_att * msg_att;
		clistiter * item_cur;
		uint32_t uid;
		size_t size;
        char * gm_msgid;
        char * gm_thrid;

		msg_att = clist_content(cur);
		uid = 0;
		size = 0;
		for(item_cur = clist_begin(msg_att->att_list); item_cur != NULL; item_cur = clist_next(item_cur)) {
			struct mailimap_msg_att_item * item;

			item = clist_content(item_cur);
			switch (item->att_type) {
				case MAILIMAP_MSG_ATT_ITEM_STATIC:
				switch (item->att_data.att_static->att_type) {
					case MAILIMAP_MSG_ATT_UID:
						uid = item->att_data.att_static->att_data.att_uid;
                        break;

					case MAILIMAP_MSG_ATT_RFC822_SIZE:
						size = item->att_data.att_static->att_data.att_rfc822_size;
                        break;
                    
                    case MAILIMAP_MSG_ATT_GM_MSGID:
                        gm_msgid = item->att_data.att_static->att_data.att_gm_msgid;
                        break;
                        
                    case MAILIMAP_MSG_ATT_GM_THRID:
                        gm_thrid = item->att_data.att_static->att_data.att_gm_thrid;
                        break;
				}
				break;
			}
		}

		msg = mailmessage_new();
		if (msg == NULL) {
			res = MAIL_ERROR_MEMORY;
			goto free_list;
		}

		r = mailmessage_init(msg, session, driver, uid, size);
		if (r != MAIL_NO_ERROR) {
			res = r;
			goto free_msg;
		}
        
        msg->gm_msgid = gm_msgid;
        msg->gm_thrid = gm_thrid;

		r = carray_add(tab, msg, NULL);
		if (r < 0) {
			res = MAIL_ERROR_MEMORY;
			goto free_msg;
		}
	}

	env_list = mailmessage_list_new(tab);
	if (env_list == NULL) {
		res = MAIL_ERROR_MEMORY;
		goto free_list;
	}

	* result = env_list;

	return MAIL_NO_ERROR;

	free_msg:
		mailmessage_free(msg);
	free_list:
		for(i = 0 ; i < carray_count(tab) ; i++)
		mailmessage_free(carray_get(tab, i));
	err:
		return res;
}
@end
