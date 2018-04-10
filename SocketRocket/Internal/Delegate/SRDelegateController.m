//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRDelegateController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SRDelegateController ()

@property (nonatomic, strong, readonly) dispatch_queue_t accessQueue;

@property (atomic, assign, readwrite) SRDelegateAvailableMethods availableDelegateMethods;

@end

@implementation SRDelegateController

@synthesize delegate = _delegate;
@synthesize dispatchQueue = _dispatchQueue;
@synthesize operationQueue = _operationQueue;

///--------------------------------------
#pragma mark - Init
///--------------------------------------

- (instancetype)init
{
    self = [super init];
    if (!self) return self;

    _accessQueue = dispatch_queue_create("com.facebook.socketrocket.delegate.access", DISPATCH_QUEUE_CONCURRENT);
    _dispatchQueue = dispatch_get_main_queue();

    return self;
}

///--------------------------------------
#pragma mark - Accessors
///--------------------------------------

- (void)setDelegate:(id<SRWebSocketDelegate> _Nullable)delegate
{
    typeof(self) weak = self;
    dispatch_barrier_async(self.accessQueue, ^{
        weak->_delegate = delegate;

        weak.availableDelegateMethods = (SRDelegateAvailableMethods) {
            .didReceiveMessage = [delegate respondsToSelector:@selector(webSocket:didReceiveMessage:)],
            .didReceiveMessageWithString = [delegate respondsToSelector:@selector(webSocket:didReceiveMessageWithString:)],
            .didReceiveMessageWithData = [delegate respondsToSelector:@selector(webSocket:didReceiveMessageWithData:)],
            .didOpen = [delegate respondsToSelector:@selector(webSocketDidOpen:)],
            .didFailWithError = [delegate respondsToSelector:@selector(webSocket:didFailWithError:)],
            .didCloseWithCode = [delegate respondsToSelector:@selector(webSocket:didCloseWithCode:reason:wasClean:)],
            .didReceivePing = [delegate respondsToSelector:@selector(webSocket:didReceivePingWithData:)],
            .didReceivePong = [delegate respondsToSelector:@selector(webSocket:didReceivePong:)],
            .shouldConvertTextFrameToString = [delegate respondsToSelector:@selector(webSocketShouldConvertTextFrameToString:)]
        };
    });
}

- (id<SRWebSocketDelegate> _Nullable)delegate
{
    typeof(self) weak = self;
    __block id<SRWebSocketDelegate> delegate = nil;
    dispatch_sync(self.accessQueue, ^{
        delegate = weak->_delegate;
    });
    return delegate;
}

- (void)setDispatchQueue:(dispatch_queue_t _Nullable)queue
{
    typeof(self) weak = self;
    dispatch_barrier_async(self.accessQueue, ^{
        weak->_dispatchQueue = queue ?: dispatch_get_main_queue();
        weak->_operationQueue = nil;
    });
}

- (dispatch_queue_t _Nullable)dispatchQueue
{
    typeof(self) weak = self;
    __block dispatch_queue_t queue = nil;
    dispatch_sync(self.accessQueue, ^{
        queue = weak->_dispatchQueue;
    });
    return queue;
}

- (void)setOperationQueue:(NSOperationQueue *_Nullable)queue
{
    typeof(self) weak = self;
    dispatch_barrier_async(self.accessQueue, ^{
        weak->_dispatchQueue = queue ? nil : dispatch_get_main_queue();
        weak->_operationQueue = queue;
    });
}

- (NSOperationQueue *_Nullable)operationQueue
{
    typeof(self) weak = self;
    __block NSOperationQueue *queue = nil;
    dispatch_sync(self.accessQueue, ^{
        queue = weak->_operationQueue;
    });
    return queue;
}

///--------------------------------------
#pragma mark - Perform
///--------------------------------------

- (void)performDelegateBlock:(SRDelegateBlock)block
{
    typeof(self) weak = self;
    __block __strong id<SRWebSocketDelegate> delegate = nil;
    __block SRDelegateAvailableMethods availableMethods = {};
    dispatch_sync(self.accessQueue, ^{
        delegate = weak->_delegate; // Not `OK` to go through `self`, since queue sync.
        availableMethods = weak.availableDelegateMethods; // `OK` to call through `self`, since no queue sync.
    });
    [self performDelegateQueueBlock:^{
        block(delegate, availableMethods);
    }];
}

- (void)performDelegateQueueBlock:(dispatch_block_t)block
{
    dispatch_queue_t dispatchQueue = self.dispatchQueue;
    if (dispatchQueue) {
        dispatch_async(dispatchQueue, block);
    } else {
        [self.operationQueue addOperationWithBlock:block];
    }
}

@end

NS_ASSUME_NONNULL_END
