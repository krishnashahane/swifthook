//
//  SHKSuperForwarder.h
//  SwiftHook
//
//  Created by Krishna.
//

#if __APPLE__
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 Injects a super-forwarding stub into a runtime-generated subclass.

 Given a class that does NOT override `selector`, this creates a tiny
 implementation that simply calls `[super selector]` with all arguments
 forwarded via inline assembly (arm64 / x86_64).

 This lets SwiftHook's per-object patches always use `class_replaceMethod`
 (which requires an existing entry) instead of mixing `class_addMethod`
 and `class_replaceMethod` code paths.
 */
@interface SuperForwarder : NSObject

/// Install a super-forwarding stub for `selector` on `targetClass`.
+ (BOOL)installForClass:(Class)targetClass
               selector:(SEL)selector
                  error:(NSError **)error;

/// YES if the method on `targetClass` for `selector` is one of our stubs.
+ (BOOL)isForwarderForClass:(Class)targetClass selector:(SEL)selector;

/// YES on arm64 and x86_64.
@property(class, readonly) BOOL isArchitectureSupported;

#if (defined(__arm64__) || defined(__x86_64__)) && __APPLE__
+ (BOOL)isCompileTimeSupported;
#endif

@end

NSString *const SHKSuperForwarderErrorDomain;

typedef NS_ERROR_ENUM(SHKSuperForwarderErrorDomain, SHKSuperForwarderErrorCode) {
    SHKSuperForwarderErrorUnsupportedArch,
    SHKSuperForwarderErrorNoSuperclass,
    SHKSuperForwarderErrorNoSuperMethod,
    SHKSuperForwarderErrorAddMethodFailed
};

NS_ASSUME_NONNULL_END
