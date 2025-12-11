# Linia Complete User Tutorial

## Table of Contents
1. [Introduction](#introduction)
2. [Understanding the Interface](#understanding-the-interface)
3. [Menu Bar](#menu-bar)
4. [Main Toolbar](#main-toolbar)
5. [Drawing Toolbar](#drawing-toolbar)
6. [Widget Toolbar](#widget-toolbar)
7. [Working with Images](#working-with-images)
8. [Project Files (.linia)](#project-files-linia)
9. [Keyboard Shortcuts](#keyboard-shortcuts)

---

## Introduction

**Linia** (Linux Image Annotator) is an annotation application designed for marking up screenshots and images on Linux. It provides multiple drawing tools, persistent undo/redo capabilities, and a project file system that preserves your complete editing history across sessions.

### Key Features
- **Comprehensive Drawing Tools**: Lines, arrows, shapes (2D and 3D), text, freehand, highlighting
- **Persistent Projects**: Save complete editing history with .linia files
- **Advanced Effects**: Magnifiers, pixelization, numbered annotations
- **SVG Import**: Add callouts, emojis, and custom graphics
- **Professional Output**: Export annotated images in multiple formats

---

## Understanding the Interface

### Why Centered Layout?

Linia uses a **centered menu bar and toolbar design** for several important reasons:

1. **Fullscreen Optimization**: When working fullscreen (F11), centered toolbars keep all controls within easy reach at the top-center of the screen, rather than forcing you to move your cursor to the far edges.

2. **Focus on Content**: The centered design creates visual balance and draws attention to your image in the canvas area rather than spreading UI elements across the entire window width.

3. **Ergonomics**: For large or ultra-wide monitors, centered controls reduce cursor travel distance, making the workflow more efficient.

4. **Professional Appearance**: The centered layout gives Linia a clean, modern aesthetic that distinguishes it from traditional desktop applications.

### Interface Layout

Linia's interface consists of four main horizontal toolbars (from top to bottom):

```
┌────────────────────────────────────────────────────┐
│              [MENU BAR - Centered]                 │
├────────────────────────────────────────────────────┤
│           [MAIN TOOLBAR - Centered]                │
├────────────────────────────────────────────────────┤
│          [DRAWING TOOLBAR - Centered]              │
├────────────────────────────────────────────────────┤
│          [WIDGET TOOLBAR - Centered]               │
├────────────────────────────────────────────────────┤
│                                                    │
│              [CANVAS / IMAGE AREA]                 │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Optional Left Side Layout**: The Drawing Toolbar can optionally be moved to the left side of the window for vertical orientation. This is useful when working with tall/portrait images or when you prefer vertical tool access. Enable this via **View → Drawing Toolbar Left**.

---

## Menu Bar

### File Menu
- **New Window**: Opens a new Linia window instance
- **Open Image**: Opens an image file for annotation (PNG, JPEG, WebP, BMP)
- **Open Project**: Opens a saved .linia project file with complete editing history
- **Open Recent**: Quick access to recently opened images (with thumbnails)
- **Save Project**: Saves your work as a .linia project file
- **Export Image As**: Exports the annotated image to a new file
- **Print**: Sends the annotated image to a printer
- **Close Image**: Closes the current image (prompts to save if modified)
- **Exit**: Closes Linia (prompts to save if modified)

### Edit Menu
- **Undo**: Reverts the last action (Ctrl+Z)
- **Redo**: Reapplies an undone action (Ctrl+Shift+Z)
- **Copy**: Copies selected annotation(s) (Ctrl+C)
- **Copy Image**: Copies the entire annotated image to clipboard (Ctrl+Shift+C)
- **Cut**: Cuts selected annotation(s) (Ctrl+X)
- **Paste**: Pastes copied annotation(s) (Ctrl+V)
- **Clear**: Removes all annotations from the image (keeps the base image)
- **Delete**: Deletes selected annotation(s) (Delete key)
- **Settings**: Opens application preferences dialog

### View Menu
- **Drawing Toolbar Left**: Toggles drawing toolbar between top (horizontal) and left (vertical) positions
- **Show Main Toolbar**: Toggles visibility of the main toolbar
- **Zoom In**: Increases image magnification (Ctrl+Plus)
- **Zoom Out**: Decreases image magnification (Ctrl+Minus)
- **Original Size**: Resets zoom to 100% (Ctrl+1)
- **Best Fit**: Fits the entire image in the window (Ctrl+2)
- **Main Toolbar Icon Size**: Adjusts icon size (16-64 pixels)
- **Drawing Toolbar Icon Size**: Adjusts drawing tool icon size (16-64 pixels)

### Help Menu
- **Keyboard Shortcuts**: Displays a comprehensive list of keyboard shortcuts
- **About**: Shows application information and version

---

## Main Toolbar

The Main Toolbar provides quick access to file operations, clipboard functions, and zoom controls. All buttons include tooltips that appear when you hover over them.

### File Operations

#### Open Image
- **Icon**: Folder/Image icon
- **Function**: Opens a file browser to select an image for annotation
- **Supported Formats**: PNG, JPEG, WebP, BMP
- **Default Location**: Opens to your Pictures directory
- **Preview**: Shows thumbnail preview as you browse files
- **Shortcut**: Ctrl+O

#### Open Recent
- **Icon**: Clock/Recent icon
- **Function**: Displays a dropdown menu of recently opened images
- **Features**:
  - Shows up to 10 most recent images
  - Displays thumbnail previews for each image
  - Shows file path for easy identification
  - Click any thumbnail to quickly reopen that image
- **Persistence**: Recent files list is saved between sessions

#### Import SVG
- **Icon**: SVG/Document icon
- **Function**: Imports SVG vector graphics as annotations
- **Use Cases**:
  - **Callouts**: Add speech bubbles and annotation callouts
  - **Emojis**: Insert emoji graphics (if you have SVG emoji files)
  - **Icons**: Add custom icons or symbols
  - **Diagrams**: Import diagram elements
  - **Logos**: Add branding or watermarks
- **Behavior**:
  - SVG is imported as a selectable, moveable annotation
  - Can be resized using Alt+Plus/Minus keys when selected
  - Maintains vector quality at any size
  - Multiple SVGs can be imported to the same image
- **Note**: SVG files must be valid XML-based SVG format

#### Close Image
- **Icon**: X/Close icon
- **Function**: Closes the current image
- **Safety**: Prompts you to save if there are unsaved changes
- **Result**: Returns to empty state, ready to open a new image

### Edit Operations

#### Undo
- **Icon**: Curved arrow pointing left
- **Function**: Reverses your last action
- **Shortcut**: Ctrl+Z
- **Scope**: Up to 50 levels of undo
- **Works With**: All drawing operations, modifications, deletions, pastes
- **Disabled When**: No actions to undo (grayed out)

#### Redo
- **Icon**: Curved arrow pointing right
- **Function**: Reapplies an action you just undid
- **Shortcut**: Ctrl+Shift+Z
- **Note**: Redo stack is cleared when you make a new modification
- **Disabled When**: No actions to redo (grayed out)

#### Copy
- **Icon**: Two overlapping rectangles
- **Function**: Copies selected annotation(s) to clipboard
- **Shortcut**: Ctrl+C
- **Usage**: Select one or more annotations, then click Copy
- **Multiple Selection**: Hold Ctrl and click multiple items to copy them all
- **Note**: Only copies annotations, not the base image

#### Cut
- **Icon**: Scissors
- **Function**: Cuts selected annotation(s) to clipboard and removes them from canvas
- **Shortcut**: Ctrl+X
- **Usage**: Select annotation(s), then click Cut
- **Result**: Annotation(s) removed from image but available for pasting

#### Paste
- **Icon**: Clipboard
- **Function**: Pastes previously copied or cut annotation(s)
- **Shortcut**: Ctrl+V
- **Behavior**:
  - Pasted items appear slightly offset from original position
  - Can paste multiple times
  - Pasted items become the new selection
- **Note**: Only pastes annotations, not external clipboard images

#### Clear
- **Icon**: Eraser or Clear icon
- **Function**: Removes ALL annotations from the image
- **Safety**: No confirmation dialog (but can be undone)
- **Use Case**: Start over with annotations while keeping the base image
- **Shortcut**: Ctrl+L

#### Delete
- **Icon**: Trash can
- **Function**: Deletes currently selected annotation(s)
- **Shortcut**: Delete key
- **Multiple Delete**: Select multiple items (Ctrl+click) and delete all at once
- **Can Be Undone**: Yes (Ctrl+Z)

### Zoom Controls

#### Zoom In
- **Icon**: Magnifying glass with plus
- **Function**: Increases image magnification
- **Shortcut**: Ctrl+Plus (or Ctrl+=)
- **Behavior**: Zooms in centered on current view
- **Limits**: Can zoom up to very large magnifications

#### Zoom Out
- **Icon**: Magnifying glass with minus
- **Function**: Decreases image magnification
- **Shortcut**: Ctrl+Minus
- **Behavior**: Zooms out centered on current view
- **Limits**: Minimum zoom shows entire image

#### Original Size
- **Icon**: 1:1 or 100% icon
- **Function**: Resets zoom to actual pixel size (100%, 1:1)
- **Shortcut**: Ctrl+1
- **Use Case**: View image at true resolution for pixel-perfect work
- **HiDPI**: Properly handles high-DPI displays and fractional scaling

#### Best Fit
- **Icon**: Fit-to-window icon
- **Function**: Adjusts zoom to fit entire image in window
- **Shortcut**: Ctrl+2
- **Behavior**: Automatically calculates optimal zoom level
- **Smart**: Maintains aspect ratio, adds padding
- **Auto-Applied**: Automatically applied when opening new images

### File Output

#### Save As
- **Icon**: Floppy disk or save icon
- **Function**: Exports the annotated image as a new image file
- **Shortcut**: Ctrl+S
- **Formats**: PNG (default), JPEG, BMP, WebP
- **Default Name**: `{original_name}_annotated.png`
- **Note**: This exports a flattened image (annotations become permanent)
- **Different From**: Save Project (which saves editable .linia file)

#### Print
- **Icon**: Printer icon
- **Function**: Opens print dialog to print the annotated image
- **Shortcut**: Ctrl+P
- **Options**: Select printer, paper size, orientation, quality
- **Preview**: Shows preview before printing

#### Exit
- **Icon**: Door/Exit icon
- **Function**: Closes Linia application
- **Safety**: Prompts to save if there are unsaved changes
- **Shortcut**: Ctrl+Q
- **Saves**: Window dimensions and tool states automatically

---

## Drawing Toolbar

The Drawing Toolbar contains all the annotation and drawing tools. It can be positioned horizontally at the top (default) or vertically on the left side. Each tool is a toggle button that becomes active when clicked.

### Selection and Manipulation

#### Select Tool
- **Icon**: Cursor/arrow pointer
- **Shortcut**: V
- **Function**: Default tool for selecting and moving annotations
- **Usage**:
  - **Click**: Select a single annotation
  - **Click and Drag**: Move selected annotation(s)
  - **Ctrl+Click**: Add/remove annotations from selection (multi-select)
  - **Click Empty Area**: Deselect all
- **Selected Items**: Show control handles for resizing/rotation
- **Right-Click**: Opens context menu with layer ordering options (Bring to Front, Send to Back, etc.)

#### Crop Tool
- **Icon**: Crop/frame icon
- **Shortcut**: C
- **Function**: Crops the image to a selected rectangular region
- **Usage**:
  1. Click and drag to define crop region (dotted rectangle appears)
  2. Adjust crop area by dragging corners/edges
  3. Press **Enter** to apply the crop
  4. Press **Escape** to cancel crop
- **Note**: Cropping is destructive and applies to the base image
- **Can Be Undone**: Yes, but affects the entire image

### Line Drawing Tools

#### Line Tool
- **Icon**: Diagonal line
- **Shortcut**: L
- **Function**: Draws straight lines
- **Usage**: Click starting point, drag to endpoint, release
- **Constraints**:
  - **Ctrl+Drag**: Horizontal line only
  - **Shift+Drag**: Vertical line only
- **Styling**: Respects current line width, stroke color, and line style (solid/dashed/dotted)

#### Single Arrow Tool
- **Icon**: Line with single arrowhead
- **Shortcut**: A
- **Function**: Draws an arrow pointing from start to end
- **Usage**: Click starting point, drag to endpoint, release
- **Constraints**: Same as Line tool (Ctrl for horizontal, Shift for vertical)
- **Styling**: Arrow size scales with line width
- **Direction**: Arrowhead appears at the end point

#### Double Arrow Tool
- **Icon**: Line with arrowheads on both ends
- **Shortcut**: Shift+A
- **Function**: Draws a line with arrows on both ends
- **Usage**: Click starting point, drag to endpoint, release
- **Use Case**: Show bidirectional relationships or measurements
- **Styling**: Both arrows scale with line width

### Basic Shape Tools

#### Rectangle Tool
- **Icon**: Rectangle shape
- **Shortcut**: R
- **Function**: Draws rectangles and squares
- **Usage**: Click corner point, drag to opposite corner, release
- **Constraint**:
  - **Ctrl+Drag**: Forces square (equal width and height)
- **Styling**:
  - **Fill**: Uses fill color with transparency
  - **Stroke**: Uses stroke color and line width
  - **Border Style**: Respects line style (solid/dashed/dotted)

#### Ellipse Tool
- **Icon**: Oval/circle shape
- **Shortcut**: E
- **Function**: Draws ellipses and circles
- **Usage**: Click center area, drag to define size, release
- **Constraint**:
  - **Ctrl+Drag**: Forces perfect circle
- **Styling**: Same as Rectangle (fill, stroke, line style)
- **Note**: Ellipse is defined by bounding box

### Polygon Tools

#### Triangle Tool
- **Icon**: Triangle shape
- **Shortcut**: T
- **Function**: Draws equilateral or isosceles triangles
- **Usage**: Click base start point, drag to define size and orientation
- **Constraint**:
  - **Ctrl+Drag**: Forces equilateral triangle
- **Styling**: Fill and stroke like other shapes
- **Orientation**: Base is horizontal by default

#### Tetragon Tool
- **Icon**: Four-sided polygon (quadrilateral)
- **Shortcut**: 4
- **Function**: Draws regular tetragons (four equal sides)
- **Usage**: Click starting point, drag to define size
- **Constraint**:
  - **Ctrl+Drag**: Forces perfect square orientation
- **Styling**: Fill and stroke
- **Shape**: Regular four-sided polygon with equal sides

#### Pentagon Tool
- **Icon**: Five-sided polygon
- **Shortcut**: 5
- **Function**: Draws regular pentagons (five equal sides)
- **Usage**: Click center area, drag to define size
- **Constraint**:
  - **Ctrl+Drag**: Forces uniform scaling
- **Styling**: Fill and stroke
- **Shape**: Regular five-sided polygon

### 3D Shape Tools

#### Pyramid Tool
- **Icon**: 3D pyramid
- **Shortcut**: Shift+P
- **Function**: Draws a 3D pyramid with proper lighting and shading
- **Usage**: Click base position, drag to define size and height
- **Features**:
  - **Automatic Lighting**: Faces have realistic shading based on orientation
  - **Perspective**: 3D projection gives depth
  - **Face Visibility**: Only visible faces are rendered
- **Styling**: Uses fill color with automatic lighting calculation
- **Note**: Creates a true 3D effect with proper face occlusion

#### Cuboid Tool
- **Icon**: 3D box/cube
- **Shortcut**: Shift+C
- **Function**: Draws a 3D rectangular box with proper lighting
- **Usage**: Click starting point, drag to define size and perspective
- **Features**:
  - **Three Visible Faces**: Front, top, and right side (typically)
  - **Automatic Lighting**: Each face has different brightness
  - **Face Occlusion**: Hidden faces are not drawn
  - **Perspective Lines**: Edges converge for 3D effect
- **Constraint**:
  - **Ctrl+Drag**: Forces cube (equal dimensions)
- **Styling**: Uses fill color with lighting for each face

### Freehand and Highlighting

#### Freehand Tool
- **Icon**: Pencil or brush
- **Shortcut**: F
- **Function**: Draw freeform lines by hand
- **Usage**: Click and drag freely to draw
- **Release**: Completes the freehand stroke
- **Styling**:
  - Uses current stroke color
  - Respects line width
  - Smooth line rendering
- **Use Cases**: Sketches, annotations, underlining, circling

#### Highlighter Tool
- **Icon**: Highlighter marker
- **Shortcut**: H
- **Function**: Draws semi-transparent highlight strokes
- **Usage**: Click and drag to highlight
- **Behavior**: Similar to freehand but with transparency
- **Styling**:
  - Uses stroke color with reduced opacity (~50%)
  - Wider default stroke
  - Overlapping areas compound transparency
- **Use Case**: Emphasize important areas without obscuring text/content

### Text and Annotation

#### Text Tool
- **Icon**: Letter 'A' or text icon
- **Shortcut**: X
- **Function**: Adds text labels and annotations
- **Usage**:
  1. Click where you want to place text
  2. Type your text
  3. Click outside or press Escape when done
- **Editing**: Click existing text to edit it
- **Styling**:
  - Font: Selected via Widget Toolbar font button
  - Size: Part of font selection
  - Color: Uses stroke color
- **Formatting**: Plain text only (no rich text/markdown)
- **Selection**: Text can be moved and resized after creation

#### Number Tool
- **Icon**: Circle with number
- **Shortcut**: N
- **Function**: Adds numbered circles (auto-incrementing)
- **Usage**: Click location to place numbered circle
- **Behavior**:
  - First circle is numbered "1"
  - Each additional circle increments: 2, 3, 4, etc.
  - Number resets when image is closed
- **Styling**:
  - Circle: Uses fill and stroke colors
  - Number: White text, centered
- **Sizing**: Radius adjustable in Settings
- **Use Case**: Step-by-step tutorials, ordered annotations

### Special Effect Tools

#### Magnifier Tool
- **Icon**: Magnifying glass
- **Shortcut**: M
- **Function**: Creates a circular magnified view of an image region
- **Usage**: Click location to place magnifier
- **Features**:
  - Shows zoomed-in view of underlying image
  - Magnification level adjustable (default 2x)
  - Circular lens effect
  - Border shows magnified area
- **Resizing**: Alt+Plus/Minus to change magnifier size
- **Adjustments**: Settings control default radius and zoom level
- **Use Case**: Show detail in screenshots, emphasize small text/icons

#### Pixelize Tool
- **Icon**: Pixelated grid
- **Shortcut**: Shift+X
- **Function**: Applies pixelization effect to obscure regions
- **Usage**: Click and drag to define rectangular area to pixelize
- **Effect**: Reduces resolution dramatically (creates large "pixels")
- **Use Cases**:
  - Hide sensitive information (passwords, personal data)
  - Anonymize faces
  - Obscure private content in screenshots
- **Adjustable**: Pixelization level is fixed but can be reapplied
- **Note**: Effect is baked into the image; select and delete to remove

---

## Widget Toolbar

The Widget Toolbar contains all the style controls and parameters for drawing tools. These controls affect newly created items and can modify selected existing items.

### Line Properties

#### Line Style Dropdown
- **Control**: Combo box dropdown
- **Options**:
  - **Solid Line**: Continuous, unbroken line (default)
  - **Dashed Line**: Evenly spaced dashes (4px dash, 4px gap)
  - **Dotted Line**: Small dots (1px dot, 2px gap)
  - **Dash Dot**: Alternating long dash and dot (6px, 3px, 1px, 3px)
  - **Long Dash**: Longer dashes (8px dash, 4px gap)
- **Applies To**: Lines, arrows, shape borders
- **Live Update**: Changes selected items immediately

#### Line Width Spinner
- **Control**: Numeric spinner with up/down arrows
- **Label**: "Width: "
- **Range**: 0.5 to 100.0 pixels
- **Default**: 3.0 pixels
- **Increment**: 0.5 pixels per click
- **Usage**: Type value or use arrows to adjust
- **Applies To**: All line-based tools, shape borders
- **Live Update**: Changes selected items immediately

### Color Properties

#### Fill Color Button
- **Control**: Color chooser button
- **Label**: "Fill: "
- **Function**: Sets interior color for filled shapes
- **Applies To**: Rectangles, ellipses, triangles, tetragons, pentagons, numbered circles, 3D shapes
- **Behavior**:
  - Click to open color picker
  - Choose from palette or custom RGB
  - Current color shown in button
- **Transparency**: Combined with Fill Transparency slider
- **Note**: Does not apply to lines, arrows, text

#### Fill Transparency Slider
- **Control**: Horizontal slider
- **Range**: 0% (fully transparent) to 100% (fully opaque)
- **Default**: 25% opacity (0.25)
- **Function**: Controls transparency of fill color
- **Usage**: Drag slider to adjust
- **Effect**:
  - 0%: Completely see-through (invisible fill)
  - 50%: Semi-transparent (common for overlays)
  - 100%: Solid color (no transparency)
- **Use Case**: Create overlay effects, show underlying content through shapes

#### Stroke Color Button
- **Control**: Color chooser button
- **Label**: "Stroke: "
- **Function**: Sets line and border color
- **Applies To**: All drawing tools (lines, arrows, shape borders, text, freehand)
- **Behavior**: Same as Fill Color button
- **Transparency**: Combined with Stroke Transparency slider

#### Stroke Transparency Slider
- **Control**: Horizontal slider
- **Range**: 0% (fully transparent) to 100% (fully opaque)
- **Default**: 100% opacity (1.0)
- **Function**: Controls transparency of stroke/line color
- **Usage**: Same as Fill Transparency slider
- **Effect**: Makes lines and borders more or less visible

### Text Properties

#### Font Button
- **Control**: Font selector button
- **Default**: "Sans 30"
- **Function**: Selects font family and size for text annotations
- **Behavior**:
  - Click to open font chooser dialog
  - Browse font families (Sans, Serif, Monospace, etc.)
  - Adjust font size with slider or number input
  - Preview shows sample text
- **Applies To**: Text tool annotations only
- **Live Update**: Changes selected text items immediately
- **System Fonts**: Uses fonts installed on your system

### Image Dimming

#### Dim Slider
- **Control**: Horizontal slider
- **Label**: "Dim: "
- **Range**: 0 (no dimming) to 100 (maximum dimming)
- **Default**: 0 (no effect)
- **Function**: Darkens the entire base image
- **Purpose**:
  - Makes annotations stand out more clearly
  - Reduces distraction from busy backgrounds
  - Improves contrast for bright images
- **Behavior**:
  - 0: Full brightness, no effect
  - 50: Moderate darkening
  - 100: Very dark, annotations highly emphasized
- **Global Effect**: Affects entire image, not individual annotations
- **Saved in Export**: Dimming is applied to exported images as an annotation effect
- **Smart Dimming**: Areas under filled shapes (rectangles, ellipses, polygons) remain undimmed, so annotations stay visible

---

## Working with Images

### Opening Images

1. **Via Main Toolbar**: Click "Open Image" button
2. **Via Menu**: File → Open Image
3. **Via Keyboard**: Press Ctrl+O
4. **File Browser**:
   - Defaults to ~/Pictures directory
   - Preview thumbnails while browsing
   - Filter for image files (PNG, JPEG, WebP, BMP)
5. **Auto-Fit**: Image automatically fits window on open

### Opening Recent Images

1. **Via Main Toolbar**: Click "Open Recent" button
2. **Via Menu**: File → Open Recent
3. **Recent List Features**:
   - Shows thumbnails for quick visual identification
   - Displays full file paths
   - Maintains up to 10 most recent files
   - Persists between application sessions
4. **Quick Access**: Click thumbnail to immediately open that image

### Viewing and Navigation

#### Zoom Operations
- **Zoom In**: Ctrl+Plus or toolbar button
- **Zoom Out**: Ctrl+Minus or toolbar button
- **Original Size**: Ctrl+1 (shows actual pixels)
- **Best Fit**: Ctrl+2 (fits entire image)
- **Mouse Wheel**: Scroll wheel zooms in/out
- **HiDPI**: Properly handles high-resolution displays

#### Panning
- **Middle Mouse Button**: Click and drag to pan
- **Shift+Left Mouse**: Hold Shift and drag to pan
- **Use Case**: Navigate large zoomed images

### Exporting Images

#### Save Image As
1. **Access**: Click "Save As" button or Ctrl+S
2. **File Dialog**:
   - Default name: `{original_name}_annotated.png`
   - Default format: PNG (lossless)
   - Can change to: JPEG, BMP, WebP
3. **Behavior**:
   - Renders all annotations onto base image
   - Creates flattened image file
   - Original image unchanged
4. **Use Case**: Create final output for sharing

#### Copy Image to Clipboard
1. **Access**: Edit → Copy Image or Ctrl+Shift+C
2. **Behavior**: Copies entire annotated image to system clipboard
3. **Usage**: Paste directly into other applications (email, chat, documents)
4. **Format**: Clipboard image (not file)

### Printing

1. **Access**: Click "Print" button or Ctrl+P
2. **Print Dialog**:
   - Select printer
   - Choose paper size
   - Set orientation (portrait/landscape)
   - Adjust quality settings
3. **Preview**: Shows how image will print
4. **Scaling**: Automatically fits to page

---

## Project Files (.linia)

### What Are .linia Files?

**.linia** project files are Linia's unique feature that sets it apart from other annotation tools. Unlike simple image exports, .linia files preserve:

- **Complete Editing History**: Every annotation, modification, and action
- **Persistent Undo/Redo**: Undo history is saved and restored
- **Layer Information**: All annotations remain as separate, editable objects
- **Tool Properties**: Colors, line widths, styles, and settings
- **Image References**: Link to original image file

Think of .linia files as "save files" for your annotation work—you can close the project, reopen it days later, and continue right where you left off with full undo capability intact.

### Saving Projects

#### Save Project
1. **Access**: File → Save Project or via main toolbar
2. **File Dialog**:
   - Choose location
   - Default name: `{image_name}.linia`
   - Extension: .linia
3. **What's Saved**:
   - All annotations and their properties
   - Undo/redo stack (up to 50 levels)
   - Current tool states
   - Image file reference
4. **File Size**: Usually very small (few KB) since it only stores vectors/metadata

#### When to Save Projects
- **Ongoing Work**: When you need to pause and return later
- **Iterative Edits**: When creating multiple versions
- **Collaboration**: Share editable projects with others
- **Archival**: Keep master copies before exporting finals
- **Complex Annotations**: When work is too valuable to lose

### Opening Projects

#### Open Existing Project
1. **Access**: File → Open Project
2. **File Dialog**: Browse and select .linia file
3. **Loading Process**:
   - Loads referenced image
   - Recreates all annotations
   - Restores undo/redo history
   - Restores tool states
4. **Dependencies**: Original image file must be accessible

#### Important Notes
- **Image Location**: If original image moved, you may need to relocate it
- **Undo History**: Full undo capability restored (up to 50 levels)
- **Continue Editing**: Can immediately continue making changes
- **Cross-Session**: Projects work across different application sessions

### Project Workflow Example

**Scenario**: Creating a tutorial with annotations

1. **Day 1**:
   - Open screenshot image
   - Add arrows, text, numbered circles
   - Save as `tutorial_page1.linia`
   - Export as `tutorial_page1_annotated.png`

2. **Day 2**:
   - Open `tutorial_page1.linia`
   - Undo last 3 annotations (client feedback)
   - Modify text color and positions
   - Add more annotations
   - Save project again (overwrites)
   - Export new PNG

3. **Day 3**:
   - Open same project
   - Make final tweaks
   - Export final version

**Benefit**: Complete editing flexibility without losing work or undo capability.

### Project vs. Image Export

| Feature | .linia Project | Exported Image |
|---------|---------------|----------------|
| **File Type** | JSON-based project file | PNG/JPEG/BMP/WebP |
| **Editability** | Fully editable | Flattened, permanent |
| **Undo History** | Preserved | Lost |
| **File Size** | Very small (KB) | Larger (image size) |
| **Annotations** | Separate layers | Baked into image |
| **Sharing** | Requires Linia to view | Universal image format |
| **Use Case** | Work in progress | Final deliverable |

**Best Practice**: Always save a .linia project before exporting final images. This gives you the ability to make changes later.

---

## Keyboard Shortcuts

### File Operations
| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open Image |
| `Ctrl+S` | Save Image As |
| `Ctrl+P` | Print |
| `Ctrl+W` | Close Image |
| `Ctrl+Q` | Exit Application |

### Edit Operations
| Shortcut | Action |
|----------|--------|
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` | Redo |
| `Ctrl+C` | Copy Annotation |
| `Ctrl+Shift+C` | Copy Image to Clipboard |
| `Ctrl+X` | Cut Annotation |
| `Ctrl+V` | Paste Annotation |
| `Ctrl+L` | Clear All Annotations |
| `Delete` | Delete Selected Annotation(s) |
| `Ctrl+A` | Select All Annotations |

### View Operations
| Shortcut | Action |
|----------|--------|
| `Ctrl+Plus` or `Ctrl+=` | Zoom In |
| `Ctrl+Minus` | Zoom Out |
| `Ctrl+1` | Original Size (100%) |
| `Ctrl+2` | Best Fit |
| `Ctrl+0` | Reset Zoom |
| `F11` | Fullscreen |

### Tool Selection
| Shortcut | Tool |
|----------|------|
| `V` | Select Tool |
| `C` | Crop Tool |
| `L` | Line Tool |
| `A` | Arrow Tool |
| `Shift+A` | Double Arrow Tool |
| `R` | Rectangle Tool |
| `E` | Ellipse Tool |
| `T` | Triangle Tool |
| `4` | Tetragon Tool |
| `5` | Pentagon Tool |
| `Shift+P` | Pyramid Tool |
| `Shift+C` | Cuboid Tool |
| `F` | Freehand Tool |
| `H` | Highlighter Tool |
| `X` | Text Tool |
| `N` | Number Tool |
| `M` | Magnifier Tool |
| `Shift+X` | Pixelize Tool |

### Drawing Modifiers
| Shortcut | Modifier |
|----------|----------|
| `Ctrl+Drag` | Constrain to Square/Circle/Equal Dimensions |
| `Ctrl+Drag` (Lines) | Horizontal Line |
| `Shift+Drag` (Lines) | Vertical Line |
| `Ctrl+Click` | Multi-Select (Add/Remove from Selection) |
| `Escape` | Cancel Current Operation |
| `Enter` | Apply (for Crop Tool) |

### Special Functions
| Shortcut | Action |
|----------|--------|
| `Middle Mouse + Drag` | Pan Image |
| `Shift+Left Mouse + Drag` | Pan Image (Alternative) |
| `Mouse Wheel` | Zoom In/Out |
| `Alt+Plus` | Increase SVG/Magnifier Size |
| `Alt+Minus` | Decrease SVG/Magnifier Size |

### Context Menu
| Shortcut | Action |
|----------|--------|
| `Right-Click` | Open Layer Context Menu |
| | - Bring to Front |
| | - Bring Forward |
| | - Send Backward |
| | - Send to Back |
| | - Delete |

---

## Tips and Best Practices

### Workflow Efficiency

1. **Learn Keyboard Shortcuts**: Master tool shortcuts (V, R, E, L, T, etc.) for rapid switching
2. **Use Recent Files**: Keep commonly-annotated screenshots in the recent list
3. **Save Projects Early**: Start with a .linia save before doing extensive annotation work
4. **Color Presets**: Set up your preferred fill and stroke colors at the start
5. **Multi-Select**: Use Ctrl+Click to select and modify multiple annotations at once

### Professional Results

1. **Consistent Styling**: Use the same colors and line widths throughout a set of images
2. **Dimming**: Apply 20-30% dim for busy screenshots to make annotations pop
3. **Layer Order**: Use right-click context menu to arrange annotations properly
4. **Number Annotations**: Use the Number tool for step-by-step tutorials
5. **Text Legibility**: Choose clear fonts at appropriate sizes (30pt minimum for screenshots)

### Performance

1. **Large Images**: Use Best Fit zoom for overview, Original Size for detail work
2. **Complex Annotations**: Save projects periodically to preserve work
3. **Undo Limit**: Remember only 50 levels—export if going beyond that
4. **SVG Size**: Import reasonably-sized SVGs; resize with Alt+Plus/Minus as needed

### Common Use Cases

#### Screenshot Tutorials
1. Take screenshot
2. Open in Linia
3. Use Number tool for steps
4. Add arrows to point out UI elements
5. Add text labels for explanations
6. Save as .linia project
7. Export as PNG

#### Bug Reports
1. Open problematic screenshot
2. Use Rectangle tool to highlight issue area
3. Use Arrow tool to point out specific problem
4. Add Text annotation with description
5. Use Pixelize on any sensitive data
6. Copy Image to Clipboard (Ctrl+Shift+C)
7. Paste directly into bug tracker

#### Image Markup
1. Open image
2. Use Freehand or Highlighter to mark areas
3. Add text notes
4. Dim background if needed (20-30%)
5. Export or copy to clipboard

#### Technical Diagrams
1. Import base diagram image
2. Add arrows to show flow
3. Use numbered circles for sequence
4. Import SVG callouts/icons
5. Add text labels
6. Save project for iterations
7. Export final version

---

## Troubleshooting

### Image Not Opening
- **Check Format**: Ensure file is PNG, JPEG, WebP, or BMP
- **File Permissions**: Verify you have read access to the file
- **Corruption**: Try opening in another image viewer first

### Project File Won't Load
- **Image Location**: Original image must be in the same location as when project was saved
- **File Format**: Ensure file has .linia extension
- **Corruption**: If project is corrupted, it may not be recoverable

### Performance Issues
- **Large Images**: Very large images (>10000px) may be slow; consider resizing
- **Too Many Annotations**: Hundreds of annotations can slow rendering; group and flatten when possible
- **System Resources**: Close other applications if Linia is sluggish

### Zoom Problems
- **Zoom Too Small**: Use Ctrl+1 for Original Size or Ctrl+2 for Best Fit
- **Can't See Image**: If zoomed out too far, use Best Fit to reset
- **Blurry**: Ensure you're not zoomed beyond original resolution

### Saving Issues
- **No Write Permission**: Choose a location where you have write access
- **Disk Full**: Ensure adequate disk space
- **Path Too Long**: Keep filenames reasonably short

---

## Conclusion

Linia provides a comprehensive, professional-grade annotation solution for Linux users. Its centered interface design, persistent project files, and extensive drawing tools make it ideal for:

- Technical documentation
- Tutorial creation
- Bug reporting
- Image markup
- Educational materials
- Design review
- Screenshot annotation

The unique .linia project file system ensures your work is never lost and can always be edited, making Linia a reliable tool for both quick annotations and complex, iterative projects.

**Get Started**: Open an image, select a tool, and start annotating. Save your work as a .linia project, and export when ready. It's that simple!

---

**Version**: 1.0  
**Last Updated**: December 2025  
**Application**: Linia (Linux Image Annotator)
