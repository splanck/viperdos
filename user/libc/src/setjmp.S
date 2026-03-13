/*
 * setjmp.S - Non-local jumps for AArch64
 *
 * jmp_buf layout (21 x 8 bytes = 168 bytes):
 *   [0-9]   x19-x28 (callee-saved general purpose registers)
 *   [10]    x29 (frame pointer)
 *   [11]    x30 (link register / return address)
 *   [12]    sp (stack pointer)
 *   [13-20] d8-d15 (callee-saved floating point registers)
 */

.text
.global setjmp
.global _setjmp
.global longjmp
.global _longjmp

/*
 * int setjmp(jmp_buf env)
 * Save registers and return 0
 * x0 = pointer to jmp_buf
 */
.type setjmp, %function
.type _setjmp, %function
setjmp:
_setjmp:
    /* Save callee-saved general purpose registers x19-x28 */
    stp     x19, x20, [x0, #0]
    stp     x21, x22, [x0, #16]
    stp     x23, x24, [x0, #32]
    stp     x25, x26, [x0, #48]
    stp     x27, x28, [x0, #64]

    /* Save frame pointer and link register */
    stp     x29, x30, [x0, #80]

    /* Save stack pointer */
    mov     x1, sp
    str     x1, [x0, #96]

    /* Save callee-saved floating point registers d8-d15 */
    stp     d8, d9, [x0, #104]
    stp     d10, d11, [x0, #120]
    stp     d12, d13, [x0, #136]
    stp     d14, d15, [x0, #152]

    /* Return 0 */
    mov     x0, #0
    ret
.size setjmp, . - setjmp

/*
 * void longjmp(jmp_buf env, int val)
 * Restore registers and return val (or 1 if val is 0) to setjmp caller
 * x0 = pointer to jmp_buf
 * x1 = return value
 */
.type longjmp, %function
.type _longjmp, %function
longjmp:
_longjmp:
    /* Ensure return value is non-zero */
    cmp     x1, #0
    csinc   x1, x1, xzr, ne     /* if x1 == 0, x1 = 1 */

    /* Restore callee-saved floating point registers d8-d15 */
    ldp     d8, d9, [x0, #104]
    ldp     d10, d11, [x0, #120]
    ldp     d12, d13, [x0, #136]
    ldp     d14, d15, [x0, #152]

    /* Restore callee-saved general purpose registers x19-x28 */
    ldp     x19, x20, [x0, #0]
    ldp     x21, x22, [x0, #16]
    ldp     x23, x24, [x0, #32]
    ldp     x25, x26, [x0, #48]
    ldp     x27, x28, [x0, #64]

    /* Restore frame pointer and link register */
    ldp     x29, x30, [x0, #80]

    /* Restore stack pointer */
    ldr     x2, [x0, #96]
    mov     sp, x2

    /* Set return value and return to setjmp caller */
    mov     x0, x1
    ret
.size longjmp, . - longjmp
