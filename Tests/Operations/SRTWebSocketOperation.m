//
// Copyright 2012 Square Inc.
// Portions Copyright (c) 2016-present, Facebook, Inc.
//
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRTWebSocketOperation.h"

#import "SRAutobahnUtilities.h"

@interface SRTWebSocketOperation () <SRWebSocketDelegate>
@property (nonatomic, assign) NSInteger testNumber;
@property (nonatomic, strong) SRWebSocket *webSocket;
@property (nonatomic, copy) NSURL *url;
@end

@implementation SRTWebSocketOperation

- (instancetype)initWithURL:(NSURL *)URL
{
    self = [super init];
    if (self) {
        _url = URL;
        _isExecuting = NO;
        _isFinished = NO;
    }
    
    return self;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)start
{
    self.isExecuting = YES;
    
    typeof(self) weak = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        weak.webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:weak.url]];
        weak.webSocket.delegate = self;
        [weak.webSocket open];
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = YES;
    _isExecuting = NO;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    _webSocket.delegate = nil;
    _webSocket = nil;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    _error = error;
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = YES;
    _isExecuting = NO;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    _webSocket.delegate = nil;
    _webSocket = nil;
}

- (BOOL)waitUntilFinishedWithTimeout:(NSTimeInterval)timeout
{
    if (self.isFinished) {
        return YES;
    }
    
    __weak typeof(self) weak = self;
    return SRRunLoopRunUntil(^BOOL{
        return weak.isFinished;
    }, timeout);
}

@end
