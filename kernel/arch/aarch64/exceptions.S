/// @file exceptions.S
/// @brief AArch64 exception vector table and trampoline handlers.
///
/// @details
/// AArch64 requires an exception vector table (VBAR_EL1) with 16 fixed entries.
/// Each entry is exactly 128 bytes. To keep each entry within this size, the
/// vector table in this file uses tiny trampoline stubs that immediately branch
/// to "real" handlers located outside the table.
///
/// The real handlers:
/// - Save CPU state into a stack-allocated @ref exceptions::ExceptionFrame.
/// - Call into C/C++ handlers such as `handle_sync_exception` or `handle_irq`.
/// - Restore the saved state and return with `eret`.
///
/// This file also provides helper entry points:
/// - `exceptions_init_asm`: installs `exception_vectors` into VBAR_EL1.
/// - `enter_user_mode`: transitions from EL1 into EL0 for the first user task.

.section .text

/// @brief Size in bytes of @ref exceptions::ExceptionFrame as saved by macros.
///
/// @details
/// The save macros allocate exactly this many bytes on the stack and store
/// registers at fixed offsets. The C++ `ExceptionFrame` definition must match
/// this layout.
.equ FRAME_SIZE, 288

/// @brief Emit a 128-byte vector entry that branches to a real handler label.
.macro VECTOR_ENTRY handler
    .align 7  // Each entry is 128 bytes (2^7)
    b       \handler
.endm

/// @brief Emit a 128-byte vector entry for unsupported/invalid vectors.
.macro VECTOR_INVALID
    .align 7
    b       vec_invalid
.endm

/// @brief Exception vector table (VBAR_EL1 target).
///
/// @details
/// The vector table must be 2KiB aligned. Entries are grouped by exception
/// origin (current EL with SP0/SPx, lower EL AArch64/AArch32) and type
/// (synchronous, IRQ, FIQ, SError). Unsupported entries branch to `vec_invalid`.
.global exception_vectors
.align 11  // 2^11 = 2048 bytes alignment
exception_vectors:
    // Current EL with SP0 (shouldn't happen, we use SPx)
    VECTOR_INVALID                      // 0x000: Synchronous
    VECTOR_INVALID                      // 0x080: IRQ
    VECTOR_INVALID                      // 0x100: FIQ
    VECTOR_INVALID                      // 0x180: SError

    // Current EL with SPx (this is what we use)
    VECTOR_ENTRY vec_sync               // 0x200: Synchronous
    VECTOR_ENTRY vec_irq                // 0x280: IRQ
    VECTOR_ENTRY vec_fiq                // 0x300: FIQ
    VECTOR_ENTRY vec_serror             // 0x380: SError

    // Lower EL using AArch64 (user mode EL0)
    VECTOR_ENTRY vec_el0_sync           // 0x400: Synchronous (syscalls, faults)
    VECTOR_ENTRY vec_el0_irq            // 0x480: IRQ
    VECTOR_INVALID                      // 0x500: FIQ (not used)
    VECTOR_ENTRY vec_el0_serror         // 0x580: SError

    // Lower EL using AArch32 (not supported)
    VECTOR_INVALID                      // 0x600: Synchronous
    VECTOR_INVALID                      // 0x680: IRQ
    VECTOR_INVALID                      // 0x700: FIQ
    VECTOR_INVALID                      // 0x780: SError

// Common exception handling code (outside the vector table)
.align 4

/// @brief Save general-purpose registers and EL1 exception context.
///
/// @details
/// Saves x0-x29, x30, the interrupted SP, ELR_EL1, SPSR_EL1, ESR_EL1 and FAR_EL1
/// into the stack frame and leaves SP pointing at the base of the saved frame.
.macro SAVE_REGS
    // Allocate stack frame
    sub     sp, sp, #FRAME_SIZE

    // Save x0-x29
    stp     x0, x1, [sp, #0]
    stp     x2, x3, [sp, #16]
    stp     x4, x5, [sp, #32]
    stp     x6, x7, [sp, #48]
    stp     x8, x9, [sp, #64]
    stp     x10, x11, [sp, #80]
    stp     x12, x13, [sp, #96]
    stp     x14, x15, [sp, #112]
    stp     x16, x17, [sp, #128]
    stp     x18, x19, [sp, #144]
    stp     x20, x21, [sp, #160]
    stp     x22, x23, [sp, #176]
    stp     x24, x25, [sp, #192]
    stp     x26, x27, [sp, #208]
    stp     x28, x29, [sp, #224]

    // Save x30 (LR) and original SP
    mov     x0, sp
    add     x0, x0, #FRAME_SIZE
    stp     x30, x0, [sp, #240]

    // Save ELR_EL1 and SPSR_EL1
    mrs     x0, elr_el1
    mrs     x1, spsr_el1
    stp     x0, x1, [sp, #256]

    // Save ESR_EL1 and FAR_EL1
    mrs     x0, esr_el1
    mrs     x1, far_el1
    stp     x0, x1, [sp, #272]
.endm

/// @brief Save registers for exceptions taken from EL0 (user mode).
///
/// @details
/// Similar to @ref SAVE_REGS, but saves SP_EL0 (the user stack pointer) instead
/// of the interrupted kernel SP. This allows C++ EL0 handlers to inspect/restore
/// the user stack pointer if needed.
.macro SAVE_EL0_REGS
    // Allocate stack frame
    sub     sp, sp, #FRAME_SIZE

    // Save x0-x29
    stp     x0, x1, [sp, #0]
    stp     x2, x3, [sp, #16]
    stp     x4, x5, [sp, #32]
    stp     x6, x7, [sp, #48]
    stp     x8, x9, [sp, #64]
    stp     x10, x11, [sp, #80]
    stp     x12, x13, [sp, #96]
    stp     x14, x15, [sp, #112]
    stp     x16, x17, [sp, #128]
    stp     x18, x19, [sp, #144]
    stp     x20, x21, [sp, #160]
    stp     x22, x23, [sp, #176]
    stp     x24, x25, [sp, #192]
    stp     x26, x27, [sp, #208]
    stp     x28, x29, [sp, #224]

    // Save x30 (LR) and SP_EL0 (user stack pointer)
    mrs     x0, sp_el0
    stp     x30, x0, [sp, #240]

    // Save ELR_EL1 and SPSR_EL1
    mrs     x0, elr_el1
    mrs     x1, spsr_el1
    stp     x0, x1, [sp, #256]

    // Save ESR_EL1 and FAR_EL1
    mrs     x0, esr_el1
    mrs     x1, far_el1
    stp     x0, x1, [sp, #272]
.endm

/// @brief Restore registers and context for returning to EL0 with `eret`.
.macro RESTORE_EL0_REGS
    // Restore ELR_EL1 and SPSR_EL1
    ldp     x0, x1, [sp, #256]
    msr     elr_el1, x0
    msr     spsr_el1, x1

    // Restore SP_EL0
    ldr     x0, [sp, #248]
    msr     sp_el0, x0

    // Restore x0-x29
    ldp     x0, x1, [sp, #0]
    ldp     x2, x3, [sp, #16]
    ldp     x4, x5, [sp, #32]
    ldp     x6, x7, [sp, #48]
    ldp     x8, x9, [sp, #64]
    ldp     x10, x11, [sp, #80]
    ldp     x12, x13, [sp, #96]
    ldp     x14, x15, [sp, #112]
    ldp     x16, x17, [sp, #128]
    ldp     x18, x19, [sp, #144]
    ldp     x20, x21, [sp, #160]
    ldp     x22, x23, [sp, #176]
    ldp     x24, x25, [sp, #192]
    ldp     x26, x27, [sp, #208]
    ldp     x28, x29, [sp, #224]
    ldr     x30, [sp, #240]

    // Deallocate stack frame
    add     sp, sp, #FRAME_SIZE
.endm

/// @brief Restore registers and EL1 context for returning with `eret`.
.macro RESTORE_REGS
    // Restore ELR_EL1 and SPSR_EL1
    ldp     x0, x1, [sp, #256]
    msr     elr_el1, x0
    msr     spsr_el1, x1

    // Restore x0-x29
    ldp     x0, x1, [sp, #0]
    ldp     x2, x3, [sp, #16]
    ldp     x4, x5, [sp, #32]
    ldp     x6, x7, [sp, #48]
    ldp     x8, x9, [sp, #64]
    ldp     x10, x11, [sp, #80]
    ldp     x12, x13, [sp, #96]
    ldp     x14, x15, [sp, #112]
    ldp     x16, x17, [sp, #128]
    ldp     x18, x19, [sp, #144]
    ldp     x20, x21, [sp, #160]
    ldp     x22, x23, [sp, #176]
    ldp     x24, x25, [sp, #192]
    ldp     x26, x27, [sp, #208]
    ldp     x28, x29, [sp, #224]
    ldr     x30, [sp, #240]

    // Deallocate stack frame
    add     sp, sp, #FRAME_SIZE
.endm

/// @brief Handler for unsupported/invalid vector entries.
vec_invalid:
    SAVE_REGS
    mov     x0, sp
    bl      handle_invalid_exception
1:  b       1b              // Hang

vec_sync:
    SAVE_REGS
    mov     x0, sp
    bl      handle_sync_exception
    RESTORE_REGS
    eret

vec_irq:
    SAVE_REGS
    mov     x0, sp
    bl      handle_irq
    RESTORE_REGS
    eret

vec_fiq:
    SAVE_REGS
    mov     x0, sp
    bl      handle_fiq
    RESTORE_REGS
    eret

vec_serror:
    SAVE_REGS
    mov     x0, sp
    bl      handle_serror
    RESTORE_REGS
    eret

// EL0 (user mode) exception handlers

vec_el0_sync:
    SAVE_EL0_REGS
    mov     x0, sp              // Pointer to saved registers
    bl      handle_el0_sync
    RESTORE_EL0_REGS
    eret

vec_el0_irq:
    SAVE_EL0_REGS
    mov     x0, sp
    bl      handle_el0_irq
    RESTORE_EL0_REGS
    eret

vec_el0_serror:
    SAVE_EL0_REGS
    mov     x0, sp
    bl      handle_el0_serror
    RESTORE_EL0_REGS
    eret

/// @brief Transition into EL0 and begin executing user code.
///
/// @details
/// Sets SP_EL0 to the user stack, ELR_EL1 to the user entry point, configures
/// SPSR_EL1 for an EL0 return state, sets the initial user argument in x0,
/// clears remaining general-purpose registers, and executes `eret`.
.global enter_user_mode
enter_user_mode:
    // Set up SP_EL0 (user stack)
    msr     sp_el0, x1

    // Set ELR_EL1 (return address = user entry point)
    msr     elr_el1, x0

    // Set SPSR_EL1 for EL0 with interrupts enabled
    // Bit 0 = 0 (EL0), Bits 6-9 = 0 (interrupts enabled)
    mov     x3, #0
    msr     spsr_el1, x3

    // Pass argument in x0
    mov     x0, x2

    // Clear other registers for security
    mov     x1, xzr
    mov     x2, xzr
    mov     x3, xzr
    mov     x4, xzr
    mov     x5, xzr
    mov     x6, xzr
    mov     x7, xzr
    mov     x8, xzr
    mov     x9, xzr
    mov     x10, xzr
    mov     x11, xzr
    mov     x12, xzr
    mov     x13, xzr
    mov     x14, xzr
    mov     x15, xzr
    mov     x16, xzr
    mov     x17, xzr
    mov     x18, xzr
    mov     x19, xzr
    mov     x20, xzr
    mov     x21, xzr
    mov     x22, xzr
    mov     x23, xzr
    mov     x24, xzr
    mov     x25, xzr
    mov     x26, xzr
    mov     x27, xzr
    mov     x28, xzr
    mov     x29, xzr
    mov     x30, xzr

    // Return to user mode
    eret

/// @brief Install the exception vector table by programming VBAR_EL1.
///
/// @details
/// Called by `exceptions::init()` during early boot.
.global exceptions_init_asm
exceptions_init_asm:
    adr     x0, exception_vectors
    msr     vbar_el1, x0
    isb
    ret
