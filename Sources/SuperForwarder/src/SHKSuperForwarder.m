//
//  SHKSuperForwarder.m
//  SwiftHook
//
//  Created by Krishna.
//

#if __APPLE__
#import "SHKSuperForwarder.h"

@import ObjectiveC.message;
@import ObjectiveC.runtime;

NS_ASSUME_NONNULL_BEGIN

NSString *const SHKSuperForwarderErrorDomain = @"dev.krishna.swifthook.superforwarder";

// Forward declarations of the naked trampolines defined below.
void shk_superTrampoline(void);
void shk_superStretTrampoline(void);

#define kLet const __auto_type
#define kVar __auto_type

// Decide which trampoline to use based on return-type encoding.
static IMP SHKTrampolineForEncoding(__unused const char *encoding) {
    BOOL needsStret = NO;
#if defined(__arm64__)
    // arm64 never uses stret dispatch.
#elif defined(__x86_64__)
    NSUInteger retSize = 0;
    NSGetSizeAndAlignment(encoding, &retSize, NULL);
    needsStret = retSize > (sizeof(void *) * 2);
#endif
    return needsStret ? (IMP)shk_superStretTrampoline : (IMP)shk_superTrampoline;
}

// C entry point for Swift's dlsym lookup.
BOOL SHKInstallSuperForwarder(Class cls, SEL sel, NSError **error);
BOOL SHKInstallSuperForwarder(Class cls, SEL sel, NSError **error) {
    return [SuperForwarder installForClass:cls selector:sel error:error];
}

#define FAIL_WITH(CODE, MSG) \
    if (error) { *error = [NSError errorWithDomain:SHKSuperForwarderErrorDomain \
        code:CODE userInfo:@{NSLocalizedDescriptionKey: MSG}]; } return NO;

// Thread-local storage for the objc_super struct used by the trampoline.
_Thread_local struct objc_super _shk_threadSuper;

static BOOL SHKIsSuperTrampoline(Method method) {
    kLet imp = method_getImplementation(method);
    return imp == (IMP)shk_superTrampoline || imp == (IMP)shk_superStretTrampoline;
}

// Called from assembly: resolve the correct super target at runtime.
struct objc_super *SHKResolveSuper(__unsafe_unretained id obj, SEL _cmd);
struct objc_super *SHKResolveSuper(__unsafe_unretained id obj, SEL _cmd) {
    Class cls = object_getClass(obj);
    Class sup = class_getSuperclass(cls);

    // Walk up to find the first non-trampoline, non-duplicate implementation.
    do {
        kLet superMethod = class_getInstanceMethod(sup, _cmd);
        kLet sameAsChild = class_getInstanceMethod(cls, _cmd) == superMethod;
        if (!sameAsChild && !SHKIsSuperTrampoline(superMethod)) {
            break;
        }
        cls = sup;
        sup = class_getSuperclass(cls);
    } while (1);

    struct objc_super *s = &_shk_threadSuper;
    s->receiver = obj;
    s->super_class = cls;
    return s;
}

@implementation SuperForwarder

+ (BOOL)isArchitectureSupported {
#if defined(__arm64__) || defined(__x86_64__)
    return YES;
#else
    return NO;
#endif
}

#if defined(__arm64__) || defined(__x86_64__)
+ (BOOL)isCompileTimeSupported {
    return [self isArchitectureSupported];
}
#endif

+ (BOOL)isForwarderForClass:(Class)cls selector:(SEL)sel {
    kLet m = class_getInstanceMethod(cls, sel);
    return SHKIsSuperTrampoline(m);
}

+ (BOOL)installForClass:(Class)cls selector:(SEL)sel error:(NSError **)error {
    if (!self.isArchitectureSupported) {
        kLet msg = @"Architecture not supported (need arm64 or x86_64)";
        FAIL_WITH(SHKSuperForwarderErrorUnsupportedArch, msg)
    }

    kLet sup = class_getSuperclass(cls);
    if (sup == nil) {
        kLet msg = [NSString stringWithFormat:@"No superclass for %@",
                    NSStringFromClass(cls)];
        FAIL_WITH(SHKSuperForwarderErrorNoSuperclass, msg)
    }

    kLet method = class_getInstanceMethod(sup, sel);
    if (method == NULL) {
        kLet msg = [NSString stringWithFormat:
            @"No super implementation of %@ on %@",
            NSStringFromSelector(sel), NSStringFromClass(cls)];
        FAIL_WITH(SHKSuperForwarderErrorNoSuperMethod, msg)
    }

    kLet encoding = method_getTypeEncoding(method);
    kLet trampoline = SHKTrampolineForEncoding(encoding);
    kLet ok = class_addMethod(cls, sel, trampoline, encoding);
    if (!ok) {
        kLet msg = [NSString stringWithFormat:
            @"class_addMethod failed for %@ on %@",
            NSStringFromSelector(sel), NSStringFromClass(cls)];
        FAIL_WITH(SHKSuperForwarderErrorAddMethodFailed, msg)
    }
    return ok;
}

// Keep floating-point registers safe across the trampoline.
#define SAVE_FP_REGS 1

@end

// ============================================================
//  Inline assembly trampolines
// ============================================================

#if defined(__arm64__)

__attribute__((__naked__))
void shk_superTrampoline(void) {
    asm volatile (
#if SAVE_FP_REGS
        "stp q6, q7, [sp, #-32]!\n"
        "stp q4, q5, [sp, #-32]!\n"
        "stp q2, q3, [sp, #-32]!\n"
        "stp q0, q1, [sp, #-32]!\n"
#endif
        "stp x8, lr, [sp, #-16]!\n"
        "stp x6, x7, [sp, #-16]!\n"
        "stp x4, x5, [sp, #-16]!\n"
        "stp x2, x3, [sp, #-16]!\n"
        "stp x0, x1, [sp, #-16]!\n"

        "bl _SHKResolveSuper\n"
        "mov x9, x0\n"

        "ldp x0, x1, [sp], #16\n"
        "ldp x2, x3, [sp], #16\n"
        "ldp x4, x5, [sp], #16\n"
        "ldp x6, x7, [sp], #16\n"
        "ldp x8, lr, [sp], #16\n"
#if SAVE_FP_REGS
        "ldp q0, q1, [sp], #32\n"
        "ldp q2, q3, [sp], #32\n"
        "ldp q4, q5, [sp], #32\n"
        "ldp q6, q7, [sp], #32\n"
#endif
        "mov x0, x9\n"
        "b _objc_msgSendSuper2\n"
        : : : "x0", "x1"
    );
}

// arm64 never needs _stret.
void shk_superStretTrampoline(void) {}

#elif defined(__x86_64__)

__attribute__((__naked__))
void shk_superTrampoline(void) {
    asm volatile (
        "pushq %%rbp\n"
        "movq %%rsp, %%rbp\n"
#if SAVE_FP_REGS
        "subq $112, %%rsp\n"
        "movdqu %%xmm0,  -64(%%rbp)\n"
        "movdqu %%xmm1,  -80(%%rbp)\n"
        "movdqu %%xmm2,  -96(%%rbp)\n"
        "movdqu %%xmm3, -112(%%rbp)\n"
#else
        "subq $48, %%rsp\n"
#endif
        "movq %%rsi, -16(%%rbp)\n"
        "movq %%rdx, -24(%%rbp)\n"
        "movq %%rcx, -32(%%rbp)\n"
        "movq %%r8,  -40(%%rbp)\n"
        "movq %%r9,  -48(%%rbp)\n"

        "callq _SHKResolveSuper\n"
        "movq %%rax, %%rdi\n"

#if SAVE_FP_REGS
        "movdqu -64(%%rbp),  %%xmm0\n"
        "movdqu -80(%%rbp),  %%xmm1\n"
        "movdqu -96(%%rbp),  %%xmm2\n"
        "movdqu -112(%%rbp), %%xmm3\n"
#endif
        "movq -16(%%rbp), %%rsi\n"
        "movq -24(%%rbp), %%rdx\n"
        "movq -32(%%rbp), %%rcx\n"
        "movq -40(%%rbp), %%r8\n"
        "movq -48(%%rbp), %%r9\n"

#if SAVE_FP_REGS
        "addq $112, %%rsp\n"
#else
        "addq $48, %%rsp\n"
#endif
        "popq %%rbp\n"
        "jmp _objc_msgSendSuper2\n"
        : : : "rsi", "rdi"
    );
}

__attribute__((__naked__))
void shk_superStretTrampoline(void) {
    asm volatile (
        "pushq %%rbp\n"
        "movq %%rsp, %%rbp\n"
        "subq $48, %%rsp\n"

        "movq %%rdi, -8(%%rbp)\n"
        "movq %%rsi, -16(%%rbp)\n"
        "movq %%rdx, -24(%%rbp)\n"
        "movq %%rcx, -32(%%rbp)\n"
        "movq %%r8,  -40(%%rbp)\n"
        "movq %%r9,  -48(%%rbp)\n"

        "movq -16(%%rbp), %%rdi\n"
        "movq -24(%%rbp), %%rsi\n"
        "callq _SHKResolveSuper\n"
        "movq %%rax, %%rsi\n"

        "movq -8(%%rbp),  %%rdi\n"
        "movq -24(%%rbp), %%rdx\n"
        "movq -32(%%rbp), %%rcx\n"
        "movq -40(%%rbp), %%r8\n"
        "movq -48(%%rbp), %%r9\n"

        "addq $48, %%rsp\n"
        "popq %%rbp\n"
        "jmp _objc_msgSendSuper2_stret\n"
        : : : "rsi", "rdi"
    );
}

#else
// Unsupported architecture - stubs only.
void shk_superTrampoline(void) {}
void shk_superStretTrampoline(void) {}
#endif

NS_ASSUME_NONNULL_END
#endif
