/**
 * @file context.S
 * @brief AArch64 context switching and task entry trampoline.
 *
 * @details
 * This file contains the low-level assembly routines used by the scheduler:
 * - `context_switch`: saves the outgoing task's callee-saved registers and stack
 *   pointer into a @ref task::TaskContext and restores the incoming task's
 *   context, effectively transferring execution.
 * - `task_entry_trampoline`: first instruction pointer for newly created tasks.
 *   It loads the task entry function and argument from the stack, calls the
 *   function, and terminates the task if the function returns.
 *
 * These routines are AArch64-specific and must match the ABI and the layouts
 * defined in `task.hpp`.
 */

.section .text

/**
 * @brief Save old context and restore new context.
 *
 * @details
 * Calling convention:
 * - x0: pointer to outgoing @ref task::TaskContext (destination for save).
 * - x1: pointer to incoming @ref task::TaskContext (source for restore).
 *
 * Saved/restored registers:
 * - ABI callee-saved registers x19-x29.
 * - Link register x30.
 * - Stack pointer SP.
 *
 * After restoration, the routine returns with `ret`, which branches to the
 * address in x30 from the *new* context. For newly created tasks, x30 is set to
 * `task_entry_trampoline`.
 */
.global context_switch
.type context_switch, @function
context_switch:
    // Save callee-saved registers to old context (x0)
    stp     x19, x20, [x0, #0x00]
    stp     x21, x22, [x0, #0x10]
    stp     x23, x24, [x0, #0x20]
    stp     x25, x26, [x0, #0x30]
    stp     x27, x28, [x0, #0x40]
    stp     x29, x30, [x0, #0x50]
    mov     x2, sp
    str     x2, [x0, #0x60]

    // Load callee-saved registers from new context (x1)
    ldp     x19, x20, [x1, #0x00]
    ldp     x21, x22, [x1, #0x10]
    ldp     x23, x24, [x1, #0x20]
    ldp     x25, x26, [x1, #0x30]
    ldp     x27, x28, [x1, #0x40]
    ldp     x29, x30, [x1, #0x50]
    ldr     x2, [x1, #0x60]
    mov     sp, x2

    // Return to new context
    // x30 contains the return address (or task_entry_trampoline for new tasks)
    ret

.size context_switch, . - context_switch


/**
 * @brief Entry point for newly created tasks.
 *
 * @details
 * The task creation code sets up the new task's stack with:
 * - [sp + 0]: entry function pointer (task::TaskEntry).
 * - [sp + 8]: argument pointer passed to the entry function.
 *
 * The trampoline:
 * - Unmasks IRQs (in case we arrived with IRQs masked).
 * - Loads the entry function into x9 and the argument into x0.
 * - Adjusts SP to remove the two pushed words.
 * - Calls the entry function via `blr`.
 * - If the entry function returns, calls `task::exit(0)` to terminate.
 */
.global task_entry_trampoline
.type task_entry_trampoline, @function
task_entry_trampoline:
    // Enable interrupts - we might have come from an IRQ handler
    // where interrupts were masked
    msr     daifclr, #2         // Unmask IRQ

    // Load entry function and argument from stack
    ldr     x9, [sp, #0]        // x9 = entry function
    ldr     x0, [sp, #8]        // x0 = arg (first parameter)

    // Adjust stack pointer (clean up the pushed values)
    add     sp, sp, #16

    // Call the entry function
    blr     x9

    // If we get here, the task returned
    // Call task::exit(0)
    mov     x0, #0              // exit code = 0
    bl      _ZN4task4exitEi     // task::exit(i32)

    // Should never get here, but just in case
1:  wfi
    b       1b

.size task_entry_trampoline, . - task_entry_trampoline

.section .text
