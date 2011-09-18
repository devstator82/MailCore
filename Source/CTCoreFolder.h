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

#import <Foundation/Foundation.h>
#import <libetpan/libetpan.h>

/*!
	@class	CTCoreFolder
	CTCoreFolder is the class used to get and set attributes for a server side folder. It is also the
	class used to get a list of messages from the server. You need to make sure and establish a connection
	first by calling connect. All methods throw an exceptions on failure.
*/

@class CTCoreMessage, CTCoreAccount;

@interface CTCoreFolder : NSObject {
	struct mailfolder *myFolder;
	CTCoreAccount *myAccount;
	NSString *myPath;
    NSString *myFolderType;
	BOOL connected;
}

/*!
	@abstract	This method is used to initialize a folder. This method or the 
				method in CTCoreAccount folderWithPath can be used to setup a folder.
	@param		inAccount This parameter must be passed in so the folder can initiate it's connection.
*/
- (id)initWithPath:(NSString *)path inAccount:(CTCoreAccount *)account;

/*!
    @abstract	This method is used to initialize a folder. This method or the 
                method in CTCoreAccount folderWithPath can be used to setup a folder.
    @param		inAccount This parameter must be passed in so the folder can initiate it's connection.
    @param      withType The folder type as returned by the imap xlist command.
 */
- (id)initWithPath:(NSString *)path inAccount:(CTCoreAccount *)account withType:(NSString*)folderType;

/*!
	@abstract	This initiates the connection after the folder has been initalized.
*/
- (void)connect;

/*!
	@abstract	This method terminates the connection, make sure you don't have any message
				connections open from this folder before disconnecting.
*/
- (void)disconnect;

/*
	Implementation is in alpha.
*/
//TODO Document Me!
- (NSSet *)messageObjectsFromIndex:(unsigned int)start toIndex:(unsigned int)end;

/*!
	@abstract	This will return the message from this folder with the UID that was passed in. If the message
				can't be found, nil is returned
	@param		uid The uid as an NSString for the message to retrieve.
	@result		A CTMessage object is returned which can be used to get further information and perform operations
				on the message.
*/
- (CTCoreMessage *)messageWithUID:(NSString *)uid;

/*!
	@abstract	Returns the number of messages in the folder. The count was retrieved when the folder connection was
				established, so to refresh the count you must disconnect and reconnect.
	@result		A NSUInteger containing the number of messages.
*/
- (NSUInteger)totalMessageCount;

/*!
 @abstract	Returns the path for the folder
 @result	A NSString containing the folder-path
 */
- (NSString*)path;

/*!
 @abstract	Returns the type of the folder as indicated by the xlist command's response, returns nil if type is not available
 @result	A NSString containing the folder-type, possible values are Inbox, AllMail, Important, Drafts, Starred, Trash, Spam, Sent
            or nil if the type was not available.
 */
- (NSString*)folderType;

/* Intended for advanced use only */
- (struct mailfolder *)folderStruct;
- (mailsession *)folderSession;
- (mailimap *)imapSession;
@end
