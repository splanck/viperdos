/**
 * @file crt0.S
 * @brief AArch64 UEFI CRT0 entry stub for the `vboot` application.
 *
 * @details
 * UEFI firmware starts an application by branching to its PE/COFF entry point.
 * For AArch64, the firmware provides:
 * - x0: `EFI_HANDLE` for the loaded image
 * - x1: `EFI_SYSTEM_TABLE*` pointer
 *
 * This file provides a minimal `_start` symbol that preserves the incoming
 * arguments and calls the C entry point `efi_main`. It is intentionally
 * minimal: no stack probing, relocation, or C runtime initialization is
 * performed beyond establishing a frame record.
 */

    .section .text
    .global _start

/**
 * @brief UEFI application entry point shim.
 *
 * @details
 * Establishes a simple frame record, then tail-calls the C entry point
 * `efi_main(ImageHandle, SystemTable)` using the argument registers already
 * provided by the firmware.
 *
 * If `efi_main` returns, the stub restores x29/x30 and returns to the firmware.
 */
_start:
    // Save arguments
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // x0 = ImageHandle (already in x0)
    // x1 = SystemTable (already in x1)

    // Call C entry point
    bl      efi_main

    // Restore and return (should not happen, but just in case)
    ldp     x29, x30, [sp], #16
    ret
