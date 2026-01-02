# Changelog

## Version 1.1 - January 2026

### Major Features

#### Notes Annotation System
A complete sticky note system for adding interactive text annotations to images:

**Core Functionality:**
- Yellow rectangular note icons with "N" letter
- Click icon to open/close notes with auto-resizing black callouts
- Drag note icons to reposition anywhere on the image
- Full keyboard text editing with Enter, Backspace, arrow keys, Escape, and Delete support
- Font widget integration for customizing note text appearance
- Smart text wrapping when reaching image edge

**Advanced Editing:**
- Click anywhere in text to position cursor at that exact location
- 20-pixel clickable area after each line for easy end-of-line cursor placement
- **Double-click** any word to select it
- **Triple-click** anywhere to select all text
- Text selection with blue translucent highlight
- Type or press Backspace to replace selected text
- Full UTF-8 support for international text (Danish æøå, Croatian čćšđž, Japanese 日本語, Chinese 汉字, Arabic العربية, emoji 😀, etc.)

**File Handling:**
- Notes are fully preserved in .linia project files with complete functionality
- Notes are intentionally excluded from PNG/JPEG exports (metadata, not image content)
- Warning dialog appears when exporting images containing notes
- Suggests saving as .linia format to preserve note functionality

**Technical Excellence:**
- Zoom and resolution independent rendering
- Full HiDPI display support
- Proper UTF-8 byte offset handling for accurate cursor positioning with multi-byte characters
- Cairo path isolation prevents phantom lines between notes
- Accurate hit detection for all interactive elements

---

#### Vastly Improved Scaling and Zooming
Complete overhaul of the scaling system with HiDPI and Wayland support:

**Dual-Variable Scaling Architecture:**
- Separated `zoom` (user-controlled zoom level) from `monitor_scale` (display scaling factor)
- Replaced legacy single `scale_factor` approach with dual-variable system
- Provides superior support for Wayland's fractional scaling (125%, 150%, 175%, 200%)

**Export Quality:**
- Exports are always at native image resolution regardless of display scaling
- No more accidentally upscaled or downscaled exports
- Consistent quality across all display configurations

**Zoom Behavior:**
- Fixed viewport centering during zoom operations
- Smooth zoom transitions with proper coordinate transforms
- Accurate mouse position tracking during zoom
- Proper handling of zoom-independent elements (like note icons)

**HiDPI Support:**
- Full support for high-DPI displays on Wayland and X11
- Crisp rendering at any display scaling factor
- Text remains sharp at all zoom levels
- All drawing tools respect display scaling correctly

---

#### Enhanced Toolbar Icons
Comprehensive visual refresh of both toolbars:

**Main Toolbar:**
- Redesigned icons with improved clarity and consistency
- Better visual distinction between tools
- Modern, professional appearance

**Drawing Toolbar:**
- Enhanced tool icons for better recognition
- Improved visual hierarchy
- Consistent styling across all drawing tools

---

### Technical Improvements

- Fixed coordinate system management between screen pixels and image coordinates
- Improved text cursor positioning with proper Pango integration
- Added comprehensive validation for cursor positions to prevent getting stuck
- Cleaned up Perl::Critic violations while maintaining functionality

---

### Bug Fixes

- Fixed Enter key creating new lines at end of text in notes
- Resolved phantom line artifacts between note icons (Cairo path state leakage)
- Fixed cursor positioning issues with UTF-8 multi-byte characters
- Corrected hit detection for note callouts with variable widths
- Fixed selection drawing causing text disappearance
- Resolved note icons jumping positions when opening/closing notes

---

### Breaking Changes

None - all changes are backward compatible with existing .linia project files.

---

### Known Issues

None currently identified.