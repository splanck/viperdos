/// @file boot.S
/// @brief AArch64 kernel entry point and early bring-up stub.
///
/// @details
/// This is the first kernel code executed on AArch64 after the boot environment
/// transfers control to the kernel image.
///
/// Calling conventions:
/// - When booted directly by QEMU with `-kernel`, x0 typically contains a DTB
///   pointer.
/// - When booted via the ViperDOS boot stub (vboot), x0 contains a `VBootInfo*`.
///
/// Responsibilities:
/// - Establish a valid EL1 stack pointer.
/// - Apply minimal CPU configuration required by the C++ kernel (e.g. alignment
///   behavior).
/// - Zero the `.bss` section so global/static variables start in a defined state.
/// - Tail-call into `kernel_main` (C++) with the boot information pointer.

.section .text.boot
.global _start

/// @brief Kernel entry symbol.
///
/// @details
/// Saves the boot parameter pointer, sets up the stack, clears `.bss`, and
/// jumps to the C++ entry point. This routine should never return; if it does,
/// the CPU is halted in an infinite loop.
_start:
    // Save x0 (boot info / DTB pointer)
    mov     x20, x0

    // Set up kernel stack
    // Use SP_EL1 for kernel mode (SPSel=1)
    msr     spsel, #1
    adrp    x0, kernel_stack_top
    add     x0, x0, :lo12:kernel_stack_top
    mov     sp, x0

    // Disable alignment checking in SCTLR_EL1
    // This allows unaligned memory accesses (needed for network structs)
    mrs     x0, sctlr_el1
    bic     x0, x0, #(1 << 1)   // Clear A bit (alignment check)
    msr     sctlr_el1, x0
    isb

    // Enable FPU/SIMD access for EL1 and EL0
    // CPACR_EL1.FPEN (bits 21:20) = 0b11 enables FP/SIMD at both EL1 and EL0
    // This is required for Clang-generated code which uses SIMD for memory ops
    mrs     x0, cpacr_el1
    orr     x0, x0, #(3 << 20)  // FPEN = 0b11
    msr     cpacr_el1, x0
    isb

    // Clear BSS section
    adrp    x0, __bss_start
    add     x0, x0, :lo12:__bss_start
    adrp    x1, __bss_end
    add     x1, x1, :lo12:__bss_end
1:
    cmp     x0, x1
    b.ge    2f
    str     xzr, [x0], #8
    b       1b
2:

    // Restore boot info pointer and call C++ entry
    mov     x0, x20
    bl      kernel_main

    // Should not return, but if it does, halt
3:
    wfi
    b       3b

/// @brief Secondary CPU entry point.
///
/// @details
/// Called by PSCI when a secondary CPU is woken up. The CPU ID is passed
/// in x0 by the PSCI CPU_ON call. Sets up the stack and jumps to C++ code.
.global secondary_entry
secondary_entry:
    // x0 contains the CPU ID (passed as context_id to PSCI CPU_ON)
    mov     x20, x0             // Save CPU ID

    // Calculate stack pointer for this CPU
    // Stack = cpu_stacks[cpu_id] + CPU_STACK_SIZE
    adrp    x1, cpu_stacks
    add     x1, x1, :lo12:cpu_stacks
    mov     x2, #16384          // CPU_STACK_SIZE
    mul     x3, x20, x2         // Offset = cpu_id * stack_size
    add     x1, x1, x3          // Stack base for this CPU
    add     x1, x1, x2          // Stack top

    // Set up stack (use SP_EL1)
    msr     spsel, #1
    mov     sp, x1

    // Disable alignment checking
    mrs     x0, sctlr_el1
    bic     x0, x0, #(1 << 1)
    msr     sctlr_el1, x0
    isb

    // Enable FPU/SIMD access for EL1 and EL0
    mrs     x0, cpacr_el1
    orr     x0, x0, #(3 << 20)  // FPEN = 0b11
    msr     cpacr_el1, x0
    isb

    // Call secondary_main(cpu_id)
    mov     x0, x20
    bl      secondary_main

    // Should not return, but if it does, halt
1:
    wfi
    b       1b

/// @brief Per-CPU kernel stacks (16KiB each, 4 CPUs max).
///
/// @details
/// These stacks are used by secondary CPUs after being woken by PSCI.
/// The boot CPU uses kernel_stack_top until cpu::init() is called.
.global cpu_stacks
.section .bss
.align 16
cpu_stacks:
    .space 16384 * 4            // 4 CPUs * 16KB each

/// @brief Kernel stack storage (16KiB) for boot CPU.
///
/// @details
/// The early boot code uses a statically reserved stack in `.bss` until higher
/// level memory management and per-CPU stacks are set up.
.align 16
kernel_stack_bottom:
    .space 16384
kernel_stack_top:
