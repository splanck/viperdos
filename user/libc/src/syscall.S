/* ViperDOS libc syscall wrappers for AArch64 */

.global __syscall0
.global __syscall1
.global __syscall2
.global __syscall3
.global __syscall4
.global __syscall5
.global __syscall6

/* Syscall ABI (new):
 * x8 = syscall number
 * x0-x5 = arguments
 * Returns:
 *   x0 = error code (0 = success, negative = error)
 *   x1 = result value 0
 *   x2 = result value 1
 *   x3 = result value 2
 *
 * This wrapper returns:
 *   - x0 (error code) if x0 < 0
 *   - x1 (result) if x0 >= 0
 * This maintains compatibility with callers expecting old-style returns.
 */

/* long __syscall0(long num) */
__syscall0:
    mov x8, x0
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret

/* long __syscall1(long num, long arg0) */
__syscall1:
    mov x8, x0
    mov x0, x1
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret

/* long __syscall2(long num, long arg0, long arg1) */
__syscall2:
    mov x8, x0
    mov x0, x1
    mov x1, x2
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret

/* long __syscall3(long num, long arg0, long arg1, long arg2) */
__syscall3:
    mov x8, x0
    mov x0, x1
    mov x1, x2
    mov x2, x3
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret

/* long __syscall4(long num, long arg0, long arg1, long arg2, long arg3) */
__syscall4:
    mov x8, x0
    mov x0, x1
    mov x1, x2
    mov x2, x3
    mov x3, x4
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret

/* long __syscall5(long num, long a0, long a1, long a2, long a3, long a4) */
__syscall5:
    mov x8, x0
    mov x0, x1
    mov x1, x2
    mov x2, x3
    mov x3, x4
    mov x4, x5
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret

/* long __syscall6(long num, long a0, long a1, long a2, long a3, long a4, long a5) */
__syscall6:
    mov x8, x0
    mov x0, x1
    mov x1, x2
    mov x2, x3
    mov x3, x4
    mov x4, x5
    mov x5, x6
    svc #0
    /* Check if error (x0 < 0) */
    cmp x0, #0
    csel x0, x0, x1, lt    /* x0 = (x0 < 0) ? x0 : x1 */
    ret
