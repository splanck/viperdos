//===----------------------------------------------------------------------===//
//
// Part of the Viper project, under the GNU GPL v3.
// See LICENSE for license information.
//
//===----------------------------------------------------------------------===//
/**
 * @file compositor.hpp
 * @brief Compositing and buffer management for displayd.
 */

#pragma once

#include "types.hpp"

namespace displayd {

// Copy back buffer to front buffer
void flip_buffers();

// Composite all surfaces to the framebuffer (double-buffered)
void composite();

// Mark that compositing is needed (deferred to end of main loop)
void mark_needs_composite();

// Check and clear the dirty flag (called from main loop)
bool needs_composite();

} // namespace displayd
