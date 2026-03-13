/**
 * @file startup.S
 * @brief AArch64 startup stub for the toolchain verification test.
 *
 * @details
 * This file provides the minimal assembly entry point needed to run the
 * freestanding `tests/boot/toolchain-test.cpp` program:
 * - Set up a known-good stack pointer.
 * - Branch to the C++ entry function `test_main`.
 * - Halt if the C++ code returns.
 *
 * It intentionally does not set up .bss/.data relocation, C++ constructors, or
 * exception handling. The test is designed to run without those facilities.
 */

.section .text.boot
.global _start

/**
 * @brief Reset/entry point for the toolchain test image.
 *
 * @details
 * The stack pointer is initialized to a fixed address. This matches the simple
 * memory layout used by the test harness and is sufficient for basic local
 * variables and call frames.
 *
 * After initializing SP, the code calls `test_main`. If `test_main` returns,
 * we enter an infinite low-power wait loop (`wfi`).
 */
_start:
    // Set up stack pointer (use 64KB stack at end of first 1MB)
    ldr     x0, =0x40100000
    mov     sp, x0

    // Call C++ entry point
    bl      test_main

    // Halt if we return
1:
    wfi
    b       1b

/**
 * @brief Reserve stack space in the binary.
 *
 * @details
 * The `.bss` space here provides a simple, fixed-size stack region that can be
 * used by the startup code (and inspected in a debugger). The actual SP value
 * loaded above is a constant chosen for the test image; the symbol below is
 * primarily documentation and a convenient anchor.
 */
.section .bss
.align 16
.space 65536
stack_top:
