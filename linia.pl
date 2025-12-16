#!/usr/bin/perl

# =============================================================================
# SECTION 1: GLOBAL STATE & INITIALIZATION
# =============================================================================

use strict;
use warnings;
use 5.10.1;

BEGIN {
    $SIG{__WARN__} = sub {
        my $message = shift;
        return if $message =~ /GLib-GObject-CRITICAL/;
        return if $message =~ /Subroutine .* redefined/;
        warn $message;
    };
    no warnings qw(redefine prototype);
}

use Glib qw/TRUE FALSE/;
use Gtk3;
use Gtk3 -init;
use Exporter;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
use Encode;
use Number::Bytes::Human;
use Cairo;
use Pango;
use POSIX qw/ strftime /;
use File::Copy qw/ cp mv /;
use File::Glob qw/ bsd_glob /;
use File::Basename qw/ fileparse dirname basename /;
use File::Temp qw/ tempfile tempdir /;
use File::Spec;
use File::Which;
use File::Copy::Recursive;
use IO::File();
use List::Util qw/ max min /;
use Time::HiRes qw/ time usleep /;
use Proc::Simple;
use Sort::Naturally;
use English;
use Image::Magick;
use Math::Trig;
use feature qw(say);
use JSON;
use Digest::MD5;
use File::HomeDir;
use Carp;

# --- Data Structures ---

my %items = (
    'lines' => [],
    'dashed-lines' => [],
    'arrows' => [],
    'rectangles' => [],
    'ellipses' => [],
    'triangles' => [],
    'tetragons' => [],
    'pentagons' => [],
    'pyramids' => [],
    'cuboids' => [],
    'numbered-circles' => [],
    'freehand-items' => [],
    'highlighter-lines' => [],
    'text_items' => [],
    'magnifiers' => [],
    'svg_items' => [],
    'pixelize_items' => []
);

my %line_styles = (
    'solid' => { name => 'Solid Line', pattern => [] },
    'dashed' => { name => 'Dashed Line', pattern => [4, 4] },
    'dotted' => { name => 'Dotted Line', pattern => [1, 2] },
    'dash-dot' => { name => 'Dash Dot', pattern => [6, 3, 1, 3] },
    'long-dash' => { name => 'Long Dash', pattern => [8, 4] }
);

# --- Application State ---

my $global_timestamp = 0;
my $current_line_style = 'solid';
my $save_counter = 1;
my $initial_file;
my $current_number = 1;
my $project_is_modified = 0;
my $max_undo_levels = 50;
my @undo_stack = ();
my @redo_stack = ();

# --- Drawing State ---

my @freehand_points = ();
my $last_tool_fill_color;
my $last_tool_stroke_color;
my $last_tool_line_width;
my $clipboard_item = undef;
my $clipboard_action = '';
my $drop_shadow_enabled = 0; 
my $shadow_offset_x = 3;   
my $shadow_offset_y = 3;   
my $shadow_blur = 3;       
my $shadow_alpha = 0.35;
my $shadow_base_color = Gtk3::Gdk::RGBA->new(0, 0, 0, 1.0);

# --- Visual Effects ---

my $dimming_level = 0;
my $fill_transparency_level = 0.25;
my $stroke_transparency_level = 1.0;

# --- Interaction State ---

my $hovered_handle = undef;
my $active_handle = undef;
my $is_zoom_fit_best = 0;
my $is_drawing = 0;
my $is_drawing_freehand = 0;
my $is_text_editing = 0;
my $is_panning = 0;
my $dragging = 0;
my $drag_handle = undef;

# --- UI Elements & Config ---

my $main_toolbar;
my $widget_toolbar;
my $main_toolbar_icon_size = 32;
my $drawing_toolbar_icon_size = 32;
my $drawing_toolbar_on_left = 0;
my ($main_toolbar_box, $drawing_toolbar_box, $drawing_toolbar);
my $drawing_toolbar_scrolled;
my ($main_vbox, $widget_toolbar_box);
my ($window, $drawing_area);
my $menu_bar_box;
my $menu_bar;
my @widget_toolbar_items = ();
my @selected_items = ();
my $is_multi_selecting = 0;

# --- Image & Canvas ---

my $current_image = undef;
my $image_surface = undef;
my $preview_surface = undef;
my $preview_ratio = 1.0;
my $scale_factor = 1.0;
my $loaded_image_name;
my $initial_scale_factor = 1.0;
my ($original_width, $original_height);

# --- Coordinates ---

my ($start_x, $start_y) = (0, 0);
my ($end_x, $end_y) = (0, 0);
my ($last_x, $last_y) = (0, 0);
my $pan_start_x = 0;
my $pan_start_y = 0;
my $pan_start_scroll_x = 0;
my $pan_start_scroll_y = 0;

# --- Tool State ---

my $current_mode = 'select';
my $current_tool = 'select';
my $last_tool = undef;
my $current_item = undef;
my $current_new_item = undef;
my $numbered_circle_number = undef;

# --- Performance ---

my $is_zooming_active = 0;
my $zoom_end_timeout = undef;

# --- Settings ---

my $window_width = 1100;
my $window_height = 800;
my $initial_tool = 'select';
my $font_size = 30;
my $font_family = "Sans";
my $font_style = "normal";
my $circle_radius = 50;
my $magnifier_radius = 100;
my $magnifier_zoom = 2.0;
my $handle_size = 5;
my $line_width = 3.0;
my $icon_theme = 'color';

# --- Paths ---

my @recent_files;
my $max_recent_files = 10;
my $recent_files_file = "$ENV{HOME}/.config/linia/recent_files.txt";
my $icon_sizes_file = "$ENV{HOME}/.config/linia/icon_sizes.txt";
my $window_config_file = "$ENV{HOME}/.config/linia/window_dimensions.txt";
my $tools_config_file = "$ENV{HOME}/.config/linia/tools_config.json";

# --- Tool Buttons ---

my %tool_buttons;
my %tool_widgets;

# --- Widgets ---

my $dimming_adjustment;
my $dimming_scale;
my $fill_transparency_adjustment;
my $fill_transparency_scale;
my $stroke_transparency_adjustment;
my $stroke_transparency_scale;
my $font_btn_w;
my $line_style_combo;
my $line_width_spin_button;
my $fill_color_button;
my $stroke_color_button;
my $open_recent_item; 
my $fill_css_provider;
my $stroke_css_provider;

# --- Text Cursor ---

my $cursor_visible = 1;
my $cursor_blink_timeout = undef;

# --- Colors ---

my $fill_color = Gtk3::Gdk::RGBA->new(0.21, 0.52, 0.89, 0.25);
my $stroke_color = Gtk3::Gdk::RGBA->new(255, 0, 0, 1);

my %toggle_tools = map { $_ => 1 } qw(
    select crop line single-arrow double-arrow
    rectangle ellipse triangle tetragon
    pentagon pyramid cuboid freehand highlighter text number magnifier pixelize
);

if (@ARGV) {
    $initial_file = $ARGV[0];
}

sub initialize_tool_state {
    $current_tool = $initial_tool;
    $current_mode = $initial_tool;

    %items = (
        'lines' => [],
        'dashed-lines' => [],
        'arrows' => [],
        'rectangles' => [],
        'ellipses' => [],
        'triangles' => [],
        'tetragons' => [],
        'pentagons' => [],
        'pyramids' => [],
        'cuboids' => [],
        'numbered-circles' => [],
        'freehand-items' => [],
        'highlighter-lines' => [],
        'text_items' => [],
        'magnifiers' => [],
        'svg_items' => [],
        'pixelize_items' => []
    );
    
    return;
}

# =============================================================================
# SECTION 2: UI & EVENT HANDLERS
# =============================================================================

load_window_dimensions();
load_icon_sizes();
load_tool_state();

$window = Gtk3::Window->new('toplevel');
$window->set_title('Linia');
$window->set_default_size($window_width, $window_height);

$menu_bar_box = Gtk3::Box->new('horizontal', 0);
$menu_bar_box->set_size_request(-1, 20);
$menu_bar_box->set_halign('center');

$main_toolbar_box = Gtk3::Box->new('horizontal', 0);
$main_toolbar_box->set_size_request(-1, $main_toolbar_icon_size + 20);
$main_toolbar_box->set_halign('center');

$drawing_toolbar_box = Gtk3::Box->new('horizontal', 0);
$drawing_toolbar_box->set_size_request(-1, $drawing_toolbar_icon_size + 20);
$drawing_toolbar_box->set_halign('center');

$widget_toolbar_box = Gtk3::Box->new('horizontal', 0);
$widget_toolbar_box->set_size_request(-1, -1);
$widget_toolbar_box->set_halign('center');

$main_vbox = Gtk3::Box->new('vertical', 0);

$drawing_area = Gtk3::DrawingArea->new;
$drawing_area->set_can_focus(TRUE);
$drawing_area->grab_focus();
$drawing_area->add_events([
    'button-press-mask',
    'button-release-mask',
    'pointer-motion-mask',
    'button1-motion-mask',
    'button2-motion-mask',
    'button3-motion-mask',
    'scroll-mask',
    'key-press-mask',
    'key-release-mask',
    'focus-change-mask'
]);

$menu_bar = Gtk3::MenuBar->new();

# --- File Menu Setup ---

my $file_menu = Gtk3::MenuItem->new_with_mnemonic('_File');
my $file_menu_item = Gtk3::Menu->new();
$file_menu->set_submenu($file_menu_item);

my $new_window_item = Gtk3::MenuItem->new_with_mnemonic('_New Window');
$new_window_item->signal_connect('activate' => sub { system($^X, $0, "&"); });

my $open_image_item = Gtk3::MenuItem->new_with_mnemonic('Open _Image');
$open_image_item->signal_connect('activate' => sub { open_image($window); });

my $open_project_item = Gtk3::MenuItem->new_with_mnemonic('Open _Project');
$open_project_item->signal_connect('activate' => sub { open_project($window); });

$open_recent_item = Gtk3::MenuItem->new_with_mnemonic('Open _Recent');

my $save_project_item = Gtk3::MenuItem->new_with_mnemonic('Save _Project');
$save_project_item->signal_connect('activate' => sub { save_project_as($window); });

my $save_as_item = Gtk3::MenuItem->new_with_mnemonic('Export Image _As');
$save_as_item->signal_connect('activate' => sub { save_image_as($window); });

my $print_item = Gtk3::MenuItem->new_with_mnemonic('_Print');
$print_item->signal_connect('activate' => sub { show_print_dialog($window); });

my $close_image_item = Gtk3::MenuItem->new_with_mnemonic('_Close Image');
$close_image_item->signal_connect('activate' => sub { close_image(); });

my $exit_item = Gtk3::MenuItem->new_with_mnemonic('_Exit');
$exit_item->signal_connect('activate' => sub {
    return unless check_unsaved_changes();
    save_window_dimensions();
    save_tool_state();
    Gtk3::main_quit();
});

$file_menu_item->append($new_window_item);
$file_menu_item->append($open_image_item);
$file_menu_item->append($open_project_item);
$file_menu_item->append($open_recent_item);
$file_menu_item->append(Gtk3::SeparatorMenuItem->new());
$file_menu_item->append($save_project_item);
$file_menu_item->append($save_as_item);
$file_menu_item->append(Gtk3::SeparatorMenuItem->new());
$file_menu_item->append($print_item);
$file_menu_item->append(Gtk3::SeparatorMenuItem->new());
$file_menu_item->append($close_image_item);
$file_menu_item->append($exit_item);

# --- Edit Menu Setup ---

my $edit_menu = Gtk3::MenuItem->new_with_mnemonic('_Edit');
my $edit_menu_item = Gtk3::Menu->new();
$edit_menu->set_submenu($edit_menu_item);

my $undo_item = Gtk3::MenuItem->new_with_mnemonic('_Undo');
$undo_item->signal_connect('activate' => \&undo_item);

my $redo_item = Gtk3::MenuItem->new_with_mnemonic('_Redo');
$redo_item->signal_connect('activate' => \&redo_item);

my $copy_item = Gtk3::MenuItem->new_with_mnemonic('_Copy');
$copy_item->signal_connect('activate' => \&copy_item);

my $copy_img_item = Gtk3::MenuItem->new_with_mnemonic('Copy _Image');
$copy_img_item->signal_connect('activate' => \&copy_image_to_clipboard);

my $cut_item = Gtk3::MenuItem->new_with_mnemonic('_Cut');
$cut_item->signal_connect('activate' => \&cut_item);

my $paste_item = Gtk3::MenuItem->new_with_mnemonic('_Paste');
$paste_item->signal_connect('activate' => \&paste_item);

my $clear_item = Gtk3::MenuItem->new_with_mnemonic('_Clear');
$clear_item->signal_connect('activate' => sub { clear_all_annotations(); });

my $delete_item = Gtk3::MenuItem->new_with_mnemonic('_Delete');
$delete_item->signal_connect('activate' => \&delete_item);

my $settings_item = Gtk3::MenuItem->new_with_mnemonic('_Settings');
$settings_item->signal_connect('activate' => sub { show_settings_dialog($window); });

$edit_menu_item->append($undo_item);
$edit_menu_item->append($redo_item);
$edit_menu_item->append(Gtk3::SeparatorMenuItem->new());
$edit_menu_item->append($copy_item);
$edit_menu_item->append($copy_img_item);
$edit_menu_item->append($cut_item);
$edit_menu_item->append($paste_item);
$edit_menu_item->append(Gtk3::SeparatorMenuItem->new());
$edit_menu_item->append($clear_item);
$edit_menu_item->append($delete_item);
$edit_menu_item->append(Gtk3::SeparatorMenuItem->new());
$edit_menu_item->append($settings_item);

# --- View Menu Setup ---

my $view_menu = Gtk3::MenuItem->new_with_mnemonic('_View');
my $view_menu_item = Gtk3::Menu->new();
$view_menu->set_submenu($view_menu_item);

my $toggle_main_toolbar = Gtk3::CheckMenuItem->new_with_mnemonic('Show _Main Toolbar');
$toggle_main_toolbar->set_active(TRUE);
$toggle_main_toolbar->signal_connect('toggled' => sub {
    my $visible = $toggle_main_toolbar->get_active();
    $main_toolbar_box->set_visible($visible);
});

my $move_drawing_toolbar = Gtk3::CheckMenuItem->new_with_mnemonic('Drawing Toolbar _Left');
$move_drawing_toolbar->signal_connect('toggled' => sub {
    my $move_left = $move_drawing_toolbar->get_active();
    $drawing_toolbar_on_left = $move_left;
    save_icon_sizes();

    my $canvas = $drawing_area->get_parent;
    while ($canvas && !$canvas->isa('Gtk3::ScrolledWindow')) {
        $canvas = $canvas->get_parent;
    }

    if ($drawing_toolbar->get_parent) { $drawing_toolbar->get_parent->remove($drawing_toolbar); }
    $drawing_toolbar_box->foreach(sub { $_[0]->destroy; });
    if ($drawing_toolbar_box->get_parent) { $drawing_toolbar_box->get_parent->remove($drawing_toolbar_box); }
    if ($widget_toolbar_box->get_parent) { $widget_toolbar_box->get_parent->remove($widget_toolbar_box); }
    
    my $canvas_parent = $canvas->get_parent;
    if ($canvas_parent) {
        $canvas_parent->remove($canvas);
        if ($canvas_parent ne $main_vbox) { $canvas_parent->destroy(); }
    }

    if ($move_left) {
        $drawing_toolbar->set_orientation('vertical');
        $drawing_toolbar->set_style('icons');
        $drawing_toolbar_box->set_orientation('vertical');
        $drawing_toolbar_box->set_size_request($drawing_toolbar_icon_size + 24, -1);

        my $scroll = Gtk3::ScrolledWindow->new();
        $scroll->set_policy('never', 'automatic');
        $scroll->set_shadow_type('none');
        $scroll->add($drawing_toolbar);
        $drawing_toolbar_box->pack_start($scroll, TRUE, TRUE, 0);

        my $hbox = Gtk3::Box->new('horizontal', 5);
        $hbox->pack_start($drawing_toolbar_box, FALSE, FALSE, 0);
        $hbox->pack_start($canvas, TRUE, TRUE, 0);

        $main_vbox->pack_start($widget_toolbar_box, FALSE, FALSE, 0);
        $main_vbox->pack_start($hbox, TRUE, TRUE, 0);
    } else {
        $drawing_toolbar->set_orientation('horizontal');
        $drawing_toolbar->set_style('icons');
        $drawing_toolbar_box->set_orientation('horizontal');
        $drawing_toolbar_box->set_size_request(-1, $drawing_toolbar_icon_size + 20);
        $drawing_toolbar_box->pack_start($drawing_toolbar, TRUE, TRUE, 0);

        $main_vbox->pack_start($drawing_toolbar_box, FALSE, FALSE, 0);
        $main_vbox->pack_start($widget_toolbar_box, FALSE, FALSE, 0);
        $main_vbox->pack_start($canvas, TRUE, TRUE, 0);
    }
    
    $window->show_all();
    Glib::Timeout->add(100, sub {
        if ($image_surface) {
            zoom_fit_best();
            update_drawing_area_size();
            $drawing_area->queue_draw();
        }
        return FALSE;
    });
});

$view_menu_item->append($move_drawing_toolbar);
$view_menu_item->append(Gtk3::SeparatorMenuItem->new());
$view_menu_item->append($toggle_main_toolbar);

my $zoom_in_item = Gtk3::MenuItem->new_with_mnemonic('Zoom _In');
$zoom_in_item->signal_connect('activate' => \&zoom_in);
my $zoom_out_item = Gtk3::MenuItem->new_with_mnemonic('Zoom _Out');
$zoom_out_item->signal_connect('activate' => \&zoom_out);
my $zoom_original_item = Gtk3::MenuItem->new_with_mnemonic('_Original Size');
$zoom_original_item->signal_connect('activate' => \&zoom_original);
my $zoom_fit_item = Gtk3::MenuItem->new_with_mnemonic('_Best Fit');
$zoom_fit_item->signal_connect('activate' => \&zoom_fit_best);

$view_menu_item->append(Gtk3::SeparatorMenuItem->new());
$view_menu_item->append($zoom_in_item);
$view_menu_item->append($zoom_out_item);
$view_menu_item->append($zoom_original_item);
$view_menu_item->append($zoom_fit_item);

$view_menu_item->append(Gtk3::SeparatorMenuItem->new());
my $main_icon_size_menu_item = Gtk3::MenuItem->new_with_mnemonic('_Main Toolbar Icon Size');
my $main_icon_size_menu = Gtk3::Menu->new();
$main_icon_size_menu_item->set_submenu($main_icon_size_menu);
my @icon_sizes = (16, 24, 32, 40, 48, 56, 64);
my $main_size_group = undef;
foreach my $size (@icon_sizes) {
    my $size_item = Gtk3::RadioMenuItem->new_with_label($main_size_group, "${size}x${size} pixels");
    $main_size_group = $size_item->get_group() unless $main_size_group;
    $size_item->set_active(1) if $size == $main_toolbar_icon_size;
    $size_item->signal_connect('toggled' => sub {
        if ($_[0]->get_active()) { update_main_toolbar_icon_size($size); }
    });
    $main_icon_size_menu->append($size_item);
}
$view_menu_item->append($main_icon_size_menu_item);

my $drawing_icon_size_menu_item = Gtk3::MenuItem->new_with_mnemonic('_Drawing Toolbar Icon Size');
my $drawing_icon_size_menu = Gtk3::Menu->new();
$drawing_icon_size_menu_item->set_submenu($drawing_icon_size_menu);
my $drawing_size_group = undef;
foreach my $size (@icon_sizes) {
    my $size_item = Gtk3::RadioMenuItem->new_with_label($drawing_size_group, "${size}x${size} pixels");
    $drawing_size_group = $size_item->get_group() unless $drawing_size_group;
    $size_item->set_active(1) if $size == $drawing_toolbar_icon_size;
    $size_item->signal_connect('toggled' => sub {
        if ($_[0]->get_active()) { update_drawing_toolbar_icon_size($size); }
    });
    $drawing_icon_size_menu->append($size_item);
}
$view_menu_item->append($drawing_icon_size_menu_item);

# --- Help Menu ---

my $help_menu = Gtk3::MenuItem->new_with_mnemonic('_Help');
my $help_menu_item = Gtk3::Menu->new();
$help_menu->set_submenu($help_menu_item);

my $shortcuts_item = Gtk3::MenuItem->new_with_mnemonic('_Keyboard Shortcuts');
$shortcuts_item->signal_connect('activate' => sub { show_shortcuts_dialog($window); });

my $about_item = Gtk3::MenuItem->new_with_mnemonic('_About');
$about_item->signal_connect('activate' => sub {
    my $dialog = Gtk3::MessageDialog->new($window, 'modal', 'info', 'ok', "Linia - Image Annotator\n\nA simple and fast annotation tool written in Perl and Gtk3.");
    $dialog->run();
    $dialog->destroy();
});

$help_menu_item->append($shortcuts_item);
$help_menu_item->append(Gtk3::SeparatorMenuItem->new());
$help_menu_item->append($about_item);

$menu_bar->append($file_menu);
$menu_bar->append($edit_menu);
$menu_bar->append($view_menu);
$menu_bar->append($help_menu);

$main_toolbar = Gtk3::Toolbar->new();
$main_toolbar->set_style('icons');
$main_toolbar->set_show_arrow(FALSE);

$drawing_toolbar = Gtk3::Toolbar->new();
$drawing_toolbar->set_style('icons');
$drawing_toolbar->set_show_arrow(FALSE);

$drawing_toolbar_scrolled = Gtk3::ScrolledWindow->new();
$drawing_toolbar_scrolled->set_policy('never', 'automatic');
$drawing_toolbar_scrolled->set_shadow_type('none');

$widget_toolbar = Gtk3::Toolbar->new();
$widget_toolbar->set_icon_size('small-toolbar');
$widget_toolbar->set_style('icons');
$widget_toolbar->set_show_arrow(TRUE);

# --- Populate Main Toolbar ---

my @main_toolbar_items = (
    { name => "image-open", label => "Open Image", tooltip => "Open image", group => "tools" },
    { name => "image-open-recent", label => "Open Recent", tooltip => "Open recent image", group => "tools", is_widget => 1 },
    { name => "svg-import", label => "Import SVG", tooltip => "Import SVG file", group => "tools" },
    { name => "image-close", label => "Close Image", tooltip => "Close image", group => "tools" },
    { name => "undo", label => "Undo", tooltip => "Undo annotation", group => "tools" },
    { name => "redo", label => "Redo", tooltip => "Redo annotation", group => "tools" },
    { name => "copy", label => "Copy", tooltip => "Copy annotation", group => "tools" },
    { name => "cut", label => "Cut", tooltip => "Cut annotation", group => "tools" },
    { name => "paste", label => "Paste", tooltip => "Paste annotation", group => "tools" },
    { name => "clear", label => "Clear", tooltip => "Clear all annotations", group => "tools" },
    { name => "delete", label => "Delete", tooltip => "Delete annotation", group => "tools" },
    { name => "zoom-in", label => "Zoom In", tooltip => "Zoom in (Ctrl+Plus)", group => "zoom" },
    { name => "zoom-out", label => "Zoom Out", tooltip => "Zoom out (Ctrl+Minus)", group => "zoom" },
    { name => "zoom-original", label => "Original Size", tooltip => "Original size (Ctrl+1)", group => "zoom" },
    { name => "zoom-fit-best", label => "Best Fit", tooltip => "Best fit (Ctrl+2)", group => "zoom" },
    { name => "save-as", label => "Save As", tooltip => "Save image as", group => "tools" },
    { name => "print", label => "Print", tooltip => "Print image", group => "tools" },
    { name => "exit", label => "Exit", tooltip => "Exit application", group => "tools" },
);

my @separator_after = qw(image-open image-open-recent svg-import image-close undo redo copy cut paste clear delete zoom-in zoom-out zoom-fit-best save-as print exit);

foreach my $item (@main_toolbar_items) {
    if ($item->{is_widget}) {
        if ($item->{name} eq 'image-open-recent') {
            my $tool_item = create_open_recent_button($main_toolbar_icon_size);
            $main_toolbar->insert($tool_item, -1);
            $tool_buttons{$item->{name}} = $tool_item;
        }
    } else {
        my $image = load_icon($item->{name}, $main_toolbar_icon_size);
        if ($image) { $image->set_size_request($main_toolbar_icon_size, $main_toolbar_icon_size); }
        
        my $tool_item = Gtk3::ToolButton->new($image, $item->{label});
        $tool_item->set_tooltip_text($item->{tooltip}) if $item->{tooltip};

        if ($item->{name} =~ /^zoom-/) {
             my $cb = $item->{name} eq 'zoom-in' ? \&zoom_in :
                      $item->{name} eq 'zoom-out' ? \&zoom_out :
                      $item->{name} eq 'zoom-original' ? \&zoom_original : \&zoom_fit_best;
             $tool_item->signal_connect('clicked' => $cb);
        } else {
             $tool_item->signal_connect('clicked' => sub { handle_main_toolbar_action($item->{name}); });
        }
        $tool_buttons{$item->{name}} = $tool_item;
        $main_toolbar->insert($tool_item, -1);
    }
    if (grep { $_ eq $item->{name} } @separator_after) {
        $main_toolbar->insert(Gtk3::SeparatorToolItem->new(), -1);
    }
}

# --- Populate Drawing Toolbar ---

my @drawing_toolbar_items = (
    { name => "select", label => "Select", tooltip => "Select area", group => "tools" },
    { type => "separator" },
    { name => "crop", label => "Crop", tooltip => "Crop Image (Enter to Apply)", group => "tools" },
    { type => "separator" },
    { name => "line", label => "Line", tooltip => "Draw line", group => "tools" },
    { type => "separator" },
    { name => "single-arrow", label => "Arrow", tooltip => "Draw arrows", group => "tools" },
    { type => "separator" },
    { name => "double-arrow", label => "Double Arrow", tooltip => "Draw double arrows", group => "tools" },
    { type => "separator" },
    { name => "rectangle", label => "Rectangle", tooltip => "Draw rectangle", group => "tools" },
    { type => "separator" },
    { name => "ellipse", label => "Ellipse", tooltip => "Draw ellipse", group => "tools" },
    { type => "separator" },
    { name => "triangle", label => "Triangle", tooltip => "Draw triangle", group => "tools" },
    { type => "separator" },
    { name => "tetragon", label => "Tetragon", tooltip => "Draw tetragon", group => "tools" },
    { type => "separator" },
    { name => "pentagon", label => "Pentagon", tooltip => "Draw pentagon", group => "tools" },
    { type => "separator" },
    { name => "pyramid", label => "Pyramid", tooltip => "Draw pyramid", group => "tools" },
    { type => "separator" },
    { name => "cuboid", label => "Cuboid", tooltip => "Draw cuboid", group => "tools" },
    { type => "separator" },
    { name => "freehand", label => "Freehand", tooltip => "Freehand drawing", group => "tools" },
    { type => "separator" },
    { name => "highlighter", label => "Highlight", tooltip => "Highlight area", group => "tools" },
    { type => "separator" },
    { name => "text", label => "Text", tooltip => "Add text", group => "tools" },
    { type => "separator" },
    { name => "number", label => "Number", tooltip => "Add numbered circle", group => "tools" },
    { type => "separator" },
    { name => "magnifier", label => "Magnifier", tooltip => "Add magnifier", group => "tools" },
    { type => "separator" },
    { name => "pixelize", label => "Pixelize", tooltip => "Pixelize area", group => "tools" },
);

my $first_draw_item = 1;
foreach my $item (@drawing_toolbar_items) {
    if ($item->{type} && $item->{type} eq 'separator') {
        $drawing_toolbar->insert(Gtk3::SeparatorToolItem->new(), -1);
    } else {
        my $tool_item = create_tool_button($item, $drawing_toolbar_icon_size);
        $tool_buttons{$item->{name}} = $tool_item;
        
        if ($tool_item->isa('Gtk3::ToggleToolButton')) {
            $tool_item->signal_connect('toggled' => sub { handle_tool_selection($tool_item, $item->{name}); });
        }
        $drawing_toolbar->insert($tool_item, -1);
    }
}

# --- Populate Widget Toolbar ---

$line_style_combo = Gtk3::ComboBoxText->new();
foreach my $style_id (sort keys %line_styles) { $line_style_combo->append($style_id, $line_styles{$style_id}{name}); }
$line_style_combo->set_active_id('solid');
$line_style_combo->signal_connect('changed' => sub {
    $current_line_style = $line_style_combo->get_active_id();
    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    foreach my $item (@targets) {
        next unless $item->{selected};
        store_state_for_undo('modify', clone_item($item));
        $item->{line_style} = $current_line_style;
    }
    $drawing_area->queue_draw() if @targets;
});
my $style_item = Gtk3::ToolItem->new(); 
my $style_box = Gtk3::Box->new('horizontal', 2);
$style_box->pack_start($line_style_combo, FALSE, FALSE, 0);
$style_item->add($style_box);

my $width_adjustment = Gtk3::Adjustment->new(3.0, 0.5, 100.0, 0.5, 10.0, 0.0);
$line_width_spin_button = Gtk3::SpinButton->new($width_adjustment, 0.5, 1);
$line_width_spin_button->signal_connect('value-changed' => sub {
    $line_width = $line_width_spin_button->get_value();
    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    foreach my $item (@targets) {
        next unless $item->{selected};
        store_state_for_undo('modify', clone_item($item));
        $item->{line_width} = $line_width;
    }
    $drawing_area->queue_draw() if @targets;
});
my $width_item = Gtk3::ToolItem->new();
my $width_box = Gtk3::Box->new('horizontal', 2);
$width_box->pack_start(Gtk3::Label->new('Width: '), FALSE, FALSE, 0);
$width_box->pack_start($line_width_spin_button, FALSE, FALSE, 0);
$width_item->add($width_box);

$fill_color_button = Gtk3::ColorButton->new_with_rgba($fill_color);
$fill_color_button->signal_connect('color-set' => sub {
 
    my $picked = $fill_color_button->get_rgba();

    my $current_alpha = $fill_transparency_scale ? $fill_transparency_scale->get_value() : $fill_color->alpha;

    my $final_color = Gtk3::Gdk::RGBA->new($picked->red, $picked->green, $picked->blue, $current_alpha);
    $fill_color = $final_color;

    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    foreach my $item (@targets) {
        next unless $item->{selected};
        if ($item->{type} =~ /^(rectangle|ellipse|triangle|tetragon|pentagon|numbered-circle|pyramid|cuboid)$/) {
            store_state_for_undo('modify', clone_item($item));
            $item->{fill_color} = $final_color->copy();
        }
    }
    $drawing_area->queue_draw() if @targets;
});
my $fill_item = Gtk3::ToolItem->new();
my $fill_box = Gtk3::Box->new('horizontal', 2);
$fill_box->pack_start(Gtk3::Label->new('Fill: '), FALSE, FALSE, 0);
$fill_box->pack_start($fill_color_button, FALSE, FALSE, 0);
$fill_item->add($fill_box);

$stroke_color_button = Gtk3::ColorButton->new_with_rgba($stroke_color);
$stroke_color_button->signal_connect('color-set' => sub {

    my $picked = $stroke_color_button->get_rgba();

    my $current_alpha = $stroke_transparency_scale ? $stroke_transparency_scale->get_value() : $stroke_color->alpha;

    my $final_color = Gtk3::Gdk::RGBA->new($picked->red, $picked->green, $picked->blue, $current_alpha);
    $stroke_color = $final_color;

    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    foreach my $item (@targets) {
        next unless $item->{selected};
        store_state_for_undo('modify', clone_item($item));
        $item->{stroke_color} = $final_color->copy();
    }
    $drawing_area->queue_draw() if @targets;
});
my $stroke_item = Gtk3::ToolItem->new();
my $stroke_box = Gtk3::Box->new('horizontal', 2);
$stroke_box->pack_start(Gtk3::Label->new('Stroke: '), FALSE, FALSE, 0);
$stroke_box->pack_start($stroke_color_button, FALSE, FALSE, 0);
$stroke_item->add($stroke_box);

$font_btn_w = Gtk3::FontButton->new();
$font_btn_w->set_font_name("Sans 30");
$font_btn_w->signal_connect('font-set' => sub {
    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    foreach my $item (@targets) {
        next unless $item->{selected};
        if ($item->{type} eq 'text') {
            store_state_for_undo('modify', clone_item($item));
            $item->{font} = $font_btn_w->get_font_name();
        }
    }
    $drawing_area->queue_draw() if @targets;
});
my $font_item = Gtk3::ToolItem->new();
$font_item->add($font_btn_w);

$dimming_adjustment = Gtk3::Adjustment->new(0, 0, 100, 1, 10, 0);
$dimming_scale = Gtk3::Scale->new_with_range('horizontal', 0, 100, 1);
$dimming_scale->set_adjustment($dimming_adjustment);
$dimming_scale->set_size_request(100, -1);
$dimming_scale->set_draw_value(FALSE);
$dimming_scale->signal_connect('value-changed' => sub {
    $dimming_level = $dimming_scale->get_value();
    $drawing_area->queue_draw();
});
my $dim_item = Gtk3::ToolItem->new();
my $dim_box = Gtk3::Box->new('horizontal', 2);
$dim_box->pack_start(Gtk3::Label->new('Dim: '), FALSE, FALSE, 0);
$dim_box->pack_start($dimming_scale, FALSE, FALSE, 0);
$dim_item->add($dim_box);

my $shadow_check = Gtk3::CheckButton->new_with_label('Shadow');
$shadow_check->set_active($drop_shadow_enabled);
$shadow_check->set_tooltip_text('Toggle drop shadow for selected item.');

$shadow_check->signal_connect('toggled' => sub {
    $drop_shadow_enabled = $shadow_check->get_active();
    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    
    foreach my $item (@targets) {
        next unless $item->{selected};
        store_state_for_undo('modify', clone_item($item));
        $item->{drop_shadow} = $drop_shadow_enabled;
        $item->{shadow_offset_x} = $shadow_offset_x;
        $item->{shadow_offset_y} = $shadow_offset_y;
        $item->{shadow_blur} = $shadow_blur;
        $item->{shadow_alpha} = $shadow_alpha;
        $item->{shadow_color} = $shadow_base_color->copy();
    }
    
    $drawing_area->queue_draw() if @targets;
});

my $shadow_settings_btn = Gtk3::Button->new_from_icon_name('preferences-system-symbolic', 'menu');
$shadow_settings_btn->set_relief('none');
$shadow_settings_btn->set_tooltip_text('Configure drop shadow properties.');

$shadow_settings_btn->signal_connect('clicked' => sub {
  
    show_shadow_settings_dialog($window);
});

my $shadow_box = Gtk3::Box->new('horizontal', 2);
$shadow_box->pack_start($shadow_check, FALSE, FALSE, 0);
$shadow_box->pack_start($shadow_settings_btn, FALSE, FALSE, 0);

my $shadow_item = Gtk3::ToolItem->new();
$shadow_item->add($shadow_box);

$widget_toolbar->insert($style_item, -1);
$widget_toolbar->insert($width_item, -1);
$widget_toolbar->insert($fill_item, -1);
$widget_toolbar->insert(create_fill_transparency_slider(), -1);
$widget_toolbar->insert($stroke_item, -1);
$widget_toolbar->insert(create_stroke_transparency_slider(), -1);
$widget_toolbar->insert($font_item, -1);
$widget_toolbar->insert($dim_item, -1);
$widget_toolbar->insert($shadow_item, -1);

$menu_bar_box->pack_start($menu_bar, TRUE, TRUE, 0);
$main_toolbar_box->pack_start($main_toolbar, TRUE, TRUE, 0);
$drawing_toolbar_box->pack_start($drawing_toolbar, TRUE, TRUE, 0);
$widget_toolbar_box->pack_start($widget_toolbar, TRUE, TRUE, 0);

$main_vbox->pack_start($menu_bar_box, FALSE, FALSE, 0);
$main_vbox->pack_start($main_toolbar_box, FALSE, FALSE, 0);
$main_vbox->pack_start($drawing_toolbar_box, FALSE, FALSE, 0);
$main_vbox->pack_start($widget_toolbar_box, FALSE, FALSE, 0);

my $scrolled_window = create_scrolled_window();
$main_vbox->pack_start($scrolled_window, TRUE, TRUE, 0);

initialize_tool_state();
$window->add($main_vbox);


sub handle_tool_selection {
    my ($tool_item, $tool_name) = @_;

    if ($tool_item->isa('Gtk3::ToggleToolButton') && $tool_item->get_active()) {
    
        if ($tool_name ne 'crop') {
            if (exists $items{rectangles}) {
                @{$items{rectangles}} = grep { $_->{type} ne 'crop_rect' } @{$items{rectangles}};
            }
        }

        if ($current_tool eq 'text') {
            stop_cursor_blink();
            $is_text_editing = 0;
            if ($current_item && $current_item->{type} eq 'text') {
                cleanup_text_editing($current_item);
            }
        }

        foreach my $name (keys %tool_buttons) {
            next unless $tool_buttons{$name}->isa('Gtk3::ToggleToolButton');
            if ($name ne $tool_name) {
                $tool_buttons{$name}->set_active(FALSE);
            }
        }

        $is_drawing = 0;
        $is_drawing_freehand = 0;
        $dragging = 0;
        $drag_handle = undef;
        
        if ($tool_name ne 'select') {
            foreach my $type (keys %items) {
                next unless exists $items{$type} && defined $items{$type};
                foreach my $item (@{$items{$type}}) {
                    $item->{selected} = 0;
                    $item->{is_editing} = 0 if $type eq 'text_items';
                }
            }
            $current_item = undef;
        }

        $last_tool = $current_tool;
        $current_tool = $tool_name;
        $current_mode = $tool_name;

        if ($current_tool eq 'highlighter') {

            $last_tool_fill_color = $fill_color;
            $last_tool_stroke_color = $stroke_color;
            $last_tool_line_width = $line_width;

            my $highlighter_color = Gtk3::Gdk::RGBA->new(1, 1, 0, 0.5);
            $stroke_color = $highlighter_color;
            $line_width = 18;

            $stroke_color_button->set_rgba($highlighter_color);
            $line_width_spin_button->set_value($line_width);
            $fill_color_button->set_sensitive(FALSE);
        }
        elsif ($last_tool eq 'highlighter') {
     
            $fill_color = $last_tool_fill_color // Gtk3::Gdk::RGBA->new(0.21, 0.52, 0.89, 0.25);
            $stroke_color = $last_tool_stroke_color // Gtk3::Gdk::RGBA->new(255, 0, 0, 1);
            $line_width = $last_tool_line_width // 3.0;

            $fill_color_button->set_rgba($fill_color);
            $stroke_color_button->set_rgba($stroke_color);
            $line_width_spin_button->set_value($line_width);
            $fill_color_button->set_sensitive(TRUE);
        }

        elsif ($current_tool eq 'crop') {
            if (exists $items{rectangles}) {
                @{$items{rectangles}} = grep { $_->{type} ne 'crop_rect' } @{$items{rectangles}};
            }

            my $margin = 20 / $scale_factor;
            
            my $crop_item = {
                type => 'crop_rect',
                timestamp => ++$global_timestamp,
                x1 => $margin, 
                y1 => $margin,
                x2 => $image_surface->get_width() - $margin,
                y2 => $image_surface->get_height() - $margin,
                stroke_color => Gtk3::Gdk::RGBA->new(1, 1, 1, 1),
                line_width => 2,
                selected => 1 
            };
            
            push @{$items{rectangles}}, $crop_item;
            $current_item = $crop_item; 
        }
        
        $drawing_area->queue_draw();

    } elsif (!$tool_item->get_active()) {

        if (!grep {
            $_ ne $tool_name &&
            $tool_buttons{$_}->isa('Gtk3::ToggleToolButton') &&
            $tool_buttons{$_}->get_active()
        } keys %tool_buttons) {
            $tool_buttons{'select'}->set_active(TRUE);
        }
    }
    
    return;
}

sub handle_main_toolbar_action {
    my ($action_name) = @_;
    if ($action_name eq 'image-open') { open_image($window); }
    elsif ($action_name eq 'svg-import') { import_svg($window); }
    elsif ($action_name eq 'image-close') { close_image(); }
    elsif ($action_name eq 'undo') { do_undo(); }
    elsif ($action_name eq 'redo') { do_redo(); }
    elsif ($action_name eq 'copy') { copy_item(); }
    elsif ($action_name eq 'cut') { cut_item(); }
    elsif ($action_name eq 'paste') { paste_item(); }
    elsif ($action_name eq 'clear') { clear_all_annotations(); }
    elsif ($action_name eq 'delete') { delete_item(); }
    elsif ($action_name eq 'save-as') { save_image_as($window); }
    elsif ($action_name eq 'print') { show_print_dialog($window); }
    elsif ($action_name eq 'exit') { save_window_dimensions(); save_tool_state(); Gtk3::main_quit(); }
    
    return;
}

sub switch_tool {
    my ($new_tool) = @_;
    $last_tool = $current_tool;
    $is_drawing = 0; $current_new_item = undef;
    if ($is_text_editing) { stop_cursor_blink(); $is_text_editing = 0; }
    $dragging = 0; $drag_handle = undef;
    if ($new_tool ne 'select' && $current_item) { deselect_all_items(); }
    $current_tool = $new_tool; $current_mode = $new_tool;
    if ($new_tool eq 'text') { $drawing_area->grab_focus(); }
    $drawing_area->queue_draw();
    
    return;
}

sub update_tool_state {
    my ($new_tool) = @_;
    return unless exists $tool_buttons{$new_tool} && $tool_buttons{$new_tool}->isa('Gtk3::ToggleToolButton');
    $tool_buttons{$new_tool}->set_active(TRUE);
    
    return;
}

sub update_tool_widgets {
    my ($tool) = @_;
    foreach my $name (keys %tool_widgets) {
        if ($tool_widgets{$name}) {
            if ($tool_widgets{$name}->isa('Gtk3::ToggleToolButton')) {
                $tool_widgets{$name}->set_active($name eq $tool);
            } else {
                $tool_widgets{$name}->set_sensitive($name ne $tool);
            }
        }
    }
    
    return;
}

$window->signal_connect('delete-event' => sub { 
    if (!check_unsaved_changes()) { return TRUE; }
    save_window_dimensions();
    save_tool_state();
    return FALSE; 
});
$window->signal_connect('destroy' => sub { Gtk3::main_quit(); });
$window->signal_connect('configure-event' => \&update_drawing_area_size);
$window->signal_connect('map-event' => sub {
    if ($initial_file && -f $initial_file) {
    
        if ($initial_file =~ /\.linia$/i) {

            local $/; 
            if (open(my $fh, '<', $initial_file)) {
                my $json_text = <$fh>;
                close $fh;
                
                my $data = eval { from_json($json_text) };
                
                if ($data) {
              
                    if ($data->{image_path} && -f $data->{image_path}) {
                        load_image_file($data->{image_path}, $window);
                        zoom_fit_best(); 
                    } else {
                        my $msg = Gtk3::MessageDialog->new($window, 'modal', 'warning', 'ok', 
                            "Original image not found at:\n" . ($data->{image_path} || "unknown") . 
                            "\n\nThe annotations will load, but the background image is missing.");
                        $msg->run();
                        $msg->destroy();
                    }

                    restore_items_from_load($data->{items});

                    $global_timestamp = $data->{global_timestamp} || 0;
                    $dimming_level = $data->{dimming_level} || 0;
                    
                    if ($dimming_scale) {
                        $dimming_scale->set_value($dimming_level);
                    }

                    update_drawing_area_size();
                    $drawing_area->queue_draw();
                    $project_is_modified = 0;
                }
            }
        } else {
       
            load_image_file($initial_file, $window);
            zoom_fit_best();
        }
    }
    return FALSE;
});

my $stored_event;
$drawing_area->signal_connect('draw' => sub {
    my ($widget, $cr) = @_;
    draw_image($widget, $cr, $stored_event);
});

$drawing_area->signal_connect('scroll-event' => sub {
    my ($widget, $event) = @_;
    return FALSE unless $image_surface;
    $is_zooming_active = 1;
    if ($zoom_end_timeout) { Glib::Source->remove($zoom_end_timeout); }
    $zoom_end_timeout = Glib::Timeout->add(150, sub {
        $is_zooming_active = 0; $zoom_end_timeout = undef; $widget->queue_draw(); return FALSE; 
    });
    my ($mouse_x, $mouse_y) = ($event->x, $event->y);
    my $old_scale = $scale_factor;
    if ($event->direction eq 'smooth') {
        my (undef, $dy) = $event->get_scroll_deltas();
        $scale_factor *= (1.0 - ($dy * 0.05)) if defined $dy;
    } elsif ($event->direction eq 'up') {
        $scale_factor *= 1.1;
    } elsif ($event->direction eq 'down') {
        $scale_factor *= 0.9;
    }
    $scale_factor = max(0.01, min(50.0, $scale_factor));
    if (abs($old_scale - $scale_factor) > 0.0001) {
        update_drawing_area_size();
        my $scrolled_window = $widget->get_parent;
        while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) { $scrolled_window = $scrolled_window->get_parent; }
        return FALSE unless $scrolled_window;
        my $hadj = $scrolled_window->get_hadjustment;
        my $vadj = $scrolled_window->get_vadjustment;
        if ($hadj && $vadj) {
            my $image_width = $image_surface->get_width * $scale_factor;
            my $view_width = $scrolled_window->get_child->get_allocated_width;
            my $h_value = (($mouse_x / $old_scale) * $scale_factor) - $mouse_x;
            $hadj->set_value(max(0, min($h_value, $image_width - $view_width)));

        }
        $widget->queue_draw();
    }
    return TRUE;
});

$drawing_area->signal_connect('key-press-event' => sub {
    my ($widget, $event) = @_;
    my $keyval = $event->keyval;

    if ($keyval == Gtk3::Gdk::KEY_Delete) {
        if ($current_item && $current_item->{type} eq 'text' && $current_item->{is_editing}) {
            cleanup_text_editing($current_item);
            delete_item();
            return TRUE;
        }
        elsif ($current_item && $current_item->{selected}) {
            delete_item();
            return TRUE;
        }
    }

    if ($current_item && $current_item->{type} eq 'text' && $current_item->{is_editing}) {
        if ($keyval == Gtk3::Gdk::KEY_Escape) {
            cleanup_text_editing($current_item);
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_Left) {
            my @lines = split("\n", $current_item->{text});
            my $curr_line = $lines[$current_item->{current_line}] // '';
            
            if ($current_item->{current_column} > 0) {
                $current_item->{current_column}--;
            } elsif ($current_item->{current_line} > 0) {
                $current_item->{current_line}--;
                my $prev_line = $lines[$current_item->{current_line}] // '';
                $current_item->{current_column} = length($prev_line);
            }
            $widget->queue_draw();
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_Right) {
            my @lines = split("\n", $current_item->{text});
            my $curr_line = $lines[$current_item->{current_line}] // '';
            my $line_length = length($curr_line);
            
            if ($current_item->{current_column} < $line_length) {
                $current_item->{current_column}++;
            } elsif ($current_item->{current_line} < scalar(@lines) - 1) {
                $current_item->{current_line}++;
                $current_item->{current_column} = 0;
            }
            $widget->queue_draw();
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_Return || $keyval == Gtk3::Gdk::KEY_KP_Enter) {
            my @lines = split("\n", $current_item->{text});
            my $curr_line = $lines[$current_item->{current_line}] // '';
            my $before = substr($curr_line, 0, $current_item->{current_column});
            my $after = substr($curr_line, $current_item->{current_column});
            $lines[$current_item->{current_line}] = $before;
            splice(@lines, $current_item->{current_line} + 1, 0, $after);
            $current_item->{text} = join("\n", @lines);
            $current_item->{current_line}++;
            $current_item->{current_column} = 0;
            $widget->queue_draw();
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_BackSpace) {
            if ($current_item->{current_column} > 0) {
                my @lines = split("\n", $current_item->{text});
                substr($lines[$current_item->{current_line}], $current_item->{current_column} - 1, 1) = '';
                $current_item->{text} = join("\n", @lines);
                $current_item->{current_column}--;
            }
            elsif ($current_item->{current_line} > 0) {
                my @lines = split("\n", $current_item->{text});
                my $prev = $lines[$current_item->{current_line} - 1];
                $current_item->{current_column} = length($prev);
                $lines[$current_item->{current_line} - 1] .= $lines[$current_item->{current_line}];
                splice(@lines, $current_item->{current_line}, 1);
                $current_item->{text} = join("\n", @lines);
                $current_item->{current_line}--;
            }
            $widget->queue_draw();
            return TRUE;
        }
        else {
            my $char = Gtk3::Gdk::keyval_to_unicode($keyval);
            if ($char && $char >= 0x20) {
                my @lines = split("\n", $current_item->{text});
                $lines[$current_item->{current_line}] //= '';
                substr($lines[$current_item->{current_line}], $current_item->{current_column}, 0) = chr($char);
                $current_item->{text} = join("\n", @lines);
                $current_item->{current_column}++;
                $widget->queue_draw();
                return TRUE;
            }
        }
    }
    
    return FALSE;
});

$window->signal_connect('key-press-event' => sub {
    my ($widget, $event) = @_;

    my $keyval = $event->keyval;
    my $keyname = Gtk3::Gdk::keyval_name($keyval);

    if ($keyval == Gtk3::Gdk::KEY_Return || $keyval == Gtk3::Gdk::KEY_KP_Enter) {
        if ($current_tool eq 'crop' && $current_item && $current_item->{type} eq 'crop_rect') {
            apply_crop();
            return TRUE;
        }
    }

    if ($keyname eq 'Shift_L' || $keyname eq 'Shift_R') {
        if ($current_tool eq 'select') {
            $is_multi_selecting = 1;
            print "Multi-selection mode activated\n";
        }
    }
    
    elsif (($event->state & 'mod1-mask') && ($current_item && $current_item->{selected})) {
        
        my $handled = 0;
        my $resize_factor = 1.1;

        if ($keyname eq 'plus' || $keyname eq 'equal' || $keyname eq 'KP_Add') {
            if ($current_item->{type} eq 'text') {
                my ($family, $size) = $current_item->{font} =~ /^(.*?)\s+(\d+)$/;
                $size ||= 30;
                my $new_size = $size + 1;
                $current_item->{font} = "$family $new_size";
                $current_item->{font_size} = $new_size;
                if ($font_btn_w) {
                    $font_btn_w->set_font_name($current_item->{font});
                }
            }
            elsif ($current_item->{type} eq 'svg') {
                $current_item->{scale} *= $resize_factor;
            }
            elsif ($current_item->{type} eq 'magnifier') {
                $current_item->{radius} *= $resize_factor;
            }
            else {
                resize_primitive($current_item, $resize_factor);
            }
            $drawing_area->queue_draw();
            return TRUE;
        }
        elsif ($keyname eq 'minus' || $keyname eq 'KP_Subtract') {
            if ($current_item->{type} eq 'text') {
                my ($family, $size) = $current_item->{font} =~ /^(.*?)\s+(\d+)$/;
                $size ||= 25;
                my $new_size = max(8, $size - 1);
                $current_item->{font} = "$family $new_size";
                $current_item->{font_size} = $new_size;
                if ($font_btn_w) {
                    $font_btn_w->set_font_name($current_item->{font});
                }
            }
            elsif ($current_item->{type} eq 'svg') {
                my $new_scale = $current_item->{scale} / $resize_factor;
                if ($new_scale >= 0.1) {
                    $current_item->{scale} = $new_scale;
                }
            }
            elsif ($current_item->{type} eq 'magnifier') {
                $current_item->{radius} /= $resize_factor;
            }
            else {
                resize_primitive($current_item, 1/$resize_factor);
            }
            $drawing_area->queue_draw();
            return TRUE;
        }
    }

    if ($event->state & 'control-mask') {

        if ($keyval == Gtk3::Gdk::KEY_c || $keyval == Gtk3::Gdk::KEY_C) {
            copy_item();
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_x || $keyval == Gtk3::Gdk::KEY_X) {
            cut_item();
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_v || $keyval == Gtk3::Gdk::KEY_V) {
            paste_item();
            return TRUE;
        }
        if ($keyval == Gtk3::Gdk::KEY_z || $keyval == Gtk3::Gdk::KEY_Z) {
            do_undo();
            return TRUE;
        }
        elsif ($keyval == Gtk3::Gdk::KEY_y || $keyval == Gtk3::Gdk::KEY_Y) {
            do_redo();
            return TRUE;
        }
        elsif ($keyname eq 'plus' || $keyname eq 'equal' || $keyname eq 'KP_Add') {
            zoom_in();
            return TRUE;
        }
        elsif ($keyname eq 'minus' || $keyname eq 'KP_Subtract') {
            zoom_out();
            return TRUE;
        }
        elsif ($keyname eq '1' || $keyname eq 'KP_1') {
            zoom_original();
            return TRUE;
        }
        elsif ($keyname eq '2' || $keyname eq 'KP_2') {
            zoom_fit_best();
            return TRUE;
        }
    }

    return FALSE;
});

$window->signal_connect('key-release-event' => sub {
    my ($widget, $event) = @_;
    my $keyname = Gtk3::Gdk::keyval_name($event->keyval);
    if ($keyname eq 'Shift_L' || $keyname eq 'Shift_R') { $is_multi_selecting = 0; }
    return FALSE;
});

$drawing_area->signal_connect('button-press-event' => sub {
    my ($widget, $event) = @_;
    $stored_event = $event; 
    return FALSE unless $image_surface;
    
    my ($x, $y) = window_to_image_coords($widget, $event->x, $event->y);
    ($start_x, $start_y) = ($x, $y);
    ($last_x, $last_y) = ($x, $y);
    
    $widget->grab_focus();

    if ($event->button == 3) {  

        unless ($current_item) { check_item_selection($widget, $event->x, $event->y); }
        
        if ($current_item) { 
       
            show_item_context_menu($event); 
        } else {
     
            show_background_context_menu($event);
        }
        return TRUE;
    }
    if ($event->button == 2) { start_panning($event->x_root, $event->y_root); return TRUE; }

    if ($event->button == 1) {
 
        if ($current_item && $current_item->{type} eq 'text' && $current_item->{is_editing}) {
            if (is_point_in_text($x, $y, $current_item)) {
                set_cursor_position_from_click($current_item, $x, $y);
                $widget->queue_draw();
                return TRUE;
            }
        }
        
        if ($current_item && $current_item->{selected}) {

            if ($current_item->{type} eq 'text') {
                my $text_handle = get_text_handle($x, $y, $current_item);
                if (defined $text_handle && $text_handle eq 'drag') {
                    $dragging = 1;
                    $drag_handle = 'drag';
                    return TRUE;
                } elsif (defined $text_handle && $text_handle eq 'body') {
                    if (!$current_item->{is_editing}) {
                        $current_item->{is_editing} = 1;
                        $is_text_editing = 1;
                        start_cursor_blink();
                    }
                    set_cursor_position_from_click($current_item, $x, $y);
                    $widget->queue_draw();
                    return TRUE;
                }
            }
            
            my $handle = undef;
            if ($current_item->{type} eq 'crop_rect' || $current_item->{type} eq 'rectangle' || $current_item->{type} eq 'pixelize') {
                $handle = get_rectangle_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'ellipse') {
                $handle = get_ellipse_handle($x, $y, $current_item);
            } elsif ($current_item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
                $handle = get_item_handle($x, $y, $current_item);
            } elsif ($current_item->{type} =~ /^(triangle|tetragon|pentagon)$/) {
                $handle = get_shape_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'pyramid') {
                $handle = get_pyramid_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'cuboid') {
                $handle = get_cuboid_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'text') {
                if (is_point_in_text($x, $y, $current_item)) {
                    $handle = 'body';
                }
            } elsif ($current_item->{type} eq 'magnifier') {
                $handle = get_circle_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'svg') {
                $handle = get_svg_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'numbered-circle') {
                $handle = get_circle_handle($x, $y, $current_item);
            } elsif ($current_item->{type} eq 'freehand' || $current_item->{type} eq 'highlighter') {
                $handle = get_freehand_handle($x, $y, $current_item);
            }

            if ($handle) {
                $dragging = 1;
                $drag_handle = $handle;
                return TRUE;
            }
        }

        if ($current_tool eq 'crop') { return TRUE; }

        my $item_was_selected = check_item_selection($widget, $event->x, $event->y);
        if ($item_was_selected) { return TRUE; }

        if ($current_item && $current_item->{selected}) {
            deselect_all_items();
            $widget->queue_draw();
            return TRUE;
        }

        if (!$current_item && $current_tool ne 'select') {
            if ($current_tool eq 'text') {
                my $text_item = create_text_item($x, $y);
                store_state_for_undo('create', $text_item);
                $is_text_editing = 1;
                start_cursor_blink();
                $widget->grab_focus();
                $widget->queue_draw();
                return TRUE;
            } elsif ($current_tool eq 'freehand' || $current_tool eq 'highlighter') {
                @freehand_points = ();
                push @freehand_points, ($x, $y);
                $is_drawing_freehand = 1;
                $widget->queue_draw();
                return TRUE;
            } elsif ($current_tool =~ /^(line|rectangle|ellipse|single-arrow|double-arrow|triangle|tetragon|pentagon|pyramid|cuboid)$/) {
                $is_drawing = 1;
                $end_x = $x; $end_y = $y;
                $widget->queue_draw();
                return TRUE;
            } elsif ($current_tool eq 'number') {
                my $circle = create_numbered_circle($x, $y);
                store_state_for_undo('create', $circle);
                $widget->queue_draw();
                return TRUE;
            } elsif ($current_tool eq 'magnifier') {
                my $magnifier = create_magnifier($x, $y);
                store_state_for_undo('create', $magnifier);
                $widget->queue_draw();
                return TRUE;
            } elsif ($current_tool eq 'pixelize') {
                $is_drawing = 1;
                $end_x = $x; $end_y = $y;
                $widget->queue_draw();
                return TRUE;
            }
        }
    }
    return TRUE;
});

$drawing_area->signal_connect('motion-notify-event' => sub {
    my ($widget, $event) = @_;
    $stored_event = $event;
    return FALSE unless $image_surface;

    if ($is_panning) {
        update_panning($event->x_root, $event->y_root);
        return TRUE;  
    }

    my ($curr_x, $curr_y) = window_to_image_coords($widget, $event->x, $event->y);
    my $dx = $curr_x - $last_x;
    my $dy = $curr_y - $last_y;
    ($last_x, $last_y) = ($curr_x, $curr_y);

    if ($dragging && $current_item) {
        $active_handle = $drag_handle;
        $hovered_handle = $drag_handle;
        handle_shape_drag($current_item, $drag_handle, $dx, $dy, $curr_x, $curr_y, $event);
        $widget->queue_draw();
        return TRUE;
    }

    if ($is_drawing_freehand && ($event->state & 'button1-mask')) {
        if ($event->state & 'control-mask') { $curr_y = $start_y; }
        elsif ($event->state & 'shift-mask') { $curr_x = $start_x; }
        push @freehand_points, ($curr_x, $curr_y);
        $widget->queue_draw();
        return TRUE;
    }

    if ($is_drawing) {
        $end_x = $curr_x;
        $end_y = $curr_y;

        if ($current_tool =~ /^(line|single-arrow|double-arrow)$/) {
            if ($event->state & 'control-mask') { $end_y = $start_y; } 
            elsif ($event->state & 'shift-mask') { $end_x = $start_x; }
            $widget->queue_draw();
            return TRUE;
        }
        elsif ($current_tool eq 'pixelize' || $current_tool eq 'pyramid') {
            $widget->queue_draw();
            return TRUE;
        }
        elsif ($current_tool eq 'cuboid') {
            $widget->queue_draw();
            return TRUE;
        }
        elsif ($current_tool =~ /^(rectangle|ellipse|triangle|pentagon|tetragon)$/) {
            if ($event->state & 'control-mask') {
                my $width = abs($curr_x - $start_x);
                my $height = abs($curr_y - $start_y);
                my $size = max($width, $height);
                my $dir_x = $curr_x > $start_x ? 1 : -1;
                my $dir_y = $curr_y > $start_y ? 1 : -1;

                if ($current_tool eq 'triangle') {
                    $end_x = $start_x + ($size * $dir_x);
                    $end_y = $start_y + ($size * sqrt(3) * $dir_y);
                } else {
                    $end_x = $start_x + ($size * $dir_x);
                    $end_y = $start_y + ($size * $dir_y);
                }
            } 
            $widget->queue_draw();
            return TRUE;
        }
    }
    
    my $window = $widget->get_window();
    if ($window) {
        my $should_show_hand = 0;
        
        if ($current_item && $current_item->{type} eq 'text' && $current_item->{selected}) {
            my $text_handle = get_text_handle($curr_x, $curr_y, $current_item);
            if (defined $text_handle && $text_handle eq 'drag') {
                $should_show_hand = 1;
            }
        }
        
        if ($should_show_hand) {
            my $cursor = Gtk3::Gdk::Cursor->new_for_display(
                $window->get_display(),
                'hand1'
            );
            $window->set_cursor($cursor);
        } elsif (!$dragging && !$is_panning) {
            $window->set_cursor(undef);
        }
    }
    
    return TRUE;
});

$drawing_area->signal_connect('button-release-event' => sub {
    my ($widget, $event) = @_;
    return FALSE unless $image_surface;

    if ($is_panning && ($event->button == 2 || ($event->button == 1 && ($event->state & 'shift-mask')))) {
        stop_panning(); return TRUE;
    }

    my ($img_x, $img_y) = window_to_image_coords($widget, $event->x, $event->y);
    ($last_x, $last_y) = ($img_x, $img_y);

    my $modified_item;
    if ($dragging && $current_item) {
        $modified_item = $current_item;
        store_state_for_undo('modify', clone_item($current_item));
        $dragging = 0; $drag_handle = undef;
        if ($current_item->{type} eq 'text') {
             $current_item->{is_resizing} = 0;
             $widget->queue_draw(); 
        }
    }

    if ($is_drawing_freehand) {
        my $points_count = scalar(@freehand_points) / 2;
        if ($points_count > 1) {
            deselect_all_items();
            my $new_item = create_polyline(undef, $freehand_points[0], $freehand_points[1], $freehand_points[-2], $freehand_points[-1], ($current_tool eq 'highlighter' ? 1 : 0));
            $new_item->{points} = [@freehand_points];
            push @{$items{$current_tool eq 'highlighter' ? 'highlighter-lines' : 'freehand-items'}}, $new_item;
            $current_item = $new_item;
            $new_item->{selected} = 1;  
            store_state_for_undo('create', clone_item($new_item));
        }
        $is_drawing_freehand = 0; @freehand_points = ();
        $widget->queue_draw(); return TRUE;
    }

    if ($is_drawing && $current_tool ne 'select') {
        my ($new_end_x, $new_end_y) = ($end_x, $end_y);

        if ($event->state & 'control-mask') {
            if ($current_tool =~ /^(rectangle|ellipse|pentagon|tetragon)$/) {
                my $width = abs($end_x - $start_x);
                my $height = abs($end_y - $start_y);
                my $size = max($width, $height); 
                my $dir_x = $end_x > $start_x ? 1 : -1;
                my $dir_y = $end_y > $start_y ? 1 : -1;
                $new_end_x = $start_x + ($size * $dir_x);
                $new_end_y = $start_y + ($size * $dir_y);
            }
        }
        elsif ($event->state & 'control-mask' && ($current_tool =~ /^(line|single-arrow|double-arrow)$/)) {
            $new_end_y = $start_y; 
        }
        elsif ($event->state & 'shift-mask' && ($current_tool =~ /^(line|single-arrow|double-arrow)$/)) {
            $new_end_x = $start_x; 
        }

        my $dx = $new_end_x - $start_x;
        my $dy = $new_end_y - $start_y;
        my $dist = sqrt($dx * $dx + $dy * $dy);

        if ($dist > 5 || $current_tool eq 'pyramid') {
            deselect_all_items();
            my $new_item;
            if ($current_tool eq 'line') { $new_item = create_line($start_x, $start_y, $new_end_x, $new_end_y); }
            elsif ($current_tool =~ /^(single-arrow|double-arrow)$/) { $new_item = create_arrow($start_x, $start_y, $new_end_x, $new_end_y); push @{$items{arrows}}, $new_item; }
            elsif ($current_tool eq 'rectangle') { $new_item = create_rectangle($start_x, $start_y, $new_end_x, $new_end_y); }
            elsif ($current_tool eq 'ellipse') { $new_item = create_ellipse($start_x, $start_y, $new_end_x, $new_end_y); }
            elsif ($current_tool eq 'triangle') {
                my $triangle = create_triangle($start_x, $start_y, $new_end_x, $new_end_y, $stored_event);
                push @{$items{triangles}}, $triangle;
                $current_item = $triangle;
                $triangle->{selected} = 1; 
                store_state_for_undo('create', clone_item($triangle));
            }
            elsif ($current_tool eq 'tetragon') { $new_item = create_tetragon($start_x, $start_y, $new_end_x, $new_end_y); push @{$items{tetragons}}, $new_item; }
            elsif ($current_tool eq 'pentagon') { $new_item = create_pentagon($start_x, $start_y, $new_end_x, $new_end_y); push @{$items{pentagons}}, $new_item; }
            elsif ($current_tool eq 'pyramid') {
                $new_item = create_pyramid($start_x, $start_y, $new_end_x, $new_end_y);
                if ($new_item) {
                    push @{$items{pyramids}}, $new_item;
                    $current_item = $new_item;
                    $new_item->{selected} = 1; 
                    store_state_for_undo('create', clone_item($new_item));
                }
            }
            elsif ($current_tool eq 'cuboid') {
                $new_item = create_cuboid($start_x, $start_y, $new_end_x, $new_end_y);
                if ($new_item) {
                    push @{$items{cuboids}}, $new_item;
                    $current_item = $new_item;
                    $new_item->{selected} = 1; 
                    store_state_for_undo('create', clone_item($new_item));
                }
            }
            elsif ($current_tool eq 'pixelize') {
                my $new_item = create_pixelize($start_x, $start_y, $new_end_x, $new_end_y);
                $new_item->{selected} = 1;
                $current_item = $new_item;
                store_state_for_undo('create', clone_item($new_item));
            }

            if ($new_item && $current_tool !~ /^(triangle|pyramid|pixelize)$/) {
                $current_item = $new_item;
                $new_item->{selected} = 1; 
                store_state_for_undo('create', clone_item($new_item));
            }
        }
    }

    $is_drawing = 0;
    $dragging = 0;
    $drag_handle = undef;
    $drawing_area->queue_draw();

    if ($modified_item) {
        store_state_for_undo('modify', $modified_item);
    }

    return TRUE;
});

# =============================================================================
# SECTION 3: FINAL INITIALIZATION & STARTUP
# =============================================================================

load_recent_files();
update_recent_files_menu();
update_undo_redo_ui();

$window->show_all();

if ($drawing_toolbar_on_left) { 
    $move_drawing_toolbar->set_active(TRUE); 
}

load_tool_state();

Gtk3::main();

# =============================================================================
# SECTION 4: FILE I/O
# =============================================================================

sub open_image {
    my ($parent_window) = @_; 
    
    return unless check_unsaved_changes();

    my $dialog = Gtk3::FileChooserDialog->new(
        "Open Image",
        $parent_window,
        'open',
        'gtk-cancel' => 'cancel',
        'gtk-open'   => 'accept'
    );

    my $preview = Gtk3::Image->new();
    $dialog->set_preview_widget($preview);

    $dialog->signal_connect('update-preview' => sub {
        my $file_chooser = shift;
        my $filename = $file_chooser->get_preview_filename();

        unless (defined $filename && -f $filename && !-d $filename) {
            $file_chooser->set_preview_widget_active(FALSE);
            return;
        }

        my $curr_scale = defined $parent_window ? $parent_window->get_scale_factor() : 1;
        my $logical_w = 300; 
        my $physical_w = $logical_w * $curr_scale; 

        my $surface = eval {
            my $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale($filename, $physical_w, -1, TRUE);
            return unless $pixbuf;
            return Gtk3::Gdk::cairo_surface_create_from_pixbuf($pixbuf, $curr_scale, undef);
        };

        if ($surface) {
            $preview->set_from_surface($surface);
            $file_chooser->set_preview_widget_active(TRUE);
        } else {
            $file_chooser->set_preview_widget_active(FALSE);
        }
    });

    my $pictures_dir = File::Spec->catdir(File::HomeDir->my_home, 'Pictures');

    if (-d $pictures_dir && -r $pictures_dir) {
        $dialog->set_current_folder($pictures_dir);
    } else {
        $dialog->set_current_folder(File::HomeDir->my_home);
    }

    my $filter = Gtk3::FileFilter->new();
    $filter->set_name("Image files");
    $filter->add_mime_type("image/png");
    $filter->add_mime_type("image/jpeg");
    $filter->add_mime_type("image/webp");
    $filter->add_mime_type("image/bmp");
    $dialog->add_filter($filter);

    my $response = $dialog->run();
    if ($response eq 'accept') {
        my $filename = $dialog->get_filename();
        if ($filename) {
            load_image_file($filename, $parent_window);
            $project_is_modified = 0;
            zoom_fit_best();
        } else {
            carp "No file selected.\n";
        }
    }

    $dialog->destroy();
    return;
}

sub load_image_file {
   my ($filename, $win) = @_;
   $initial_file = $filename;
   
   eval {
       if ($image_surface) {
           $image_surface->finish();
           undef $image_surface;
       }
       if ($preview_surface) {
           $preview_surface->finish();
           undef $preview_surface;
       }

       my $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file($filename);
       if ($pixbuf) {
           $original_width = $pixbuf->get_width();
           $original_height = $pixbuf->get_height();

           my $temp_surface = Cairo::ImageSurface->create('argb32',
               $original_width,
               $original_height
           );
           my $cr = Cairo::Context->create($temp_surface);
           Gtk3::Gdk::cairo_set_source_pixbuf($cr, $pixbuf, 0, 0);
           $cr->paint();

           $image_surface = $temp_surface;

           my $max_dimension = max($original_width, $original_height);
           if ($max_dimension > 2048) {
               $preview_ratio = 2048 / $max_dimension; 
               
               my $prev_w = int($original_width * $preview_ratio);
               my $prev_h = int($original_height * $preview_ratio);
               
               $preview_surface = Cairo::ImageSurface->create('argb32', $prev_w, $prev_h);
               my $p_cr = Cairo::Context->create($preview_surface);

               $p_cr->scale($preview_ratio, $preview_ratio);
               $p_cr->set_source_surface($image_surface, 0, 0);
               $p_cr->paint();
           } else {
               $preview_surface = $image_surface;
               $preview_ratio = 1.0;
           }

           $initial_scale_factor = 1;

           %items = (
               'lines' => [],
               'dashed-lines' => [],
               'arrows' => [],
               'rectangles' => [],
               'ellipses' => [],
               'triangles' => [],
               'tetragons' => [],
               'pentagons' => [],
               'pyramids' => [],
               'freehand_items' => [],
               'highlighter-lines' => [],
               'text_items' => [],
               'magnifiers' => [],
               'pixelized_items' => [],
               'numbered-circles' => [],
               'cuboids' => [],
               'svg_items' => []
           );

           @undo_stack = ();
           @redo_stack = ();
           $current_number = 1;

           update_drawing_area_size();
           $drawing_area->queue_draw();
           
           my $display_name = basename($filename);
           $window->set_title("Linia - $display_name");
       }

       add_recent_file($filename) if $image_surface;
   };
   if ($@) {
       carp "Error loading image: $@\n";
   }
   return;
}

sub close_image {
    return unless check_unsaved_changes(); 

    if ($image_surface) {
        $image_surface->finish();
        undef $image_surface;

        my $scrolled_window = $drawing_area->get_parent;
        while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
            $scrolled_window = $scrolled_window->get_parent;
        }

        if ($scrolled_window) {
       
            my $hadj = $scrolled_window->get_hadjustment();
            my $vadj = $scrolled_window->get_vadjustment();

            $hadj->set_value(0);
            $vadj->set_value(0);

            $drawing_area->set_size_request(1, 1);
        }

        $scale_factor = 1.0;

        %items = (
            'lines' => [],
            'arrows' => [],
            'rectangles' => [],
            'ellipses' => [],
            'triangles' => [],
            'tetragons' => [],
            'pentagons' => [],
            'freehand-items' => [],
            'highlighter-lines' => [],
            'numbered-circles' => [],
            'text_items' => [],
            'magnifiers' => [],
            'pixelize_items' => [],
            'svg_items' => []
        );

        $current_item = undef;

        $drawing_area->queue_resize();
        $drawing_area->queue_draw();
        $project_is_modified = 0;
        
        $window->set_title('Linia');
    }
    
    return;
}

sub save_image_as {
    my ($window) = @_;
    return unless $image_surface;

    use File::Basename;
    use POSIX qw(strftime);

    my $base_name = "annotation";
    if ($initial_file) {
        $base_name = basename($initial_file);
        $base_name =~ s/\.[^.]+$//; 
    }

    my $lang = $ENV{LANG} || $ENV{LC_ALL} || '';
    my $date_format;

    if ($lang =~ /US/i) {
        $date_format = "%b-%d-%Y-%H_%M";
    } else {
        $date_format = "%d-%b-%Y-%H_%M";
    }

    my $timestamp = strftime($date_format, localtime);
    $timestamp = lc($timestamp); 

    my $suggested_name = "${base_name}-annotated-${timestamp}";

    my $dialog = Gtk3::FileChooserDialog->new(
        "Save Image As",
        $window,
        'save',
        'gtk-cancel' => 'cancel',
        'gtk-save'   => 'accept'
    );

    $dialog->set_do_overwrite_confirmation(TRUE);
    $dialog->set_current_name($suggested_name . ".png");

    my $png_filter = Gtk3::FileFilter->new();
    $png_filter->set_name("PNG files (*.png)");
    $png_filter->add_mime_type("image/png");
    $png_filter->add_pattern("*.png");
    $dialog->add_filter($png_filter);

    my $jpeg_filter = Gtk3::FileFilter->new();
    $jpeg_filter->set_name("JPEG files (*.jpg, *.jpeg)");
    $jpeg_filter->add_mime_type("image/jpeg");
    $jpeg_filter->add_pattern("*.jpg");
    $jpeg_filter->add_pattern("*.jpeg");
    $dialog->add_filter($jpeg_filter);

    $dialog->set_filter($png_filter);

    my $response = $dialog->run();
    if ($response eq 'accept') {
        my $filename = $dialog->get_filename();
        return unless defined $filename;

        my $current_filter = $dialog->get_filter();

        if ($current_filter == $png_filter && $filename !~ /\.png$/i) {
            $filename .= '.png';
        }
        elsif ($current_filter == $jpeg_filter && $filename !~ /\.(jpg|jpeg)$/i) {
            $filename .= '.jpg';
        }

        my $width = $image_surface->get_width();
        my $height = $image_surface->get_height();
        my $save_surface = Cairo::ImageSurface->create('argb32', $width, $height);
        my $cr = Cairo::Context->create($save_surface);

        $cr->set_source_surface($image_surface, 0, 0);
        $cr->paint();

        if ($dimming_level > 0) {
            my $mask = Cairo::ImageSurface->create('a8', $width, $height);
            my $mask_cr = Cairo::Context->create($mask);

            $mask_cr->set_source_rgb(0, 0, 0);
            $mask_cr->paint();
            $mask_cr->set_operator('clear');

            foreach my $rect (@{$items{rectangles}}) {
                next unless defined $rect;
                my $x = min($rect->{x1}, $rect->{x2});
                my $y = min($rect->{y1}, $rect->{y2});
                my $w = abs($rect->{x2} - $rect->{x1});
                my $h = abs($rect->{y2} - $rect->{y1});
                $mask_cr->rectangle($x, $y, $w, $h);
                $mask_cr->fill();
            }
            foreach my $ellipse (@{$items{ellipses}}) {
                next unless defined $ellipse;
                my $cx = ($ellipse->{x1} + $ellipse->{x2}) / 2;
                my $cy = ($ellipse->{y1} + $ellipse->{y2}) / 2;
                my $rx = abs($ellipse->{x2} - $ellipse->{x1}) / 2;
                my $ry = abs($ellipse->{y2} - $ellipse->{y1}) / 2;
                $mask_cr->save();
                $mask_cr->translate($cx, $cy);
                $mask_cr->scale($rx, $ry);
                $mask_cr->arc(0, 0, 1, 0, 2 * 3.14159);
                $mask_cr->restore();
                $mask_cr->fill();
            }
            foreach my $type (qw(triangles tetragons pentagons pyramids)) {
                foreach my $shape (@{$items{$type}}) {
                    next unless defined $shape && $shape->{vertices};
                    $mask_cr->move_to(@{$shape->{vertices}[0]});
                    for my $i (1 .. $#{$shape->{vertices}}) {
                        $mask_cr->line_to(@{$shape->{vertices}[$i]});
                    }
                    $mask_cr->close_path();
                    $mask_cr->fill();
                }
            }

            my $alpha = $dimming_level * 0.9 / 100;
            $cr->set_source_rgba(0, 0, 0, $alpha);
            $cr->mask_surface($mask, 0, 0);
            $mask->finish();
        }

        my @all_types = qw(
            freehand-items highlighter-lines lines dashed-lines arrows 
            rectangles ellipses triangles tetragons pentagons pyramids cuboids
            numbered-circles svg_items pixelize_items text_items magnifiers
        );

        foreach my $type (@all_types) {
            next unless exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY';
            foreach my $item (@{$items{$type}}) {
                next unless defined $item && defined $item->{type};

                my $was_selected = $item->{selected};
                $item->{selected} = 0;

                draw_item($cr, $item, 0);

                $item->{selected} = $was_selected;
            }
        }

        eval {
            if ($filename =~ /\.png$/i) {
                $save_surface->write_to_png($filename);
            }
            elsif ($filename =~ /\.(jpg|jpeg)$/i) {
                my ($temp_fh, $temp_filename) = File::Temp::tempfile(SUFFIX => '.png');
                close $temp_fh;
                $save_surface->write_to_png($temp_filename);
                my $magick = Image::Magick->new();
                my $result = $magick->Read($temp_filename);
                if ($result) {
                    unlink $temp_filename;
                    die "Failed to read temporary PNG: $result\n";
                }
                $magick->Set('format' => 'JPEG');
                $magick->Set('quality' => 100);
                $result = $magick->Write(filename => $filename);
                unlink $temp_filename;
                die "Failed to write JPEG: $result\n" if $result;
            }
        };

        if ($@) {
            my $error_dialog = Gtk3::MessageDialog->new(
                $window,
                'modal',
                'error',
                'ok',
                "Failed to save image:\n$@"
            );
            $error_dialog->run();
            $error_dialog->destroy();
        }
    }

    $dialog->destroy();
    return TRUE;
}

sub save_project_as {
    my ($window) = @_;

    my $save_data = {
        version => '1.0',
        image_path => $initial_file, 
        canvas_width => $original_width,
        canvas_height => $original_height,
        global_timestamp => $global_timestamp,
        items => prepare_items_for_save(),
        dimming_level => $dimming_level,
    };

    my $dialog = Gtk3::FileChooserDialog->new(
        "Save Project",
        $window,
        'save',
        'gtk-cancel' => 'cancel',
        'gtk-save'   => 'accept'
    );
    
    $dialog->set_do_overwrite_confirmation(TRUE);
    $dialog->set_current_name("project.linia");
    
    my $linia_filter = Gtk3::FileFilter->new();
    $linia_filter->set_name("Linia Project (*.linia)");
    $linia_filter->add_pattern("*.linia");
    $dialog->add_filter($linia_filter);
    
    my $response = $dialog->run();
    my $success = 0;
    
    if ($response eq 'accept') {

        my $filename = $dialog->get_filename();

        $filename .= ".linia" unless $filename =~ /\.linia$/;

        if (open(my $fh, '>', $filename)) {
            print $fh to_json($save_data, { utf8 => 1, pretty => 1 });
            close $fh;
            
            $project_is_modified = 0; 
            $success = 1;
            
            my $display_name = basename($filename);
            $window->set_title("Linia - $display_name");
        } else {
            warn "Could not save project: $!";
        }
    }
    
    $dialog->destroy();
    return $success; 
}

sub open_project {
    my ($window) = @_;
    
    return unless check_unsaved_changes(); 
    
    my $dialog = Gtk3::FileChooserDialog->new(
        "Open Project",
        $window,
        'open',
        'gtk-cancel' => 'cancel',
        'gtk-open'   => 'accept'
    );
    
    my $linia_filter = Gtk3::FileFilter->new();
    $linia_filter->set_name("Linia Project (*.linia)");
    $linia_filter->add_pattern("*.linia");
    $dialog->add_filter($linia_filter);
    
    if ($dialog->run() eq 'accept') {
        my $filename = $dialog->get_filename();
        
        print "DEBUG: Opening project file: $filename\n";

        local $/; 
        open(my $fh, '<', $filename) or die "Cannot open file: $!";
        my $json_text = <$fh>;
        close $fh;
        
        print "DEBUG: JSON text length: " . length($json_text) . " bytes\n";
        
        my $data = eval { from_json($json_text) };
        
        if ($@) {
            print "DEBUG: ERROR parsing JSON: $@\n";
            my $error_dialog = Gtk3::MessageDialog->new($window, 'modal', 'error', 'ok', 
                "Error loading project:\n$@");
            $error_dialog->run();
            $error_dialog->destroy();
            $dialog->destroy();
            return;
        }
        
        if ($data) {
            print "DEBUG: Project data loaded successfully\n";
            print "DEBUG: Data keys: " . join(", ", keys %$data) . "\n";
            
            if ($data->{items}) {
                print "DEBUG: Items keys: " . join(", ", keys %{$data->{items}}) . "\n";
            } else {
                print "DEBUG: WARNING - No items key in data!\n";
            }

            if (-f $data->{image_path}) {
                print "DEBUG: Loading image: $data->{image_path}\n";
                load_image_file($data->{image_path}, $window);
                zoom_fit_best(); 
            } else {
                print "DEBUG: WARNING - Image not found: $data->{image_path}\n";
                my $msg = Gtk3::MessageDialog->new($window, 'modal', 'warning', 'ok', 
                    "Original image not found at:\n" . $data->{image_path} . 
                    "\n\nThe annotations will load, but the background image is missing.");
                $msg->run();
                $msg->destroy();
                close_image(); 
            }

            restore_items_from_load($data->{items});

            $global_timestamp = $data->{global_timestamp} || 0;

            $dimming_level = $data->{dimming_level} || 0;
            
            if ($dimming_scale) {
                $dimming_scale->set_value($dimming_level);
            }

            update_drawing_area_size();
            $drawing_area->queue_draw();
            $project_is_modified = 0;
            
            my $display_name = basename($filename);
            $window->set_title("Linia - $display_name");
        }
    }
    $dialog->destroy();
    
    return;
}

sub check_unsaved_changes {
    return 1 unless $project_is_modified;

    return 1 unless %items && (
        scalar(@{$items{lines} // []}) > 0 || 
        scalar(@{$items{rectangles} // []}) > 0 || 
        scalar(@{$items{text_items} // []}) > 0 || 
        scalar(@{$items{arrows} // []}) > 0 ||
        scalar(@{$items{ellipses} // []}) > 0 ||
        scalar(@{$items{triangles} // []}) > 0 ||
        scalar(@{$items{freehand_items} // []}) > 0
    ); 

    my $dialog = Gtk3::MessageDialog->new(
        $window,
        'modal',
        'question',
        'none',
        "You have unsaved changes."
    );
    
    $dialog->format_secondary_text("Do you want to save the project before closing?");
    
    $dialog->add_button('Close without Saving', 'close');
    $dialog->add_button('Cancel', 'cancel');
    $dialog->add_button('Save Project', 'accept');
    
    my $response = $dialog->run();
    $dialog->destroy();

    if ($response eq 'accept') {
        return save_project_as($window);
    }
    elsif ($response eq 'close') {
        return 1; 
    }

    return 0; 
}

sub prepare_items_for_save {
    my $clean_items = {};
    
    foreach my $type (keys %items) {
        $clean_items->{$type} = [];
        foreach my $item (@{$items{$type}}) {
            my $copy = clone_item($item);

            if ($copy->{stroke_color}) {
                $copy->{stroke_color} = color_to_hash($copy->{stroke_color});
            }
            if ($copy->{fill_color}) {
                $copy->{fill_color} = color_to_hash($copy->{fill_color});
            }
            if ($copy->{shadow_color}) {
                $copy->{shadow_color} = color_to_hash($copy->{shadow_color});
            }

            delete $copy->{pixelated_surface}; 
            delete $copy->{pixbuf}; 
            
            push @{$clean_items->{$type}}, $copy;
        }
    }
    return $clean_items;
}

sub restore_items_from_load {
    my ($loaded_items) = @_;

    print "DEBUG: restore_items_from_load called\n";
    
    unless (defined $loaded_items) {
        print "DEBUG: ERROR - loaded_items is undefined!\n";
        return;
    }
    
    unless (ref($loaded_items) eq 'HASH') {
        print "DEBUG: ERROR - loaded_items is not a hash reference!\n";
        return;
    }

    my %key_mapping = (
        'pixelized_items' => 'pixelize_items',
        'freehand_items'  => 'freehand-items',
    );

    foreach my $old_key (keys %key_mapping) {
        if (exists $loaded_items->{$old_key}) {
            my $new_key = $key_mapping{$old_key};
            print "DEBUG: Converting old key '$old_key' to '$new_key'\n";
            $loaded_items->{$new_key} = $loaded_items->{$old_key};
            delete $loaded_items->{$old_key};
        }
    }

    if (exists $loaded_items->{crop_rects} && ref($loaded_items->{crop_rects}) eq 'ARRAY') {
        print "DEBUG: Merging crop_rects into rectangles\n";
        $loaded_items->{rectangles} = [] unless exists $loaded_items->{rectangles};
        push @{$loaded_items->{rectangles}}, @{$loaded_items->{crop_rects}};
        delete $loaded_items->{crop_rects};
    }

    %items = ();
    
    my $total_items = 0;
    foreach my $type (keys %$loaded_items) {
        my $count = scalar(@{$loaded_items->{$type}});
        print "DEBUG: Loading type '$type' with $count items\n";
        $total_items += $count;
        
        $items{$type} = [];
        foreach my $item (@{$loaded_items->{$type}}) {
         
            if ($item->{stroke_color}) {
                $item->{stroke_color} = hash_to_color($item->{stroke_color});
            }
            if ($item->{fill_color}) {
                $item->{fill_color} = hash_to_color($item->{fill_color});
            }
            if ($item->{shadow_color}) {
                $item->{shadow_color} = hash_to_color($item->{shadow_color});
            }

            if ($item->{type} eq 'svg' && $item->{svg_content}) {
                my ($fh, $temp_file) = File::Temp::tempfile(SUFFIX => '.svg');
                print $fh $item->{svg_content};
                close $fh;

                my $w = $item->{original_width} || 100;
                my $h = $item->{original_height} || 100;
                
                my $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale($temp_file, $w, $h, TRUE);
                $item->{pixbuf} = $pixbuf;
                unlink $temp_file;
            }
            
            push @{$items{$type}}, $item;
        }
    }
    
    print "DEBUG: Total items loaded: $total_items\n";
    print "DEBUG: Items hash now contains: " . join(", ", map { "$_=" . scalar(@{$items{$_}}) } keys %items) . "\n";
    
    $current_item = undef;
    @selected_items = ();
    
    return;
}

sub load_recent_files {
    return unless -f $recent_files_file;

    open(my $fh, '<', $recent_files_file) or return;
    @recent_files = ();
    while (my $line = <$fh>) {
        chomp $line;
        push @recent_files, $line if -f $line;
    }
    close $fh;

    @recent_files = @recent_files[0..($max_recent_files-1)] if @recent_files > $max_recent_files;
    
    return;
}

sub save_recent_files {

    my $dir = dirname($recent_files_file);
    mkdir $dir unless -d $dir;

    open(my $fh, '>', $recent_files_file) or return;
    print $fh "$_\n" for @recent_files;
    close $fh;
    
    return;
}

sub add_recent_file {
    my ($filename) = @_;

    @recent_files = grep { $_ ne $filename } @recent_files;

    unshift @recent_files, $filename;

    @recent_files = @recent_files[0..($max_recent_files-1)] if @recent_files > $max_recent_files;

    create_thumbnail($filename);

    save_recent_files();
    update_recent_files_menu();
    
    return;
}

sub import_svg {
    my ($window) = @_;

    my $dialog = Gtk3::FileChooserDialog->new(
        "Import SVG",
        $window,
        'open',
        'gtk-cancel' => 'cancel',
        'gtk-open'   => 'accept'
    );

    my $filter = Gtk3::FileFilter->new();
    $filter->set_name("SVG files");
    $filter->add_mime_type("image/svg+xml");
    $dialog->add_filter($filter);

    my $response = $dialog->run();
    if ($response eq 'accept') {
        my $filename = $dialog->get_filename();
        load_svg_file($filename);
    }
    $dialog->destroy();
    
    return;
}

sub load_svg_file {
    my ($filename) = @_;

    eval {
        open my $fh, '<', $filename or die "Cannot open $filename: $!";
        my $svg_content = do { local $/; <$fh> };
        close $fh;

        my $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale(
            $filename,
            200,
            200,
            TRUE
        );
        return unless $pixbuf;

        my $width = $pixbuf->get_width();
        my $height = $pixbuf->get_height();

        my $canvas_width = $image_surface ? $image_surface->get_width() : $drawing_area->get_allocated_width();
        my $canvas_height = $image_surface ? $image_surface->get_height() : $drawing_area->get_allocated_height();

        my $center_x = ($canvas_width - $width) / 2;
        my $center_y = ($canvas_height - $height) / 2;

        my $svg_item = {
            type => 'svg',
            timestamp => ++$global_timestamp,
            pixbuf => $pixbuf,
            svg_content => $svg_content,
            x => $center_x,
            y => $center_y,
            width => $width,
            height => $height,
            original_width => $width,
            original_height => $height,
            scale => 1.0,
            selected => 1
        };

        push @{$items{svg_items}}, $svg_item;
        $current_item = $svg_item;
        $drawing_area->queue_draw();
    };
    if ($@) {
        warn "Error loading SVG: $@\n";
        my $dialog = Gtk3::MessageDialog->new(
            $window,
            'modal',
            'error',
            'ok',
            "Failed to load SVG file: $@"
        );
        $dialog->run();
        $dialog->destroy();
    }
    
    return;
}

sub load_icon {
    my ($icon_name, $size) = @_;

    $size = 32 unless defined $size;

    my $base = "$ENV{HOME}/.config/linia/icons/toolbar-icons";

    my $icon_path = "$base/$icon_theme/$icon_name.svg";

    unless (-f $icon_path) {
        $icon_path = "$base/$icon_name.svg";

        unless (-f $icon_path) {
            $icon_path = "$base/scalable/$icon_name.svg";

            unless (-f $icon_path) {
                warn "Icon not found: $icon_name.svg (Theme: $icon_theme)\n";
                return Gtk3::Image->new_from_stock('gtk-missing-image', 'menu');
            }
        }
    }

    my $scale_factor = 1;
    if (defined $window && $window->get_window()) {
        $scale_factor = $window->get_scale_factor();
    } else {
        my $display = Gtk3::Gdk::Display::get_default();
        if ($display) {
            my $monitor = $display->get_primary_monitor() || $display->get_monitor(0);
            $scale_factor = $monitor->get_scale_factor() if $monitor;
        }
    }

    my $render_size = $size * $scale_factor;

    my $surface = eval {
        my $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale($icon_path, $render_size, $render_size, TRUE);
        return unless $pixbuf;
        return Gtk3::Gdk::cairo_surface_create_from_pixbuf($pixbuf, $scale_factor, undef);
    };
    
    if ($@ || !$surface) {
        return Gtk3::Image->new_from_stock('gtk-missing-image', 'menu');
    }

    return Gtk3::Image->new_from_surface($surface);
}

sub save_icon_sizes {
    my $dir = dirname($icon_sizes_file);
    mkdir $dir unless -d $dir;

    open(my $fh, '>', $icon_sizes_file) or do {
        warn "Could not save icon sizes: $!\n";
        return;
    };
    
    print $fh "main_toolbar=$main_toolbar_icon_size\n";
    print $fh "drawing_toolbar=$drawing_toolbar_icon_size\n";
    print $fh "drawing_toolbar_position=" . ($drawing_toolbar_on_left ? "left" : "top") . "\n";
    
    close $fh;
    
    print "Icon sizes and toolbar position saved\n";
    
    return;
}

sub save_tool_state {
    my $dir = dirname($tools_config_file);
    mkdir $dir unless -d $dir;

    my $data = {
        line_width => $line_width,
        line_style => $current_line_style,
        font_name  => $font_btn_w ? $font_btn_w->get_font_name() : "Sans 30",
        stroke_color => color_to_hash($stroke_color),
        fill_color   => color_to_hash($fill_color),
        fill_alpha   => $fill_transparency_level,
        stroke_alpha => $stroke_transparency_level,
        dimming      => $dimming_level,
        handle_size  => $handle_size,
        drawing_toolbar_left => $drawing_toolbar_on_left,
        icon_theme => $icon_theme,
    };

    if (open(my $fh, '>', $tools_config_file)) {
        print $fh to_json($data, { utf8 => 1, pretty => 1 });
        close $fh;
        print "Tool state saved.\n";
    } else {
        warn "Could not save tool state: $!\n";
    }
    
    return;
}

sub load_tool_state {
    return unless -f $tools_config_file;

    local $/;
    open(my $fh, '<', $tools_config_file) or return;
    my $json_text = <$fh>;
    close $fh;

    my $data = eval { from_json($json_text) };
    return unless $data;

    if (defined $data->{line_width}) { $line_width = $data->{line_width}; }
    if (defined $data->{line_style}) { $current_line_style = $data->{line_style}; }
    if (defined $data->{handle_size}) { $handle_size = $data->{handle_size}; }
    if (defined $data->{icon_theme})  { $icon_theme  = $data->{icon_theme}; }
    
    if ($data->{stroke_color}) { $stroke_color = hash_to_color($data->{stroke_color}); }
    if ($data->{fill_color})   { $fill_color   = hash_to_color($data->{fill_color}); }
    
    if (defined $data->{fill_alpha})   { $fill_transparency_level = $data->{fill_alpha}; }
    if (defined $data->{stroke_alpha}) { $stroke_transparency_level = $data->{stroke_alpha}; }
    if (defined $data->{dimming})      { $dimming_level = $data->{dimming}; }

    if ($line_width_spin_button) { $line_width_spin_button->set_value($line_width); }
    if ($line_style_combo)       { $line_style_combo->set_active_id($current_line_style); }
    
    if ($stroke_color_button)    { $stroke_color_button->set_rgba($stroke_color); }
    if ($fill_color_button)      { $fill_color_button->set_rgba($fill_color); }
    
    if ($font_btn_w && $data->{font_name}) { 
        $font_btn_w->set_font_name($data->{font_name}); 
        if ($data->{font_name} =~ /(\d+)$/) { $font_size = $1; }
    }

    if ($fill_transparency_scale) {
        $fill_transparency_scale->set_value($fill_transparency_level);
        if ($fill_css_provider) {
             my $css = sprintf("scale trough highlight { background: %s; }", $fill_color->to_string());
             $fill_css_provider->load_from_data($css);
        }
    }

    if ($stroke_transparency_scale) {
        $stroke_transparency_scale->set_value($stroke_transparency_level);
        if ($stroke_css_provider) {
             my $css = sprintf("scale trough highlight { background: %s; }", $stroke_color->to_string());
             $stroke_css_provider->load_from_data($css);
        }
    }

    if ($dimming_scale) { $dimming_scale->set_value($dimming_level); }

    print "Tool state loaded.\n";
    
    return;
}

sub save_window_dimensions {
    my $dir = dirname($window_config_file);
    mkdir $dir unless -d $dir;

    open(my $fh, '>', $window_config_file) or do {
        warn "Could not save window dimensions: $!\n";
        return;
    };
    
    my ($width, $height) = $window->get_size();
    my ($x, $y) = $window->get_position();
    
    print $fh "width=$width\n";
    print $fh "height=$height\n";
    print $fh "x=$x\n";
    print $fh "y=$y\n";
    
    close $fh;
    
    print "Window dimensions saved: ${width}x${height} at ($x,$y)\n";
    
    return;
}

sub load_window_dimensions {
    return unless -f $window_config_file;

    my ($width, $height, $x, $y);
    
    open(my $fh, '<', $window_config_file) or return;
    
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^width=(\d+)$/) {
            $width = $1;
        }
        elsif ($line =~ /^height=(\d+)$/) {
            $height = $1;
        }
        elsif ($line =~ /^x=(-?\d+)$/) {
            $x = $1;
        }
        elsif ($line =~ /^y=(-?\d+)$/) {
            $y = $1;
        }
    }
    
    close $fh;

    if (defined $width && defined $height) {
        $window_width = $width;
        $window_height = $height;
        print "Loaded window size: ${width}x${height}\n";
    }
    
    if (defined $x && defined $y) {
        print "Will restore window position: ($x,$y)\n";

        Glib::Timeout->add(100, sub {
            if ($window) {
                $window->move($x, $y);
            }
            return FALSE;
        });
    }
    
    return;
}

sub copy_image_to_clipboard {
    return unless $image_surface;

    my $width = $image_surface->get_width();
    my $height = $image_surface->get_height();
    my $save_surface = Cairo::ImageSurface->create('argb32', $width, $height);
    my $cr = Cairo::Context->create($save_surface);

    $cr->set_source_surface($image_surface, 0, 0);
    $cr->paint();

    foreach my $type (qw(freehand-items highlighter-lines lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons numbered-circles svg_items pixelize_items text_items pyramids cuboids)) {
        if (exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY') {
            foreach my $item (@{$items{$type}}) {
                draw_item($cr, $item, 0); 
            }
        }
    }

    my ($fh, $filename) = File::Temp::tempfile(SUFFIX => '.png');
    $save_surface->write_to_png($filename);
    close $fh;

    my $pixbuf = eval { Gtk3::Gdk::Pixbuf->new_from_file($filename) };
    
    if ($pixbuf) {
        my $clipboard_atom = Gtk3::Gdk::Atom::intern('CLIPBOARD', FALSE);
        my $clipboard = Gtk3::Clipboard::get($clipboard_atom);
        $clipboard->set_image($pixbuf);
    } else {
        carp "Failed to create pixbuf for clipboard.\n";
    }
    unlink $filename;
    return;
}

sub create_thumbnail {
    my ($filename) = @_;
    return unless -f $filename;

    my $thumb_dir = "$ENV{HOME}/.config/linia/thumbnails";
    mkdir $thumb_dir unless -d $thumb_dir;

    my $thumb_name = Digest::MD5::md5_hex($filename) . ".png";
    my $thumb_path = "$thumb_dir/$thumb_name";

    my $max_size = 400; 

    eval {
        my $image = Image::Magick->new();
        $image->Read($filename);

        $image->Resize(
            geometry => "${max_size}x${max_size}>",
            filter   => 'Lanczos'
        );

        $image->UnsharpMask(radius => 0, sigma => 0.75, amount => 1.0, threshold => 0.05);

        $image->Strip();

        $image->Write($thumb_path);
    };
    if ($@) {
        warn "Error creating thumbnail for $filename: $@\n";
        return;
    }

    return $thumb_path;
}
    
    
# =============================================================================
# SECTION 5. FACTORY (Item creation)
# =============================================================================

sub create_line {
    my ($start_x, $start_y, $end_x, $end_y) = @_;

    my $line = {
        type => 'line',
        timestamp => ++$global_timestamp,
        start_x => $start_x,
        start_y => $start_y,
        end_x => $end_x,
        end_y => $end_y,
        control_x => undef,
        control_y => undef,
        stroke_color => $stroke_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1,
        is_curved => 0
    };
    
    if ($drop_shadow_enabled) {
        $line->{drop_shadow}     = 1;
        $line->{shadow_offset_x} = $shadow_offset_x;
        $line->{shadow_offset_y} = $shadow_offset_y;
        $line->{shadow_blur}     = $shadow_blur;
        $line->{shadow_alpha}    = $shadow_alpha;
        $line->{shadow_color}    = $shadow_base_color->copy();
    }

    $items{lines} = [] unless exists $items{lines};
    push @{$items{lines}}, $line;
    $current_item = $line;

    return $line;
}

sub create_arrow {
    my ($start_x, $start_y, $end_x, $end_y) = @_;
    my $arrow = {
        type => $current_tool,
        timestamp => ++$global_timestamp,
        start_x => $start_x,
        start_y => $start_y,
        end_x => $end_x,
        end_y => $end_y,
        control_x => ($start_x + $end_x) / 2,
        control_y => ($start_y + $end_y) / 2,
        stroke_color => $stroke_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1,
        is_curved => 0,
        style => $current_tool eq 'double-arrow' ? 'Double Arrow' : 'Single Arrow'
    };
    
    if ($drop_shadow_enabled) {
        $arrow->{drop_shadow}     = 1;
        $arrow->{shadow_offset_x} = $shadow_offset_x;
        $arrow->{shadow_offset_y} = $shadow_offset_y;
        $arrow->{shadow_blur}     = $shadow_blur;
        $arrow->{shadow_alpha}    = $shadow_alpha;
        $arrow->{shadow_color}    = $shadow_base_color->copy();
    }
    
    $current_item = $arrow;
    return $arrow;
}

sub create_rectangle {
    my ($start_x, $start_y, $end_x, $end_y) = @_;
    my $rectangle = {
        type => 'rectangle',
        timestamp => ++$global_timestamp,
        x1 => $start_x,
        y1 => $start_y,
        x2 => $end_x,
        y2 => $end_y,
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1
    };
    
    if ($drop_shadow_enabled) {
        $rectangle->{drop_shadow}     = 1;
        $rectangle->{shadow_offset_x} = $shadow_offset_x;
        $rectangle->{shadow_offset_y} = $shadow_offset_y;
        $rectangle->{shadow_blur}     = $shadow_blur;
        $rectangle->{shadow_alpha}    = $shadow_alpha;
        $rectangle->{shadow_color}    = $shadow_base_color->copy();
    }
    
    push @{$items{rectangles}}, $rectangle;
    $current_item = $rectangle;
    return $rectangle;
}

sub create_ellipse {
    my ($start_x, $start_y, $end_x, $end_y) = @_;
    my $ellipse = {
        type => 'ellipse',
        timestamp => ++$global_timestamp,
        x1 => $start_x,
        y1 => $start_y,
        x2 => $end_x,
        y2 => $end_y,
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1
    };
    
    if ($drop_shadow_enabled) {
        $ellipse->{drop_shadow}     = 1;
        $ellipse->{shadow_offset_x} = $shadow_offset_x;
        $ellipse->{shadow_offset_y} = $shadow_offset_y;
        $ellipse->{shadow_blur}     = $shadow_blur;
        $ellipse->{shadow_alpha}    = $shadow_alpha;
        $ellipse->{shadow_color}    = $shadow_base_color->copy();
    }
    
    push @{$items{ellipses}}, $ellipse;
    $current_item = $ellipse;
    return $ellipse;
}

sub create_triangle {
    my ($start_x, $start_y, $end_x, $end_y) = @_;

    my $dx = $end_x - $start_x;
    my $dy = $end_y - $start_y;

    my @vertices = (
        [$start_x, $start_y],   
        [$end_x, $end_y],              
        [$start_x - $dx, $end_y]  
    );

    my $triangle = {
        type => 'triangle',
        timestamp => ++$global_timestamp,
        vertices => \@vertices,
        middle_points => [],
        midpoint_states => { 0 => 'edge', 1 => 'edge', 2 => 'edge' },
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1
    };
    
    if ($drop_shadow_enabled) {
        $triangle->{drop_shadow}     = 1;
        $triangle->{shadow_offset_x} = $shadow_offset_x;
        $triangle->{shadow_offset_y} = $shadow_offset_y;
        $triangle->{shadow_blur}     = $shadow_blur;
        $triangle->{shadow_alpha}    = $shadow_alpha;
        $triangle->{shadow_color}    = $shadow_base_color->copy();
    }

    update_triangle_midpoints($triangle);
    return $triangle;
}

sub create_tetragon {
    my ($start_x, $start_y, $end_x, $end_y) = @_;
    my $width = $end_x - $start_x;
    my $height = $end_y - $start_y;

    my $tetragon = {
        type => 'tetragon',
        timestamp => ++$global_timestamp,
        vertices => [
            [$start_x, $start_y],
            [$start_x + $width, $start_y],
            [$start_x + $width, $start_y + $height],
            [$start_x, $start_y + $height]
        ],
        midpoint_states => {
            0 => 'edge',
            1 => 'edge',
            2 => 'edge',
            3 => 'edge'
        },
        middle_points => [],
        vertex_count => 4,
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1,
        is_dragging => 0
    };
    
    if ($drop_shadow_enabled) {
        $tetragon->{drop_shadow}     = 1;
        $tetragon->{shadow_offset_x} = $shadow_offset_x;
        $tetragon->{shadow_offset_y} = $shadow_offset_y;
        $tetragon->{shadow_blur}     = $shadow_blur;
        $tetragon->{shadow_alpha}    = $shadow_alpha;
        $tetragon->{shadow_color}    = $shadow_base_color->copy();
    }

    update_tetragon_midpoints($tetragon);

    return $tetragon;
}

sub create_pentagon {
    my ($start_x, $start_y, $end_x, $end_y) = @_;

    my $center_x = $start_x;
    my $center_y = $start_y;

    my $dx = $end_x - $center_x;
    my $dy = $end_y - $center_y;
    my $size = sqrt($dx * $dx + $dy * $dy);

    my @vertices;
    for my $i (0..4) {
        my $angle = (-pi/2) + ($i * 2 * pi / 5);
        my $x = $center_x + $size * cos($angle);
        my $y = $center_y + $size * sin($angle);
        push @vertices, [$x, $y];
    }

    my $pentagon = {
        type => 'pentagon',
        timestamp => ++$global_timestamp,
        vertices => \@vertices,
        midpoint_states => {
            map { $_ => 'edge' } (0..4)
        },
        middle_points => [],
        vertex_count => 5,
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1,
        is_dragging => 0
    };
    
    if ($drop_shadow_enabled) {
        $pentagon->{drop_shadow}     = 1;
        $pentagon->{shadow_offset_x} = $shadow_offset_x;
        $pentagon->{shadow_offset_y} = $shadow_offset_y;
        $pentagon->{shadow_blur}     = $shadow_blur;
        $pentagon->{shadow_alpha}    = $shadow_alpha;
        $pentagon->{shadow_color}    = $shadow_base_color->copy();
    }

    update_pentagon_midpoints($pentagon);
    return $pentagon;
}

sub create_pyramid {
    my ($start_x, $start_y, $end_x, $end_y) = @_;

    my $base_width = abs($end_x - $start_x);
    my $base_height = abs($end_y - $start_y);
    my $base_left = min($start_x, $end_x);
    my $base_right = max($start_x, $end_x);
    my $base_front = max($start_y, $end_y);
    my $base_back = min($start_y, $end_y);
    my $apex_x = ($base_left + $base_right) / 2;
    my $apex_y = $base_back - ($base_height * 0.8); 
    my $apex_z = $base_height * 0.6; 

    my $pyramid = {
        type => 'pyramid',
        base_left => $base_left,
        base_right => $base_right,
        base_front => $base_front,
        base_back => $base_back,
        apex_x => $apex_x,
        apex_y => $apex_y,
        apex_z => $apex_z,
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 0,
        timestamp => ++$global_timestamp
    };

    my %faces = (
        'base' => {
            vertices => [
                [$base_left, $base_front, 0],
                [$base_right, $base_front, 0],
                [$base_right, $base_back, 0],
                [$base_left, $base_back, 0]
            ],
            z_order => 4,
            face_type => 'base'
        },
        'front' => {
            vertices => [
                [$base_left, $base_front, 0],
                [$apex_x, $apex_y, $apex_z],
                [$base_right, $base_front, 0]
            ],
            z_order => 1,
            face_type => 'front'
        },
        'back' => {
            vertices => [
                [$base_right, $base_back, 0],
                [$apex_x, $apex_y, $apex_z],
                [$base_left, $base_back, 0]
            ],
            z_order => 3,
            face_type => 'back'
        },
        'left' => {
            vertices => [
                [$base_left, $base_back, 0],
                [$apex_x, $apex_y, $apex_z],
                [$base_left, $base_front, 0]
            ],
            z_order => 2,
            face_type => 'side'
        },
        'right' => {
            vertices => [
                [$base_right, $base_front, 0],
                [$apex_x, $apex_y, $apex_z],
                [$base_right, $base_back, 0]
            ],
            z_order => 5,
            face_type => 'side'
        }
    );

    foreach my $face_name (keys %faces) {
        my $face = $faces{$face_name};
        my @normal = calculate_face_normal($face->{vertices});
        $face->{normal} = \@normal;
    }

    $pyramid->{faces} = \%faces;

    $pyramid->{vertices} = [
        [$base_left, $base_front],
        [$base_right, $base_front],
        [$base_right, $base_back],
        [$base_left, $base_back],
        [$apex_x, $apex_y]
    ];
    
    if ($drop_shadow_enabled) {
        $pyramid->{drop_shadow}     = 1;
        $pyramid->{shadow_offset_x} = $shadow_offset_x;
        $pyramid->{shadow_offset_y} = $shadow_offset_y;
        $pyramid->{shadow_blur}     = $shadow_blur;
        $pyramid->{shadow_alpha}    = $shadow_alpha;
        $pyramid->{shadow_color}    = $shadow_base_color->copy();
    }
    
    update_pyramid_geometry($pyramid);
    
    return $pyramid;
}

sub create_cuboid {
    my ($start_x, $start_y, $end_x, $end_y) = @_;

    my $width = abs($end_x - $start_x);
    my $height = abs($end_y - $start_y);
    my $depth = min($width, $height) * 0.5; 
    my $front_left = min($start_x, $end_x);
    my $front_right = max($start_x, $end_x);
    my $front_top = min($start_y, $end_y);
    my $front_bottom = max($start_y, $end_y);
    my $back_offset_x = $depth * 0.6; 
    my $back_offset_y = -$depth * 0.6; 
    my $back_left = $front_left + $back_offset_x;
    my $back_right = $front_right + $back_offset_x;
    my $back_top = $front_top + $back_offset_y;
    my $back_bottom = $front_bottom + $back_offset_y;

    my $cuboid = {
        type => 'cuboid',
        front_left => $front_left,
        front_right => $front_right,
        front_top => $front_top,
        front_bottom => $front_bottom,
        back_left => $back_left,
        back_right => $back_right,
        back_top => $back_top,
        back_bottom => $back_bottom,
        depth => $depth,
        stroke_color => $stroke_color->copy(),
        fill_color => $fill_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 0,
        timestamp => ++$global_timestamp
    };

    my %faces = (
        'front' => {
            vertices => [
                [$front_left, $front_top, 0],
                [$front_right, $front_top, 0],
                [$front_right, $front_bottom, 0],
                [$front_left, $front_bottom, 0]
            ],
            z_order => 1,
            face_type => 'front'
        },
        'back' => {
            vertices => [
                [$back_left, $back_top, $depth],
                [$back_right, $back_top, $depth],
                [$back_right, $back_bottom, $depth],
                [$back_left, $back_bottom, $depth]
            ],
            z_order => 6,
            face_type => 'back'
        },
        'left' => {
            vertices => [
                [$front_left, $front_top, 0],
                [$back_left, $back_top, $depth],
                [$back_left, $back_bottom, $depth],
                [$front_left, $front_bottom, 0]
            ],
            z_order => 3,
            face_type => 'side'
        },
        'right' => {
            vertices => [
                [$front_right, $front_top, 0],
                [$back_right, $back_top, $depth],
                [$back_right, $back_bottom, $depth],
                [$front_right, $front_bottom, 0]
            ],
            z_order => 4,
            face_type => 'side'
        },
        'top' => {
            vertices => [
                [$front_left, $front_top, 0],
                [$front_right, $front_top, 0],
                [$back_right, $back_top, $depth],
                [$back_left, $back_top, $depth]
            ],
            z_order => 2,
            face_type => 'top'
        },
        'bottom' => {
            vertices => [
                [$front_left, $front_bottom, 0],
                [$front_right, $front_bottom, 0],
                [$back_right, $back_bottom, $depth],
                [$back_left, $back_bottom, $depth]
            ],
            z_order => 5,
            face_type => 'bottom'
        }
    );

    foreach my $face_name (keys %faces) {
        my $face = $faces{$face_name};
        my @normal = calculate_face_normal($face->{vertices});
        $face->{normal} = \@normal;
    }

    $cuboid->{faces} = \%faces;

    $cuboid->{vertices} = [
        [$front_left, $front_top],
        [$front_right, $front_top],
        [$front_right, $front_bottom],
        [$front_left, $front_bottom],
        [$back_left, $back_top],
        [$back_right, $back_top],
        [$back_right, $back_bottom],
        [$back_left, $back_bottom]
    ];
    
    if ($drop_shadow_enabled) {
        $cuboid->{drop_shadow}     = 1;
        $cuboid->{shadow_offset_x} = $shadow_offset_x;
        $cuboid->{shadow_offset_y} = $shadow_offset_y;
        $cuboid->{shadow_blur}     = $shadow_blur;
        $cuboid->{shadow_alpha}    = $shadow_alpha;
        $cuboid->{shadow_color}    = $shadow_base_color->copy();
    }
    
    update_cuboid_faces($cuboid);
    return $cuboid;
}

sub create_text_item {
    my ($x, $y) = @_;
    
    my $current_font = $font_btn_w ? $font_btn_w->get_font_name() : 'Sans 20';
    
    my ($size) = $current_font =~ /(\d+)$/;
    $size //= 20;

    my $text_item = {
        type => 'text',
        x => $x,
        y => $y,
        text => '', 
        font => $current_font, 
        stroke_color => $stroke_color->copy(),
        timestamp => ++$global_timestamp,
        selected => 1,
        is_editing => 1, 
        width => 0,
        height => $size * 1.5, 
        dragging => 0,
        cursor_pos => 0,
        current_line => 0,
        current_column => 0,
        handles => {}
    };
    
    if ($drop_shadow_enabled) {
        $text_item->{drop_shadow}     = 1;
        $text_item->{shadow_offset_x} = $shadow_offset_x;
        $text_item->{shadow_offset_y} = $shadow_offset_y;
        $text_item->{shadow_blur}     = $shadow_blur;
        $text_item->{shadow_alpha}    = $shadow_alpha;
        $text_item->{shadow_color}    = $shadow_base_color->copy(); 
    }

    push @{$items{text_items}}, $text_item;
    $current_item = $text_item;
    return $text_item;
}

sub create_numbered_circle {
    my ($x, $y) = @_;

    my $next_number = 1;
    if (exists $items{'numbered-circles'} && ref($items{'numbered-circles'}) eq 'ARRAY') {
        my @active_circles = grep { !$_->{anchored} } @{$items{'numbered-circles'}};
        if (@active_circles) {
            $next_number = max(map { $_->{number} } @active_circles) + 1;
        }
    }

    $font_size = int($circle_radius * 0.6) unless $font_size;

    my $circle = {
        type => 'numbered-circle',
        timestamp => ++$global_timestamp,
        x => $x,
        y => $y,
        radius => $circle_radius,     
        number => $next_number,
        fill_color => $fill_color->copy(),
        stroke_color => $stroke_color->copy(),
        line_width => $line_width,       
        line_style => $current_line_style,
        selected => 1,
        font_family => $font_family,
        font_size => $font_size,      
        font_style => $font_style
    };
    
    if ($drop_shadow_enabled) {
        $circle->{drop_shadow}     = 1;
        $circle->{shadow_offset_x} = $shadow_offset_x;
        $circle->{shadow_offset_y} = $shadow_offset_y;
        $circle->{shadow_blur}     = $shadow_blur;
        $circle->{shadow_alpha}    = $shadow_alpha;
        $circle->{shadow_color}    = $shadow_base_color->copy();
    }

    push @{$items{'numbered-circles'}}, $circle;
    $current_item = $circle;
    return $circle;
}

sub create_freehand_item {
    my ($points) = @_;
    my $freehand = {
        type => 'freehand',
        timestamp => ++$global_timestamp,
        points => [@$points],
        stroke_color => $stroke_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1
    };

    if (exists $line_styles{$current_line_style}) {
        my $pattern = $line_styles{$current_line_style}{pattern};
    }

    return $freehand;
}

sub create_polyline {
    my ($self, $start_x, $start_y, $end_x, $end_y, $is_highlighter) = @_;

    my $polyline = {
        type => ($is_highlighter ? 'highlighter' : 'freehand'),
        timestamp => ++$global_timestamp,
        points => [$start_x, $start_y],
        stroke_color => $stroke_color->copy(),
        line_width => $line_width,
        line_style => $current_line_style,
        selected => 1
    };

    if ($is_highlighter) {
   
        $polyline->{stroke_color} = Gtk3::Gdk::RGBA->new(1, 1, 0, 0.5);
        $polyline->{line_width} = 18; 
        push @{$items{'highlighter-lines'}}, $polyline;
    } else {
        $polyline->{stroke_color} = $stroke_color->copy();
        $polyline->{line_width} = $line_width;
        push @{$items{'freehand-items'}}, $polyline;
    }

    $current_item = $polyline;
    return $polyline;
}

sub create_magnifier {
    my ($x, $y) = @_;

    my $magnifier = {
        type => 'magnifier',
        timestamp => ++$global_timestamp,
        x => $x,
        y => $y,
        radius => $magnifier_radius,
        zoom => $magnifier_zoom,
        selected => 1
    };

    push @{$items{magnifiers}}, $magnifier;
    $current_item = $magnifier;
    return $magnifier;
}

sub create_pixelize {
    my ($start_x, $start_y, $end_x, $end_y) = @_;

    my $img_w = $image_surface ? $image_surface->get_width() : 1000;
    my $img_h = $image_surface ? $image_surface->get_height() : 1000;
    my $max_dim = max($img_w, $img_h);

    my $auto_pixel_size = int($max_dim / 80); 

    $auto_pixel_size = max(10, $auto_pixel_size);

    my $pixelize = {
        type => 'pixelize',
        timestamp => ++$global_timestamp,
        x1 => $start_x,
        y1 => $start_y,
        x2 => $end_x,
        y2 => $end_y,
        stroke_color => $stroke_color->copy(),
        line_width => 2,
        selected => 1,
        pixel_size => $auto_pixel_size 
    };
    
    push @{$items{pixelize_items}}, $pixelize;

    $current_item = $pixelize;
    return $pixelize;
}

sub clone_item {
    my ($item) = @_;
    return unless defined $item; 

    my $clone = {};
    foreach my $key (keys %$item) {
       
        if (ref($item->{$key}) eq 'ARRAY') {
       
            if (@{$item->{$key}} && ref($item->{$key}->[0]) eq 'ARRAY') {
                $clone->{$key} = [ map { [@$_] } @{$item->{$key}} ];
            } else {
              
                $clone->{$key} = [ @{$item->{$key}} ];
            }
        }
   
        elsif (ref($item->{$key}) eq 'HASH' && $key ne 'faces') {
            $clone->{$key} = { %{$item->{$key}} };
        }
   
        elsif ($key eq 'faces' && ref($item->{$key}) eq 'HASH') {
            my $new_faces = {};
            foreach my $face_name (keys %{$item->{$key}}) {
                my $face_data = $item->{$key}{$face_name};
                $new_faces->{$face_name} = { %$face_data }; 

                if ($face_data->{vertices}) {
                    $new_faces->{$face_name}{vertices} = [ map { [@$_] } @{$face_data->{vertices}} ];
                }

                if ($face_data->{normal}) {
                    $new_faces->{$face_name}{normal} = [ @{$face_data->{normal}} ];
                }
            }
            $clone->{$key} = $new_faces;
        }

        elsif ($key eq 'edges' && ref($item->{$key}) eq 'ARRAY') {
    
             $clone->{$key} = [ map { [@$_] } @{$item->{$key}} ];
        }

        elsif ($key eq 'stroke_color' || $key eq 'fill_color') {
            if (defined $item->{$key} && $item->{$key}->can('copy')) { 
                $clone->{$key} = $item->{$key}->copy();
            } else {
                $clone->{$key} = undef; 
            }
        }

        elsif ($key eq 'pixbuf' && $item->{$key}) {
            $clone->{$key} = $item->{$key}->copy();
        }

        elsif ($key eq 'pixelated_surface') {
        
            $clone->{$key} = undef; 
        }

        else {
            $clone->{$key} = $item->{$key};
        }
    }
    return $clone;
}

sub clone_current_state {
    my %state;
    foreach my $key (keys %items) {
        $state{$key} = [map { clone_item($_) } @{$items{$key}}];
    }
    return \%state;
}
    
    
# =============================================================================
# SECTION 6. VIEW (Rendering & Drawing)
# =============================================================================


# Main Loop:

sub draw_image {
    my ($widget, $cr, $event) = @_;

    $cr->set_source_rgb(178/255, 183/255, 190/255);
    $cr->paint();

    return unless $image_surface;

    $cr->save();

    my $render_surface = $image_surface;
    my $render_ratio = 1.0;

    if ($preview_surface && $preview_surface != $image_surface) {
        my $screen_w = $image_surface->get_width() * $scale_factor;
        if ($screen_w < $preview_surface->get_width() * 1.5) { 
            $render_surface = $preview_surface;
            $render_ratio = $preview_ratio;
        }
    }

    my $cairo_scale = $scale_factor / $render_ratio;

    $cr->scale($cairo_scale, $cairo_scale);
    $cr->set_source_surface($render_surface, 0, 0);

    my $pattern = $cr->get_source();
    if ($is_zooming_active || $is_panning) {
        $pattern->set_filter('fast'); 
    } else {
        $pattern->set_filter('good'); 
    }
    
    $cr->paint();

    if ($dimming_level > 0) {
    
        my $mask = Cairo::ImageSurface->create('a8', 
            $render_surface->get_width(), 
            $render_surface->get_height()
        );
        my $mask_cr = Cairo::Context->create($mask);

        $mask_cr->scale($render_ratio, $render_ratio);

        $mask_cr->set_source_rgb(0, 0, 0);
        $mask_cr->paint();
        $mask_cr->set_operator('clear');

        foreach my $rect (@{$items{rectangles}}) {
            next unless defined $rect;
            my $x = min($rect->{x1}, $rect->{x2});
            my $y = min($rect->{y1}, $rect->{y2});
            my $width = abs($rect->{x2} - $rect->{x1});
            my $height = abs($rect->{y2} - $rect->{y1});
            $mask_cr->rectangle($x, $y, $width, $height);
            $mask_cr->fill();
        }
        foreach my $ellipse (@{$items{ellipses}}) {
            next unless defined $ellipse;
            my $cx = ($ellipse->{x1} + $ellipse->{x2}) / 2;
            my $cy = ($ellipse->{y1} + $ellipse->{y2}) / 2;
            my $rx = abs($ellipse->{x2} - $ellipse->{x1}) / 2;
            my $ry = abs($ellipse->{y2} - $ellipse->{y1}) / 2;
            $mask_cr->save();
            $mask_cr->translate($cx, $cy);
            $mask_cr->scale($rx, $ry);
            $mask_cr->arc(0, 0, 1, 0, 2 * 3.14159);
            $mask_cr->restore();
            $mask_cr->fill();
        }
        foreach my $type (qw(triangles tetragons pentagons pyramids)) {
            foreach my $shape (@{$items{$type}}) {
                next unless defined $shape && $shape->{vertices};
                $mask_cr->move_to(@{$shape->{vertices}[0]});
                for my $i (1 .. $#{$shape->{vertices}}) {
                    $mask_cr->line_to(@{$shape->{vertices}[$i]});
                }
                $mask_cr->close_path();
                $mask_cr->fill();
            }
        }

        my $alpha = $dimming_level * 0.9 / 100;
        $cr->set_source_rgba(0, 0, 0, $alpha);
        $cr->mask_surface($mask, 0, 0);
        $mask->finish();
    }
    
    $cr->restore();

    my @all_items;
    foreach my $type (qw(text_items svg_items magnifiers numbered-circles lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines pixelize_items crop_rect)) {
        if (exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY') {
     
            foreach my $item (grep { defined $_ } @{$items{$type}}) {
                push @all_items, $item;
            }
        }
    }

    @all_items = sort { $a->{timestamp} <=> $b->{timestamp} } @all_items;

    if (@all_items) {
        foreach my $item (@all_items) {
            $cr->save();
            $cr->scale($scale_factor, $scale_factor);
            my $is_anchored_flag = (defined $item->{anchored} && $item->{anchored}) ? 1 : 0;
            draw_item($cr, $item, $is_anchored_flag);
            $cr->restore();
        }
    }

    if ($is_drawing_freehand && @freehand_points >= 2) {
        $cr->save();
        $cr->scale($scale_factor, $scale_factor);

        if ($current_tool eq 'highlighter') {
            $cr->set_line_width(18);
            $cr->set_source_rgba(1, 1, 0, 0.5); 
        } else {
            $cr->set_line_width($line_width);
            $cr->set_source_rgba(
                $stroke_color->red,
                $stroke_color->green,
                $stroke_color->blue,
                $stroke_color->alpha
            );
        }
        $cr->set_line_cap('round');
        $cr->set_line_join('round');
        $cr->move_to($freehand_points[0], $freehand_points[1]);
        for (my $i = 2; $i < @freehand_points; $i += 2) {
            $cr->line_to($freehand_points[$i], $freehand_points[$i+1]);
        }
        $cr->stroke();
        $cr->restore();
    }

    if ($is_drawing && defined $start_x && defined $start_y && defined $end_x && defined $end_y) {
        $cr->save();
        $cr->scale($scale_factor, $scale_factor);

        my $raw_dist = sqrt(($end_x - $start_x)**2 + ($end_y - $start_y)**2);

        if ($current_tool =~ /arrow/ && $raw_dist < 5) {
            $cr->restore();
            return FALSE;
        }

        if ($current_tool eq 'crop') {
        
             my $x = min($start_x, $end_x);
             my $y = min($start_y, $end_y);
             my $w = abs($end_x - $start_x);
             my $h = abs($end_y - $start_y);
             
             $cr->set_source_rgb(1, 1, 1);
             $cr->set_line_width(2 / $scale_factor);
             $cr->set_dash(5, 5);
             $cr->rectangle($x, $y, $w, $h);
             $cr->stroke();
             $cr->set_dash(0);
        }
        elsif ($current_tool eq 'line') {
            my $actual_end_x = $end_x;
            my $actual_end_y = $end_y;
            if ($stored_event && $stored_event->state & 'control-mask') {
                $actual_end_y = $start_y;
            } elsif ($stored_event && $stored_event->state & 'shift-mask') {
                $actual_end_x = $start_x;
            }
            draw_line($cr, $start_x, $start_y, $actual_end_x, $actual_end_y, $stroke_color, $line_width);
        }
        elsif ($current_tool =~ /^(single-arrow|double-arrow)$/) {
            my $actual_end_x = $end_x;
            my $actual_end_y = $end_y;
            if ($stored_event && $stored_event->state & 'control-mask') {
                $actual_end_y = $start_y; 
            } elsif ($stored_event && $stored_event->state & 'shift-mask') {
                $actual_end_x = $start_x;
            }
            my $preview_item = {
                type => $current_tool,
                start_x => $start_x,
                start_y => $start_y,
                end_x => $actual_end_x,
                end_y => $actual_end_y,
                stroke_color => $stroke_color,
                line_width => $line_width,
                style => ($current_tool eq 'double-arrow' ? 'Double Arrow' : 'Single Arrow'),
                line_style => $current_line_style 
            };
            draw_arrow($cr, $start_x, $start_y, $actual_end_x, $actual_end_y, $stroke_color, $line_width, $preview_item);
        }
       elsif ($current_tool eq 'rectangle') {
            my $preview_item = {
                type => 'rectangle',
                x1 => $start_x,
                y1 => $start_y,
                x2 => $end_x,
                y2 => $end_y,
                stroke_color => $stroke_color,
                fill_color => $fill_color,
                line_width => $line_width,

                line_style => $current_line_style,
                
                selected => 1
            };
            draw_rectangle($cr, $start_x, $start_y, $end_x, $end_y, $stroke_color, $fill_color, $line_width, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'ellipse') {
            my $preview_item = {
                type => 'ellipse',
                x1 => $start_x,
                y1 => $start_y,
                x2 => $end_x,
                y2 => $end_y,
                stroke_color => $stroke_color,
                fill_color => $fill_color,
                line_width => $line_width,

                line_style => $current_line_style,
                
                selected => 1
            };
            draw_ellipse($cr, $start_x, $start_y, $end_x, $end_y, $stroke_color, $fill_color, $line_width, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'triangle') {
            my $preview_item = create_triangle($start_x, $start_y, $end_x, $end_y);            
            if ($preview_item) {
                $preview_item->{selected} = 1;
                draw_triangle($cr, $preview_item);
                draw_selection_handles($cr, $preview_item);
            }
        }
        elsif ($current_tool eq 'tetragon') {
            my $preview_item = create_tetragon($start_x, $start_y, $end_x, $end_y);
            $preview_item->{selected} = 1;
            draw_tetragon($cr, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'pentagon') {
            my $preview_item = create_pentagon($start_x, $start_y, $end_x, $end_y);
            $preview_item->{selected} = 1;
            draw_pentagon($cr, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'pyramid') {
            my $preview_item = create_pyramid($start_x, $start_y, $end_x, $end_y);
            $preview_item->{selected} = 1;
            draw_pyramid($cr, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'cuboid') {
            my $preview_item = create_cuboid($start_x, $start_y, $end_x, $end_y);
            $preview_item->{selected} = 1;
            draw_cuboid($cr, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'pixelize') {
 
            my $img_w = $image_surface->get_width();
            my $img_h = $image_surface->get_height();
            my $auto_size = int(max($img_w, $img_h) / 80);
            $auto_size = max(10, $auto_size);

            my $preview_item = {
                type => 'pixelize',
                x1 => $start_x, y1 => $start_y, x2 => $end_x, y2 => $end_y,
                stroke_color => $stroke_color, 
                line_width => 2, 
                selected => 1, 
                pixel_size => $auto_size 
            };
            
            draw_pixelize($cr, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }
        elsif ($current_tool eq 'numbered-circle') {
            my $preview_item = {
                type => 'numbered-circle',
                x => $start_x,
                y => $start_y,
                radius => sqrt(($end_x - $start_x)**2 + ($end_y - $start_y)**2),
                number => $current_number, 
                stroke_color => $stroke_color,
                fill_color => $fill_color,
                line_width => $line_width,
                selected => 1
            };
            draw_numbered_circle($cr, $preview_item);
            draw_selection_handles($cr, $preview_item);
        }

        $cr->restore();
    }

    return FALSE;
}

# Dispatcher:

sub draw_shadow {
    my ($cr, $item) = @_;
    
    return unless $item->{drop_shadow};

    my $offset_x = $item->{shadow_offset_x} // $shadow_offset_x;
    my $offset_y = $item->{shadow_offset_y} // $shadow_offset_y;
    my $alpha    = $item->{shadow_alpha} // $shadow_alpha;
    my $blur_radius = $item->{shadow_blur} // $shadow_blur;
    my $line_w   = $item->{line_width} // 3; 
    my $base_color;
    if ($item->{shadow_color}) {
        $base_color = $item->{shadow_color};
    } else {
        $base_color = $shadow_base_color;
    }

    $cr->save();
    
    my $should_clip = ($item->{type} =~ /^(rectangle|ellipse|triangle|tetragon|pentagon|numbered-circle)$/);
    
    if ($should_clip) {
        my $large_size = 100000;
        $cr->rectangle(-$large_size, -$large_size, $large_size * 2, $large_size * 2);
        
        if ($item->{type} eq 'rectangle') {
            my $x = min($item->{x1}, $item->{x2});
            my $y = min($item->{y1}, $item->{y2});
            my $width = abs($item->{x2} - $item->{x1});
            my $height = abs($item->{y2} - $item->{y1});
            $cr->rectangle($x, $y, $width, $height);
            
        } elsif ($item->{type} eq 'ellipse') {
            my $center_x = ($item->{x1} + $item->{x2}) / 2;
            my $center_y = ($item->{y1} + $item->{y2}) / 2;
            my $radius_x = abs($item->{x2} - $item->{x1}) / 2;
            my $radius_y = abs($item->{y2} - $item->{y1}) / 2;
            
            $cr->save();
            $cr->translate($center_x, $center_y);
            $cr->scale($radius_x, $radius_y);
            $cr->arc(0, 0, 1, 0, 2 * 3.14159);
            $cr->restore();
            
        } elsif ($item->{type} eq 'numbered-circle') {
            $cr->arc($item->{x}, $item->{y}, $item->{radius}, 0, 2 * pi);
            
        } elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/ && $item->{vertices}) {
            $cr->move_to(@{$item->{vertices}[0]});
            for my $i (1 .. $#{$item->{vertices}}) {
                $cr->line_to(@{$item->{vertices}[$i]});
            }
            $cr->close_path();
        }
        
        $cr->set_fill_rule('even-odd');
        $cr->clip();
    }

    my $blur_iterations = $blur_radius > 0 ? int($blur_radius * 2 + 1) : 1;
    my $blur_step = $blur_radius > 0 ? $blur_radius / ($blur_iterations - 1) : 0;
    
    for (my $i = 0; $i < $blur_iterations; $i++) {
        $cr->save();
        
        my $blur_offset = $blur_radius > 0 ? -$blur_radius + ($i * $blur_step * 2) : 0;
        my $iteration_alpha = $blur_iterations > 1 ? $alpha / $blur_iterations : $alpha;
        
        $cr->set_source_rgba(
            $base_color->red, 
            $base_color->green, 
            $base_color->blue, 
            $iteration_alpha 
        );

        $cr->set_line_width($line_w * 1.5); 
        $cr->set_line_join('round');
        $cr->set_line_cap('round');
        $cr->set_dash(0); 

        $cr->translate($offset_x + $blur_offset, $offset_y + $blur_offset);
        $cr->new_path();

        my $shape_drawn = 0;
        
        if ($item->{type} eq 'text') {
            my $layout = Pango::Cairo::create_layout($cr);
            my $desc = Pango::FontDescription->from_string($item->{font});
            $layout->set_font_description($desc);
            
            my @lines = split("\n", $item->{text});
            my $y_offset = 0;
            
            foreach my $line (@lines) {
                $layout->set_text($line || ' ');
                my (undef, $height) = $layout->get_pixel_size();
                $cr->move_to($item->{x}, $item->{y} + $y_offset);
                Pango::Cairo::show_layout($cr, $layout);
                $y_offset += $height;
            }
            $cr->fill();
            $shape_drawn = 1;

        } elsif ($item->{type} eq 'rectangle') {
            my $x = min($item->{x1}, $item->{x2});
            my $y = min($item->{y1}, $item->{y2});
            my $width = abs($item->{x2} - $item->{x1});
            my $height = abs($item->{y2} - $item->{y1});
            $cr->rectangle($x, $y, $width, $height);
            $shape_drawn = 3;

        } elsif ($item->{type} eq 'ellipse') {
            my $center_x = ($item->{x1} + $item->{x2}) / 2;
            my $center_y = ($item->{y1} + $item->{y2}) / 2;
            my $radius_x = abs($item->{x2} - $item->{x1}) / 2;
            my $radius_y = abs($item->{y2} - $item->{y1}) / 2;
            
            $cr->save();
            $cr->translate($center_x, $center_y);
            $cr->scale($radius_x, $radius_y);
            $cr->arc(0, 0, 1, 0, 2 * 3.14159);
            $cr->restore();
            
            $shape_drawn = 3;

        } elsif ($item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
            
            if ($item->{line_style} && exists $line_styles{$item->{line_style}}) {
                my $pattern = $line_styles{$item->{line_style}}{pattern};
                if (@$pattern) {
                    my @scaled_pattern = map { $_ * $line_w } @$pattern;
                    $cr->set_dash(0, @scaled_pattern);
                }
            }
            
            my $arrow_length = $line_w * 7;
            my $arrow_angle = 0.4;
            
            my $is_arrow = ($item->{type} =~ /arrow$/);
            
            my $is_curved = $item->{is_curved} && defined $item->{control_x} && defined $item->{control_y};
            
            if ($is_arrow) {
                my ($start_angle, $end_angle);
                
                if ($is_curved) {
                    my $control_x = $item->{control_x};
                    my $control_y = $item->{control_y};
                    my $start_x = $item->{start_x};
                    my $start_y = $item->{start_y};
                    my $end_x = $item->{end_x};
                    my $end_y = $item->{end_y};
                    
                    my $steps = 100;
                    my @curve_points;
                    for my $i (0..$steps) {
                        my $t = $i / $steps;
                        my $t2 = 1 - $t;
                        my $x = $t2 * $t2 * $start_x + 2 * $t2 * $t * $control_x + $t * $t * $end_x;
                        my $y = $t2 * $t2 * $start_y + 2 * $t2 * $t * $control_y + $t * $t * $end_y;
                        push @curve_points, [$x, $y];
                    }
                    
                    $end_angle = atan2(
                        $curve_points[-1][1] - $curve_points[-2][1],
                        $curve_points[-1][0] - $curve_points[-2][0]
                    );
                    $start_angle = atan2(
                        $curve_points[1][1] - $curve_points[0][1],
                        $curve_points[1][0] - $curve_points[0][0]
                    );
                } else {
                    my $dx = $item->{end_x} - $item->{start_x};
                    my $dy = $item->{end_y} - $item->{start_y};
                    $end_angle = $start_angle = atan2($dy, $dx);
                }
                
                my $start_adjust = ($item->{type} eq 'double-arrow') ? $arrow_length * 0.7 : 0;
                my $end_adjust = $arrow_length * 0.7;
                
                my $adj_start_x = $item->{start_x} + cos($start_angle) * $start_adjust;
                my $adj_start_y = $item->{start_y} + sin($start_angle) * $start_adjust;
                my $adj_end_x = $item->{end_x} - cos($end_angle) * $end_adjust;
                my $adj_end_y = $item->{end_y} - sin($end_angle) * $end_adjust;
                
                if ($is_curved) {
                    $cr->move_to($adj_start_x, $adj_start_y);
                    $cr->curve_to(
                        $item->{control_x}, $item->{control_y},
                        $item->{control_x}, $item->{control_y},
                        $adj_end_x, $adj_end_y
                    );
                } else {
                    $cr->move_to($adj_start_x, $adj_start_y);
                    $cr->line_to($adj_end_x, $adj_end_y);
                }
                $cr->stroke();
                
                my $x1 = $item->{end_x} - $arrow_length * cos($end_angle + $arrow_angle);
                my $y1 = $item->{end_y} - $arrow_length * sin($end_angle + $arrow_angle);
                my $x2 = $item->{end_x} - $arrow_length * cos($end_angle - $arrow_angle);
                my $y2 = $item->{end_y} - $arrow_length * sin($end_angle - $arrow_angle);
                
                $cr->move_to($item->{end_x}, $item->{end_y});
                $cr->line_to($x1, $y1);
                $cr->line_to($x2, $y2);
                $cr->close_path();
                $cr->fill();
                
                if ($item->{type} eq 'double-arrow') {
                    my $x3 = $item->{start_x} + $arrow_length * cos($start_angle + $arrow_angle);
                    my $y3 = $item->{start_y} + $arrow_length * sin($start_angle + $arrow_angle);
                    my $x4 = $item->{start_x} + $arrow_length * cos($start_angle - $arrow_angle);
                    my $y4 = $item->{start_y} + $arrow_length * sin($start_angle - $arrow_angle);
                    
                    $cr->move_to($item->{start_x}, $item->{start_y});
                    $cr->line_to($x3, $y3);
                    $cr->line_to($x4, $y4);
                    $cr->close_path();
                    $cr->fill();
                }
                
                $shape_drawn = 1;
            } else {
                if ($is_curved) {
                    $cr->move_to($item->{start_x}, $item->{start_y});
                    $cr->curve_to(
                        $item->{control_x}, $item->{control_y},
                        $item->{control_x}, $item->{control_y},
                        $item->{end_x}, $item->{end_y}
                    );
                } else {
                    $cr->move_to($item->{start_x}, $item->{start_y});
                    $cr->line_to($item->{end_x}, $item->{end_y});
                }
                $shape_drawn = 2;
            }
            
            $cr->set_dash(0);

        } elsif ($item->{type} eq 'pyramid' && $item->{vertices}) {
            my $vertices = $item->{vertices};
            if ($vertices && @$vertices >= 4) {
                $cr->move_to(@{$vertices->[0]});
                for my $i (1..3) {
                    $cr->line_to(@{$vertices->[$i]});
                }
                $cr->close_path();
                
                if (@$vertices >= 5) {
                    for my $i (0..3) {
                        $cr->move_to(@{$vertices->[$i]});
                        $cr->line_to(@{$vertices->[4]});
                    }
                }
                $shape_drawn = 2;
            }
            
        } elsif ($item->{type} eq 'cuboid' && $item->{faces}) {
            my %edges_drawn;
            
            foreach my $face_name (keys %{$item->{faces}}) {
                my $face = $item->{faces}{$face_name};
                next unless $face && $face->{vertices};
                my $verts = $face->{vertices};
                next unless @$verts >= 3;
                
                for my $i (0..$#$verts) {
                    my $next_i = ($i + 1) % scalar(@$verts);
                    my ($x1, $y1) = @{$verts->[$i]};
                    my ($x2, $y2) = @{$verts->[$next_i]};
                    
                    my $edge_key = join(',', sort ("$x1,$y1", "$x2,$y2"));
                    
                    unless ($edges_drawn{$edge_key}) {
                        $cr->move_to($x1, $y1);
                        $cr->line_to($x2, $y2);
                        $edges_drawn{$edge_key} = 1;
                    }
                }
            }
            $shape_drawn = 2;

        } elsif ($item->{type} eq 'numbered-circle') {
            $cr->arc($item->{x}, $item->{y}, $item->{radius}, 0, 2 * pi);
            $shape_drawn = 3;
            
        } elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/ && $item->{vertices}) {
            $cr->move_to(@{$item->{vertices}[0]});
            for my $i (1 .. $#{$item->{vertices}}) {
                $cr->line_to(@{$item->{vertices}[$i]});
            }
            $cr->close_path();
            $shape_drawn = 3;
        }
        
        if ($shape_drawn == 2) {
            $cr->stroke();
        } elsif ($shape_drawn == 3) {
            $cr->fill();
        }
        
        $cr->restore();
    }
    
    $cr->restore();
    
    return;
}

sub draw_item {
    my ($cr, $item, $is_anchored) = @_;

    return unless defined $item;

    if ($item->{drop_shadow}) {
        draw_shadow($cr, $item);
    }

    if ($item->{type} eq 'pixelize') {
        draw_pixelize($cr, $item);
    }
    elsif ($item->{type} eq 'crop_rect') {
  
        $cr->save();
        $cr->set_source_rgb(1, 1, 1); 
        $cr->set_line_width(2 / $scale_factor); 
        $cr->set_dash(5, 5);
        $cr->rectangle($item->{x1}, $item->{y1}, 
                      $item->{x2} - $item->{x1}, 
                      $item->{y2} - $item->{y1});
        $cr->stroke();
        $cr->set_dash(0);
        $cr->restore();

        if ($item->{selected}) {
            my $x = min($item->{x1}, $item->{x2});
            my $y = min($item->{y1}, $item->{y2});
            my $w = abs($item->{x2} - $item->{x1});
            my $h = abs($item->{y2} - $item->{y1});
            my $mx = $x + $w/2;
            my $my = $y + $h/2;

            my @handles = (
                ['nw', $x, $y], ['n', $mx, $y], ['ne', $x+$w, $y],
                ['e', $x+$w, $my], ['se', $x+$w, $y+$h], ['s', $mx, $y+$h],
                ['sw', $x, $y+$h], ['w', $x, $my]
            );
            foreach my $h (@handles) {
                draw_handle($cr, $h->[1], $h->[2], $h->[0]);
            }
        }
    }
    elsif ($item->{type} eq 'text') {
        draw_text($cr, $item);
    }
    elsif ($item->{type} eq 'rectangle') {
        draw_rectangle($cr, $item->{x1}, $item->{y1}, $item->{x2}, $item->{y2},
            $item->{stroke_color}, $item->{fill_color}, $item->{line_width}, $item);
    }
    elsif ($item->{type} eq 'ellipse') {
        draw_ellipse($cr, $item->{x1}, $item->{y1}, $item->{x2}, $item->{y2},
            $item->{stroke_color}, $item->{fill_color}, $item->{line_width}, $item);
    }
    elsif ($item->{type} eq 'pyramid') {
        draw_pyramid($cr, $item);
    }
    elsif ($item->{type} eq 'cuboid') {
        draw_cuboid($cr, $item);
    }
    elsif ($item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
        if ($item->{type} eq 'line') {
            draw_line($cr, $item->{start_x}, $item->{start_y}, $item->{end_x}, $item->{end_y},
                $item->{stroke_color}, $item->{line_width}, $item);
        } else {
            draw_arrow($cr, $item->{start_x}, $item->{start_y}, $item->{end_x}, $item->{end_y},
                $item->{stroke_color}, $item->{line_width}, $item);
        }
    }
    elsif ($item->{type} eq 'freehand' || $item->{type} eq 'highlighter') {
        draw_freehand_line($cr, $item->{points}, $item->{stroke_color}, $item->{line_width}, $item);
    }
    elsif ($item->{type} eq 'triangle') {
        draw_triangle($cr, $item);
    }
    elsif ($item->{type} eq 'tetragon') {
        draw_tetragon($cr, $item);
    }
    elsif ($item->{type} eq 'pentagon') {
        draw_pentagon($cr, $item);
    }
    elsif ($item->{type} eq 'numbered-circle') {
        draw_numbered_circle($cr, $item);
    }
    elsif ($item->{type} eq 'magnifier') {
        draw_magnifier($cr, $item);
    }
    elsif ($item->{type} eq 'svg') {
        draw_svg_item($cr, $item);
    }

    draw_measurements_on_item($cr, $item);

    if ($item->{selected} &&
        !(defined $item->{anchored} && $item->{anchored})) {
        if ($item->{type} eq 'text' || !$item->{is_editing}) {
            draw_selection_handles($cr, $item);
        }
    }
    
    return;
}

# Primitives:

sub draw_line {
    my ($cr, $start_x, $start_y, $end_x, $end_y, $stroke_color, $line_width, $line) = @_;

    $cr->set_line_width($line_width);
    $cr->set_line_cap('round');
    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );

    if ($line && $line->{line_style} && exists $line_styles{$line->{line_style}}) {
        my $pattern = $line_styles{$line->{line_style}}{pattern};
        if (@$pattern) {
            my @scaled_pattern = map { $_ * $line_width } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        }
    }

    $cr->new_path();
    if ($line && $line->{is_curved}) {

        my $control_x = $line->{control_x};
        my $control_y = $line->{control_y};

        my $control2_x = $control_x;
        my $control2_y = $control_y;

        $cr->move_to($start_x, $start_y);
        $cr->curve_to(
            $control_x, $control_y,
            $control2_x, $control2_y,
            $end_x, $end_y
        );
    } else {
        $cr->move_to($start_x, $start_y);
        $cr->line_to($end_x, $end_y);
    }
    $cr->stroke();

    $cr->set_dash(0);
    
    return;
}


sub draw_dashed_line {
    my ($cr, $line) = @_;

    $cr->set_line_width($line->{line_width});
    $cr->set_source_rgba(
        $line->{stroke_color}->red,
        $line->{stroke_color}->green,
        $line->{stroke_color}->blue,
        $line->{stroke_color}->alpha
    );

    if ($line->{line_style} && exists $line_styles{$line->{line_style}}) {
        my $pattern = $line_styles{$line->{line_style}}{pattern};
        if (@$pattern) {
            $cr->set_dash(0, @$pattern);
        }
    }

    if ($line->{is_curved}) {
        $cr->move_to($line->{start_x}, $line->{start_y});
        $cr->curve_to(
            $line->{control_x}, $line->{control_y},
            $line->{control_x}, $line->{control_y},
            $line->{end_x}, $line->{end_y}
        );
    } else {
        $cr->move_to($line->{start_x}, $line->{start_y});
        $cr->line_to($line->{end_x}, $line->{end_y});
    }
    $cr->stroke();

    $cr->set_dash(0);
    
    return;
}

sub draw_arrow {
    my ($cr, $start_x, $start_y, $end_x, $end_y, $stroke_color, $line_width, $arrow) = @_;

    $arrow->{style} //= "Single Arrow";

    $cr->set_line_width($line_width);
    $cr->set_line_cap('round');
    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );

    if ($arrow->{line_style} && exists $line_styles{$arrow->{line_style}}) {
        my $pattern = $line_styles{$arrow->{line_style}}{pattern};
        if (@$pattern) {
            my @scaled_pattern = map { $_ * $line_width } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        }
    }

    my $arrow_length = $line_width * 3;
    my $arrow_width = $arrow_length * 0.8;

    if ($arrow->{is_curved}) {
        my $control_x = $arrow->{control_x};
        my $control_y = $arrow->{control_y};

        my $steps = 100;
        my @curve_points;
        for my $i (0..$steps) {
            my $t = $i / $steps;
            my $t2 = 1 - $t;
            my $x = $t2 * $t2 * $start_x + 2 * $t2 * $t * $control_x + $t * $t * $end_x;
            my $y = $t2 * $t2 * $start_y + 2 * $t2 * $t * $control_y + $t * $t * $end_y;
            push @curve_points, [$x, $y];
        }

        my $end_angle = atan2(
            $curve_points[-1][1] - $curve_points[-2][1],
            $curve_points[-1][0] - $curve_points[-2][0]
        );
        my $start_angle = atan2(
            $curve_points[1][1] - $curve_points[0][1],
            $curve_points[1][0] - $curve_points[0][0]
        );

        my $start_adjust = ($arrow->{style} eq "Double Arrow") ? $arrow_length * 0.7 : 0;
        my $end_adjust = $arrow_length * 0.7;

        my $adj_start_x = $start_x + cos($start_angle) * $start_adjust;
        my $adj_start_y = $start_y + sin($start_angle) * $start_adjust;
        my $adj_end_x = $end_x - cos($end_angle) * $end_adjust;
        my $adj_end_y = $end_y - sin($end_angle) * $end_adjust;

        $cr->move_to($adj_start_x, $adj_start_y);
        $cr->curve_to(
            $control_x, $control_y,
            $control_x, $control_y,
            $adj_end_x, $adj_end_y
        );
        $cr->stroke();

        draw_arrowhead($cr, $end_x, $end_y, $end_angle, $line_width, $arrow_length, $arrow_width);

        if ($arrow->{style} eq "Double Arrow") {
            draw_arrowhead($cr, $start_x, $start_y, $start_angle + pi, $line_width, $arrow_length, $arrow_width);
        }
    } else {

        my $dx = $end_x - $start_x;
        my $dy = $end_y - $start_y;
        my $angle = atan2($dy, $dx);

        my $start_adjust = ($arrow->{style} eq "Double Arrow") ? $arrow_length * 0.7 : 0;
        my $end_adjust = $arrow_length * 0.7;

        my $adj_start_x = $start_x + cos($angle) * $start_adjust;
        my $adj_start_y = $start_y + sin($angle) * $start_adjust;
        my $adj_end_x = $end_x - cos($angle) * $end_adjust;
        my $adj_end_y = $end_y - sin($angle) * $end_adjust;

        $cr->move_to($adj_start_x, $adj_start_y);
        $cr->line_to($adj_end_x, $adj_end_y);
        $cr->stroke();

        draw_arrowhead($cr, $end_x, $end_y, $angle, $line_width, $arrow_length, $arrow_width);
        if ($arrow->{style} eq "Double Arrow") {
            draw_arrowhead($cr, $start_x, $start_y, $angle + pi, $line_width, $arrow_length, $arrow_width);
        }
    }

    $cr->set_dash(0);
    
    return;
}

sub draw_arrowhead {
    my ($cr, $x, $y, $angle, $line_width) = @_;

    my $arrow_length = $line_width * 7; 
    my $arrow_angle = 0.4; 

    my $x1 = $x - $arrow_length * cos($angle + $arrow_angle);
    my $y1 = $y - $arrow_length * sin($angle + $arrow_angle);
    my $x2 = $x - $arrow_length * cos($angle - $arrow_angle);
    my $y2 = $y - $arrow_length * sin($angle - $arrow_angle);

    $cr->move_to($x, $y);
    $cr->line_to($x1, $y1);
    $cr->line_to($x2, $y2);
    $cr->close_path();
    $cr->fill();
    
    return;
}

sub draw_single_arrow {
    my ($cr, $start_x, $start_y, $end_x, $end_y, $stroke_color, $line_width) = @_;

    my $dx = $end_x - $start_x;
    my $dy = $end_y - $start_y;
    my $angle = atan2($dy, $dx);
    my $length = sqrt($dx * $dx + $dy * $dy);

    my $base_arrow_length = min(max($length * 0.2, 10), 30);  
    my $scale_factor = $line_width / 5;  
    my $arrow_length = $base_arrow_length * $scale_factor; 
    $arrow_length = max($arrow_length, $line_width * 3);   
    my $arrow_width = $arrow_length * 0.8;  


    $cr->set_line_width($line_width);
    $cr->set_line_cap('round');
    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );

    $cr->move_to($start_x, $start_y);
 
    my $shaft_end_x = $end_x - cos($angle) * ($arrow_length * 0.7);
    my $shaft_end_y = $end_y - sin($angle) * ($arrow_length * 0.7);
    $cr->line_to($shaft_end_x, $shaft_end_y);
    $cr->stroke();

    my $arrow_angle = 0.5;
    my $x1 = $end_x - $arrow_length * cos($angle + $arrow_angle);
    my $y1 = $end_y - $arrow_length * sin($angle + $arrow_angle);
    my $x2 = $end_x - $arrow_length * cos($angle - $arrow_angle);
    my $y2 = $end_y - $arrow_length * sin($angle - $arrow_angle);

    $cr->move_to($end_x, $end_y);
    $cr->line_to($x1, $y1);
    $cr->line_to($x2, $y2);
    $cr->close_path();
    $cr->fill();
    
    return;
}

sub draw_double_arrow {
    my ($cr, $start_x, $start_y, $end_x, $end_y, $stroke_color, $line_width) = @_;

    my $dx = $end_x - $start_x;
    my $dy = $end_y - $start_y;
    my $angle = atan2($dy, $dx);
    my $length = sqrt($dx * $dx + $dy * $dy);

    my $base_arrow_length = min(max($length * 0.2, 10), 30);
    my $scale_factor = $line_width / 5;
    my $arrow_length = $base_arrow_length * $scale_factor;
    $arrow_length = max($arrow_length, $line_width * 3);
    my $arrow_width = $arrow_length * 0.8;

    $cr->set_line_width($line_width);
    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );

    my $shaft_start_x = $start_x + cos($angle) * ($arrow_length * 0.7);
    my $shaft_start_y = $start_y + sin($angle) * ($arrow_length * 0.7);
    my $shaft_end_x = $end_x - cos($angle) * ($arrow_length * 0.7);
    my $shaft_end_y = $end_y - sin($angle) * ($arrow_length * 0.7);
    $cr->move_to($shaft_start_x, $shaft_start_y);
    $cr->line_to($shaft_end_x, $shaft_end_y);
    $cr->stroke();

    my $arrow_angle = 0.5;
    my $x1 = $end_x - $arrow_length * cos($angle + $arrow_angle);
    my $y1 = $end_y - $arrow_length * sin($angle + $arrow_angle);
    my $x2 = $end_x - $arrow_length * cos($angle - $arrow_angle);
    my $y2 = $end_y - $arrow_length * sin($angle - $arrow_angle);

    $cr->move_to($end_x, $end_y);
    $cr->line_to($x1, $y1);
    $cr->line_to($x2, $y2);
    $cr->close_path();
    $cr->fill();

    my $x3 = $start_x + $arrow_length * cos($angle + $arrow_angle);
    my $y3 = $start_y + $arrow_length * sin($angle + $arrow_angle);
    my $x4 = $start_x + $arrow_length * cos($angle - $arrow_angle);
    my $y4 = $start_y + $arrow_length * sin($angle - $arrow_angle);

    $cr->move_to($start_x, $start_y);
    $cr->line_to($x3, $y3);
    $cr->line_to($x4, $y4);
    $cr->close_path();
    $cr->fill();
    
    return;
}

sub draw_rectangle {
    my ($cr, $x1, $y1, $x2, $y2, $stroke_color, $fill_color, $line_width, $rectangle) = @_;

    my $x = $x1 < $x2 ? $x1 : $x2;
    my $y = $y1 < $y2 ? $y1 : $y2;
    my $width = abs($x2 - $x1);
    my $height = abs($y2 - $y1);

    if ($fill_color) {
        $cr->set_source_rgba(
            $fill_color->red,
            $fill_color->green,
            $fill_color->blue,
            $fill_color->alpha
        );
        $cr->rectangle($x, $y, $width, $height);
        $cr->fill();
    }

    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );
    $cr->set_line_width($line_width);
    $cr->set_line_join('miter'); 

    if ($rectangle && $rectangle->{line_style} && exists $line_styles{$rectangle->{line_style}}) {
        my $pattern = $line_styles{$rectangle->{line_style}}{pattern};
        if (@$pattern) {
            my @scaled_pattern = map { $_ * $line_width } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        } else {
            $cr->set_dash(0);
        }
    }

    my $aligned_x = pixel_align($x, $line_width);
    my $aligned_y = pixel_align($y, $line_width);
    my $aligned_width = pixel_align($x + $width, $line_width) - $aligned_x;
    my $aligned_height = pixel_align($y + $height, $line_width) - $aligned_y;

    $cr->rectangle($aligned_x, $aligned_y, $aligned_width, $aligned_height);
    $cr->stroke();

    $cr->set_dash(0);
    
    return;
}

sub draw_ellipse {
    my ($cr, $x1, $y1, $x2, $y2, $stroke_color, $fill_color, $line_width, $ellipse) = @_;

    my $center_x = ($x1 + $x2) / 2;
    my $center_y = ($y1 + $y2) / 2;
    my $radius_x = abs($x2 - $x1) / 2;
    my $radius_y = abs($y2 - $y1) / 2;

    return if $radius_x < 0.1 || $radius_y < 0.1;

    my $actual_stroke_color = $ellipse && $ellipse->{stroke_color} ? $ellipse->{stroke_color} : $stroke_color;
    my $actual_fill_color = $ellipse && $ellipse->{fill_color} ? $ellipse->{fill_color} : $fill_color;
    my $actual_line_width = $ellipse && defined $ellipse->{line_width} ? $ellipse->{line_width} : $line_width;

    my $aligned_center_x = pixel_align($center_x, $actual_line_width);
    my $aligned_center_y = pixel_align($center_y, $actual_line_width);

    if ($actual_fill_color) {
        $cr->save();
        $cr->translate($aligned_center_x, $aligned_center_y);
        $cr->scale($radius_x, $radius_y);
        $cr->arc(0, 0, 1, 0, 2 * 3.14159265359);
        $cr->restore(); 
        
        $cr->set_source_rgba(
            $actual_fill_color->red,
            $actual_fill_color->green,
            $actual_fill_color->blue,
            $actual_fill_color->alpha
        );
        $cr->fill();
    }

    $cr->save();
    $cr->translate($aligned_center_x, $aligned_center_y);
    $cr->scale($radius_x, $radius_y);
    $cr->arc(0, 0, 1, 0, 2 * 3.14159265359);

    $cr->restore();

    $cr->set_source_rgba(
        $actual_stroke_color->red,
        $actual_stroke_color->green,
        $actual_stroke_color->blue,
        $actual_stroke_color->alpha
    );

    $cr->set_line_width($actual_line_width);

    if ($ellipse && $ellipse->{line_style} && exists $line_styles{$ellipse->{line_style}}) {
        my $pattern = $line_styles{$ellipse->{line_style}}{pattern};
        if (@$pattern) {
        
            my @scaled_pattern = map { $_ * $actual_line_width } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        }
    }

    $cr->stroke();
    $cr->set_dash(0);
    
    return;
}

sub draw_triangle {
    my ($cr, $triangle) = @_;

    if ($triangle->{fill_color}) {
        $cr->set_source_rgba(
            $triangle->{fill_color}->red,
            $triangle->{fill_color}->green,
            $triangle->{fill_color}->blue,
            $triangle->{fill_color}->alpha
        );

        $cr->move_to(@{$triangle->{vertices}[0]});
        for my $i (1 .. $#{$triangle->{vertices}}) {
            $cr->line_to(@{$triangle->{vertices}[$i]});
        }
        $cr->close_path();
        $cr->fill();
    }

    $cr->set_source_rgba(
        $triangle->{stroke_color}->red,
        $triangle->{stroke_color}->green,
        $triangle->{stroke_color}->blue,
        $triangle->{stroke_color}->alpha
    );
    $cr->set_line_width($triangle->{line_width});
    $cr->set_line_join('miter');  
    $cr->set_line_cap('square');  

    if ($triangle->{line_style} && exists $line_styles{$triangle->{line_style}}) {
        my $pattern = $line_styles{$triangle->{line_style}}{pattern};
        if (@$pattern) {
            my @scaled_pattern = map { $_ * $triangle->{line_width} } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        }
    }

    my @aligned_vertices;
    for my $vertex (@{$triangle->{vertices}}) {
        push @aligned_vertices, [
            pixel_align($vertex->[0], $triangle->{line_width}),
            pixel_align($vertex->[1], $triangle->{line_width})
        ];
    }

    $cr->move_to(@{$aligned_vertices[0]});
    for my $i (1 .. $#aligned_vertices) {
        $cr->line_to(@{$aligned_vertices[$i]});
    }
    $cr->close_path();
    $cr->stroke();

    $cr->set_dash(0);
    
    return;
}

sub draw_tetragon {
    my ($cr, $tetragon) = @_;

    return unless $tetragon && $tetragon->{vertices} && @{$tetragon->{vertices}} == 4;

    if ($tetragon->{fill_color}) {
        $cr->set_source_rgba(
            $tetragon->{fill_color}->red,
            $tetragon->{fill_color}->green,
            $tetragon->{fill_color}->blue,
            $tetragon->{fill_color}->alpha
        );

        $cr->move_to(@{$tetragon->{vertices}[0]});
        for my $i (1 .. $#{$tetragon->{vertices}}) {
            $cr->line_to(@{$tetragon->{vertices}[$i]});
        }
        $cr->close_path();
        $cr->fill();
    }

    if ($tetragon->{stroke_color}) {
        $cr->set_source_rgba(
            $tetragon->{stroke_color}->red,
            $tetragon->{stroke_color}->green,
            $tetragon->{stroke_color}->blue,
            $tetragon->{stroke_color}->alpha
        );
        $cr->set_line_width($tetragon->{line_width});
        $cr->set_line_join('miter');  
        $cr->set_line_cap('square');   

        if ($tetragon->{line_style} && exists $line_styles{$tetragon->{line_style}}) {
            my $pattern = $line_styles{$tetragon->{line_style}}{pattern};
            if (@$pattern) {
                my @scaled_pattern = map { $_ * $tetragon->{line_width} } @$pattern;
                $cr->set_dash(0, @scaled_pattern);
            }
        }

        my @aligned_vertices;
        for my $vertex (@{$tetragon->{vertices}}) {
            push @aligned_vertices, [
                pixel_align($vertex->[0], $tetragon->{line_width}),
                pixel_align($vertex->[1], $tetragon->{line_width})
            ];
        }

        $cr->move_to(@{$aligned_vertices[0]});
        for my $i (1 .. $#aligned_vertices) {
            $cr->line_to(@{$aligned_vertices[$i]});
        }
        $cr->close_path();
        $cr->stroke();

        $cr->set_dash(0);
    }
    
    return;
}

sub draw_pentagon {
    my ($cr, $pentagon) = @_;

    return unless $pentagon && $pentagon->{vertices} && @{$pentagon->{vertices}} == 5;

    if ($pentagon->{fill_color}) {
        $cr->set_source_rgba(
            $pentagon->{fill_color}->red,
            $pentagon->{fill_color}->green,
            $pentagon->{fill_color}->blue,
            $pentagon->{fill_color}->alpha
        );

        $cr->move_to(@{$pentagon->{vertices}[0]});
        for my $i (1 .. $#{$pentagon->{vertices}}) {
            $cr->line_to(@{$pentagon->{vertices}[$i]});
        }
        $cr->close_path();
        $cr->fill();
    }

    if ($pentagon->{stroke_color}) {
        $cr->set_source_rgba(
            $pentagon->{stroke_color}->red,
            $pentagon->{stroke_color}->green,
            $pentagon->{stroke_color}->blue,
            $pentagon->{stroke_color}->alpha
        );
        $cr->set_line_width($pentagon->{line_width});
        $cr->set_line_join('miter'); 
        $cr->set_line_cap('square'); 

        if ($pentagon->{line_style} && exists $line_styles{$pentagon->{line_style}}) {
            my $pattern = $line_styles{$pentagon->{line_style}}{pattern};
            if (@$pattern) {
                my @scaled_pattern = map { $_ * $pentagon->{line_width} } @$pattern;
                $cr->set_dash(0, @scaled_pattern);
            }
        }

        my @aligned_vertices;
        for my $vertex (@{$pentagon->{vertices}}) {
            push @aligned_vertices, [
                pixel_align($vertex->[0], $pentagon->{line_width}),
                pixel_align($vertex->[1], $pentagon->{line_width})
            ];
        }

        $cr->move_to(@{$aligned_vertices[0]});
        for my $i (1 .. $#aligned_vertices) {
            $cr->line_to(@{$aligned_vertices[$i]});
        }
        $cr->close_path();
        $cr->stroke();

        $cr->set_dash(0);
    }

    if ($pentagon->{selected}) {
        draw_pentagon_handles($cr, $pentagon);
    }
    
    return;
}

sub draw_pyramid {
    my ($cr, $pyramid) = @_;
    return unless $pyramid && $pyramid->{faces};

    my $base_fill_color = $pyramid->{fill_color} || Gtk3::Gdk::RGBA->new(0.5, 0.5, 0.5, 1.0);
    my $base_stroke_color = $pyramid->{stroke_color} || Gtk3::Gdk::RGBA->new(0, 0, 0, 1.0);
    my $actual_line_width = $pyramid->{line_width} || 1;

    my $base_a = $base_fill_color->alpha;
    if ($base_a > 0.95) { $base_a = 1.0; }

    my $is_black = (0.299 * $base_fill_color->red + 0.587 * $base_fill_color->green + 0.114 * $base_fill_color->blue) < 0.1;

    my @hidden_sides;
    my @base_face;
    my @visible_sides;

    my $dominant_face_name = '';
    my $max_area = -1;

    foreach my $name (keys %{$pyramid->{faces}}) {
        my $face = $pyramid->{faces}{$name};
        my $v = $face->{vertices};
        next unless @$v >= 3;

        my $area = 0;
        for my $i (0 .. $#{$v}) {
            my $j = ($i + 1) % scalar(@$v);
            $area += ($v->[$i][0] * $v->[$j][1]);
            $area -= ($v->[$j][0] * $v->[$i][1]);
        }

        if ($name ne 'base' && $area > 0 && abs($area) > $max_area) {
            $max_area = abs($area);
            $dominant_face_name = $name;
        }

        my $face_data = {
            name => $name,
            vertices => $v,
            area => $area,
            avg_y => _calculate_avg_y($v)
        };

        if ($name eq 'base') {
            push @base_face, $face_data;
        } elsif ($area <= 0) {
         
            if ($base_a < 1.0) {
                push @hidden_sides, $face_data;
            }
        } else {
   
            push @visible_sides, $face_data;
        }
    }

    
    @hidden_sides = sort { $a->{avg_y} <=> $b->{avg_y} } @hidden_sides;
    @visible_sides = sort { $a->{avg_y} <=> $b->{avg_y} } @visible_sides;

    my @faces_to_draw = (@hidden_sides, @base_face, @visible_sides);

    foreach my $item (@faces_to_draw) {
        my $name = $item->{name};
        my $v = $item->{vertices};

        my ($r, $g, $b);

        if ($is_black) {
    
            if ($name eq $dominant_face_name) {
              
                ($r, $g, $b) = (0.30, 0.30, 0.30); 
            } 
            elsif ($name eq 'base') {
  
                ($r, $g, $b) = (0.0, 0.0, 0.0); 
            } 
            else {
          
                ($r, $g, $b) = (0.10, 0.10, 0.10); 
            }
        } else {
      
            my $factor = 1.0;
            
            if ($name eq $dominant_face_name) { 
        
                ($r, $g, $b) = ($base_fill_color->red, $base_fill_color->green, $base_fill_color->blue);
            }
            elsif ($name eq 'base') { 
                $factor = 0.60;  
                $r = $base_fill_color->red * $factor;
                $g = $base_fill_color->green * $factor;
                $b = $base_fill_color->blue * $factor;
            } 
            else { 
                $factor = 0.75; 
                $r = $base_fill_color->red * $factor;
                $g = $base_fill_color->green * $factor;
                $b = $base_fill_color->blue * $factor;
            }
        }

        $cr->new_path();
        $cr->move_to($v->[0][0], $v->[0][1]);
        for my $i (1..$#{$v}) {
            $cr->line_to($v->[$i][0], $v->[$i][1]);
        }
        $cr->close_path();

        my $face_alpha = ($name eq 'base' || grep { $_->{name} eq $name } @hidden_sides) ? 0.0 : $base_a;
        $cr->set_source_rgba($r, $g, $b, $face_alpha);
        $cr->fill_preserve(); 

        $cr->set_source_rgba(
            $base_stroke_color->red,
            $base_stroke_color->green,
            $base_stroke_color->blue,
            $base_stroke_color->alpha
        );
        $cr->set_line_width($actual_line_width);
        
        $cr->set_line_join('round'); 
        
        if ($pyramid->{line_style} && exists $line_styles{$pyramid->{line_style}}) {
            my $pattern = $line_styles{$pyramid->{line_style}}{pattern};
            if (@$pattern) {
                my @scaled_pattern = map { $_ * $actual_line_width } @$pattern;
                $cr->set_dash(0, @scaled_pattern);
            }
        }

        $cr->stroke(); 
        $cr->set_dash(0); 
    }

    if ($pyramid->{selected}) {
        draw_pyramid_handles($cr, $pyramid);
    }
    
    return;
}

sub _calculate_avg_y {
    my ($vertices) = @_;
    my $sum = 0;
    foreach my $v (@$vertices) { $sum += $v->[1]; }
    return $sum / scalar(@$vertices);
}

sub draw_cuboid {
    my ($cr, $cuboid) = @_;
    return unless $cuboid && $cuboid->{faces};

    my $base_fill_color = $cuboid->{fill_color};
    my $base_stroke_color = $cuboid->{stroke_color};
    my $actual_line_width = $cuboid->{line_width} || 1;

    unless ($base_fill_color && ref($base_fill_color) && $base_fill_color->can('copy')) {
        $base_fill_color = Gtk3::Gdk::RGBA->new(0.5, 0.5, 0.5, 1.0);
    }
    unless ($base_stroke_color && ref($base_stroke_color) && $base_stroke_color->can('copy')) {
        $base_stroke_color = Gtk3::Gdk::RGBA->new(0, 0, 0, 1.0);
    }

    my ($visible_faces, $face_lighting) = determine_cuboid_visibility_and_lighting($cuboid);
    my $is_transparent = $base_fill_color->alpha < 0.95;

    my $luminance = 0.299 * $base_fill_color->red + 0.587 * $base_fill_color->green + 0.114 * $base_fill_color->blue;
    my $is_black = ($luminance < 0.05); 

    if ($is_transparent) {
        my @all_faces = ('front', 'back', 'left', 'right', 'top', 'bottom');
        my %visible_face_hash = map { $_ => 1 } @$visible_faces;
        my @hidden_faces = grep { !$visible_face_hash{$_} } @all_faces;

        foreach my $face_name (@hidden_faces) {
            my $face = $cuboid->{faces}{$face_name};
            next unless $face && $face->{vertices} && @{$face->{vertices}} >= 3;

            my $lit_fill_color;
            if ($is_black) {
  
                $lit_fill_color = Gtk3::Gdk::RGBA->new(0.1, 0.1, 0.1, $base_fill_color->alpha);
            } else {
                my $hidden_lighting_factor = 0.4; 
                $lit_fill_color = apply_lighting_to_color($base_fill_color, $hidden_lighting_factor);
         
                $lit_fill_color = Gtk3::Gdk::RGBA->new(
                    $lit_fill_color->red,
                    $lit_fill_color->green,
                    $lit_fill_color->blue,
                    0.0  
                );
            }

            if ($lit_fill_color && $lit_fill_color->alpha > 0) {
                $cr->set_source_rgba(
                    $lit_fill_color->red,
                    $lit_fill_color->green,
                    $lit_fill_color->blue,
                    $lit_fill_color->alpha
                );

                $cr->new_path();
                $cr->move_to($face->{vertices}[0][0], $face->{vertices}[0][1]);
                for my $i (1..$#{$face->{vertices}}) {
                    $cr->line_to($face->{vertices}[$i][0], $face->{vertices}[$i][1]);
                }
                $cr->close_path();
                $cr->fill();
            }
        }
    }

    my @sorted_visible_faces;
    
    foreach my $face_name (@$visible_faces) {
        next unless exists $cuboid->{faces}{$face_name};
        my $face = $cuboid->{faces}{$face_name};
        push @sorted_visible_faces, { name => $face_name, z_order => $face->{z_order} };
    }
    @sorted_visible_faces = sort { $b->{z_order} <=> $a->{z_order} } @sorted_visible_faces;

    foreach my $face_info (@sorted_visible_faces) {
        my $face_name = $face_info->{name};
        my $face = $cuboid->{faces}{$face_name};
        my $vertices = $face->{vertices};

        if ($is_black) {
        
            my ($r, $g, $b);

            if ($face_name eq 'front') {
   
                ($r, $g, $b) = (0.25, 0.25, 0.25); 
            } 
            elsif ($face_name eq 'top') {
                ($r, $g, $b) = (0.15, 0.15, 0.15); 
            } 
            elsif ($face_name eq 'left') {
                 ($r, $g, $b) = (0.20, 0.20, 0.20); 
            }
            else {
           
                ($r, $g, $b) = (0.0, 0.0, 0.0);   
            }
            
            $cr->set_source_rgba($r, $g, $b, $base_fill_color->alpha);
            
        } else {
         
            my $lighting_factor = $face_lighting->{$face_name} || 0.5;
            my $lit_fill_color = apply_lighting_to_color($base_fill_color, $lighting_factor);

            if ($face_name eq 'front') {
                $lit_fill_color = $base_fill_color;
            }

            
            $cr->set_source_rgba(
                $lit_fill_color->red,
                $lit_fill_color->green,
                $lit_fill_color->blue,
                $lit_fill_color->alpha
            );
        }

        $cr->new_path();
        $cr->move_to($vertices->[0][0], $vertices->[0][1]);
        for my $i (1 .. $#{$vertices}) {
            $cr->line_to($vertices->[$i][0], $vertices->[$i][1]);
        }
        $cr->close_path();
        $cr->fill();
    }

    $cr->set_source_rgba(
        $base_stroke_color->red,
        $base_stroke_color->green,
        $base_stroke_color->blue,
        $base_stroke_color->alpha
    );
    $cr->set_line_width($actual_line_width);

    if ($cuboid->{line_style} && exists $line_styles{$cuboid->{line_style}}) {
        my $pattern = $line_styles{$cuboid->{line_style}}{pattern};
        if (@$pattern) {
            my @scaled_pattern = map { $_ * $actual_line_width } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        }
    }

    my @edges_to_draw = get_visible_cuboid_edges($cuboid, $visible_faces, $is_transparent);
    foreach my $edge (@edges_to_draw) {
        $cr->move_to($edge->[0], $edge->[1]);
        $cr->line_to($edge->[2], $edge->[3]);
        $cr->stroke();
    }
    $cr->set_dash(0);

    if ($cuboid->{selected}) {
        draw_cuboid_handles($cr, $cuboid);
    }
    
    return;
}

sub draw_text {
    my ($cr, $text_item) = @_;
    return unless $text_item;

    if ($text_item->{font}) {
    
        my $layout = Pango::Cairo::create_layout($cr);
        my $desc = Pango::FontDescription->from_string($text_item->{font});
        $layout->set_font_description($desc);

        unless ($text_item->{is_resizing}) {
         
            my $temp_surface = Cairo::ImageSurface->create('argb32', 10, 10);
            my $temp_cr = Cairo::Context->create($temp_surface);
            my $temp_layout = Pango::Cairo::create_layout($temp_cr);
            $temp_layout->set_font_description($desc);

            $text_item->{width} = 0;
            my @lines = split("\n", $text_item->{text});
            my $total_height = 0;

            foreach my $line (@lines) {
             
                $temp_layout->set_text($line || ' ');
                my ($width, $height) = $temp_layout->get_pixel_size();
                
                $text_item->{width} = max($text_item->{width}, $width);
                $total_height += $height;
            }
       
            $text_item->{height} = $total_height || 30;

            $temp_surface->finish();
        } 

        my @lines = split("\n", $text_item->{text});
        my $y_offset = 0;
        
        foreach my $line (@lines) {
            $layout->set_text($line || ' ');
            my (undef, $height) = $layout->get_pixel_size();

            $cr->set_source_rgba(
                $text_item->{stroke_color}->red,
                $text_item->{stroke_color}->green,
                $text_item->{stroke_color}->blue,
                $text_item->{stroke_color}->alpha
            );

            $cr->move_to($text_item->{x}, $text_item->{y} + $y_offset);
            Pango::Cairo::show_layout($cr, $layout);
            $y_offset += $height;
        }

        if ($text_item->{is_editing} && $cursor_visible) {
            my $cursor_layout = Pango::Cairo::create_layout($cr);
            $cursor_layout->set_font_description($desc);
            my @lines = split("\n", $text_item->{text});
            my $current_line_text = $lines[$text_item->{current_line}] // '';
            my $text_before_cursor = substr($current_line_text, 0, $text_item->{current_column});
            
            my $cursor_width = 0;
            my $line_height = 20;
            
            if ($text_before_cursor) {
                $cursor_layout->set_text($text_before_cursor);
                ($cursor_width, $line_height) = $cursor_layout->get_pixel_size();
            } else {
                $cursor_layout->set_text(' ');
                (undef, $line_height) = $cursor_layout->get_pixel_size();
                $cursor_width = 0;
            }

            my $cursor_y = $text_item->{y} + ($line_height * $text_item->{current_line});
            my $cursor_x = $text_item->{x} + $cursor_width;

            $cr->set_source_rgba(
                $text_item->{stroke_color}->red,
                $text_item->{stroke_color}->green,
                $text_item->{stroke_color}->blue,
                $text_item->{stroke_color}->alpha
            );
            $cr->set_line_width(1);
            $cr->move_to($cursor_x, $cursor_y);
            $cr->line_to($cursor_x, $cursor_y + $line_height);
            $cr->stroke();
        }

        if ($text_item->{selected} && !$text_item->{is_editing}) {
            $cr->set_source_rgba(1, 1, 1, 1);
            $cr->set_line_width(0.3);
            $cr->set_dash(3, 3);
            $cr->rectangle($text_item->{x}, $text_item->{y},
                          $text_item->{width}, $text_item->{height});
            $cr->stroke();
            $cr->set_dash(0);
        }
    }
    
    return;
}

sub draw_numbered_circle {
    my ($cr, $circle) = @_;

    return unless $circle;

    $cr->new_path();
    $cr->arc($circle->{x}, $circle->{y}, $circle->{radius}, 0, 2 * pi);

    if ($circle->{fill_color}) {
        $cr->set_source_rgba(
            $circle->{fill_color}->red,
            $circle->{fill_color}->green,
            $circle->{fill_color}->blue,
            $circle->{fill_color}->alpha
        );
        $cr->fill_preserve();
    }

    $cr->set_source_rgba(
        $circle->{stroke_color}->red,
        $circle->{stroke_color}->green,
        $circle->{stroke_color}->blue,
        $circle->{stroke_color}->alpha
    );
    $cr->set_line_width($circle->{line_width});

    if ($circle->{line_style} && exists $line_styles{$circle->{line_style}}) {
        my $pattern = $line_styles{$circle->{line_style}}{pattern};
        if (@$pattern) {
            my @scaled_pattern = map { $_ * $circle->{line_width} } @$pattern;
            $cr->set_dash(0, @scaled_pattern);
        }
    }

    $cr->stroke();
    
    $cr->set_dash(0); 

    $cr->select_font_face(
        $circle->{font_family},
        $circle->{font_style} eq 'italic' ? 'italic' : 'normal',
        'normal'
    );

    my $font_size = min($circle->{radius} * 1.2, $circle->{radius} * 1.5);
    $font_size = max($font_size, 30);

    $cr->set_font_size($font_size);

    my $text = $circle->{number};
    my $extents = $cr->text_extents($text);
    my $text_x = $circle->{x} - ($extents->{width} / 2 + $extents->{x_bearing});
    my $text_y = $circle->{y} - ($extents->{height} / 2 + $extents->{y_bearing});

    $cr->move_to($text_x, $text_y);
    $cr->show_text($text);
    
    return;
}

sub draw_freehand_line {
    my ($cr, $points, $stroke_color, $line_width, $item) = @_;
    return unless $points && @$points >= 4;

    $cr->set_line_width($line_width);
    $cr->set_line_cap('round');
    $cr->set_line_join('round');
    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );

    if ($item && $item->{line_style} && exists $line_styles{$item->{line_style}}) {
        my $pattern = $line_styles{$item->{line_style}}{pattern};
        if (@$pattern) {

            my @scaled_pattern;
            for my $value (@$pattern) {
                push @scaled_pattern, $value * ($line_width / 2);
            }
            $cr->set_dash(0, @scaled_pattern);
        } else {
            $cr->set_dash(0);
        }
    }

    $cr->new_path();
    $cr->move_to($points->[0], $points->[1]);
    for (my $i = 2; $i < @$points; $i += 2) {
        $cr->line_to($points->[$i], $points->[$i+1]);
    }
    $cr->stroke();

    $cr->set_dash(0);
    
    return;
}

sub draw_highlighter {
    my ($cr, $points, $stroke_color, $line_width) = @_;
    return unless @$points >= 4;

    $cr->set_line_width($line_width);
    $cr->set_line_cap('round');
    $cr->set_line_join('round');
    $cr->set_source_rgba(
        $stroke_color->red,
        $stroke_color->green,
        $stroke_color->blue,
        $stroke_color->alpha
    );

    $cr->move_to($points->[0], $points->[1]);
    for (my $i = 2; $i < @$points; $i += 2) {
        $cr->line_to($points->[$i], $points->[$i+1]);
    }
    $cr->stroke();
    
    return;
}

sub draw_magnifier {
    my ($cr, $magnifier) = @_;
    return unless $magnifier && $image_surface;

    my $x = $magnifier->{x};
    my $y = $magnifier->{y};

    $cr->save();

    $cr->new_path();
    $cr->arc($x, $y, $magnifier->{radius}, 0, 2 * pi);
    $cr->clip();

    $cr->translate($x, $y);
    $cr->scale($magnifier->{zoom}, $magnifier->{zoom});
    $cr->translate(-$x, -$y);

    $cr->set_source_surface($image_surface, 0, 0);
    $cr->paint();
    $cr->restore();

    $cr->set_source_rgba(0, 0, 0, 0.5);
    $cr->set_line_width(1);
    $cr->arc($x, $y, $magnifier->{radius}, 0, 2 * pi);
    $cr->stroke();
    
    return;
}

sub draw_pixelize {
    my ($cr, $item) = @_;
    return unless $image_surface; 

    my $x = min($item->{x1}, $item->{x2});
    my $y = min($item->{y1}, $item->{y2});
    my $width = abs($item->{x2} - $item->{x1});
    my $height = abs($item->{y2} - $item->{y1});
    
    return if $width < 1 || $height < 1;

    my $pixel_size = $item->{pixel_size} || 10;

    $cr->save();

    $cr->rectangle($x, $y, $width, $height);
    $cr->clip();

    my $small_w = int($width / $pixel_size) || 1;
    my $small_h = int($height / $pixel_size) || 1;
    
    my $temp_surf = Cairo::ImageSurface->create('argb32', $small_w, $small_h);
    my $temp_cr = Cairo::Context->create($temp_surf);

    my $scale_x = $small_w / $width;
    my $scale_y = $small_h / $height;
    
    $temp_cr->scale($scale_x, $scale_y);
    $temp_cr->set_source_surface($image_surface, -$x, -$y);
    $temp_cr->paint();

    $cr->translate($x, $y);
    $cr->scale(1 / $scale_x, 1 / $scale_y);
    
    $cr->set_source_surface($temp_surf, 0, 0);

    $cr->get_source()->set_filter('nearest');
    
    $cr->paint();

    $temp_surf->finish();
    
    $cr->restore();

    if ($item->{selected}) {
        $cr->set_source_rgb(0, 0, 0);
        $cr->set_line_width(1);
        $cr->rectangle($x, $y, $width, $height);
        $cr->stroke();

        my $middle_x = ($item->{x1} + $item->{x2}) / 2;
        my $middle_y = ($item->{y1} + $item->{y2}) / 2;

        my @handles = (
            ['top-left',     $x, $y],
            ['top',          $middle_x, $y],
            ['top-right',    $x + $width, $y],
            ['right',        $x + $width, $middle_y],
            ['bottom-right', $x + $width, $y + $height],
            ['bottom',       $middle_x, $y + $height],
            ['bottom-left',  $x, $y + $height],
            ['left',         $x, $middle_y]
        );

        foreach my $handle (@handles) {
            draw_handle($cr, $handle->[1], $handle->[2]);
        }
    }
    
    return;
}

sub draw_svg_item {
    my ($cr, $item) = @_;

    return unless $item && ($item->{pixbuf} || $item->{svg_content});

    $cr->save();

    if ($item->{scale} != 1.0) {
        my $new_width = int($item->{width} * $item->{scale});
        my $new_height = int($item->{height} * $item->{scale});

        my ($fh, $temp_file) = tempfile(SUFFIX => '.svg');
        print $fh $item->{svg_content};
        close $fh;

        my $scaled_pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale(
            $temp_file,
            $new_width,
            $new_height,
            TRUE
        );

        unlink $temp_file;

        if ($scaled_pixbuf) {
            Gtk3::Gdk::cairo_set_source_pixbuf($cr, $scaled_pixbuf, $item->{x}, $item->{y});
        }
    } else {
        Gtk3::Gdk::cairo_set_source_pixbuf($cr, $item->{pixbuf}, $item->{x}, $item->{y});
    }

    $cr->paint_with_alpha(1.0);
    $cr->restore();
    
    return;
}

sub draw_bounding_box_dash_line {
    my ($cr, $x1, $y1, $x2, $y2) = @_;

    $cr->set_source_rgba(1, 1, 1, 1);
    $cr->set_line_width(0.5);

    $cr->set_dash(3, 3);

    $cr->move_to($x1, $y1);
    $cr->line_to($x2, $y2);
    $cr->stroke();

    $cr->set_dash(0);
    
    return;
}

# Decorations:

sub draw_selection_handles {
    my ($cr, $item) = @_;
    return unless $item && $item->{selected};

    if ($item->{type} eq 'freehand' || $item->{type} eq 'highlighter') {
        my $points = $item->{points};
        return unless @$points >= 4;

        draw_handle($cr, $points->[0], $points->[1], 'start');
        my $last_idx = scalar(@$points) - 2;
        draw_handle($cr, $points->[$last_idx], $points->[$last_idx + 1], 'end');
    }
    
    elsif ($item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
        my $start_x = $item->{start_x};
        my $start_y = $item->{start_y};
        my $end_x = $item->{end_x};
        my $end_y = $item->{end_y};

        draw_handle($cr, $start_x, $start_y, 'start');
        draw_handle($cr, $end_x, $end_y, 'end');

        if ($item->{is_curved} && defined $item->{control_x}) {
         
            draw_handle($cr, $item->{control_x}, $item->{control_y}, 'control');
        } else {
        
            my $mid_x = ($start_x + $end_x) / 2;
            my $mid_y = ($start_y + $end_y) / 2;
            draw_handle($cr, $mid_x, $mid_y, 'middle');
        }
    }
    
    elsif ($item->{type} eq 'rectangle') {
        my $middle_x = ($item->{x1} + $item->{x2}) / 2;
        my $middle_y = ($item->{y1} + $item->{y2}) / 2;

        my @handles = (
            ['top-left',     $item->{x1},  $item->{y1}],
            ['top',          $middle_x,    $item->{y1}],
            ['top-right',    $item->{x2},  $item->{y1}],
            ['right',        $item->{x2},  $middle_y],
            ['bottom-right', $item->{x2},  $item->{y2}],
            ['bottom',       $middle_x,    $item->{y2}],
            ['bottom-left',  $item->{x1},  $item->{y2}],
            ['left',         $item->{x1},  $middle_y]
        );

        foreach my $handle (@handles) {
            draw_handle($cr, $handle->[1], $handle->[2], $handle->[0]);
        }
    }
    elsif ($item->{type} eq 'ellipse') {
        my $middle_x = ($item->{x1} + $item->{x2}) / 2;
        my $middle_y = ($item->{y1} + $item->{y2}) / 2;

        $cr->set_source_rgba(1, 1, 1, 1); 
        $cr->set_line_width(0.3);
        $cr->set_dash(3, 3);

        $cr->rectangle(
            $item->{x1},
            $item->{y1},
            $item->{x2} - $item->{x1},
            $item->{y2} - $item->{y1}
        );
        $cr->stroke();
        $cr->set_dash(0);

        my @handles = (
            ['top-left',     $item->{x1},  $item->{y1}],
            ['top',          $middle_x,    $item->{y1}],
            ['top-right',    $item->{x2},  $item->{y1}],
            ['right',        $item->{x2},  $middle_y],
            ['bottom-right', $item->{x2},  $item->{y2}],
            ['bottom',       $middle_x,    $item->{y2}],
            ['bottom-left',  $item->{x1},  $item->{y2}],
            ['left',         $item->{x1},  $middle_y]
        );

        foreach my $handle (@handles) {
            draw_handle($cr, $handle->[1], $handle->[2], $handle->[0]);
        }
    }
    elsif ($item->{type} eq 'pyramid') {
        draw_pyramid_handles($cr, $item);
    }
    elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/) {
        foreach my $i (0..$#{$item->{vertices}}) {
            my $handle_id = "vertex-$i";
            draw_handle($cr, $item->{vertices}[$i][0], $item->{vertices}[$i][1], $handle_id);
        }

        if ($item->{middle_points}) {
            foreach my $i (0..$#{$item->{middle_points}}) {
                my $handle_id = "middle-$i";
                draw_handle($cr, $item->{middle_points}[$i][0], $item->{middle_points}[$i][1], $handle_id);
            }
        }
    }
    elsif ($item->{type} eq 'numbered-circle') {
        my $box_size = $item->{radius} * 2;
        my $box_x = $item->{x} - $item->{radius};
        my $box_y = $item->{y} - $item->{radius};

        $cr->set_source_rgba(1, 1, 1, 1); 
        $cr->set_line_width(0.3);
        $cr->set_dash(3, 3);

        $cr->rectangle($box_x, $box_y, $box_size, $box_size);
        $cr->stroke();
        $cr->set_dash(0);

        my @handle_positions = (
            ['nw', $box_x, $box_y],
            ['ne', $box_x + $box_size, $box_y],
            ['se', $box_x + $box_size, $box_y + $box_size],
            ['sw', $box_x, $box_y + $box_size],
            ['n', $box_x + $box_size/2, $box_y],
            ['e', $box_x + $box_size, $box_y + $box_size/2],
            ['s', $box_x + $box_size/2, $box_y + $box_size],
            ['w', $box_x, $box_y + $box_size/2]
        );

        foreach my $pos (@handle_positions) {
            draw_handle($cr, $pos->[1], $pos->[2], $pos->[0]);
        }
    }
    elsif ($item->{type} eq 'text') {
        my $box_x = $item->{x};
        my $box_y = $item->{y};
        my $box_width = $item->{width};
        my $box_height = $item->{height};

        $cr->set_source_rgba(1, 1, 1, 1);  
        $cr->set_line_width(0.3);
        $cr->set_dash(3, 3);

        $cr->rectangle($box_x, $box_y, $box_width, $box_height);
        $cr->stroke();
        $cr->set_dash(0);
        
        my $handle_size = 100;
        my $handle_gap = 15;
        my $handle_x = $box_x - $handle_size - $handle_gap;
        my $handle_y = $box_y + ($box_height / 2);
        
        my @svg_paths = (
            File::HomeDir->my_home . '/.config/linia/icons/drag-handle.svg',
            dirname(__FILE__) . '/drag-handle.svg',
            '/usr/share/linia/drag-handle.svg',
            '/usr/share/linia/icons/drag-handle.svg',
            File::HomeDir->my_home . '/.local/share/linia/drag-handle.svg',
            '/home/claude/drag-handle.svg'
        );
        
        my $pixbuf;
        foreach my $svg_path (@svg_paths) {
            if (-f $svg_path) {
                eval {
                    my $high_res_size = $handle_size * 3;
                    $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file_at_scale(
                        $svg_path, $high_res_size, $high_res_size, TRUE
                    );
                };
                last if $pixbuf;
            }
        }
        
        if ($pixbuf) {
            my $icon_x = $handle_x - ($handle_size / 2);
            my $icon_y = $handle_y - ($handle_size / 2);
            
            $cr->save();
            $cr->translate($icon_x, $icon_y);
            $cr->scale(1.0 / 3.0, 1.0 / 3.0);
            Gtk3::Gdk::cairo_set_source_pixbuf($cr, $pixbuf, 0, 0);
            $cr->paint();
            $cr->restore();
        } else {
            $cr->set_source_rgba(1, 1, 1, 1);
            $cr->arc($handle_x, $handle_y, $handle_size / 2, 0, 2 * 3.14159);
            $cr->fill();
            
            $cr->set_source_rgba(0, 0, 0, 1);
            $cr->set_line_width(3.0);
            $cr->arc($handle_x, $handle_y, $handle_size / 2, 0, 2 * 3.14159);
            $cr->stroke();
            
            $cr->set_line_width(4.0);
            $cr->move_to($handle_x, $handle_y - 20);
            $cr->line_to($handle_x, $handle_y + 20);
            $cr->move_to($handle_x - 20, $handle_y);
            $cr->line_to($handle_x + 20, $handle_y);
            $cr->stroke();
        }
    }
    elsif ($item->{type} eq 'magnifier') {
        my $box_size = $item->{radius} * 2;
        my $box_x = $item->{x} - $item->{radius};
        my $box_y = $item->{y} - $item->{radius};

        $cr->set_source_rgba(1, 1, 1, 1); 
        $cr->set_line_width(0.3);
        $cr->set_dash(3, 3);

        $cr->rectangle($box_x, $box_y, $box_size, $box_size);
        $cr->stroke();
        $cr->set_dash(0);

        my @handle_positions = (
            ['nw', $box_x, $box_y],
            ['ne', $box_x + $box_size, $box_y],
            ['se', $box_x + $box_size, $box_y + $box_size],
            ['sw', $box_x, $box_y + $box_size],
            ['n', $box_x + $box_size/2, $box_y],
            ['e', $box_x + $box_size, $box_y + $box_size/2],
            ['s', $box_x + $box_size/2, $box_y + $box_size],
            ['w', $box_x, $box_y + $box_size/2]
        );

        foreach my $pos (@handle_positions) {
            draw_handle($cr, $pos->[1], $pos->[2], $pos->[0]);
        }
    }
    elsif ($item->{type} eq 'pixelize') {
        my $box_x = min($item->{x1}, $item->{x2});
        my $box_y = min($item->{y1}, $item->{y2});
        my $box_width = abs($item->{x2} - $item->{x1});
        my $box_height = abs($item->{y2} - $item->{y1});

        my $middle_x = ($item->{x1} + $item->{x2}) / 2;
        my $middle_y = ($item->{y1} + $item->{y2}) / 2;

        my @handles = (
            ['top-left',     $box_x, $box_y],
            ['top',          $middle_x, $box_y],
            ['top-right',    $box_x + $box_width, $box_y],
            ['right',        $box_x + $box_width, $middle_y],
            ['bottom-right', $box_x + $box_width, $box_y + $box_height],
            ['bottom',       $middle_x, $box_y + $box_height],
            ['bottom-left',  $box_x, $box_y + $box_height],
            ['left',         $box_x, $middle_y]
        );

        foreach my $handle (@handles) {
            draw_handle($cr, $handle->[1], $handle->[2], $handle->[0]);
        }
    }
    elsif ($item->{type} eq 'svg') {
        my $scaled_width = $item->{width} * $item->{scale};
        my $scaled_height = $item->{height} * $item->{scale};

        $cr->set_source_rgba(1, 1, 1, 1);  
        $cr->set_line_width(0.3);
        $cr->set_dash(3, 3);

        $cr->rectangle($item->{x}, $item->{y}, $scaled_width, $scaled_height);
        $cr->stroke();
        $cr->set_dash(0);

        my @handle_positions = (
            ['nw', $item->{x}, $item->{y}],
            ['ne', $item->{x} + $scaled_width, $item->{y}],
            ['se', $item->{x} + $scaled_width, $item->{y} + $scaled_height],
            ['sw', $item->{x}, $item->{y} + $scaled_height]
        );

        foreach my $pos (@handle_positions) {
            draw_handle($cr, $pos->[1], $pos->[2], $pos->[0]);
        }
    }

    if ($is_multi_selecting && defined $item->{selection_order}) {
        my $order = $item->{selection_order};

        my ($label_x, $label_y);

        if ($item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
            $label_x = ($item->{start_x} + $item->{end_x}) / 2;
            $label_y = ($item->{start_y} + $item->{end_y}) / 2;
        }
        elsif ($item->{type} eq 'rectangle' || $item->{type} eq 'ellipse' || $item->{type} eq 'pixelize') {
            $label_x = ($item->{x1} + $item->{x2}) / 2;
            $label_y = ($item->{y1} + $item->{y2}) / 2;
        }
        elsif ($item->{type} eq 'pyramid') {

            $label_x = ($item->{base_left} + $item->{base_right}) / 2;
            $label_y = ($item->{base_front} + $item->{base_back}) / 2;
        }
        elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/ && $item->{vertices}) {

            $label_x = 0;
            $label_y = 0;
            my $count = scalar @{$item->{vertices}};
            foreach my $vertex (@{$item->{vertices}}) {
                $label_x += $vertex->[0];
                $label_y += $vertex->[1];
            }
            $label_x /= $count;
            $label_y /= $count;
        }
        elsif ($item->{type} eq 'text') {
            $label_x = $item->{x} + $item->{width} / 2;
            $label_y = $item->{y} + $item->{height} / 2;
        }
        elsif ($item->{type} eq 'numbered-circle' || $item->{type} eq 'magnifier') {
            $label_x = $item->{x};
            $label_y = $item->{y};
        }
        elsif ($item->{type} eq 'svg') {
            $label_x = $item->{x} + ($item->{width} * $item->{scale}) / 2;
            $label_y = $item->{y} + ($item->{height} * $item->{scale}) / 2;
        }
        elsif ($item->{type} eq 'freehand' || $item->{type} eq 'highlighter') {

            if ($item->{points} && @{$item->{points}} >= 4) {
                $label_x = ($item->{points}[0] + $item->{points}[-2]) / 2;
                $label_y = ($item->{points}[1] + $item->{points}[-1]) / 2;
            }
        }

        $cr->save();
        $cr->set_source_rgba(0, 0.7, 1, 0.8); 
        $cr->arc($label_x, $label_y, 12, 0, 2 * pi);
        $cr->fill();

        $cr->set_source_rgba(1, 1, 1, 1); 
        $cr->select_font_face('Sans', 'normal', 'bold');
        $cr->set_font_size(14);

        my $text = "$order";
        my $extents = $cr->text_extents($text);
        my $text_x = $label_x - ($extents->{width} / 2 + $extents->{x_bearing});
        my $text_y = $label_y - ($extents->{height} / 2 + $extents->{y_bearing});

        $cr->move_to($text_x, $text_y);
        $cr->show_text($text);
        $cr->restore();
    }
    
    return;
}

sub draw_handle {
    my ($cr, $x, $y, $handle_id) = @_;

    $cr->save();

    my $visual_size = $handle_size * 1.5 / $scale_factor;

    my $active_id = ref($drag_handle) eq 'ARRAY' ?
        join('-', @$drag_handle) : $drag_handle;
    my $hover_id = ref($hovered_handle) eq 'ARRAY' ?
        join('-', @$hovered_handle) : $hovered_handle;
    my $current_id = ref($handle_id) eq 'ARRAY' ?
        join('-', @$handle_id) : $handle_id;

    if (defined $active_id && defined $current_id && $active_id eq $current_id) {
        $cr->set_source_rgba(1, 0, 0, 1.0);  
    }
    elsif (defined $hover_id && defined $current_id && $hover_id eq $current_id) {
        $cr->set_source_rgba(1, 0, 0, 1.0); 
    }
    else {
        $cr->set_source_rgba(1, 1, 1, 1.0);  
    }

    $cr->arc($x, $y, $visual_size / 2, 0, 2 * pi);
    $cr->fill_preserve();

    $cr->set_source_rgba(0, 0, 0, 1.0);  
    $cr->set_line_width(0.3 / $scale_factor);  
    $cr->stroke();

    $cr->restore();
    
    return;
}

sub draw_pyramid_handles {
    my ($cr, $pyramid) = @_;
    return unless $pyramid && $pyramid->{selected};

    draw_handle($cr, $pyramid->{apex_x}, $pyramid->{apex_y}, 'apex');

    draw_handle($cr, $pyramid->{base_left}, $pyramid->{base_front}, 'base_left_front');
    draw_handle($cr, $pyramid->{base_right}, $pyramid->{base_front}, 'base_right_front');
    draw_handle($cr, $pyramid->{base_left}, $pyramid->{base_back}, 'base_left_back');
    draw_handle($cr, $pyramid->{base_right}, $pyramid->{base_back}, 'base_right_back');
    
    return;
}

sub draw_pentagon_handles {
    my ($cr, $pentagon) = @_;
    return unless $pentagon && $pentagon->{vertices};

    foreach my $i (0..$#{$pentagon->{vertices}}) {
        my $v = $pentagon->{vertices}[$i];
        draw_handle($cr, $v->[0], $v->[1], "vertex-$i");
    }

    if ($pentagon->{middle_points}) {
        foreach my $i (0..$#{$pentagon->{middle_points}}) {
            my $m = $pentagon->{middle_points}[$i];
            draw_handle($cr, $m->[0], $m->[1], "middle-$i");
        }
    }
    
    return;
}

sub draw_cuboid_handles {
    my ($cr, $cuboid) = @_;
    return unless $cuboid && $cuboid->{selected};

    draw_handle($cr, $cuboid->{front_left}, $cuboid->{front_top}, 'front_top_left');
    draw_handle($cr, $cuboid->{front_right}, $cuboid->{front_top}, 'front_top_right');
    draw_handle($cr, $cuboid->{front_left}, $cuboid->{front_bottom}, 'front_bottom_left');
    draw_handle($cr, $cuboid->{front_right}, $cuboid->{front_bottom}, 'front_bottom_right');

    draw_handle($cr, $cuboid->{back_left}, $cuboid->{back_top}, 'back_top_left');
    draw_handle($cr, $cuboid->{back_right}, $cuboid->{back_top}, 'back_top_right');
    draw_handle($cr, $cuboid->{back_left}, $cuboid->{back_bottom}, 'back_bottom_left');
    draw_handle($cr, $cuboid->{back_right}, $cuboid->{back_bottom}, 'back_bottom_right');
    
    return;
}

sub draw_measurements_on_item {
    my ($cr, $item) = @_;
    
    return unless $item;

    if (defined $item->{show_measures} && $item->{show_measures}) {
        $item->{show_angles} = 1 unless defined $item->{show_angles};
        $item->{show_edges} = 1 unless defined $item->{show_edges};
        $item->{show_area} = 1 unless defined $item->{show_area};
        delete $item->{show_measures};
    }

    my $show_any = ($item->{show_angles} // 0) || 
                   ($item->{show_edges} // 0) || 
                   ($item->{show_area} // 0);
    
    return unless $show_any;

    my $type = $item->{type};

    if ($type eq 'line' || $type eq 'dashed-line') {
        draw_line_measurements($cr, $item);
    }
    elsif ($type eq 'rectangle') {
        draw_rectangle_measurements($cr, $item);
    }
    elsif ($type eq 'tetragon') {
        draw_tetragon_measurements($cr, $item);
    }
    elsif ($type eq 'pyramid') {
        draw_pyramid_measurements($cr, $item);
    }
    
    return;
}

sub draw_line_measurements {
    my ($cr, $item) = @_;
    
    return unless $item->{show_edges};
    
    my $dx = $item->{end_x} - $item->{start_x};
    my $dy = $item->{end_y} - $item->{start_y};
    my $length = sqrt($dx * $dx + $dy * $dy);
    
    my $mid_x = ($item->{start_x} + $item->{end_x}) / 2;
    my $mid_y = ($item->{start_y} + $item->{end_y}) / 2;

    my $angle = atan2($dy, $dx);
    my $perp_angle = $angle + pi / 2;
    my $offset = 15;
    my $text_x = $mid_x + cos($perp_angle) * $offset;
    my $text_y = $mid_y + sin($perp_angle) * $offset;
    
    my $text = sprintf("%.1f px", $length);
    draw_measurement_text($cr, $text, $text_x, $text_y);
    
    return;
}

sub draw_rectangle_measurements {
    my ($cr, $item) = @_;
    
    my $width = abs($item->{x2} - $item->{x1});
    my $height = abs($item->{y2} - $item->{y1});
    my $area = $width * $height;

    if ($item->{show_area}) {
        my $center_x = ($item->{x1} + $item->{x2}) / 2;
        my $center_y = ($item->{y1} + $item->{y2}) / 2;
        my $area_text = sprintf("%.1f px²", $area);
        draw_measurement_text($cr, $area_text, $center_x, $center_y);
    }

    if ($item->{show_edges}) {
        my $top_mid_x = ($item->{x1} + $item->{x2}) / 2;
        my $top_y = min($item->{y1}, $item->{y2}) - 35;  
        my $width_text = sprintf("%.1f px", $width);
        draw_measurement_text($cr, $width_text, $top_mid_x, $top_y);
        
        my $right_x = max($item->{x1}, $item->{x2}) + 50;  
        my $right_mid_y = ($item->{y1} + $item->{y2}) / 2;
        my $height_text = sprintf("%.1f px", $height);
        draw_measurement_text($cr, $height_text, $right_x, $right_mid_y);
    }
    
    return;
}

sub draw_tetragon_measurements {
    my ($cr, $item) = @_;
    
    my @vertices = @{$item->{vertices}};
    my @sides;
    my @angles;

    if ($item->{show_edges}) {
        for my $i (0..3) {
            my $next = ($i + 1) % 4;
            my $dx = $vertices[$next][0] - $vertices[$i][0];
            my $dy = $vertices[$next][1] - $vertices[$i][1];
            my $length = sqrt($dx * $dx + $dy * $dy);
            push @sides, $length;
            
            my $mid_x = ($vertices[$i][0] + $vertices[$next][0]) / 2;
            my $mid_y = ($vertices[$i][1] + $vertices[$next][1]) / 2;
            
            my $angle = atan2($dy, $dx);
            my $perp_angle = $angle + pi / 2;
            my $offset = 25;
            my $text_x = $mid_x + cos($perp_angle) * $offset;
            my $text_y = $mid_y + sin($perp_angle) * $offset;
            
            my $text = sprintf("%.1f", $length);
            draw_measurement_text($cr, $text, $text_x, $text_y, 10);
        }
    }

    if ($item->{show_angles}) {
        for my $i (0..3) {
            my $prev = ($i - 1 + 4) % 4;
            my $next = ($i + 1) % 4;
            
            my $angle = calculate_interior_angle(
                $vertices[$prev], $vertices[$i], $vertices[$next]
            );
            push @angles, $angle;
            
            my $angle_text = sprintf("%.1f°", $angle);
            draw_angle_marker($cr, $vertices[$i][0], $vertices[$i][1], $angle_text);
        }
    }

    if ($item->{show_area}) {
        my $area = abs(calculate_polygon_area(\@vertices));
        my $center_x = 0;
        my $center_y = 0;
        foreach my $v (@vertices) {
            $center_x += $v->[0];
            $center_y += $v->[1];
        }
        $center_x /= 4;
        $center_y /= 4;
        
        my $area_text = sprintf("%.1f px²", $area);
        draw_measurement_text($cr, $area_text, $center_x, $center_y);
    }
    
    return;
}

sub draw_pyramid_measurements {
    my ($cr, $item) = @_;    
    
    my $apex_x = $item->{apex_x};
    my $apex_y = $item->{apex_y};
    
    my @base_vertices = (
        [$item->{base_left}, $item->{base_front}],
        [$item->{base_right}, $item->{base_front}],
        [$item->{base_right}, $item->{base_back}],
        [$item->{base_left}, $item->{base_back}]
    );

    if ($item->{show_edges}) {
        for my $i (0..3) {
            my $next = ($i + 1) % 4;
            my $dx = $base_vertices[$next][0] - $base_vertices[$i][0];
            my $dy = $base_vertices[$next][1] - $base_vertices[$i][1];
            my $length = sqrt($dx * $dx + $dy * $dy);

            my $mid_x = ($base_vertices[$i][0] + $base_vertices[$next][0]) / 2;
            my $mid_y = ($base_vertices[$i][1] + $base_vertices[$next][1]) / 2;
            
            my $angle = atan2($dy, $dx);
            my $perp_angle = $angle + pi / 2;
            my $offset = 25;
            my $text_x = $mid_x + cos($perp_angle) * $offset;
            my $text_y = $mid_y + sin($perp_angle) * $offset;
            
            my $text = sprintf("%.1f", $length);
            draw_measurement_text($cr, $text, $text_x, $text_y, 10);
        }
    }

    if ($item->{show_area}) {
        my $area = abs(calculate_polygon_area(\@base_vertices));
        my $center_x = ($item->{base_left} + $item->{base_right}) / 2;
        my $center_y = ($item->{base_front} + $item->{base_back}) / 2;
        
        my $area_text = sprintf("%.1f px²", $area);
        draw_measurement_text($cr, $area_text, $center_x, $center_y);
    }

    if ($item->{show_angles}) {
        my @front_face = (
            [$item->{base_left}, $item->{base_front}],
            [$item->{base_right}, $item->{base_front}],
            [$apex_x, $apex_y]
        );
        draw_face_angles_with_offset($cr, \@front_face, 0, 25); 
        
        my @right_face = (
            [$item->{base_right}, $item->{base_front}],
            [$item->{base_right}, $item->{base_back}],
            [$apex_x, $apex_y]
        );
        draw_face_angles_with_offset($cr, \@right_face, 25, 0); 

        my @back_face = (
            [$item->{base_right}, $item->{base_back}],
            [$item->{base_left}, $item->{base_back}],
            [$apex_x, $apex_y]
        );
        draw_face_angles_with_offset($cr, \@back_face, 0, -25);  

        my @left_face = (
            [$item->{base_left}, $item->{base_back}],
            [$item->{base_left}, $item->{base_front}],
            [$apex_x, $apex_y]
        );
        draw_face_angles_with_offset($cr, \@left_face, -25, 0);
    }
    
    return;
}

sub draw_face_angles {
    my ($cr, $vertices) = @_;
    
    for my $i (0..2) {
        my $prev = ($i - 1 + 3) % 3;
        my $next = ($i + 1) % 3;
        
        my $angle = calculate_triangle_angle(
            $vertices->[$prev], 
            $vertices->[$i], 
            $vertices->[$next]
        );
        
        my $angle_text = sprintf("%.1f°", $angle);
        draw_angle_marker($cr, $vertices->[$i][0], $vertices->[$i][1], $angle_text);
    }
    
    return;
}

sub draw_face_angles_with_offset {
    my ($cr, $vertices, $offset_x, $offset_y) = @_;
    
    for my $i (0..2) {
        my $prev = ($i - 1 + 3) % 3;
        my $next = ($i + 1) % 3;
        
        my $angle = calculate_triangle_angle(
            $vertices->[$prev], 
            $vertices->[$i], 
            $vertices->[$next]
        );
        
        my $angle_text = sprintf("%.1f°", $angle);

        my $marker_x = $vertices->[$i][0] + $offset_x;
        my $marker_y = $vertices->[$i][1] + $offset_y;
        
        draw_angle_marker($cr, $marker_x, $marker_y, $angle_text);
    }
    
    return;
}

sub draw_measurement_text {
    my ($cr, $text, $x, $y, $size) = @_;
    $size ||= 11;
    
    my $layout = Pango::Cairo::create_layout($cr);
    my $desc = Pango::FontDescription->from_string("Sans Bold $size");
    $layout->set_font_description($desc);
    $layout->set_text($text);
    
    my ($width, $height) = $layout->get_pixel_size();
    
    $cr->save();
    
    $cr->set_source_rgba(1, 1, 1, 0.9);
    $cr->rectangle($x - $width/2 - 3, $y - $height/2 - 2, $width + 6, $height + 4);
    $cr->fill();

    $cr->set_source_rgba(0, 0, 0, 0.5);
    $cr->set_line_width(1);
    $cr->rectangle($x - $width/2 - 3, $y - $height/2 - 2, $width + 6, $height + 4);
    $cr->stroke();

    $cr->set_source_rgba(0, 0, 0, 1);
    $cr->move_to($x - $width/2, $y - $height/2);
    Pango::Cairo::show_layout($cr, $layout);

    $cr->restore();
    
    return;
}

sub draw_angle_marker {
    my ($cr, $x, $y, $text) = @_;
    
    my $layout = Pango::Cairo::create_layout($cr);
    my $desc = Pango::FontDescription->from_string("Sans Bold 9");
    $layout->set_font_description($desc);
    $layout->set_text($text);
    
    my ($width, $height) = $layout->get_pixel_size();
    
    my $offset_x = $x + 20;
    my $offset_y = $y + 20;
    
    $cr->set_source_rgba(1, 1, 0.8, 0.9);
    $cr->rectangle($offset_x - 2, $offset_y - 2, $width + 4, $height + 4);
    $cr->fill();
    
    $cr->set_source_rgba(0, 0, 0, 0.5);
    $cr->set_line_width(1);
    $cr->rectangle($offset_x - 2, $offset_y - 2, $width + 4, $height + 4);
    $cr->stroke();
    
    $cr->set_source_rgba(0, 0, 0, 1);
    $cr->move_to($offset_x, $offset_y);
    Pango::Cairo::show_layout($cr, $layout);
    
    return;
}
    
# =============================================================================
# SECTION 7. MATH & GEOMETRY Hit (Calculations)
# =============================================================================

# Hit Tests:

sub check_item_selection {
    my ($widget, $x, $y) = @_;
    my ($img_x, $img_y) = window_to_image_coords($widget, $x, $y);

    my @all_items;
    foreach my $type (qw(pixelize_items text_items svg_items magnifiers numbered-circles lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines)) {
        next unless exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY';
        push @all_items, @{$items{$type}};
    }

    @all_items = sort { $b->{timestamp} <=> $a->{timestamp} } @all_items;

    my $hit = 0;
    foreach my $item (@all_items) {
        next unless defined $item;
        if (is_point_near_item($img_x, $img_y, $item)) {
            $hit = 1;
            last;
        }
    }

    if (!$hit && $current_item) {
        deselect_all_items();
        $widget->queue_draw();
        return TRUE;
    }

    my $is_right_click = $stored_event && $stored_event->button == 3;

    my $topmost_item = undef;
    my $topmost_handle = undef;
    
    foreach my $item (@all_items) {
        next unless defined $item;
        
        next if defined $item->{anchored} && $item->{anchored} && !$is_right_click;
        
        my $handle = undef;
        my $item_hit = 0;

        if ($item->{type} eq 'pixelize' || $item->{type} eq 'rectangle' || $item->{type} eq 'crop_rect') {
            $handle = get_rectangle_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_rectangle($img_x, $img_y, $item);
        }
        elsif ($item->{type} eq 'ellipse') {
            $handle = get_ellipse_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_ellipse($img_x, $img_y, $item);
        }
        elsif ($item->{type} =~ /^(line|dashed-line|single-arrow|double-arrow)$/) {
            $handle = get_item_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_near_line($img_x, $img_y, $item);
        }
        elsif ($item->{type} eq 'text') {
            $handle = get_text_handle($img_x, $img_y, $item);
            $item_hit = defined $handle;
        }
        elsif ($item->{type} eq 'numbered-circle') {
            $handle = get_circle_handle($img_x, $img_y, $item);
            $item_hit = defined $handle;
        }
        elsif ($item->{type} eq 'magnifier') {
            $handle = get_circle_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_magnifier($img_x, $img_y, $item);
        }
        elsif ($item->{type} eq 'svg') {
            $handle = get_svg_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_svg($img_x, $img_y, $item);
        }
        elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/) {
            $handle = get_shape_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_shape($img_x, $img_y, $item);
        }
        elsif ($item->{type} =~ /^(freehand|highlighter)$/) {
            $item_hit = is_point_near_freehand($img_x, $img_y, $item);
            if ($item_hit) {
                $handle = get_freehand_handle($img_x, $img_y, $item);
            }
        }
        elsif ($item->{type} eq 'pyramid') {
    
            $handle = get_pyramid_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_pyramid($img_x, $img_y, $item);
        }
        elsif ($item->{type} eq 'cuboid') {
    
            $handle = get_cuboid_handle($img_x, $img_y, $item);
            $item_hit = defined $handle || is_point_in_cuboid($img_x, $img_y, $item);
        }

        if ($item_hit) {

            $topmost_item = $item;
            $topmost_handle = $handle;
            last; 
        }
    }

    if ($topmost_item) {
        if ($is_right_click && $topmost_item->{anchored}) {
            $current_item = $topmost_item;
        } else {
            select_item($topmost_item, $topmost_handle);
        }
        return TRUE;
    }

    if ($current_item) {

        unless ($current_tool eq 'crop') {
            deselect_all_items();
            $widget->queue_draw();
        }
    }

    return FALSE;
}

sub is_point_near_item {
    my ($x, $y, $item) = @_;

    if ($item->{type} =~ /^(line|dashed-line|single-arrow|double-arrow)$/) {
        return is_point_near_line($x, $y, $item);
    }
    elsif ($item->{type} eq 'rectangle' || $item->{type} eq 'pixelize') {
        return is_point_in_rectangle($x, $y, $item);
    }
    elsif ($item->{type} eq 'ellipse') {
        return is_point_in_ellipse($x, $y, $item);
    }
    elsif ($item->{type} =~ /^(freehand|highlighter)$/) {
        return is_point_near_freehand($x, $y, $item);
    }
    elsif ($item->{type} eq 'text') {
        return is_point_in_text($x, $y, $item);
    }
    elsif ($item->{type} eq 'numbered-circle') {
        return is_point_in_circle($x, $y, $item);
    }
    elsif ($item->{type} eq 'magnifier') {
        return is_point_in_magnifier($x, $y, $item);
    }
    elsif ($item->{type} eq 'svg') {
        return 1 if defined get_svg_handle($x, $y, $item);
        return is_point_in_svg($x, $y, $item);
    }
    elsif ($item->{type} =~ /^(triangle|tetragon|pentagon|pyramid|cuboid)$/) {
        return is_point_in_shape($x, $y, $item);
    }

    return 0;
}

sub is_point_near_point {
    my ($x1, $y1, $x2, $y2, $threshold) = @_;
    $threshold ||= $handle_size;

    my $dx = $x1 - $x2;
    my $dy = $y1 - $y2;
    return sqrt($dx*$dx + $dy*$dy) < $threshold;
}

sub is_point_near_line {
    my ($x, $y, $line, $tolerance) = @_;
    $tolerance ||= 5;

    if ($line->{is_curved}) {

        my $min_x = min($line->{start_x}, $line->{end_x}, $line->{control_x});
        my $max_x = max($line->{start_x}, $line->{end_x}, $line->{control_x});
        my $min_y = min($line->{start_y}, $line->{end_y}, $line->{control_y});
        my $max_y = max($line->{start_y}, $line->{end_y}, $line->{control_y});

        $min_x -= $tolerance;
        $max_x += $tolerance;
        $min_y -= $tolerance;
        $max_y += $tolerance;

        return 0 if $x < $min_x || $x > $max_x || $y < $min_y || $y > $max_y;

        my @segments = (
            [$line->{start_x}, $line->{start_y}, $line->{control_x}, $line->{control_y}],
            [$line->{control_x}, $line->{control_y}, $line->{end_x}, $line->{end_y}]
        );

        foreach my $seg (@segments) {
            my ($x1, $y1, $x2, $y2) = @$seg;
            my $dx = $x2 - $x1;
            my $dy = $y2 - $y1;
            my $len_sq = $dx * $dx + $dy * $dy;

            if ($len_sq != 0) {
                my $t = max(0, min(1, (($x - $x1) * $dx + ($y - $y1) * $dy) / $len_sq));
                my $proj_x = $x1 + $t * $dx;
                my $proj_y = $y1 + $t * $dy;
                my $dist = sqrt(($x - $proj_x)**2 + ($y - $proj_y)**2);

                return 1 if $dist < $tolerance;
            }
        }
        return 0;
    }

    my $dx = $line->{end_x} - $line->{start_x};
    my $dy = $line->{end_y} - $line->{start_y};
    my $len_sq = $dx * $dx + $dy * $dy;

    if ($len_sq == 0) {
        my $dist = sqrt(($x - $line->{start_x})**2 + ($y - $line->{start_y})**2);
        return $dist < $tolerance;
    }

    my $t = max(0, min(1, (($x - $line->{start_x}) * $dx + ($y - $line->{start_y}) * $dy) / $len_sq));
    my $proj_x = $line->{start_x} + $t * $dx;
    my $proj_y = $line->{start_y} + $t * $dy;  
    my $dist = sqrt(($x - $proj_x)**2 + ($y - $proj_y)**2);

    return $dist < $tolerance;
}

sub is_point_on_line_segment {
    my ($x, $y, $x1, $y1, $x2, $y2) = @_;
    my $buffer = 5;

    my $d = sqrt(($x2-$x1)**2 + ($y2-$y1)**2);
    my $d1 = sqrt(($x-$x1)**2 + ($y-$y1)**2);
    my $d2 = sqrt(($x-$x2)**2 + ($y-$y2)**2);

    if ($d1 + $d2 >= $d - 0.1 && $d1 + $d2 <= $d + 0.1) {
        my $dx = $x2 - $x1;
        my $dy = $y2 - $y1;
        my $len_sq = $dx * $dx + $dy * $dy;

        if ($len_sq != 0) {
            my $t = max(0, min(1, (($x - $x1) * $dx + ($y - $y1) * $dy) / $len_sq));
            my $proj_x = $x1 + $t * $dx;
            my $proj_y = $y1 + $t * $dy;
            my $dist = sqrt(($x - $proj_x)**2 + ($y - $proj_y)**2);
            return 1 if $dist < $buffer;
        }
    }
    return 0;
}

sub is_point_in_rectangle {
   my ($x, $y, $rect) = @_;
   return unless defined $rect;

   my $x1 = min($rect->{x1}, $rect->{x2});
   my $x2 = max($rect->{x1}, $rect->{x2});
   my $y1 = min($rect->{y1}, $rect->{y2});
   my $y2 = max($rect->{y1}, $rect->{y2});

   if ($x >= $x1 && $x <= $x2 && $y >= $y1 && $y <= $y2) {
       return 1;
   }

   my $border_threshold = $handle_size;

   if ($x >= $x1 && $x <= $x2) {
       return 1 if abs($y - $y1) <= $border_threshold;
       return 1 if abs($y - $y2) <= $border_threshold;
   }

   if ($y >= $y1 && $y <= $y2) {
       return 1 if abs($x - $x1) <= $border_threshold;
       return 1 if abs($x - $x2) <= $border_threshold;
   }

   return 0;
}

sub is_point_in_ellipse {
    my ($x, $y, $ellipse) = @_;

    my $center_x = ($ellipse->{x1} + $ellipse->{x2}) / 2;
    my $center_y = ($ellipse->{y1} + $ellipse->{y2}) / 2;
    my $a = abs($ellipse->{x2} - $ellipse->{x1}) / 2;  
    my $b = abs($ellipse->{y2} - $ellipse->{y1}) / 2;  

    return 0 if $a == 0 || $b == 0; 

    my $px = $x - $center_x;
    my $py = $y - $center_y;

    my $check = ($px * $px) / ($a * $a) + ($py * $py) / ($b * $b);
    return $check <= 1.1; 
}

sub is_point_in_circle {
    my ($x, $y, $item) = @_;
    return 0 unless defined $item->{x} && defined $item->{y} && defined $item->{radius};
    
    my $dx = $x - $item->{x};
    my $dy = $y - $item->{y};
    my $distance = sqrt($dx * $dx + $dy * $dy);
    
    return $distance <= $item->{radius};
}

sub is_point_in_text {
    my ($x, $y, $text_item) = @_;
    return 0 unless $text_item && defined $text_item->{text};

    my $box_x = $text_item->{x};
    my $box_y = $text_item->{y};
    my $box_width = $text_item->{width};
    my $box_height = $text_item->{height};

    my $padding = 15 / ($scale_factor || 1); 

    if ($x >= $box_x - $padding &&
        $x <= $box_x + $box_width + $padding &&
        $y >= $box_y - $padding &&
        $y <= $box_y + $box_height + $padding) {
        return 1;
    }

    return 0;
}

sub is_point_in_shape {
    my ($x, $y, $shape) = @_;
    return 0 unless $shape && $shape->{vertices} && @{$shape->{vertices}} >= 3;

    my $inside = 0;
    my $n = scalar @{$shape->{vertices}};

    for my $i (0 .. $n-1) {
        my $j = ($i + 1) % $n;
        my $xi = $shape->{vertices}[$i][0];
        my $yi = $shape->{vertices}[$i][1];
        my $xj = $shape->{vertices}[$j][0];
        my $yj = $shape->{vertices}[$j][1];

        if (is_point_on_line_segment($x, $y, $xi, $yi, $xj, $yj)) {
            return 1;
        }

        if ((($yi > $y) != ($yj > $y)) &&
            ($x < ($xj - $xi) * ($y - $yi) / ($yj - $yi) + $xi)) {
            $inside = !$inside;
        }
    }
    return $inside;
}

sub is_point_in_pentagon {
    my ($x, $y, $pentagon) = @_;
    return 0 unless $pentagon && $pentagon->{vertices} && @{$pentagon->{vertices}} >= 5;

    my $inside = 0;
    my $n = scalar @{$pentagon->{vertices}};

    for my $i (0 .. $n-1) {
        my $j = ($i + 1) % $n;
        my $xi = $pentagon->{vertices}[$i][0];
        my $yi = $pentagon->{vertices}[$i][1];
        my $xj = $pentagon->{vertices}[$j][0];
        my $yj = $pentagon->{vertices}[$j][1];

        if ((($yi > $y) != ($yj > $y)) &&
            ($x < ($xj - $xi) * ($y - $yi) / ($yj - $yi) + $xi)) {
            $inside = !$inside;
        }
    }

    return $inside;
}

sub is_point_in_pyramid {
    my ($x, $y, $pyramid) = @_;
    return 0 unless $pyramid && $pyramid->{faces};

    foreach my $face_name (keys %{$pyramid->{faces}}) {
        if (is_point_in_face($x, $y, $pyramid->{faces}{$face_name}{vertices})) {
            return 1;
        }
    }
    return 0;
}

sub is_point_in_cuboid {
    my ($x, $y, $cuboid) = @_;
    return 0 unless $cuboid && $cuboid->{faces};
    
    foreach my $face_name (keys %{$cuboid->{faces}}) {
        if (is_point_in_face($x, $y, $cuboid->{faces}{$face_name}{vertices})) {
            return 1;
        }
    }
    return 0;
}

sub is_point_in_svg {
    my ($x, $y, $item) = @_;

    my $img_x = $x;
    my $img_y = $y;

    my $scaled_width = $item->{width} * $item->{scale};
    my $scaled_height = $item->{height} * $item->{scale};

    return ($img_x >= $item->{x} &&
            $img_x <= $item->{x} + $scaled_width &&
            $img_y >= $item->{y} &&
            $img_y <= $item->{y} + $scaled_height);
    
    return;
}

sub is_point_in_magnifier {
    my ($x, $y, $magnifier) = @_;
    return 0 unless $magnifier;

    my $display_x = $magnifier->{x};
    my $display_y = $magnifier->{y};

    my $dx = $x - $display_x;
    my $dy = $y - $display_y;
    return sqrt($dx*$dx + $dy*$dy) <= $magnifier->{radius};
}

sub is_point_near_freehand {
    my ($x, $y, $item) = @_;
    return 0 unless $item && $item->{points} && @{$item->{points}} >= 4;
    return 0 unless $item->{type} eq 'freehand' || $item->{type} eq 'highlighter';

    my $tolerance = ($item->{type} eq 'highlighter') ? 9 : 5;

    for (my $i = 0; $i < @{$item->{points}} - 2; $i += 2) {
        my $x1 = $item->{points}[$i];
        my $y1 = $item->{points}[$i + 1];
        my $x2 = $item->{points}[$i + 2];
        my $y2 = $item->{points}[$i + 3];

        my $dx = $x2 - $x1;
        my $dy = $y2 - $y1;
        my $len_sq = $dx * $dx + $dy * $dy;

        if ($len_sq != 0) {
            my $t = max(0, min(1, (($x - $x1) * $dx + ($y - $y1) * $dy) / $len_sq));
            my $proj_x = $x1 + $t * $dx;
            my $proj_y = $y1 + $t * $dy;
            my $dist = sqrt(($x - $proj_x)**2 + ($y - $proj_y)**2);

            return 1 if $dist < $tolerance;
        }
    }
    return 0;
}

sub is_point_near_curve {
    my ($x, $y, $item) = @_;
    return 0 unless $item->{is_curved};

    my $steps = 20;
    my ($prev_x, $prev_y) = ($item->{start_x}, $item->{start_y});

    for my $i (1..$steps) {
        my $t = $i / $steps;

        my $curr_x = ((1-$t) * (1-$t)) * $item->{start_x} +
            2*(1-$t)*$t * $item->{control_x} +
            ($t * $t) * $item->{end_x};
        my $curr_y = ((1-$t) * (1-$t)) * $item->{start_y} +
            2*(1-$t)*$t * $item->{control_y} +
            ($t * $t) * $item->{end_y};

        my $dx = $curr_x - $prev_x;
        my $dy = $curr_y - $prev_y;
        my $len_sq = $dx * $dx + $dy * $dy;

        if ($len_sq > 0) {
            my $t = max(0, min(1, (($x - $prev_x) * $dx + ($y - $prev_y) * $dy) / $len_sq));
            my $proj_x = $prev_x + $t * $dx;
            my $proj_y = $prev_y + $t * $dy;
            my $dist = sqrt(($x - $proj_x)**2 + ($y - $proj_y)**2);

            return 1 if $dist < 5;
        }

        ($prev_x, $prev_y) = ($curr_x, $curr_y);
    }
    return 0;
}

sub is_point_near_arrow {
    my ($x, $y, $arrow) = @_;

    my $dx = $arrow->{end_x} - $arrow->{start_x};
    my $dy = $arrow->{end_y} - $arrow->{start_y};
    my $len_sq = $dx * $dx + $dy * $dy;

    my $t = max(0, min(1, (($x - $arrow->{start_x}) * $dx + ($y - $arrow->{start_y}) * $dy) / $len_sq));

    my $proj_x = $arrow->{start_x} + $t * $dx;
    my $proj_y = $arrow->{start_y} + $t * $dy;

    my $dist = sqrt(($x - $proj_x) * ($x - $proj_x) + ($y - $proj_y) * ($y - $proj_y));

    return $dist < 5;
}


sub is_point_near_control {
    my ($x, $y, $arrow) = @_;
    return (abs($x - $arrow->{control_x}) < $handle_size &&
            abs($y - $arrow->{control_y}) < $handle_size);
    
    return;
}

sub is_point_in_face {
    my ($x, $y, $vertices) = @_;
    return 0 unless $vertices && @$vertices >= 3;
    
    my $inside = 0;
    my $n = scalar @$vertices;
    
    for my $i (0 .. $n-1) {
        my $j = ($i + 1) % $n;
        my $xi = $vertices->[$i][0];
        my $yi = $vertices->[$i][1];
        my $xj = $vertices->[$j][0];
        my $yj = $vertices->[$j][1];
        
        if ((($yi > $y) != ($yj > $y)) &&
            ($x < ($xj - $xi) * ($y - $yi) / ($yj - $yi) + $xi)) {
            $inside = !$inside;
        }
    }
    return $inside;
}

# Handle Detection:

sub get_item_handle {
    my ($x, $y, $item) = @_;
    my $threshold = get_handle_threshold();

    return unless $item->{type} =~ /^(line|single-arrow|double-arrow)$/;

    my ($x1, $y1) = ($item->{start_x}, $item->{start_y});
    my ($x2, $y2) = ($item->{end_x}, $item->{end_y});

    if (is_point_near_point($x, $y, $x1, $y1, $threshold)) {
        return 'start';
    }
    if (is_point_near_point($x, $y, $x2, $y2, $threshold)) {
        return 'end';
    }

    if ($item->{is_curved} && defined $item->{control_x}) {
     
        if (is_point_near_point($x, $y, $item->{control_x}, $item->{control_y}, $threshold)) {
            return 'control';
        }
    } else {
   
        my $mid_x = ($x1 + $x2) / 2;
        my $mid_y = ($y1 + $y2) / 2;
        if (is_point_near_point($x, $y, $mid_x, $mid_y, $threshold)) {
            return 'middle';
        }
    }

    if (is_point_near_line($x, $y, $item, 5)) {
        return 'body';
    }
    return;
}

sub get_rectangle_handle {
    my ($x, $y, $rect) = @_;
    my $threshold = get_handle_threshold();

    if ($rect->{type} eq 'crop_rect') {
        $threshold *= 3.0; 
    }

    my $middle_x = ($rect->{x1} + $rect->{x2}) / 2;
    my $middle_y = ($rect->{y1} + $rect->{y2}) / 2;

    my %handle_points = (
        'top-left'     => [$rect->{x1}, $rect->{y1}],
        'top'          => [$middle_x, $rect->{y1}],
        'top-right'    => [$rect->{x2}, $rect->{y1}],
        'right'        => [$rect->{x2}, $middle_y],
        'bottom-right' => [$rect->{x2}, $rect->{y2}],
        'bottom'       => [$middle_x, $rect->{y2}],
        'bottom-left'  => [$rect->{x1}, $rect->{y2}],
        'left'         => [$rect->{x1}, $middle_y]
    );

    for my $handle (keys %handle_points) {
        my $dx = $x - $handle_points{$handle}[0];
        my $dy = $y - $handle_points{$handle}[1];
        return $handle if sqrt($dx*$dx + $dy*$dy) < $threshold;
    }

    if ($x >= min($rect->{x1}, $rect->{x2}) &&
        $x <= max($rect->{x1}, $rect->{x2}) &&
        $y >= min($rect->{y1}, $rect->{y2}) &&
        $y <= max($rect->{y1}, $rect->{y2})) {
        return 'body';
    }
    
    return;
}

sub get_ellipse_handle {
    my ($x, $y, $ellipse) = @_;
    my $threshold = get_handle_threshold();

    my $center_x = ($ellipse->{x1} + $ellipse->{x2}) / 2;
    my $center_y = ($ellipse->{y1} + $ellipse->{y2}) / 2;

    my %handle_points = (
        'top-left'     => [$ellipse->{x1}, $ellipse->{y1}],
        'top'          => [$center_x, $ellipse->{y1}],
        'top-right'    => [$ellipse->{x2}, $ellipse->{y1}],
        'right'        => [$ellipse->{x2}, $center_y],
        'bottom-right' => [$ellipse->{x2}, $ellipse->{y2}],
        'bottom'       => [$center_x, $ellipse->{y2}],
        'bottom-left'  => [$ellipse->{x1}, $ellipse->{y2}],
        'left'         => [$ellipse->{x1}, $center_y]
    );

    for my $handle (keys %handle_points) {
        my $dx = $x - $handle_points{$handle}[0];
        my $dy = $y - $handle_points{$handle}[1];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return $handle;
        }
    }

    my $a = abs($ellipse->{x2} - $ellipse->{x1}) / 2;
    my $b = abs($ellipse->{y2} - $ellipse->{y1}) / 2;
    my $px = $x - $center_x;
    my $py = $y - $center_y;

    if (($px * $px) / ($a * $a) + ($py * $py) / ($b * $b) <= 1.1) {
        return 'body';
    }
    
    return;
}

sub get_shape_handle {
    my ($x, $y, $shape) = @_;
    my $threshold = get_handle_threshold();

    for my $i (0 .. $#{$shape->{vertices}}) {
        my $dx = $x - $shape->{vertices}[$i][0];
        my $dy = $y - $shape->{vertices}[$i][1];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return ['vertex', $i];
        }
    }

    if ($shape->{middle_points}) {
        for my $i (0 .. $#{$shape->{middle_points}}) {
            my $dx = $x - $shape->{middle_points}[$i][0];
            my $dy = $y - $shape->{middle_points}[$i][1];
            if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
                return ['middle', $i];
            }
        }
    }

    if (is_point_in_shape($x, $y, $shape)) {
        return ['body', -1];
    }
    return;
}

sub get_pentagon_handle {
    my ($x, $y, $pentagon) = @_;
    my $threshold = get_handle_threshold();

    if ($pentagon->{middle_points}) {
        for my $i (0 .. $#{$pentagon->{middle_points}}) {
            my $mx = $pentagon->{middle_points}[$i][0];
            my $my = $pentagon->{middle_points}[$i][1];

            my $dx = $x - $mx;
            my $dy = $y - $my;
            if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
                return ['middle', $i];
            }
        }
    }

    for my $i (0 .. $#{$pentagon->{vertices}}) {
        my $vx = $pentagon->{vertices}[$i][0];
        my $vy = $pentagon->{vertices}[$i][1];

        my $dx = $x - $vx;
        my $dy = $y - $vy;
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return ['vertex', $i];
        }
    }

    if (is_point_in_pentagon($x, $y, $pentagon)) {
        return ['body', -1];
    }
}

sub get_pyramid_handle {
    my ($x, $y, $pyramid) = @_;
    my $threshold = get_handle_threshold();

    my $dx = $x - $pyramid->{apex_x};
    my $dy = $y - $pyramid->{apex_y};
    if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
        return 'apex';
    }

    my @base_points = (
        ['base_left_front', $pyramid->{base_left}, $pyramid->{base_front}],
        ['base_right_front', $pyramid->{base_right}, $pyramid->{base_front}],
        ['base_left_back', $pyramid->{base_left}, $pyramid->{base_back}],
        ['base_right_back', $pyramid->{base_right}, $pyramid->{base_back}]
    );

    foreach my $point (@base_points) {
        my $dx = $x - $point->[1];
        my $dy = $y - $point->[2];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return $point->[0];
        }
    }

    if ($pyramid->{vertices} && @{$pyramid->{vertices}} >= 3) {
        if (is_point_in_pyramid($x, $y, $pyramid)) {
        return 'body';
        }
    }
    return;
}

sub get_cuboid_handle {
    my ($x, $y, $cuboid) = @_;
    my $threshold = get_handle_threshold();

    my @front_corners = (
        ['front_top_left', $cuboid->{front_left}, $cuboid->{front_top}],
        ['front_top_right', $cuboid->{front_right}, $cuboid->{front_top}],
        ['front_bottom_left', $cuboid->{front_left}, $cuboid->{front_bottom}],
        ['front_bottom_right', $cuboid->{front_right}, $cuboid->{front_bottom}]
    );

    foreach my $corner (@front_corners) {
        my $dx = $x - $corner->[1];
        my $dy = $y - $corner->[2];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return $corner->[0];
        }
    }

    my @back_corners = (
        ['back_top_left', $cuboid->{back_left}, $cuboid->{back_top}],
        ['back_top_right', $cuboid->{back_right}, $cuboid->{back_top}],
        ['back_bottom_left', $cuboid->{back_left}, $cuboid->{back_bottom}],
        ['back_bottom_right', $cuboid->{back_right}, $cuboid->{back_bottom}]
    );

    foreach my $corner (@back_corners) {
        my $dx = $x - $corner->[1];
        my $dy = $y - $corner->[2];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return $corner->[0];
        }
    }

    if (is_point_in_cuboid($x, $y, $cuboid)) {
        return 'body';
    }
    
    return;
}

sub get_text_handle {
    my ($x, $y, $text_item) = @_;
    return unless $text_item;

    my $threshold = get_handle_threshold() * 1.5; 
    
    my $box_x = $text_item->{x};
    my $box_y = $text_item->{y};
    my $box_width = $text_item->{width};
    my $box_height = $text_item->{height};

    my $handle_size = 100;
    my $handle_radius = $handle_size / 2;
    my $handle_gap = 15;
    my $handle_x = $box_x - $handle_size - $handle_gap;
    my $handle_y = $box_y + ($box_height / 2);
    
    my $dx = $x - $handle_x;
    my $dy = $y - $handle_y;
    my $distance = sqrt($dx * $dx + $dy * $dy);
    
    if ($distance <= $handle_radius * 1.2) {
        return 'drag';
    }

    if (is_point_in_text($x, $y, $text_item)) {
        return 'body';
    }
    
    return;
}

sub set_cursor_position_from_click {
    my ($text_item, $click_x, $click_y) = @_;
    return unless $text_item && defined $click_x && defined $click_y;

    my @lines = split("\n", $text_item->{text});
    
    my $desc = Pango::FontDescription->from_string($text_item->{font} // 'Sans 12');
    my $temp_surface = Cairo::ImageSurface->create('argb32', 10, 10);
    my $temp_cr = Cairo::Context->create($temp_surface);
    my $temp_layout = Pango::Cairo::create_layout($temp_cr);
    $temp_layout->set_font_description($desc);

    $temp_layout->set_text($lines[0] || ' ');
    my (undef, $line_height) = $temp_layout->get_pixel_size();
    $line_height = 20 if $line_height <= 0;

    my $relative_y = $click_y - $text_item->{y};
    my $line_index = int($relative_y / $line_height);
    $line_index = max(0, min($line_index, scalar(@lines) - 1));
    
    $text_item->{current_line} = $line_index;

    my $current_line_text = $lines[$line_index] // '';
    my $relative_x = $click_x - $text_item->{x};
    
    my $char_pos = 0;
    if (length($current_line_text) > 0) {

        for my $i (0 .. length($current_line_text)) {
            my $substr = substr($current_line_text, 0, $i);
            $temp_layout->set_text($substr || ' ');
            my ($width, undef) = $temp_layout->get_pixel_size();
            
            if ($width >= $relative_x) {

                if ($i > 0) {
                    my $prev_substr = substr($current_line_text, 0, $i - 1);
                    $temp_layout->set_text($prev_substr || ' ');
                    my ($prev_width, undef) = $temp_layout->get_pixel_size();
                    
                    if ($relative_x - $prev_width < $width - $relative_x) {
                        $char_pos = $i - 1;
                    } else {
                        $char_pos = $i;
                    }
                } else {
                    $char_pos = 0;
                }
                last;
            }
            $char_pos = $i;
        }
    }
    
    $text_item->{current_column} = max(0, min($char_pos, length($current_line_text)));
    
    $temp_surface->finish();
}

sub get_circle_handle {
    my ($x, $y, $circle) = @_;
    my $threshold = get_handle_threshold();

    my $circle_x = $circle->{x};
    my $circle_y = $circle->{y};

    my $box_size = $circle->{radius} * 2;
    my $box_x = $circle_x - $circle->{radius};
    my $box_y = $circle_y - $circle->{radius};

    my %handles = (
        'nw' => [$box_x, $box_y],
        'ne' => [$box_x + $box_size, $box_y],
        'se' => [$box_x + $box_size, $box_y + $box_size],
        'sw' => [$box_x, $box_y + $box_size],
        'n'  => [$box_x + $box_size/2, $box_y],
        'e'  => [$box_x + $box_size, $box_y + $box_size/2],
        's'  => [$box_x + $box_size/2, $box_y + $box_size],
        'w'  => [$box_x, $box_y + $box_size/2]
    );

    for my $handle_type (keys %handles) {
        my $dx = $x - $handles{$handle_type}[0];
        my $dy = $y - $handles{$handle_type}[1];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return $handle_type;
        }
    }

    my $dx = $x - $circle_x;
    my $dy = $y - $circle_y;
    return 'body' if sqrt($dx*$dx + $dy*$dy) <= $circle->{radius};
    
    return;
}

sub get_svg_handle {
    my ($x, $y, $item) = @_;
    my $threshold = get_handle_threshold();

    my $img_x = $x;
    my $img_y = $y;

    my $scaled_width = $item->{width} * $item->{scale};
    my $scaled_height = $item->{height} * $item->{scale};

    my $box_x = $item->{x};
    my $box_y = $item->{y};
    my $box_width = $scaled_width;
    my $box_height = $scaled_height;

    my %handles = (
        'nw' => [$box_x, $box_y],
        'ne' => [$box_x + $box_width, $box_y],
        'se' => [$box_x + $box_width, $box_y + $box_height],
        'sw' => [$box_x, $box_y + $box_height]
    );

    foreach my $handle_type (keys %handles) {
        my $dx = $img_x - $handles{$handle_type}[0];
        my $dy = $img_y - $handles{$handle_type}[1];
        if (sqrt($dx*$dx + $dy*$dy) < $threshold) {
            return $handle_type;
        }
    }

    if ($img_x >= $box_x &&
        $img_x <= $box_x + $box_width &&
        $img_y >= $box_y &&
        $img_y <= $box_y + $box_height) {
        return 'body';
    }
    
    return;
}

sub get_freehand_handle {
    my ($x, $y, $item) = @_;
    my $threshold = get_handle_threshold();

    my $points = $item->{points};
    return unless @$points >= 4;

    if (is_point_near_point($x, $y, $points->[0], $points->[1], $threshold)) {
        return 'start';
    }

    my $last_idx = scalar(@$points) - 2;
    if (is_point_near_point($x, $y, $points->[$last_idx], $points->[$last_idx + 1], $threshold)) {
        return 'end';
    }

    if (is_point_near_freehand($x, $y, $item)) {
        return 'body';
    }
    
    return;
}

sub get_handle_at_position {
    my ($x, $y) = @_;
    return unless $current_item;

    my $handle = get_item_handle($x, $y, $current_item);
    return $handle if $handle;
    
    return;
}

sub get_handle_threshold {

    my $base_threshold = $handle_size * 2;
    
    my $adjusted_threshold = $base_threshold / $scale_factor;
    
    return $adjusted_threshold;
}

# Geometry & Math:

sub pixel_align {
    my ($coord, $l_width) = @_; 
    if (int($l_width) % 2 == 1) {
        return int($coord) + 0.5;
    } else {
        return int($coord + 0.5);
    }
}

sub get_image_offset {
    my ($widget) = @_;

    my $widget_width = $widget->get_allocated_width();
    my $widget_height = $widget->get_allocated_height();

    my $scaled_width = $image_surface->get_width() * $scale_factor;
    my $scaled_height = $image_surface->get_height() * $scale_factor;

    my $x_offset = ($widget_width - $scaled_width) / 2;
    my $y_offset = ($widget_height - $scaled_height) / 2;

    $x_offset = max(0, $x_offset);
    $y_offset = max(0, $y_offset);

    return ($x_offset, $y_offset);
}

sub window_to_image_coords {
    my ($widget, $x, $y) = @_;
    my ($x_offset, $y_offset) = get_image_offset($widget);

    my $image_x = ($x - $x_offset) / $scale_factor;
    my $image_y = ($y - $y_offset) / $scale_factor;

    return ($image_x, $image_y);
}

sub calculate_face_normal {
    my ($vertices) = @_;

    return (0, 0, 1) unless $vertices && @$vertices >= 3;

    my @p1 = @{$vertices->[0]};
    my @p2 = @{$vertices->[1]};
    my @p3 = @{$vertices->[2]};

    for my $point (\@p1, \@p2, \@p3) {
        for my $coord (@$point) {
            $coord = 0 unless defined $coord;
        }
    }

    print "  v1: ($p1[0], $p1[1], $p1[2])\n";
    print "  v2: ($p2[0], $p2[1], $p2[2])\n";
    print "  v3: ($p3[0], $p3[1], $p3[2])\n";

    my @edge1 = ($p2[0] - $p1[0], $p2[1] - $p1[1], $p2[2] - $p1[2]);
    my @edge2 = ($p3[0] - $p1[0], $p3[1] - $p1[1], $p3[2] - $p1[2]);

    print "  edge1: ($edge1[0], $edge1[1], $edge1[2])\n";
    print "  edge2: ($edge2[0], $edge2[1], $edge2[2])\n";

    my @normal = (
        $edge1[1] * $edge2[2] - $edge1[2] * $edge2[1],
        $edge1[2] * $edge2[0] - $edge1[0] * $edge2[2],
        $edge1[0] * $edge2[1] - $edge1[1] * $edge2[0]
    );

    print "  raw normal: ($normal[0], $normal[1], $normal[2])\n";

    my $length = sqrt($normal[0]**2 + $normal[1]**2 + $normal[2]**2);
    if ($length > 0) {
        @normal = map { $_ / $length } @normal;
    } else {
      
        @normal = (0, 0, 1);
    }

    print "  normalized normal: ($normal[0], $normal[1], $normal[2])\n";
    print "  normal length: $length\n\n";

    return @normal;
}

sub calculate_lighting {
    my (@normal) = @_;
    my ($pyramid, $face_name) = @_[3, 4]; 

    my $light_x = -0.7;  
    my $light_y = -0.7;  
    my $light_z = 0.5; 

    my $ambient_light = 0.20;  
    my $diffuse_light = 0.60;  

    my $light_length = sqrt($light_x**2 + $light_y**2 + $light_z**2);
    my @light_dir = ($light_x / $light_length, $light_y / $light_length, $light_z / $light_length);

    my $dot_product = $normal[0] * $light_dir[0] +
                     $normal[1] * $light_dir[1] +
                     $normal[2] * $light_dir[2];

    my $base_lighting = $ambient_light + ($diffuse_light * $dot_product);

    my $lighting_factor;

    if ($face_name) {
        if ($face_name eq 'base') {
   
            $lighting_factor = min(0.35, max(0.15, $base_lighting));
        } elsif ($face_name eq 'front') {
         
            $lighting_factor = min(0.95, max(0.65, $base_lighting + 0.15));
        } elsif ($face_name eq 'left') {
         
            $lighting_factor = min(0.75, max(0.45, $base_lighting + 0.05));
        } elsif ($face_name eq 'right') {
         
            $lighting_factor = min(0.55, max(0.25, $base_lighting - 0.10));
        } elsif ($face_name eq 'back') {
         
            $lighting_factor = min(0.45, max(0.20, $base_lighting - 0.15));
        } else {
         
            $lighting_factor = min(1.0, max(0.3, $base_lighting));
        }
    } else {
      
        if ($dot_product < -0.3) {
           
            $lighting_factor = min(0.4, max(0.15, $base_lighting)); 
        } else {
          
            $lighting_factor = min(1.0, max(0.3, $base_lighting));
        }
    }

    if ($pyramid && $face_name && $face_name ne 'base') {
       
        my $base_center_x = ($pyramid->{base_left} + $pyramid->{base_right}) / 2;
        my $base_center_y = ($pyramid->{base_front} + $pyramid->{base_back}) / 2;

        my $apex_offset_x = $pyramid->{apex_x} - $base_center_x;
        my $apex_offset_y = $pyramid->{apex_y} - $base_center_y;

        if ($face_name eq 'front') {
            $lighting_factor += $apex_offset_y * 0.1; 
        } elsif ($face_name eq 'back') {
            $lighting_factor -= $apex_offset_y * 0.1; 
        } elsif ($face_name eq 'left') {
            $lighting_factor += $apex_offset_x * 0.1;  
        } elsif ($face_name eq 'right') {
            $lighting_factor -= $apex_offset_x * 0.1; 
        }

        $lighting_factor = min(1.0, max(0.15, $lighting_factor));
    }

    print "  face normal: ($normal[0], $normal[1], $normal[2])\n";
    print "  dot product: $dot_product\n";
    print "  base lighting: $base_lighting\n";
    print "  final lighting factor: $lighting_factor\n\n";

    return $lighting_factor;
}

sub calculate_triangle_angle {
    my ($prev_vertex, $current_vertex, $next_vertex) = @_;
    
    my $v1_x = $prev_vertex->[0] - $current_vertex->[0];
    my $v1_y = $prev_vertex->[1] - $current_vertex->[1];
    my $v2_x = $next_vertex->[0] - $current_vertex->[0];
    my $v2_y = $next_vertex->[1] - $current_vertex->[1];
    
    my $len1 = sqrt($v1_x * $v1_x + $v1_y * $v1_y);
    my $len2 = sqrt($v2_x * $v2_x + $v2_y * $v2_y);
    
    return 0 if $len1 == 0 || $len2 == 0;
    
    my $dot = $v1_x * $v2_x + $v1_y * $v2_y;
    
    my $cos_angle = $dot / ($len1 * $len2);
    
    $cos_angle = max(-1, min(1, $cos_angle));
    
    my $angle_rad = acos($cos_angle);
    my $angle_deg = $angle_rad * 180 / pi;
    
    return $angle_deg;
}

sub calculate_interior_angle {
    my ($prev_vertex, $current_vertex, $next_vertex) = @_;

    my $v1_x = $prev_vertex->[0] - $current_vertex->[0];
    my $v1_y = $prev_vertex->[1] - $current_vertex->[1];
    my $v2_x = $next_vertex->[0] - $current_vertex->[0];
    my $v2_y = $next_vertex->[1] - $current_vertex->[1];
    
    my $angle1 = atan2($v1_y, $v1_x);
    my $angle2 = atan2($v2_y, $v2_x);
    
    my $angle_diff = $angle2 - $angle1;
    
    while ($angle_diff > pi) {
        $angle_diff -= 2 * pi;
    }
    while ($angle_diff < -pi) {
        $angle_diff += 2 * pi;
    }
    
    my $angle_degrees = abs($angle_diff) * 180 / pi;

    if ($angle_degrees > 180) {
        $angle_degrees = 360 - $angle_degrees;
    }
    
    return $angle_degrees;
}

sub calculate_polygon_area {
    my ($vertices) = @_;
    my $area = 0;
    my $n = scalar @$vertices;
    
    for my $i (0..$n-1) {
        my $j = ($i + 1) % $n;
        $area += $vertices->[$i][0] * $vertices->[$j][1];
        $area -= $vertices->[$j][0] * $vertices->[$i][1];
    }
    
    return $area / 2;
}

sub determine_pyramid_visibility_and_lighting {
    my ($pyramid) = @_;

    my $apex_x = $pyramid->{apex_x};
    my $apex_y = $pyramid->{apex_y};
    my $base_left = $pyramid->{base_left};
    my $base_right = $pyramid->{base_right};
    my $base_front = $pyramid->{base_front};
    my $base_back = $pyramid->{base_back};

    my @visible_faces = ();
    my %face_lighting = ();

    my $apex_left_of_base = $apex_x < $base_left;
    my $apex_right_of_base = $apex_x > $base_right;
    my $apex_above_base = $apex_y < $base_back;
    my $apex_below_base = $apex_y > $base_front;

    if ($apex_left_of_base && $apex_above_base) {
        @visible_faces = ('right', 'front');
        %face_lighting = (
            'front' => 1.0, 
            'right' => 0.6   
        );
    }
    elsif ($apex_left_of_base && $apex_below_base) {
        @visible_faces = ('right', 'back');
        %face_lighting = (
            'back' => 0.5,   
            'right' => 0.6
        );
    }
    elsif ($apex_right_of_base && $apex_above_base) {
        @visible_faces = ('front', 'left');
        %face_lighting = (
            'left' => 0.75, 
            'front' => 1.0
        );
    }
    elsif ($apex_right_of_base && $apex_below_base) {
        @visible_faces = ('back', 'left');
        %face_lighting = (
            'left' => 0.75,
            'back' => 0.5
        );
    }
    elsif ($apex_left_of_base && !$apex_above_base && !$apex_below_base) {
        @visible_faces = ('back', 'right', 'front');
        %face_lighting = (
            'front' => 1.0,
            'back' => 0.5,
            'right' => 0.6
        );
    }
    elsif ($apex_right_of_base && !$apex_above_base && !$apex_below_base) {
        @visible_faces = ('back', 'left', 'front');
        %face_lighting = (
            'left' => 0.75, 
            'front' => 1.0,
            'back' => 0.5
        );
    }
    elsif ($apex_above_base && !$apex_left_of_base && !$apex_right_of_base) {
        @visible_faces = ('right', 'front', 'left');
        %face_lighting = (
            'front' => 1.0,  
            'left' => 0.75,   
            'right' => 0.6    
        );
    }
    elsif ($apex_below_base && !$apex_left_of_base && !$apex_right_of_base) {
        @visible_faces = ('right', 'back', 'left');
        %face_lighting = (
            'back' => 0.5,
            'left' => 0.75,
            'right' => 0.6
        );
    }
    else {

        @visible_faces = ('back', 'right', 'front', 'left');
        %face_lighting = (
            'front' => 1.0,
            'left' => 0.75, 
            'back' => 0.5,
            'right' => 0.6   
        );
    }

    return (\@visible_faces, \%face_lighting);
}


sub determine_cuboid_visibility_and_lighting {
    my ($cuboid) = @_;

    my @visible_faces = ('front');

    my %face_lighting = (
        'front'  => 1.0,   
        'back'   => 0.25,  
        'left'   => 0.65,  
        'right'  => 0.55, 
        'top'    => 0.85,  
        'bottom' => 0.50  
    );

    if ($cuboid->{back_left} < $cuboid->{front_left}) {
        push @visible_faces, 'left';
    }

    if ($cuboid->{back_right} > $cuboid->{front_right}) {
        push @visible_faces, 'right';
    }

    if ($cuboid->{back_top} < $cuboid->{front_top}) {
        push @visible_faces, 'top';
    }
 
    if ($cuboid->{back_bottom} > $cuboid->{front_bottom}) {
        push @visible_faces, 'bottom';
    }

    return (\@visible_faces, \%face_lighting);
}


sub update_triangle_midpoints {
    my ($triangle) = @_;
    $triangle->{middle_points} = [];

    for my $i (0 .. $#{$triangle->{vertices}}) {
        my $next = ($i + 1) % scalar(@{$triangle->{vertices}});
        push @{$triangle->{middle_points}}, [
            ($triangle->{vertices}[$i][0] + $triangle->{vertices}[$next][0]) / 2,
            ($triangle->{vertices}[$i][1] + $triangle->{vertices}[$next][1]) / 2
        ];
    }
    
    return;
}

sub update_tetragon_midpoints {
    my ($tetragon) = @_;
    $tetragon->{middle_points} = [];

    for my $i (0 .. $#{$tetragon->{vertices}}) {
        my $next = ($i + 1) % scalar(@{$tetragon->{vertices}});
        push @{$tetragon->{middle_points}}, [
            ($tetragon->{vertices}[$i][0] + $tetragon->{vertices}[$next][0]) / 2,
            ($tetragon->{vertices}[$i][1] + $tetragon->{vertices}[$next][1]) / 2
        ];
    }
    
    return;
}

sub update_pentagon_midpoints {
    my ($pentagon) = @_;
    $pentagon->{middle_points} = [];

    for my $i (0 .. $#{$pentagon->{vertices}}) {
        my $next = ($i + 1) % scalar(@{$pentagon->{vertices}});
        push @{$pentagon->{middle_points}}, [
            ($pentagon->{vertices}[$i][0] + $pentagon->{vertices}[$next][0]) / 2,
            ($pentagon->{vertices}[$i][1] + $pentagon->{vertices}[$next][1]) / 2
        ];
    }
    
    return;
}

sub update_pyramid_geometry {
    my ($pyramid) = @_;

    $pyramid->{apex_x} = 0 unless defined $pyramid->{apex_x};
    $pyramid->{apex_y} = 0 unless defined $pyramid->{apex_y};
    $pyramid->{apex_z} = 100 unless defined $pyramid->{apex_z};


    my %faces = (
        'base' => {
            vertices => [
                [$pyramid->{base_left}, $pyramid->{base_front}, 0],
                [$pyramid->{base_right}, $pyramid->{base_front}, 0],
                [$pyramid->{base_right}, $pyramid->{base_back}, 0],
                [$pyramid->{base_left}, $pyramid->{base_back}, 0]
            ],
            z_order => 0,
            face_type => 'base'
        },
        'front' => {
            vertices => [
                [$pyramid->{base_left}, $pyramid->{base_front}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_right}, $pyramid->{base_front}, 0]
            ],
            z_order => 1,
            face_type => 'side'
        },
        'back' => {
            vertices => [
                [$pyramid->{base_right}, $pyramid->{base_back}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_left}, $pyramid->{base_back}, 0]
            ],
            z_order => 3,
            face_type => 'side'
        },
        'left' => {
            vertices => [
                [$pyramid->{base_left}, $pyramid->{base_back}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_left}, $pyramid->{base_front}, 0]
            ],
            z_order => 2,
            face_type => 'side'
        },
        'right' => {
            vertices => [
                [$pyramid->{base_right}, $pyramid->{base_front}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_right}, $pyramid->{base_back}, 0]
            ],
            z_order => 2,
            face_type => 'side'
        }
    );

    foreach my $face_name (keys %faces) {
        my $face = $faces{$face_name};
        my @normal = calculate_face_normal($face->{vertices});
        $face->{normal} = \@normal;
    }

    my @edges = (
        [$pyramid->{base_left}, $pyramid->{base_front}, $pyramid->{base_right}, $pyramid->{base_front}],
        [$pyramid->{base_right}, $pyramid->{base_front}, $pyramid->{base_right}, $pyramid->{base_back}],
        [$pyramid->{base_right}, $pyramid->{base_back}, $pyramid->{base_left}, $pyramid->{base_back}],
        [$pyramid->{base_left}, $pyramid->{base_back}, $pyramid->{base_left}, $pyramid->{base_front}],
        [$pyramid->{base_left}, $pyramid->{base_front}, $pyramid->{apex_x}, $pyramid->{apex_y}],
        [$pyramid->{base_right}, $pyramid->{base_front}, $pyramid->{apex_x}, $pyramid->{apex_y}],
        [$pyramid->{base_left}, $pyramid->{base_back}, $pyramid->{apex_x}, $pyramid->{apex_y}],
        [$pyramid->{base_right}, $pyramid->{base_back}, $pyramid->{apex_x}, $pyramid->{apex_y}]
    );

    $pyramid->{faces} = \%faces;
    $pyramid->{edges} = \@edges;

    $pyramid->{vertices} = [
        [$pyramid->{base_left}, $pyramid->{base_front}],  
        [$pyramid->{base_right}, $pyramid->{base_front}], 
        [$pyramid->{base_right}, $pyramid->{base_back}], 
        [$pyramid->{base_left}, $pyramid->{base_back}],  
        [$pyramid->{apex_x}, $pyramid->{apex_y}]  
    ];

    
    return;
}

sub update_pyramid_faces {
    my ($pyramid) = @_;

    my $base_width = abs($pyramid->{base_right} - $pyramid->{base_left});
    my $base_height = abs($pyramid->{base_front} - $pyramid->{base_back});
    $pyramid->{apex_z} = max($base_width, $base_height) * 0.6;

    print "  base_left: $pyramid->{base_left}, base_right: $pyramid->{base_right}\n";
    print "  base_front: $pyramid->{base_front}, base_back: $pyramid->{base_back}\n";
    print "  apex: ($pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z})\n\n";

    my %faces = (
        'base' => {
            vertices => [
                [$pyramid->{base_left}, $pyramid->{base_front}, 0],
                [$pyramid->{base_right}, $pyramid->{base_front}, 0],
                [$pyramid->{base_right}, $pyramid->{base_back}, 0],
                [$pyramid->{base_left}, $pyramid->{base_back}, 0]
            ],
            z_order => 4,
            face_type => 'base'
        },
        'front' => {
            vertices => [
                [$pyramid->{base_left}, $pyramid->{base_front}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_right}, $pyramid->{base_front}, 0]
            ],
            z_order => 1,
            face_type => 'front'
        },
        'back' => {
            vertices => [
                [$pyramid->{base_right}, $pyramid->{base_back}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_left}, $pyramid->{base_back}, 0]
            ],
            z_order => 3,
            face_type => 'back'
        },
        'left' => {
            vertices => [
                [$pyramid->{base_left}, $pyramid->{base_back}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_left}, $pyramid->{base_front}, 0]
            ],
            z_order => 2,
            face_type => 'side'
        },
        'right' => {
            vertices => [
                [$pyramid->{base_right}, $pyramid->{base_front}, 0],
                [$pyramid->{apex_x}, $pyramid->{apex_y}, $pyramid->{apex_z}],
                [$pyramid->{base_right}, $pyramid->{base_back}, 0]
            ],
            z_order => 2,
            face_type => 'side'
        }
    );

    foreach my $face_name (keys %faces) {
        my $face = $faces{$face_name};
        my @normal = calculate_face_normal($face->{vertices});
        $face->{normal} = \@normal;
    }

    my @edges = (
        [$pyramid->{base_left}, $pyramid->{base_front}, $pyramid->{base_right}, $pyramid->{base_front}],
        [$pyramid->{base_right}, $pyramid->{base_front}, $pyramid->{base_right}, $pyramid->{base_back}],
        [$pyramid->{base_right}, $pyramid->{base_back}, $pyramid->{base_left}, $pyramid->{base_back}],
        [$pyramid->{base_left}, $pyramid->{base_back}, $pyramid->{base_left}, $pyramid->{base_front}],
        [$pyramid->{base_left}, $pyramid->{base_front}, $pyramid->{apex_x}, $pyramid->{apex_y}],
        [$pyramid->{base_right}, $pyramid->{base_front}, $pyramid->{apex_x}, $pyramid->{apex_y}],
        [$pyramid->{base_left}, $pyramid->{base_back}, $pyramid->{apex_x}, $pyramid->{apex_y}],
        [$pyramid->{base_right}, $pyramid->{base_back}, $pyramid->{apex_x}, $pyramid->{apex_y}]
    );

    $pyramid->{faces} = \%faces;
    $pyramid->{edges} = \@edges;

    $pyramid->{vertices} = [
        [$pyramid->{base_left}, $pyramid->{base_front}],  
        [$pyramid->{base_right}, $pyramid->{base_front}], 
        [$pyramid->{base_right}, $pyramid->{base_back}],  
        [$pyramid->{base_left}, $pyramid->{base_back}],   
        [$pyramid->{apex_x}, $pyramid->{apex_y}]       
    ];

    
    return;
}

sub update_pyramid_edges {
    my ($pyramid) = @_;

    my @edges = (

        {
            name => 'base_front',
            start => [$pyramid->{base_left}, $pyramid->{base_front}],
            end => [$pyramid->{base_right}, $pyramid->{base_front}],
            face_type => 'base',
            z_order => 1
        },
        {
            name => 'base_back',
            start => [$pyramid->{base_left}, $pyramid->{base_back}],
            end => [$pyramid->{base_right}, $pyramid->{base_back}],
            face_type => 'base',
            z_order => 3
        },
        {
            name => 'base_left',
            start => [$pyramid->{base_left}, $pyramid->{base_front}],
            end => [$pyramid->{base_left}, $pyramid->{base_back}],
            face_type => 'base',
            z_order => 2
        },
        {
            name => 'base_right',
            start => [$pyramid->{base_right}, $pyramid->{base_front}],
            end => [$pyramid->{base_right}, $pyramid->{base_back}],
            face_type => 'base',
            z_order => 2
        },

        {
            name => 'edge_front_left',
            start => [$pyramid->{base_left}, $pyramid->{base_front}],
            end => [$pyramid->{apex_x}, $pyramid->{apex_y}],
            face_type => 'front_face',
            z_order => 1
        },
        {
            name => 'edge_front_right',
            start => [$pyramid->{base_right}, $pyramid->{base_front}],
            end => [$pyramid->{apex_x}, $pyramid->{apex_y}],
            face_type => 'front_face',
            z_order => 1
        },
        {
            name => 'edge_back_left',
            start => [$pyramid->{base_left}, $pyramid->{base_back}],
            end => [$pyramid->{apex_x}, $pyramid->{apex_y}],
            face_type => 'back_face',
            z_order => 3
        },
        {
            name => 'edge_back_right',
            start => [$pyramid->{base_right}, $pyramid->{base_back}],
            end => [$pyramid->{apex_x}, $pyramid->{apex_y}],
            face_type => 'back_face',
            z_order => 3
        }
    );

    $pyramid->{edges} = \@edges;
    
    return;
}

sub update_cuboid_faces {
    my ($cuboid) = @_;

    print "  front: left=$cuboid->{front_left}, right=$cuboid->{front_right}, top=$cuboid->{front_top}, bottom=$cuboid->{front_bottom}\n";
    print "  back: left=$cuboid->{back_left}, right=$cuboid->{back_right}, top=$cuboid->{back_top}, bottom=$cuboid->{back_bottom}\n";

    my %faces = (
        'front' => {
            vertices => [
                [$cuboid->{front_left}, $cuboid->{front_top}, 0],
                [$cuboid->{front_right}, $cuboid->{front_top}, 0],
                [$cuboid->{front_right}, $cuboid->{front_bottom}, 0],
                [$cuboid->{front_left}, $cuboid->{front_bottom}, 0]
            ],
            z_order => 1,
            face_type => 'front'
        },
        'back' => {
            vertices => [
                [$cuboid->{back_left}, $cuboid->{back_top}, $cuboid->{depth}],
                [$cuboid->{back_right}, $cuboid->{back_top}, $cuboid->{depth}],
                [$cuboid->{back_right}, $cuboid->{back_bottom}, $cuboid->{depth}],
                [$cuboid->{back_left}, $cuboid->{back_bottom}, $cuboid->{depth}]
            ],
            z_order => 6,
            face_type => 'back'
        },
        'left' => {
            vertices => [
                [$cuboid->{front_left}, $cuboid->{front_top}, 0],
                [$cuboid->{back_left}, $cuboid->{back_top}, $cuboid->{depth}],
                [$cuboid->{back_left}, $cuboid->{back_bottom}, $cuboid->{depth}],
                [$cuboid->{front_left}, $cuboid->{front_bottom}, 0]
            ],
            z_order => 3,
            face_type => 'side'
        },
        'right' => {
            vertices => [
                [$cuboid->{front_right}, $cuboid->{front_top}, 0],
                [$cuboid->{back_right}, $cuboid->{back_top}, $cuboid->{depth}],
                [$cuboid->{back_right}, $cuboid->{back_bottom}, $cuboid->{depth}],
                [$cuboid->{front_right}, $cuboid->{front_bottom}, 0]
            ],
            z_order => 4,
            face_type => 'side'
        },
        'top' => {
            vertices => [
                [$cuboid->{front_left}, $cuboid->{front_top}, 0],
                [$cuboid->{front_right}, $cuboid->{front_top}, 0],
                [$cuboid->{back_right}, $cuboid->{back_top}, $cuboid->{depth}],
                [$cuboid->{back_left}, $cuboid->{back_top}, $cuboid->{depth}]
            ],
            z_order => 2,
            face_type => 'top'
        },
        'bottom' => {
            vertices => [
                [$cuboid->{front_left}, $cuboid->{front_bottom}, 0],
                [$cuboid->{front_right}, $cuboid->{front_bottom}, 0],
                [$cuboid->{back_right}, $cuboid->{back_bottom}, $cuboid->{depth}],
                [$cuboid->{back_left}, $cuboid->{back_bottom}, $cuboid->{depth}]
            ],
            z_order => 5,
            face_type => 'bottom'
        }
    );

    foreach my $face_name (keys %faces) {
        my $face = $faces{$face_name};
        my @normal = calculate_face_normal($face->{vertices});
        $face->{normal} = \@normal;
    }

    my @edges = (
    
        [$cuboid->{front_left}, $cuboid->{front_top}, 0, $cuboid->{front_right}, $cuboid->{front_top}, 0],
        [$cuboid->{front_right}, $cuboid->{front_top}, 0, $cuboid->{front_right}, $cuboid->{front_bottom}, 0],
        [$cuboid->{front_right}, $cuboid->{front_bottom}, 0, $cuboid->{front_left}, $cuboid->{front_bottom}, 0],
        [$cuboid->{front_left}, $cuboid->{front_bottom}, 0, $cuboid->{front_left}, $cuboid->{front_top}, 0],

        [$cuboid->{back_left}, $cuboid->{back_top}, $cuboid->{depth}, $cuboid->{back_right}, $cuboid->{back_top}, $cuboid->{depth}],
        [$cuboid->{back_right}, $cuboid->{back_top}, $cuboid->{depth}, $cuboid->{back_right}, $cuboid->{back_bottom}, $cuboid->{depth}],
        [$cuboid->{back_right}, $cuboid->{back_bottom}, $cuboid->{depth}, $cuboid->{back_left}, $cuboid->{back_bottom}, $cuboid->{depth}],
        [$cuboid->{back_left}, $cuboid->{back_bottom}, $cuboid->{depth}, $cuboid->{back_left}, $cuboid->{back_top}, $cuboid->{depth}],

        [$cuboid->{front_left}, $cuboid->{front_top}, 0, $cuboid->{back_left}, $cuboid->{back_top}, $cuboid->{depth}],
        [$cuboid->{front_right}, $cuboid->{front_top}, 0, $cuboid->{back_right}, $cuboid->{back_top}, $cuboid->{depth}],
        [$cuboid->{front_right}, $cuboid->{front_bottom}, 0, $cuboid->{back_right}, $cuboid->{back_bottom}, $cuboid->{depth}],
        [$cuboid->{front_left}, $cuboid->{front_bottom}, 0, $cuboid->{back_left}, $cuboid->{back_bottom}, $cuboid->{depth}]
    );

    $cuboid->{faces} = \%faces;
    $cuboid->{edges} = \@edges;

    
    return;
}

sub get_visible_edges {
    my ($pyramid, $visible_faces, $is_transparent) = @_;

    my $base_left = $pyramid->{base_left};
    my $base_right = $pyramid->{base_right};
    my $base_front = $pyramid->{base_front};
    my $base_back = $pyramid->{base_back};
    my $apex_x = $pyramid->{apex_x};
    my $apex_y = $pyramid->{apex_y};

    my @edges_to_draw = ();
    my %visible_face_hash = map { $_ => 1 } @$visible_faces;

    my %edge_definitions = (
 
        'base_front' => {
            coords => [$base_left, $base_front, $base_right, $base_front],
            faces => ['base', 'front']
        },
        'base_back' => {
            coords => [$base_left, $base_back, $base_right, $base_back],
            faces => ['base', 'back']
        },
        'base_left' => {
            coords => [$base_left, $base_front, $base_left, $base_back],
            faces => ['base', 'left']
        },
        'base_right' => {
            coords => [$base_right, $base_front, $base_right, $base_back],
            faces => ['base', 'right']
        },

        'edge_front_left' => {
            coords => [$base_left, $base_front, $apex_x, $apex_y],
            faces => ['front', 'left']
        },
        'edge_front_right' => {
            coords => [$base_right, $base_front, $apex_x, $apex_y],
            faces => ['front', 'right']
        },
        'edge_back_left' => {
            coords => [$base_left, $base_back, $apex_x, $apex_y],
            faces => ['back', 'left']
        },
        'edge_back_right' => {
            coords => [$base_right, $base_back, $apex_x, $apex_y],
            faces => ['back', 'right']
        }
    );

    foreach my $edge_name (keys %edge_definitions) {
        my $edge_def = $edge_definitions{$edge_name};
        my $edge_faces = $edge_def->{faces};
        my $should_draw_edge = 0;

        if ($is_transparent) {
      
            $should_draw_edge = 1;
        } else {

            my $visible_face_count = 0;
            foreach my $face (@$edge_faces) {
                $visible_face_count++ if $visible_face_hash{$face};
            }

            if ($visible_face_count > 0) {
   
                if ($visible_face_count == 2) {
             
                    $should_draw_edge = 1;
                } elsif ($visible_face_count == 1) {
               
                    $should_draw_edge = 1;
                }
            } else {
           
            }
        }

        if ($should_draw_edge) {
            push @edges_to_draw, $edge_def->{coords};
        }
    }

    return @edges_to_draw;
}

sub get_visible_cuboid_edges {
    my ($cuboid, $visible_faces, $is_transparent) = @_;

    my @edges_to_draw = ();
    my %visible_face_hash = map { $_ => 1 } @$visible_faces;

    my %edge_definitions = (
     
        'front_top' => {
            coords => [$cuboid->{front_left}, $cuboid->{front_top},
                      $cuboid->{front_right}, $cuboid->{front_top}],
            faces => ['front', 'top']
        },
        'front_right' => {
            coords => [$cuboid->{front_right}, $cuboid->{front_top},
                      $cuboid->{front_right}, $cuboid->{front_bottom}],
            faces => ['front', 'right']
        },
        'front_bottom' => {
            coords => [$cuboid->{front_right}, $cuboid->{front_bottom},
                      $cuboid->{front_left}, $cuboid->{front_bottom}],
            faces => ['front', 'bottom']
        },
        'front_left' => {
            coords => [$cuboid->{front_left}, $cuboid->{front_bottom},
                      $cuboid->{front_left}, $cuboid->{front_top}],
            faces => ['front', 'left']
        },

        'back_top' => {
            coords => [$cuboid->{back_left}, $cuboid->{back_top},
                      $cuboid->{back_right}, $cuboid->{back_top}],
            faces => ['back', 'top']
        },
        'back_right' => {
            coords => [$cuboid->{back_right}, $cuboid->{back_top},
                      $cuboid->{back_right}, $cuboid->{back_bottom}],
            faces => ['back', 'right']
        },
        'back_bottom' => {
            coords => [$cuboid->{back_right}, $cuboid->{back_bottom},
                      $cuboid->{back_left}, $cuboid->{back_bottom}],
            faces => ['back', 'bottom']
        },
        'back_left' => {
            coords => [$cuboid->{back_left}, $cuboid->{back_bottom},
                      $cuboid->{back_left}, $cuboid->{back_top}],
            faces => ['back', 'left']
        },

        'connect_top_left' => {
            coords => [$cuboid->{front_left}, $cuboid->{front_top},
                      $cuboid->{back_left}, $cuboid->{back_top}],
            faces => ['left', 'top']
        },
        'connect_top_right' => {
            coords => [$cuboid->{front_right}, $cuboid->{front_top},
                      $cuboid->{back_right}, $cuboid->{back_top}],
            faces => ['right', 'top']
        },
        'connect_bottom_right' => {
            coords => [$cuboid->{front_right}, $cuboid->{front_bottom},
                      $cuboid->{back_right}, $cuboid->{back_bottom}],
            faces => ['right', 'bottom']
        },
        'connect_bottom_left' => {
            coords => [$cuboid->{front_left}, $cuboid->{front_bottom},
                      $cuboid->{back_left}, $cuboid->{back_bottom}],
            faces => ['left', 'bottom']
        }
    );

    foreach my $edge_name (keys %edge_definitions) {
        my $edge_def = $edge_definitions{$edge_name};
        my $edge_faces = $edge_def->{faces};
        my $should_draw_edge = 0;

        if ($is_transparent) {
        
            $should_draw_edge = 1;
        } else {

            my $visible_face_count = 0;
            foreach my $face (@$edge_faces) {
                $visible_face_count++ if $visible_face_hash{$face};
            }

            if ($visible_face_count > 0) {
         
                if ($visible_face_count == 2) {
          
                    $should_draw_edge = 1;
                } elsif ($visible_face_count == 1) {
       
                    $should_draw_edge = 1;
                }
            } else {
            }
        }

        if ($should_draw_edge) {
            push @edges_to_draw, $edge_def->{coords};
        }
    }

    return @edges_to_draw;
}

sub get_freehand_bounds {
    my ($points) = @_;

    my $min_x = $points->[0];
    my $max_x = $points->[0];
    my $min_y = $points->[1];
    my $max_y = $points->[1];

    for (my $i = 0; $i < @$points; $i += 2) {
        $min_x = min($min_x, $points->[$i]);
        $max_x = max($max_x, $points->[$i]);
        $min_y = min($min_y, $points->[$i+1]);
        $max_y = max($max_y, $points->[$i+1]);
    }
    return ($min_x, $max_x, $min_y, $max_y);
}

# Modification Logic:

sub handle_shape_drag {
    my ($item, $handle, $dx, $dy, $curr_x, $curr_y, $event) = @_;
    return unless defined $item && defined $handle && defined $dx && defined $dy;

    my $is_ctrl_pressed = $event && ($event->state & 'control-mask');

    if (defined $item->{type} && $item->{type} eq 'text') {

            if ($handle eq 'body' || $handle eq 'drag') {
                $item->{x} += $dx;
                $item->{y} += $dy;
            }
            else {
                $item->{is_resizing} = 1;

                my $anchor_x = ($handle =~ /w/) ? ($item->{x} + $item->{width})  : $item->{x};
                my $anchor_y = ($handle =~ /n/) ? ($item->{y} + $item->{height}) : $item->{y};

                my $raw_w = abs($curr_x - $anchor_x);
                my $raw_h = abs($curr_y - $anchor_y);

                return if $item->{height} <= 0 || $item->{width} <= 0;

                my $scale = $raw_h / $item->{height};
   
                if ($handle =~ /^(e|w)$/) {
                    $scale = $raw_w / $item->{width};
                }

                my ($family, $current_size) = $item->{font} =~ /^(.*?)\s+(\d+)$/;
                $current_size ||= 20;

                if ($current_size * $scale < 5)   { $scale = 5 / $current_size; }
                if ($current_size * $scale > 500) { $scale = 500 / $current_size; }

                my $new_size = int($current_size * $scale);

                my $clean_scale = $new_size / $current_size;

                $item->{font} = "$family $new_size";
                $item->{font_size} = $new_size;

                my $new_w = $item->{width} * $clean_scale;
                my $new_h = $item->{height} * $clean_scale;
                
                $item->{width} = $new_w;
                $item->{height} = $new_h;

                if ($handle =~ /w/) {
                    $item->{x} = $anchor_x - $new_w;
                } else {
                    $item->{x} = $anchor_x;
                }

                if ($handle =~ /n/) {
                    $item->{y} = $anchor_y - $new_h;
                } else {
                    $item->{y} = $anchor_y;
                }
            }
        }

        elsif (defined $item->{type} && ($item->{type} eq 'svg')) {
        
            my $width = $item->{width} * $item->{scale};
            my $height = $item->{height} * $item->{scale};

            if ($handle eq 'body') {
                $item->{x} += $dx;
                $item->{y} += $dy;
            }
            elsif ($handle =~ /^(nw|ne|se|sw)$/) {
                my $original_width = $width;
                my $original_height = $height;

                if ($handle eq 'nw') {
                    my $new_width = $width - $dx;
                    my $new_height = $height - $dy;
                    if ($is_ctrl_pressed) {
                        my $scale = min($new_width / $width, $new_height / $height);
                        $new_width = $width * $scale;
                        $new_height = $height * $scale;
                    }
                    $item->{scale} = $new_width / $item->{width};
                    $item->{x} += $original_width - $new_width;
                    $item->{y} += $original_height - $new_height;
                }
                elsif ($handle eq 'ne') {
                    my $new_width = $width + $dx;
                    my $new_height = $height - $dy;
                    if ($is_ctrl_pressed) {
                        my $scale = min($new_width / $width, $new_height / $height);
                        $new_width = $width * $scale;
                        $new_height = $height * $scale;
                    }
                    $item->{scale} = $new_width / $item->{width};
                    $item->{y} += $original_height - $new_height;
                }
                elsif ($handle eq 'se') {
                    my $new_width = $width + $dx;
                    my $new_height = $height + $dy;
                    if ($is_ctrl_pressed) {
                        my $scale = min($new_width / $width, $new_height / $height);
                        $new_width = $width * $scale;
                        $new_height = $height * $scale;
                    }
                    $item->{scale} = $new_width / $item->{width};
                }
                elsif ($handle eq 'sw') {
                    my $new_width = $width - $dx;
                    my $new_height = $height + $dy;
                    if ($is_ctrl_pressed) {
                        my $scale = min($new_width / $width, $new_height / $height);
                        $new_width = $width * $scale;
                        $new_height = $height * $scale;
                    }
                    $item->{scale} = $new_width / $item->{width};
                    $item->{x} += $original_width - $new_width;
                }

                $item->{scale} = max(0.1, $item->{scale});
            }
        }

        elsif (defined $item->{type} && $item->{type} eq 'pyramid') {
            handle_pyramid_drag($item, $handle, $dx, $dy, $curr_x, $curr_y, $event);
        }
        
        elsif (defined $item->{type} && $item->{type} eq 'cuboid') {
            handle_cuboid_drag($item, $handle, $dx, $dy, $curr_x, $curr_y, $event);
        }

        elsif (defined $item->{type} && ($item->{type} eq 'freehand' || $item->{type} eq 'highlighter')) {
            if ($handle eq 'body') {
                for (my $i = 0; $i < @{$item->{points}}; $i += 2) {
                    $item->{points}[$i] += $dx;
                    $item->{points}[$i+1] += $dy;
                }
            }
            elsif ($handle eq 'start' || $handle eq 'end') {
                scale_freehand_from_point($item, $handle, $dx, $dy);
            }
        }

        elsif (defined $item->{type} && ($item->{type} eq 'numbered-circle' || $item->{type} eq 'magnifier')) {
            if ($handle eq 'body') {
                $item->{x} += $dx;
                $item->{y} += $dy;
            } else {
                handle_resize_circular($item, $curr_x, $curr_y, $handle);
            }
        }

        elsif (defined $item->{type} && $item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
            my $orig_x1 = $item->{start_x};
            my $orig_y1 = $item->{start_y};
            my $orig_x2 = $item->{end_x};
            my $orig_y2 = $item->{end_y};

            if ($handle eq 'start') {
                $item->{start_x} += $dx;
                $item->{start_y} += $dy;
            }
            elsif ($handle eq 'end') {
                $item->{end_x} += $dx;
                $item->{end_y} += $dy;
            }

            elsif ($handle eq 'middle' || $handle eq 'control') {
            
                $item->{is_curved} = 1;

                if (!defined $item->{control_x}) {
                    $item->{control_x} = ($orig_x1 + $orig_x2) / 2;
                    $item->{control_y} = ($orig_y1 + $orig_y2) / 2;
                }

                $item->{control_x} += $dx;
                $item->{control_y} += $dy;
            }

            elsif ($handle eq 'body') {
                $item->{start_x} += $dx;
                $item->{start_y} += $dy;
                $item->{end_x}   += $dx;
                $item->{end_y}   += $dy;

                if ($item->{is_curved} && defined $item->{control_x}) {
                    $item->{control_x} += $dx;
                    $item->{control_y} += $dy;
                }
            }
        }

        elsif (defined $item->{type}) {
            if ($item->{type} eq 'rectangle' || $item->{type} eq 'ellipse' || $item->{type} eq 'pixelize' || $item->{type} eq 'crop_rect') {
                if (defined $handle) {
                    if ($handle eq 'body') {
                        $item->{x1} += $dx;
                        $item->{y1} += $dy;
                        $item->{x2} += $dx;
                        $item->{y2} += $dy;
                    }
                    else {
      
                        my $center_x = ($item->{x1} + $item->{x2}) / 2;
                        my $center_y = ($item->{y1} + $item->{y2}) / 2;
                        my $original_width = abs($item->{x2} - $item->{x1});
                        my $original_height = abs($item->{y2} - $item->{y1});
                        my $aspect_ratio = $original_width / $original_height;

                        if ($is_ctrl_pressed) {
                     
                            if ($handle =~ /top-left/) {
                                $item->{x1} += $dx;
                                $item->{y1} = $item->{y2} - abs($item->{x2} - $item->{x1}) / $aspect_ratio;
                            }
                            elsif ($handle =~ /top-right/) {
                                $item->{x2} += $dx;
                                $item->{y1} = $item->{y2} - abs($item->{x2} - $item->{x1}) / $aspect_ratio;
                            }
                            elsif ($handle =~ /bottom-left/) {
                                $item->{x1} += $dx;
                                $item->{y2} = $item->{y1} + abs($item->{x2} - $item->{x1}) / $aspect_ratio;
                            }
                            elsif ($handle =~ /bottom-right/) {
                                $item->{x2} += $dx;
                                $item->{y2} = $item->{y1} + abs($item->{x2} - $item->{x1}) / $aspect_ratio;
                            }
                            elsif ($handle eq 'left' || $handle eq 'right') {
                                if ($handle eq 'left') {
                                    $item->{x1} += $dx;
                                } else {
                                    $item->{x2} += $dx;
                                }
                                my $new_width = abs($item->{x2} - $item->{x1});
                                my $new_height = $new_width / $aspect_ratio;
                                my $height_diff = ($new_height - $original_height) / 2;
                                $item->{y1} = $center_y - $new_height/2;
                                $item->{y2} = $center_y + $new_height/2;
                            }
                            elsif ($handle eq 'top' || $handle eq 'bottom') {
                                if ($handle eq 'top') {
                                    $item->{y1} += $dy;
                                } else {
                                    $item->{y2} += $dy;
                                }
                                my $new_height = abs($item->{y2} - $item->{y1});
                                my $new_width = $new_height * $aspect_ratio;
                                my $width_diff = ($new_width - $original_width) / 2;
                                $item->{x1} = $center_x - $new_width/2;
                                $item->{x2} = $center_x + $new_width/2;
                            }
                        }
                        else {
                      
                            if ($handle =~ /top-left/) {
                                $item->{x1} += $dx;
                                $item->{y1} += $dy;
                            }
                            elsif ($handle =~ /top-right/) {
                                $item->{x2} += $dx;
                                $item->{y1} += $dy;
                            }
                            elsif ($handle =~ /bottom-left/) {
                                $item->{x1} += $dx;
                                $item->{y2} += $dy;
                            }
                            elsif ($handle =~ /bottom-right/) {
                                $item->{x2} += $dx;
                                $item->{y2} += $dy;
                            }
                            elsif ($handle eq 'top') {
                                $item->{y1} += $dy;
                            }
                            elsif ($handle eq 'bottom') {
                                $item->{y2} += $dy;
                            }
                            elsif ($handle eq 'left') {
                                $item->{x1} += $dx;
                            }
                            elsif ($handle eq 'right') {
                                $item->{x2} += $dx;
                            }
                        }
                    }
                }
            }
        }
        if (defined $item->{type} && $item->{type} =~ /^(pentagon|triangle|tetragon)$/) {
        return unless defined $handle && ref($handle) eq 'ARRAY' && @$handle >= 2;

        my $handle_type = $handle->[0];
        my $handle_index = $handle->[1];

        my $center_x = 0;
        my $center_y = 0;
        my $vertex_count = scalar(@{$item->{vertices}});
        foreach my $vertex (@{$item->{vertices}}) {
            $center_x += $vertex->[0];
            $center_y += $vertex->[1];
        }
        $center_x /= $vertex_count;
        $center_y /= $vertex_count;

        if (defined $handle_type && $handle_type eq 'vertex') {
            if ($is_ctrl_pressed) {

                my @orig_distances;
                foreach my $vertex (@{$item->{vertices}}) {
                    my $dx = $vertex->[0] - $center_x;
                    my $dy = $vertex->[1] - $center_y;
                    push @orig_distances, sqrt($dx * $dx + $dy * $dy);
                }

                my $new_x = $item->{vertices}[$handle_index][0] + $dx;
                my $new_y = $item->{vertices}[$handle_index][1] + $dy;

                my $orig_dist = $orig_distances[$handle_index];
                my $new_dist = sqrt(($new_x - $center_x)**2 + ($new_y - $center_y)**2);
                my $scale = $new_dist / $orig_dist;

                foreach my $i (0..$#{$item->{vertices}}) {
                    my $dx = $item->{vertices}[$i][0] - $center_x;
                    my $dy = $item->{vertices}[$i][1] - $center_y;
                    $item->{vertices}[$i][0] = $center_x + $dx * $scale;
                    $item->{vertices}[$i][1] = $center_y + $dy * $scale;
                }
            } else {
                $item->{vertices}[$handle_index][0] += $dx;
                $item->{vertices}[$handle_index][1] += $dy;
            }
        }
        elsif (defined $handle_type && $handle_type eq 'middle') {
            my $next_index = ($handle_index + 1) % scalar(@{$item->{vertices}});
            if ($is_ctrl_pressed) {

                my $mid_x = ($item->{vertices}[$handle_index][0] + $item->{vertices}[$next_index][0]) / 2;
                my $mid_y = ($item->{vertices}[$handle_index][1] + $item->{vertices}[$next_index][1]) / 2;

                my $orig_dist = sqrt(($mid_x - $center_x)**2 + ($mid_y - $center_y)**2);
                my $new_dist = sqrt(($mid_x + $dx - $center_x)**2 + ($mid_y + $dy - $center_y)**2);
                my $scale = $new_dist / $orig_dist;

                foreach my $i (0..$#{$item->{vertices}}) {
                    my $dx = $item->{vertices}[$i][0] - $center_x;
                    my $dy = $item->{vertices}[$i][1] - $center_y;
                    $item->{vertices}[$i][0] = $center_x + $dx * $scale;
                    $item->{vertices}[$i][1] = $center_y + $dy * $scale;
                }
            } else {
                $item->{vertices}[$handle_index][0] += $dx;
                $item->{vertices}[$handle_index][1] += $dy;
                $item->{vertices}[$next_index][0] += $dx;
                $item->{vertices}[$next_index][1] += $dy;
            }
        }
        elsif (defined $handle_type && $handle_type eq 'body') {
            foreach my $vertex (@{$item->{vertices}}) {
                $vertex->[0] += $dx;
                $vertex->[1] += $dy;
            }
        }

        if ($item->{type} eq 'pentagon') {
            update_pentagon_midpoints($item);
        } elsif ($item->{type} eq 'triangle') {
            update_triangle_midpoints($item);
        } elsif ($item->{type} eq 'tetragon') {
            update_tetragon_midpoints($item);
        }
    }
    
    return;
}

sub handle_text_resize {
    my ($text_item, $handle, $dx, $dy) = @_;
    return unless $text_item && $handle;

    if ($handle eq 'body') {
        $text_item->{x} += $dx;
        $text_item->{y} += $dy;
        return;
    }

    my $min_width = 20;
    my $min_height = 20;
    my $orig_width = $text_item->{width};
    my $orig_height = $text_item->{height};
    my $orig_x = $text_item->{x};
    my $orig_y = $text_item->{y};

    my ($new_x, $new_y, $new_width, $new_height) = ($orig_x, $orig_y, $orig_width, $orig_height);

    if ($handle =~ /e/) {
        $new_width = max($min_width, $orig_width + $dx);
    } elsif ($handle =~ /w/) {
        my $proposed_width = max($min_width, $orig_width - $dx);
        $new_x = $orig_x + ($orig_width - $proposed_width);
        $new_width = $proposed_width;
    }

    if ($handle =~ /s/) {
        $new_height = max($min_height, $orig_height + $dy);
    } elsif ($handle =~ /n/) {
        my $proposed_height = max($min_height, $orig_height - $dy);
        $new_y = $orig_y + ($orig_height - $proposed_height);
        $new_height = $proposed_height;
    }

    my $scale = max($new_width / $orig_width, $new_height / $orig_height);
    my ($family, $size) = $text_item->{font} =~ /^(.*?)\s+(\d+)$/;
    $size ||= 20;
    my $new_size = max(8, min(400, int($size * $scale)));

    $text_item->{x} = $new_x;
    $text_item->{y} = $new_y;
    $text_item->{width} = $new_width;
    $text_item->{height} = $new_height;
    $text_item->{font} = "$family $new_size";
    $text_item->{font_size} = $new_size;

    if ($font_btn_w) {
        $font_btn_w->set_font_name($text_item->{font});
    }

    $text_item->{is_resizing} = 1;
    
    return;
}

sub handle_resize_circular {
    my ($item, $curr_x, $curr_y, $handle) = @_;
    return unless $item && ($item->{type} eq 'numbered-circle' || $item->{type} eq 'magnifier');

    my ($dx, $dy);
    my $new_radius;

    $dx = $curr_x - $item->{x};
    $dy = $curr_y - $item->{y};

    if ($handle =~ /^[nsew]$/) {
        if ($handle eq 'n' || $handle eq 's') {
            $new_radius = abs($dy);
        } else {
            $new_radius = abs($dx);
        }
    } elsif ($handle =~ /^(ne|se|sw|nw)$/) {
        $new_radius = max(abs($dx), abs($dy));
    }

    if ($item->{type} eq 'numbered-circle') {
        my $min_radius = $item->{font_size} * 0.75;
        $item->{radius} = max($new_radius, $min_radius);

        $circle_radius = $item->{radius};

        $font_size = int($circle_radius * 0.6); 
        $item->{font_size} = $font_size; 

    } elsif ($item->{type} eq 'magnifier') {
        my $min_radius = 30;
        my $max_radius = 1000;
        $item->{radius} = max($min_radius, min($max_radius, $new_radius));
    }
    
    return;
}

sub handle_pyramid_drag {
    my ($item, $handle, $dx, $dy, $curr_x, $curr_y, $event) = @_;
    return unless $item && $item->{type} eq 'pyramid';

    my $actual_handle = $handle;
    if (ref($handle) eq 'ARRAY') {
        $actual_handle = $handle->[0]; 
    }

    if ($actual_handle eq 'apex') {
        $item->{apex_x} += $dx;
        $item->{apex_y} += $dy;
    }
    elsif ($actual_handle eq 'base_left_front') {
        $item->{base_left} += $dx;
        $item->{base_front} += $dy;
    }
    elsif ($actual_handle eq 'base_right_front') {
        $item->{base_right} += $dx;
        $item->{base_front} += $dy;
    }
    elsif ($actual_handle eq 'base_left_back') {
        $item->{base_left} += $dx;
        $item->{base_back} += $dy;
    }
    elsif ($actual_handle eq 'base_right_back') {
        $item->{base_right} += $dx;
        $item->{base_back} += $dy;
    }
    elsif ($actual_handle eq 'body') {

        $item->{base_left} += $dx;
        $item->{base_right} += $dx;
        $item->{base_front} += $dy;
        $item->{base_back} += $dy;
        $item->{apex_x} += $dx;
        $item->{apex_y} += $dy;
        }
        update_pyramid_faces($item);
    
    return;
}

sub handle_cuboid_drag {
    my ($item, $handle, $dx, $dy, $curr_x, $curr_y, $event) = @_;
    return unless $item && $item->{type} eq 'cuboid';

    if ($handle eq 'front_top_left') {
        $item->{front_left} += $dx;
        $item->{front_top} += $dy;
    }
    elsif ($handle eq 'front_top_right') {
        $item->{front_right} += $dx;
        $item->{front_top} += $dy;
    }
    elsif ($handle eq 'front_bottom_left') {
        $item->{front_left} += $dx;
        $item->{front_bottom} += $dy;
    }
    elsif ($handle eq 'front_bottom_right') {
        $item->{front_right} += $dx;
        $item->{front_bottom} += $dy;
    }

    elsif ($handle eq 'back_top_left') {
        $item->{back_left} += $dx;
        $item->{back_top} += $dy;
    }
    elsif ($handle eq 'back_top_right') {
        $item->{back_right} += $dx;
        $item->{back_top} += $dy;
    }
    elsif ($handle eq 'back_bottom_left') {
        $item->{back_left} += $dx;
        $item->{back_bottom} += $dy;
    }
    elsif ($handle eq 'back_bottom_right') {
        $item->{back_right} += $dx;
        $item->{back_bottom} += $dy;
    }

    elsif ($handle eq 'body') {
        $item->{front_left} += $dx;
        $item->{front_right} += $dx;
        $item->{front_top} += $dy;
        $item->{front_bottom} += $dy;
        $item->{back_left} += $dx;
        $item->{back_right} += $dx;
        $item->{back_top} += $dy;
        $item->{back_bottom} += $dy;
    }

    update_cuboid_faces($item);
    
    return;
}

sub scale_freehand_from_point {
    my ($item, $handle, $dx, $dy) = @_;
    my $points = $item->{points};
    return unless @$points >= 4;

    my ($anchor_x, $anchor_y, $orig_moving_x, $orig_moving_y);
    if ($handle eq 'start') {
        $anchor_x = $points->[-2];
        $anchor_y = $points->[-1];
        $orig_moving_x = $points->[0];
        $orig_moving_y = $points->[1];
    } else {
        $anchor_x = $points->[0];
        $anchor_y = $points->[1];
        $orig_moving_x = $points->[-2];
        $orig_moving_y = $points->[-1];
    }

    my $dir_x = $orig_moving_x - $anchor_x;
    my $dir_y = $orig_moving_y - $anchor_y;
    my $dir_len = sqrt($dir_x * $dir_x + $dir_y * $dir_y);
    return if $dir_len == 0;

    $dir_x /= $dir_len;
    $dir_y /= $dir_len;

    my $proj = $dx * $dir_x + $dy * $dir_y;

    my $moving_x = $orig_moving_x + $proj * $dir_x;
    my $moving_y = $orig_moving_y + $proj * $dir_y;

    my $new_dist = sqrt(($moving_x - $anchor_x)**2 + ($moving_y - $anchor_y)**2);
    my $scale = $new_dist / $dir_len;
    return if $scale == 0;

    if ($handle eq 'start') {
        $points->[0] = $moving_x;
        $points->[1] = $moving_y;

        for (my $i = 2; $i < @$points - 2; $i += 2) {
            my $dx = $points->[$i] - $anchor_x;
            my $dy = $points->[$i + 1] - $anchor_y;
            $points->[$i] = $anchor_x + $dx * $scale;
            $points->[$i + 1] = $anchor_y + $dy * $scale;
        }
    } else {
        $points->[-2] = $moving_x;
        $points->[-1] = $moving_y;

        for (my $i = 2; $i < @$points - 2; $i += 2) {
            my $dx = $points->[$i] - $anchor_x;
            my $dy = $points->[$i + 1] - $anchor_y;
            $points->[$i] = $anchor_x + $dx * $scale;
            $points->[$i + 1] = $anchor_y + $dy * $scale;
        }
    }
    
    return;
}

sub resize_primitive {
    my ($item, $factor) = @_;

    if ($item->{type} eq 'freehand' || $item->{type} eq 'highlighter') {
        my ($min_x, $max_x, $min_y, $max_y) = get_freehand_bounds($item->{points});
        my $center_x = ($min_x + $max_x) / 2;
        my $center_y = ($min_y + $max_y) / 2;

        for (my $i = 0; $i < @{$item->{points}}; $i += 2) {
            $item->{points}[$i] = $center_x + ($item->{points}[$i] - $center_x) * $factor;
            $item->{points}[$i+1] = $center_y + ($item->{points}[$i+1] - $center_y) * $factor;
        }
    }
    elsif ($item->{type} =~ /^(rectangle|ellipse)$/) {
        my $center_x = ($item->{x1} + $item->{x2}) / 2;
        my $center_y = ($item->{y1} + $item->{y2}) / 2;

        my $half_width = ($item->{x2} - $item->{x1}) * $factor / 2;
        my $half_height = ($item->{y2} - $item->{y1}) * $factor / 2;

        $item->{x1} = $center_x - $half_width;
        $item->{x2} = $center_x + $half_width;
        $item->{y1} = $center_y - $half_height;
        $item->{y2} = $center_y + $half_height;
    }
    elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/) {
        my $center_x = 0;
        my $center_y = 0;
        my $vertex_count = scalar @{$item->{vertices}};

        foreach my $vertex (@{$item->{vertices}}) {
            $center_x += $vertex->[0];
            $center_y += $vertex->[1];
        }
        $center_x /= $vertex_count;
        $center_y /= $vertex_count;

        foreach my $vertex (@{$item->{vertices}}) {
            $vertex->[0] = $center_x + ($vertex->[0] - $center_x) * $factor;
            $vertex->[1] = $center_y + ($vertex->[1] - $center_y) * $factor;
        }

        if ($item->{type} eq 'triangle') {
            update_triangle_midpoints($item);
        }
        elsif ($item->{type} eq 'tetragon') {
            update_tetragon_midpoints($item);
        }
        elsif ($item->{type} eq 'pentagon') {
            update_pentagon_midpoints($item);
        }
    }
    elsif ($item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
        my $center_x = ($item->{start_x} + $item->{end_x}) / 2;
        my $center_y = ($item->{start_y} + $item->{end_y}) / 2;

        $item->{start_x} = $center_x + ($item->{start_x} - $center_x) * $factor;
        $item->{start_y} = $center_y + ($item->{start_y} - $center_y) * $factor;
        $item->{end_x} = $center_x + ($item->{end_x} - $center_x) * $factor;
        $item->{end_y} = $center_y + ($item->{end_y} - $center_y) * $factor;

        if ($item->{is_curved} && defined $item->{control_x}) {
            $item->{control_x} = $center_x + ($item->{control_x} - $center_x) * $factor;
            $item->{control_y} = $center_y + ($item->{control_y} - $center_y) * $factor;
        }
    }
    elsif ($item->{type} eq 'numbered-circle') {
        $item->{radius} *= $factor;
    }
    elsif ($item->{type} eq 'text') {
        my $center_x = $item->{x} + ($item->{width} / 2);
        my $center_y = $item->{y} + ($item->{height} / 2);

        my $new_width = $item->{width} * $factor;
        my $new_height = $item->{height} * $factor;

        $item->{x} = $center_x - ($new_width / 2);
        $item->{y} = $center_y - ($new_height / 2);

        my ($family, $size) = $item->{font} =~ /^(.*?)\s+(\d+)$/;
        $size ||= 25;
        my $new_size = max(8, min(400, int($size * $factor)));

        $item->{font} = "$family $new_size";
        $item->{font_size} = $new_size;
        $item->{width} = $new_width;
        $item->{height} = $new_height;

        if ($font_btn_w) {
            $font_btn_w->set_font_name($item->{font});
        }
    }

    elsif ($item->{type} eq 'pyramid') {

        my $cx = ($item->{base_left} + $item->{base_right}) / 2;
        my $cy = ($item->{base_front} + $item->{base_back}) / 2;

        $item->{base_left} = $cx + ($item->{base_left} - $cx) * $factor;
        $item->{base_right} = $cx + ($item->{base_right} - $cx) * $factor;
        $item->{base_front} = $cy + ($item->{base_front} - $cy) * $factor;
        $item->{base_back} = $cy + ($item->{base_back} - $cy) * $factor;

        $item->{apex_x} = $cx + ($item->{apex_x} - $cx) * $factor;
        $item->{apex_y} = $cy + ($item->{apex_y} - $cy) * $factor;

        update_pyramid_faces($item);
    }

    elsif ($item->{type} eq 'cuboid') {
    
        my $cx = ($item->{front_left} + $item->{front_right}) / 2;
        my $cy = ($item->{front_top} + $item->{front_bottom}) / 2;

        $item->{front_left} = $cx + ($item->{front_left} - $cx) * $factor;
        $item->{front_right} = $cx + ($item->{front_right} - $cx) * $factor;
        $item->{front_top} = $cy + ($item->{front_top} - $cy) * $factor;
        $item->{front_bottom} = $cy + ($item->{front_bottom} - $cy) * $factor;

        $item->{back_left} = $cx + ($item->{back_left} - $cx) * $factor;
        $item->{back_right} = $cx + ($item->{back_right} - $cx) * $factor;
        $item->{back_top} = $cy + ($item->{back_top} - $cy) * $factor;
        $item->{back_bottom} = $cy + ($item->{back_bottom} - $cy) * $factor;

        $item->{depth} *= $factor;

        update_cuboid_faces($item);
    }
    
    return;
}

sub resize_magnifier {
    my ($magnifier, $handle, $dx, $dy) = @_;

    my $old_radius = $magnifier->{radius};
    my $center_x = $magnifier->{x};
    my $center_y = $magnifier->{y};

    if ($handle =~ /^[nsew]$/) {
        if ($handle eq 'n' || $handle eq 's') {
            $magnifier->{radius} = abs($dy);
        } else {
            $magnifier->{radius} = abs($dx);
        }
    } elsif ($handle =~ /^(ne|se|sw|nw)$/) {
        $magnifier->{radius} = sqrt($dx*$dx + $dy*$dy);
    }

    $magnifier->{radius} = max(30, min(1000, $magnifier->{radius}));
    
    return;
}

sub shift_all_items {
    my ($dx, $dy) = @_;
    
    foreach my $type (keys %items) {
        next unless exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY';
        
        foreach my $item (@{$items{$type}}) {
            if ($item->{type} eq 'freehand' || $item->{type} eq 'highlighter') {
                for (my $i = 0; $i < @{$item->{points}}; $i += 2) {
                    $item->{points}[$i] += $dx;
                    $item->{points}[$i+1] += $dy;
                }
            }
            elsif ($item->{type} =~ /^(rectangle|ellipse|pixelize|crop_rect)$/) {
                $item->{x1} += $dx; $item->{y1} += $dy;
                $item->{x2} += $dx; $item->{y2} += $dy;
            }
            elsif ($item->{type} =~ /^(line|single-arrow|double-arrow)$/) {
                $item->{start_x} += $dx; $item->{start_y} += $dy;
                $item->{end_x} += $dx;   $item->{end_y} += $dy;
                if (defined $item->{control_x}) {
                    $item->{control_x} += $dx; $item->{control_y} += $dy;
                }
            }
            elsif ($item->{type} =~ /^(triangle|tetragon|pentagon)$/) {
                foreach my $v (@{$item->{vertices}}) {
                    $v->[0] += $dx; $v->[1] += $dy;
                }
                if ($item->{type} eq 'triangle') { update_triangle_midpoints($item); }
                elsif ($item->{type} eq 'tetragon') { update_tetragon_midpoints($item); }
                elsif ($item->{type} eq 'pentagon') { update_pentagon_midpoints($item); }
            }
            elsif ($item->{type} eq 'pyramid') {
                $item->{base_left} += $dx; $item->{base_right} += $dx;
                $item->{base_front} += $dy; $item->{base_back} += $dy;
                $item->{apex_x} += $dx; $item->{apex_y} += $dy;
                update_pyramid_geometry($item); 
            }
            elsif ($item->{type} eq 'cuboid') {
                 handle_cuboid_drag($item, 'body', $dx, $dy, 0, 0, undef); 
            }
            elsif ($item->{type} =~ /^(text|numbered-circle|magnifier|svg)$/) {
                $item->{x} += $dx;
                $item->{y} += $dy;
            }
        }
    }
    
    return;
}

sub store_crop_state_for_undo {
    my ($crop_rect) = @_;

    if (@undo_stack && $undo_stack[-1]{action} eq 'crop') {

        my $old_crop = pop @undo_stack;

        if ($old_crop->{temp_image_file} && -f $old_crop->{temp_image_file}) {
            unlink $old_crop->{temp_image_file};
        }
    }

    my $temp_file = "/tmp/linia_crop_undo_" . time() . "_" . $$ . ".png";
    $image_surface->write_to_png($temp_file);

    my $items_clone = clone_current_state();

    if (exists $items_clone->{rectangles}) {
        $items_clone->{rectangles} = [grep { $_->{type} ne 'crop_rect' } @{$items_clone->{rectangles}}];
    }
    
    my $state = {
        action => 'crop',
        temp_image_file => $temp_file,
        previous_width => $original_width,
        previous_height => $original_height,
        previous_items => $items_clone,
        crop_rect => clone_item($crop_rect),
        timestamp => time()
    };
    
    push @undo_stack, $state;

    for my $redo_action (@redo_stack) {
        if ($redo_action->{action} eq 'crop' && $redo_action->{temp_image_file} && -f $redo_action->{temp_image_file}) {
            unlink $redo_action->{temp_image_file};
        }
    }
    
    @redo_stack = ();
    update_undo_redo_ui();
    
    return;
}

sub apply_crop {
    return unless $current_item && $current_item->{type} eq 'crop_rect';

    store_crop_state_for_undo($current_item);

    my $crop_x = min($current_item->{x1}, $current_item->{x2});
    my $crop_y = min($current_item->{y1}, $current_item->{y2});
    my $crop_w = abs($current_item->{x2} - $current_item->{x1});
    my $crop_h = abs($current_item->{y2} - $current_item->{y1});
    
    return if $crop_w < 10 || $crop_h < 10;

    my $new_surface = Cairo::ImageSurface->create('argb32', $crop_w, $crop_h);
    my $cr = Cairo::Context->create($new_surface);

    $cr->set_source_surface($image_surface, -$crop_x, -$crop_y);
    $cr->paint();

    $image_surface = $new_surface;
    $original_width = $crop_w;
    $original_height = $crop_h;
    $project_is_modified = 1;

    if (defined $preview_surface) {
        $preview_surface->finish(); 
        undef $preview_surface;
        $preview_ratio = 1.0;
    }

    shift_all_items(-$crop_x, -$crop_y);
    
    if (exists $items{rectangles}) {
        @{$items{rectangles}} = grep { $_ != $current_item } @{$items{rectangles}};
    }
    $current_item = undef;

    $scale_factor = 1.0; 
    zoom_fit_best();     
    $current_tool = 'select'; 
    update_tool_widgets('select'); 
    
    
    $drawing_area->queue_draw();
    return;
}
    

# =============================================================================
# SECTION 8. HELPERS (Dialogs & Utilities)
# =============================================================================


# UI Construction:

sub create_scrolled_window {
    my $scrolled_window = Gtk3::ScrolledWindow->new();
    $scrolled_window->set_policy('automatic', 'automatic');

    my $viewport = Gtk3::Viewport->new(undef, undef);
    my $padding_box = Gtk3::Box->new('vertical', 0);

    my $hbox = Gtk3::Box->new('horizontal', 0);
    my $vbox = Gtk3::Box->new('vertical', 0);

    $vbox->pack_start($drawing_area, TRUE, FALSE, 0);
    $hbox->pack_start($vbox, TRUE, FALSE, 0);
    $padding_box->pack_start($hbox, TRUE, FALSE, 0);

    $viewport->add($padding_box);
    $scrolled_window->add($viewport);

    return $scrolled_window;
}

sub create_tool_button {
    my ($item, $size) = @_;
    
    $size = $drawing_toolbar_icon_size unless defined $size;
    
    my $image = load_icon($item->{name}, $size);
    
    if ($image) {
        $image->set_size_request($size, $size);
    }
    
    my $tool_item;

    if ($toggle_tools{$item->{name}}) {
        $tool_item = Gtk3::ToggleToolButton->new();
        $tool_item->set_icon_widget($image);
        $tool_item->set_label($item->{label});
        $tool_item->set_tooltip_text($item->{tooltip}) if $item->{tooltip};
    } else {
        $tool_item = Gtk3::ToolButton->new($image, $item->{label});
        $tool_item->set_tooltip_text($item->{tooltip}) if $item->{tooltip};
    }

    return $tool_item;
}

sub create_open_recent_button {

    my ($size) = @_;
    $size = $main_toolbar_icon_size unless defined $size;

    my $menu_button = Gtk3::MenuButton->new();
    $menu_button->set_tooltip_text("Open Recent Images");
    $menu_button->set_direction('down');
    $menu_button->set_relief('none');

    $menu_button->set_valign('center');

    my $vbox = Gtk3::Box->new('vertical', 2);
    $vbox->set_valign('center'); 

    my $image = load_icon('image-open-recent', $size);
    if ($image) {
        $image->set_size_request($size, $size);
    }
    
    my $label = Gtk3::Label->new('Open Recent');
    $label->set_xalign(0.5);
    $label->set_margin_top(2);

    my $toolbar_style = $main_toolbar->get_style();
    if ($toolbar_style eq 'icons') {
        $label->set_no_show_all(TRUE);
        $label->hide();
    }

    $vbox->pack_start($image, FALSE, FALSE, 0);
    $vbox->pack_start($label, FALSE, FALSE, 0);

    $menu_button->add($vbox);

    my $popup_menu = Gtk3::Menu->new();

    if (@recent_files) {
        foreach my $file (@recent_files) {
            next unless -f $file;
            my $thumb_path = "$ENV{HOME}/.config/linia/thumbnails/" . Digest::MD5::md5_hex($file) . ".png";
            my $item = create_menu_item_with_thumbnail($file, $thumb_path);
            $item->signal_connect('activate' => sub {
                load_image_file($file, $window);
                zoom_fit_best();
            });
            $popup_menu->append($item);
            $item->show_all();
        }
    } else {
        my $item = Gtk3::MenuItem->new_with_label("No Recent Files");
        $item->set_sensitive(FALSE);
        $popup_menu->append($item);
        $item->show_all();
    }

    $popup_menu->show_all();
    $menu_button->set_popup($popup_menu);

    my $tool_item = Gtk3::ToolItem->new();
    $tool_item->add($menu_button);
    $tool_item->{recent_menu} = $popup_menu;

    $tool_item->set_valign('center');
    
    $tool_item->show_all();

    return $tool_item;
}

sub create_menu_item_with_thumbnail {
    my ($filename, $thumb_path) = @_;

    my $box = Gtk3::Box->new('horizontal', 0);
    $box->set_halign('center');

    my $image_loaded = 0;

    if ($thumb_path && -f $thumb_path) {

        my $scale_factor = defined $window ? $window->get_scale_factor() : 1;
        my $logical_w = 200; 
        my $physical_w = $logical_w * $scale_factor;

        my $surface = eval {

            my $src_pixbuf = Gtk3::Gdk::Pixbuf->new_from_file($thumb_path);
            
            return unless (defined $src_pixbuf && ref($src_pixbuf));
            
            my $w = $src_pixbuf->get_width();
            my $h = $src_pixbuf->get_height();
            
            return unless ($w > 0 && $h > 0);

            my $aspect = $h / $w;
            my $physical_h = int($physical_w * $aspect);

            my $scaled_pixbuf = $src_pixbuf->scale_simple($physical_w, $physical_h, 'hyper');

            return Gtk3::Gdk::cairo_surface_create_from_pixbuf($scaled_pixbuf, $scale_factor, undef);
        };

        if ($surface) {
            my $image = Gtk3::Image->new_from_surface($surface);
            $box->pack_start($image, FALSE, FALSE, 0);
            $image_loaded = 1;
        }
    }

    unless ($image_loaded) {
        my $label = Gtk3::Label->new(basename($filename));
        $box->pack_start($label, TRUE, TRUE, 5);
    }

    my $menu_item = Gtk3::MenuItem->new();
    $menu_item->add($box);
    
    $menu_item->set_tooltip_text($filename);

    return $menu_item;
}

sub create_recent_files_menu {
    my $menu = Gtk3::Menu->new();

    if (@recent_files) {
        for my $file (@recent_files) {
            next unless -f $file; 

            my $thumb_path = "$ENV{HOME}/.config/linia/thumbnails/" .
                           Digest::MD5::md5_hex($file) . ".png";

            my $item = create_menu_item_with_thumbnail($file, $thumb_path);

            $item->signal_connect('activate' => sub {
                load_image_file($file, $window);
                zoom_fit_best();
            });

            $menu->append($item);
        }
    } else {
        my $item = Gtk3::MenuItem->new_with_label("No Recent Files");
        $item->set_sensitive(FALSE);
        $menu->append($item);
    }

    $menu->show_all();
    return $menu;
}

sub create_fill_transparency_slider {
    my $transparency_box = Gtk3::Box->new('horizontal', 2);

    $fill_transparency_adjustment = Gtk3::Adjustment->new(0.25, 0.0, 1.0, 0.05, 0.05, 0.0);
    $fill_transparency_scale = Gtk3::Scale->new_with_range('horizontal', 0.0, 1.0, 0.01);
    $fill_transparency_scale->set_adjustment($fill_transparency_adjustment);
    $fill_transparency_scale->set_size_request(150, -1);
    $fill_transparency_scale->set_value_pos('right');
    $fill_transparency_scale->set_tooltip_text("Adjust fill opacity level");

    $fill_css_provider = Gtk3::CssProvider->new();
    my $initial_css = sprintf("scale trough highlight { background: %s; }" , $fill_color->to_string());
    $fill_css_provider->load_from_data($initial_css);

    $fill_color_button->signal_connect('color-set' => sub {
        my $rgba = $fill_color_button->get_rgba();
        my $current_alpha = $fill_transparency_scale->get_value();
        my $new_fill_color = Gtk3::Gdk::RGBA->new($rgba->red, $rgba->green, $rgba->blue, $current_alpha);
        $fill_color = $new_fill_color;

        my $css = sprintf("scale trough highlight { background: %s; }", $new_fill_color->to_string());
        $fill_css_provider->load_from_data($css);
    });

    my $style_context = $fill_transparency_scale->get_style_context();
    $style_context->add_provider($fill_css_provider, Gtk3::STYLE_PROVIDER_PRIORITY_APPLICATION);
    $transparency_box->pack_start($fill_transparency_scale, FALSE, FALSE, 0);
    
    my $transparency_tool_item = Gtk3::ToolItem->new();
    $transparency_tool_item->add($transparency_box);

    $fill_transparency_scale->signal_connect('value-changed' => sub {
        $fill_transparency_level = $fill_transparency_scale->get_value();
        my $new_fill_color = Gtk3::Gdk::RGBA->new($fill_color->red, $fill_color->green, $fill_color->blue, $fill_transparency_level);
        $fill_color = $new_fill_color;
        $fill_color_button->set_rgba($new_fill_color);

        my $new_css = sprintf("scale trough highlight { background: %s; }", $fill_color->to_string());
        $fill_css_provider->load_from_data($new_css);

        my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
        foreach my $item (@targets) {
            next unless $item->{selected};
            if ($item->{type} =~ /^(rectangle|ellipse|triangle|tetragon|pentagon|numbered-circle|pyramid|cuboid)$/) {
                store_state_for_undo('modify', clone_item($item));
                $item->{fill_color} = $new_fill_color->copy();
            }
        }
        $drawing_area->queue_draw() if @targets;
    });

    return $transparency_tool_item;
}

sub create_stroke_transparency_slider {
    my $transparency_box = Gtk3::Box->new('horizontal', 2);

    $stroke_transparency_adjustment = Gtk3::Adjustment->new(1.0, 0.0, 1.0, 0.05, 0.05, 0.0);
    $stroke_transparency_scale = Gtk3::Scale->new_with_range('horizontal', 0.0, 1.0, 0.01);
    $stroke_transparency_scale->set_adjustment($stroke_transparency_adjustment);
    $stroke_transparency_scale->set_size_request(150, -1);
    $stroke_transparency_scale->set_value_pos('right');
    $stroke_transparency_scale->set_tooltip_text("Adjust stroke opacity level");

    $stroke_css_provider = Gtk3::CssProvider->new();
    my $initial_css = sprintf("scale trough highlight { background: %s; }" , $stroke_color->to_string());
    $stroke_css_provider->load_from_data($initial_css);

    $stroke_color_button->signal_connect('color-set' => sub {
        my $rgba = $stroke_color_button->get_rgba();
        my $current_alpha = $stroke_transparency_scale->get_value();
        my $new_stroke_color = Gtk3::Gdk::RGBA->new($rgba->red, $rgba->green, $rgba->blue, $current_alpha);
        $stroke_color = $new_stroke_color;
        
        my $css = sprintf("scale trough highlight { background: %s; }", $new_stroke_color->to_string());
        $stroke_css_provider->load_from_data($css);
    });

    my $style_context = $stroke_transparency_scale->get_style_context();
    $style_context->add_provider($stroke_css_provider, Gtk3::STYLE_PROVIDER_PRIORITY_APPLICATION);
    $transparency_box->pack_start($stroke_transparency_scale, FALSE, FALSE, 0);

    my $transparency_tool_item = Gtk3::ToolItem->new();
    $transparency_tool_item->add($transparency_box);

    $stroke_transparency_scale->signal_connect('value-changed' => sub {
        $stroke_transparency_level = $stroke_transparency_scale->get_value();
        my $new_stroke_color = Gtk3::Gdk::RGBA->new($stroke_color->red, $stroke_color->green, $stroke_color->blue, $stroke_transparency_level);
        $stroke_color = $new_stroke_color;
        $stroke_color_button->set_rgba($new_stroke_color);

        my $new_css = sprintf("scale trough highlight { background: %s; }", $stroke_color->to_string());
        $stroke_css_provider->load_from_data($new_css);

        my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
        foreach my $item (@targets) {
            next unless $item->{selected};
            store_state_for_undo('modify', clone_item($item));
            $item->{stroke_color} = $new_stroke_color->copy();
        }
        $drawing_area->queue_draw() if @targets;
    });

    return $transparency_tool_item;
}

sub show_shadow_settings_dialog {
    my ($parent) = @_;

    my $dialog = Gtk3::Dialog->new(
        "Drop Shadow Settings",
        $parent,
        'modal',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok'
    );
    $dialog->set_default_size(350, 350); 

    my $content_area = $dialog->get_content_area();
    my $grid = Gtk3::Grid->new();
    $grid->set_row_spacing(10);
    $grid->set_column_spacing(15);
    $grid->set_margin_left(15);   
    $grid->set_margin_right(15);
    $grid->set_margin_top(15);
    $grid->set_margin_bottom(15);
    
    my $row = 0;
    sub add_spin_row {
        my ($grid_ref, $row_ref, $label_text, $min, $max, $step, $default_value_ref, $digits) = @_;
        $digits //= 1;
        
        my $label = Gtk3::Label->new($label_text . ':');
        $label->set_halign('start');
        
        my $adjustment = Gtk3::Adjustment->new($$default_value_ref, $min, $max, $step, 0, 0);
        my $spin = Gtk3::SpinButton->new($adjustment, $step, $digits);
        $spin->set_value($$default_value_ref);
        $spin->set_hexpand(TRUE);
        
        $$grid_ref->attach($label, 0, $$row_ref, 1, 1);
        $$grid_ref->attach($spin, 1, $$row_ref, 1, 1);
        $$row_ref++;
        
        return $spin;
    }

    my $spin_offset_x = add_spin_row(\$grid, \$row, "Offset X (px)", -30, 30, 0.5, \$shadow_offset_x, 1);
    my $spin_offset_y = add_spin_row(\$grid, \$row, "Offset Y (px)", -30, 30, 0.5, \$shadow_offset_y, 1);
    my $spin_blur     = add_spin_row(\$grid, \$row, "Blur Radius (px)", 0, 30, 0.5, \$shadow_blur, 1);
    
    my $shadow_color_label = Gtk3::Label->new("Shadow Color:");
    $shadow_color_label->set_halign('start');
    
    my $shadow_color_btn = Gtk3::ColorButton->new_with_rgba($shadow_base_color);

    $grid->attach($shadow_color_label, 0, $row, 1, 1);
    $grid->attach($shadow_color_btn, 1, $row, 1, 1);
    $row++; 
    
    my $spin_alpha    = add_spin_row(\$grid, \$row, "Opacity", 0.0, 1.0, 0.05, \$shadow_alpha, 2); 

    $content_area->pack_start($grid, TRUE, TRUE, 0);
    $dialog->show_all();

    my $response = $dialog->run();

    if ($response eq 'ok') {
        $shadow_offset_x = $spin_offset_x->get_value();
        $shadow_offset_y = $spin_offset_y->get_value();
        $shadow_alpha    = $spin_alpha->get_value();
        $shadow_blur     = $spin_blur->get_value();
        
        my $picked_color = $shadow_color_btn->get_rgba();
        $shadow_base_color = Gtk3::Gdk::RGBA->new(
            $picked_color->red,
            $picked_color->green,
            $picked_color->blue,
            1.0
        );

        my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
        foreach my $item (@targets) {
            next unless $item->{selected} && $item->{drop_shadow};
            store_state_for_undo('modify', clone_item($item));
            
            $item->{shadow_offset_x} = $shadow_offset_x;
            $item->{shadow_offset_y} = $shadow_offset_y;
            $item->{shadow_alpha}    = $shadow_alpha;
            $item->{shadow_blur}     = $shadow_blur;
            
            $item->{shadow_color} = Gtk3::Gdk::RGBA->new(
                $picked_color->red, 
                $picked_color->green, 
                $picked_color->blue, 
                1.0
            );
        }
        
        $drawing_area->queue_draw() if @targets;
    }
    
    $dialog->destroy();
    return;
}

sub rebuild_main_toolbar {

    foreach my $child ($main_toolbar->get_children()) {
        $main_toolbar->remove($child);
    }

    my @separator_after = qw(image-close redo paste delete zoom-fit-best save-as print);
    foreach my $item (@main_toolbar_items) {
        if ($item->{is_widget}) {
            if ($item->{name} eq 'image-open-recent') {
 
                my $tool_item = create_open_recent_button($main_toolbar_icon_size);
                
                $main_toolbar->insert($tool_item, -1);
                $tool_buttons{$item->{name}} = $tool_item;
            }
        } else {
            my $image = load_icon($item->{name}, $main_toolbar_icon_size);
            my $tool_item = Gtk3::ToolButton->new($image, $item->{label});
            $tool_item->set_tooltip_text($item->{tooltip}) if $item->{tooltip};

            if ($item->{name} =~ /^zoom-/) {
                if ($item->{name} eq 'zoom-in') {
                    $tool_item->signal_connect('clicked' => \&zoom_in);
                }
                elsif ($item->{name} eq 'zoom-out') {
                    $tool_item->signal_connect('clicked' => \&zoom_out);
                }
                elsif ($item->{name} eq 'zoom-original') {
                    $tool_item->signal_connect('clicked' => \&zoom_original);
                }
                elsif ($item->{name} eq 'zoom-fit-best') {
                    $tool_item->signal_connect('clicked' => \&zoom_fit_best);
                }
            } else {
                $tool_item->signal_connect('clicked' => sub {
                    handle_main_toolbar_action($item->{name});
                });
            }

            $tool_buttons{$item->{name}} = $tool_item;
            $main_toolbar->insert($tool_item, -1);

            if (grep { $_ eq $item->{name} } @separator_after) {
                $main_toolbar->insert(Gtk3::SeparatorToolItem->new(), -1);
            }
        }
    }
    
    $main_toolbar->show_all();
    
    return;
}

sub rebuild_drawing_toolbar {
   
    my $active_tool = $current_tool;

    foreach my $child ($drawing_toolbar->get_children()) {
        $drawing_toolbar->remove($child);
    }

    my $first_drawing_item = 1;
    foreach my $item (@drawing_toolbar_items) {
        if ($item->{type} && $item->{type} eq 'separator') {
            $drawing_toolbar->insert(Gtk3::SeparatorToolItem->new(), -1);
            $first_drawing_item = 0;
        } else {
            my $tool_item = create_tool_button($item, $drawing_toolbar_icon_size);
            $tool_buttons{$item->{name}} = $tool_item;
            
            $tool_item->signal_connect('toggled' => sub {
                handle_tool_selection($tool_item, $item->{name});
            }) if $tool_item->isa('Gtk3::ToggleToolButton');
            
            $drawing_toolbar->insert($tool_item, -1);
        }
    }

    if ($tool_buttons{$active_tool} && $tool_buttons{$active_tool}->isa('Gtk3::ToggleToolButton')) {
        $tool_buttons{$active_tool}->set_active(1);
    }
    
    $drawing_toolbar->show_all();
    
    return;
}

sub update_main_toolbar_icon_size {
    my ($new_size) = @_;
    
    $main_toolbar_icon_size = $new_size;

    $main_toolbar->set_icon_size(get_gtk_icon_size($new_size));
    
    rebuild_main_toolbar();
    
    save_icon_sizes();

    $window->queue_draw() if $window;
    
    print "Main toolbar icon size changed to: ${new_size}x${new_size}\n";
    
    return;
}

sub update_drawing_toolbar_icon_size {
    my ($new_size) = @_;
    
    $drawing_toolbar_icon_size = $new_size;
    
    $drawing_toolbar->set_icon_size(get_gtk_icon_size($new_size));
    
    rebuild_drawing_toolbar();
    
    save_icon_sizes();
    
    $window->queue_draw() if $window;
    
    print "Drawing toolbar icon size changed to: ${new_size}x${new_size}\n";
    
    return;
}

sub update_recent_files_menu {
  
    $open_recent_item->set_submenu(create_recent_files_menu());

    if (exists $tool_buttons{'image-open-recent'}) {
        my $tool_item = $tool_buttons{'image-open-recent'};
        if ($tool_item && $tool_item->{recent_menu}) {
            my $menu = $tool_item->{recent_menu};

            foreach my $child ($menu->get_children()) {
                $menu->remove($child);
            }

            if (@recent_files) {
                foreach my $file (@recent_files) {
                    next unless -f $file;

                    my $thumb_path = "$ENV{HOME}/.config/linia/thumbnails/" .
                                   Digest::MD5::md5_hex($file) . ".png";

                    my $item = create_menu_item_with_thumbnail($file, $thumb_path);

                    $item->signal_connect('activate' => sub {
                        load_image_file($file, $window);
                        zoom_fit_best();
                    });

                    $menu->append($item);
                    $item->show_all(); 
                }
            } else {
                my $item = Gtk3::MenuItem->new_with_label("No Recent Files");
                $item->set_sensitive(FALSE);
                $menu->append($item);
                $item->show_all();
            }

            $menu->show_all(); 
        }
    }
    
    return;
}


sub update_drawing_area_size {
    return unless $image_surface && $drawing_area;

    my $scaled_width = $image_surface->get_width() * $scale_factor;
    my $scaled_height = $image_surface->get_height() * $scale_factor;

    $drawing_area->set_size_request($scaled_width, $scaled_height);

    my $scrolled_window = $drawing_area->get_parent;
    while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
        $scrolled_window = $scrolled_window->get_parent;
    }

    if ($scrolled_window) {
        $scrolled_window->set_policy('automatic', 'automatic');

        my $viewport = $scrolled_window->get_child;
        my $vadj_local = $scrolled_window->get_vadjustment;
        my $hadj_local = $scrolled_window->get_hadjustment; 

        if ($hadj_local) {
            $hadj_local->set_upper($scaled_width);
            $hadj_local->set_page_size($viewport->get_allocated_width);
        }
        if ($vadj_local) {
            $vadj_local->set_upper($scaled_height);
            $vadj_local->set_page_size($viewport->get_allocated_height);
        }
    }
    $drawing_area->queue_draw();
    return;
}

# Dialogs:

sub show_shortcuts_dialog {
    my ($parent) = @_;

    my $dialog = Gtk3::Dialog->new(
        "Keyboard Shortcuts",
        $parent,
        'modal',
        'gtk-close' => 'close'
    );
    $dialog->set_default_size(500, 650); 
    
    my $content_area = $dialog->get_content_area();
    
    my $scrolled = Gtk3::ScrolledWindow->new();
    $scrolled->set_policy('automatic', 'automatic');
    $scrolled->set_border_width(10);
    
    my $grid = Gtk3::Grid->new();
    $grid->set_column_spacing(20);
    $grid->set_row_spacing(8);

    my @shortcuts = (
        ["GENERAL", "", ""],
        ["", "Undo", "Ctrl + Z"],
        ["", "Redo", "Ctrl + Y"],
        ["", "Copy", "Ctrl + C"],
        ["", "Cut", "Ctrl + X"],
        ["", "Paste", "Ctrl + V"],
        ["", "Delete Item", "Delete"],
        
        ["VIEW", "", ""],
        ["", "Zoom In", "Ctrl + Plus"],
        ["", "Zoom Out", "Ctrl + Minus"],
        ["", "Original Size", "Ctrl + 1"],
        ["", "Best Fit", "Ctrl + 2"],
        ["", "Pan Canvas", "Middle Click Drag"],
        
        ["TOOLS & DRAWING", "", ""],
        ["", "Multi-Select", "Hold Shift + Click"],
        ["", "Constrain Shape (Square/Circle)", "Hold Ctrl + Drag"],
        ["", "Snap Horizontal (Lines/Free)", "Hold Ctrl + Drag"],
        ["", "Snap Vertical (Lines/Free)", "Hold Shift + Drag"],
        ["", "Resize from Center (Shapes)", "Hold Ctrl + Drag Handle"],
        
        ["MANIPULATION", "", ""],
        ["", "Increase Line Width / Font", "Alt + Plus"],
        ["", "Decrease Line Width / Font", "Alt + Minus"],
        ["", "Resize SVG / Magnifier", "Alt + Plus / Minus"],
        
        ["SPECIFIC", "", ""],
        ["", "Finish Crop", "Enter"],
        ["", "Text: New Line", "Enter"],
        ["", "Text: Cancel Edit", "Escape"],
        ["", "Context Menu", "Right Click"],
    );

    my $row = 0;
    foreach my $entry (@shortcuts) {
        my ($cat, $action, $keys) = @$entry;
        
        if ($cat ne "") {
    
            my $label = Gtk3::Label->new("<b>$cat</b>");
            $label->set_use_markup(TRUE);
            $label->set_halign('start');
            $label->set_margin_top($row == 0 ? 0 : 15);
            $label->set_margin_bottom(5);
            $grid->attach($label, 0, $row, 2, 1);
            $row++;
        } else {
 
            my $lbl_action = Gtk3::Label->new($action);
            $lbl_action->set_halign('start');
            
            my $lbl_keys = Gtk3::Label->new($keys);
            $lbl_keys->set_halign('end');
            $lbl_keys->get_style_context()->add_class('dim-label'); 
            
            $grid->attach($lbl_action, 0, $row, 1, 1);
            $grid->attach($lbl_keys, 1, $row, 1, 1);
            $row++;
        }
    }

    $scrolled->add($grid);
    $content_area->pack_start($scrolled, TRUE, TRUE, 0);
    
    $dialog->show_all();
    $dialog->run();
    $dialog->destroy();
    
    return;
}

sub show_print_dialog {
    my ($parent_window) = @_;

    my $print = Gtk3::PrintOperation->new();

    my $result = $print->run('print-dialog', $parent_window);

    if ($result eq 'print' || $result eq 'preview') {
        print "Printing...\n";
    }
    
    return;
}

sub show_settings_dialog {
    my ($parent_window) = @_;

    my $dialog = Gtk3::Dialog->new(
        "Settings",
        $parent_window,
        'modal',
        'gtk-close' => 'close'
    );

    $dialog->set_default_size(400, 350);

    my $content_area = $dialog->get_content_area();
    my $grid = Gtk3::Grid->new();
    $grid->set_row_spacing(15);
    $grid->set_column_spacing(15);
    $grid->set_margin_left(20);
    $grid->set_margin_right(20);
    $grid->set_margin_top(20);
    $grid->set_margin_bottom(20);

    my $handle_label = Gtk3::Label->new("Handle Size:");
    $handle_label->set_halign('start');

    my $handle_scale = Gtk3::Scale->new_with_range('horizontal', 3, 15, 1);
    $handle_scale->set_value($handle_size);
    $handle_scale->set_value_pos('right');
    $handle_scale->set_hexpand(TRUE);

    $grid->attach($handle_label, 0, 0, 1, 1);
    $grid->attach($handle_scale, 1, 0, 1, 1);

    my $theme_label = Gtk3::Label->new("Icon Theme:");
    $theme_label->set_halign('start');

    my $theme_combo = Gtk3::ComboBoxText->new();
    $theme_combo->append('color', 'Multi-Color');
    $theme_combo->append('white', 'White (Dark Mode)');
    $theme_combo->append('black', 'Black (Light Mode)');


    $theme_combo->set_active_id($icon_theme);

    $grid->attach($theme_label, 0, 1, 1, 1);
    $grid->attach($theme_combo, 1, 1, 1, 1);
    
    $handle_scale->signal_connect('value-changed' => sub {
        $handle_size = $handle_scale->get_value();
        $drawing_area->queue_draw();
    });

    $theme_combo->signal_connect('changed' => sub {
        my $new_theme = $theme_combo->get_active_id();
        if ($new_theme && $new_theme ne $icon_theme) {
            $icon_theme = $new_theme;
            print "Switching icon theme to: $icon_theme\n";

            rebuild_main_toolbar();
            rebuild_drawing_toolbar();
        }
    });

    $content_area->pack_start($grid, TRUE, TRUE, 0);
    $dialog->show_all();

    $dialog->run();

    save_tool_state();
    
    $dialog->destroy();
    
    return;
}

sub show_handle_size_dialog {
    my ($parent_window) = @_;

    my $dialog = Gtk3::Dialog->new(
        "Custom Handle Size",
        $parent_window,
        'modal',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok'
    );

    my $content_area = $dialog->get_content_area();
    my $grid = Gtk3::Grid->new();
    $grid->set_row_spacing(10);
    $grid->set_column_spacing(10);
    $grid->set_margin_left(20);
    $grid->set_margin_right(20);
    $grid->set_margin_top(20);
    $grid->set_margin_bottom(20);

    my $label = Gtk3::Label->new("Handle Size (5-25):");
    my $scale = Gtk3::Scale->new_with_range('horizontal', 5, 25, 1);
    $scale->set_value($handle_size);
    $scale->set_value_pos('right');
    $scale->set_hexpand(TRUE);

    $grid->attach($label, 0, 0, 1, 1);
    $grid->attach($scale, 0, 1, 1, 1);

    $content_area->pack_start($grid, TRUE, TRUE, 0);
    $dialog->show_all();

    my $response = $dialog->run();

    if ($response eq 'ok') {
        $handle_size = $scale->get_value();
        $drawing_area->queue_draw();
        print "Custom handle size set to: $handle_size\n";
    }
    $dialog->destroy();
    
    return;
}

sub show_text_edit_dialog {
    my ($text_item) = @_;

    my $dialog = Gtk3::Dialog->new(
        'Edit Text',
        $window,
        'modal',
        'gtk-ok' => 'ok',
        'gtk-cancel' => 'cancel'
    );
    
    $dialog->set_default_size(400, 300);
    my $content_area = $dialog->get_content_area();

    my $scrolled_window = Gtk3::ScrolledWindow->new();
    $scrolled_window->set_policy('automatic', 'automatic');
    $scrolled_window->set_size_request(380, 200);

    my $text_view = Gtk3::TextView->new();
    $text_view->set_wrap_mode('word');
    $text_view->get_buffer()->set_text($text_item->{text});
    $scrolled_window->add($text_view);
    $content_area->pack_start($scrolled_window, TRUE, TRUE, 0);

    my $font_box = Gtk3::Box->new('horizontal', 6);
    my $font_label = Gtk3::Label->new('Font:');
    my $font_button = Gtk3::FontButton->new();
    $font_button->set_font_name($text_item->{font});
    $font_box->pack_start($font_label, FALSE, FALSE, 0);
    $font_box->pack_start($font_button, TRUE, TRUE, 0);
    $content_area->pack_start($font_box, FALSE, FALSE, 0);

    my $color_box = Gtk3::Box->new('horizontal', 6);
    my $color_label = Gtk3::Label->new('Color:');
    my $color_button = Gtk3::ColorButton->new_with_rgba($text_item->{stroke_color});
    $color_box->pack_start($color_label, FALSE, FALSE, 0);
    $color_box->pack_start($color_button, TRUE, TRUE, 0);
    $content_area->pack_start($color_box, FALSE, FALSE, 0);

    $dialog->show_all();

    my $response = $dialog->run();
    if ($response eq 'ok') {
      
        store_state_for_undo('modify', clone_item($text_item));

        $text_item->{text} = $text_view->get_buffer()->get_text(
            $text_view->get_buffer()->get_start_iter(),
            $text_view->get_buffer()->get_end_iter(),
            TRUE
        );
        $text_item->{font} = $font_button->get_font_name();
        $text_item->{stroke_color} = $color_button->get_rgba();

        $drawing_area->queue_draw();
    }

    $dialog->destroy();
    
    return;
}

sub show_background_context_menu {
    my ($event) = @_;
    my $menu = Gtk3::Menu->new();

    my $undo_item = Gtk3::MenuItem->new_with_label("Undo");
    $undo_item->set_sensitive(scalar(@undo_stack) > 0);
    $undo_item->signal_connect('activate' => \&do_undo);
    $menu->append($undo_item);

    my $redo_item = Gtk3::MenuItem->new_with_label("Redo");
    $redo_item->set_sensitive(scalar(@redo_stack) > 0);
    $redo_item->signal_connect('activate' => \&do_redo);
    $menu->append($redo_item);

    $menu->append(Gtk3::SeparatorMenuItem->new());

    my $paste_item = Gtk3::MenuItem->new_with_label("Paste");

    $paste_item->set_sensitive(defined $clipboard_item);
    $paste_item->signal_connect('activate' => \&paste_item);
    $menu->append($paste_item);

    my $clear_item = Gtk3::MenuItem->new_with_label("Clear All");
    $clear_item->signal_connect('activate' => sub { clear_all_annotations(); });
    $menu->append($clear_item);

    $menu->append(Gtk3::SeparatorMenuItem->new());

    my $copy_img_item = Gtk3::MenuItem->new_with_label("Copy Image");
    $copy_img_item->signal_connect('activate' => \&copy_image_to_clipboard);
    $menu->append($copy_img_item);

    $menu->append(Gtk3::SeparatorMenuItem->new());

    my $settings_item = Gtk3::MenuItem->new_with_label("Settings");
    $settings_item->signal_connect('activate' => sub { show_settings_dialog($window); });
    $menu->append($settings_item);

    $menu->show_all();
    $menu->popup(undef, undef, undef, undef, $event->button, $event->time);
    
    return;
}

sub show_item_context_menu {
    my ($event) = @_;

    if (@selected_items > 1) {
        my $menu = Gtk3::Menu->new();

        my $layers_menu_item = Gtk3::MenuItem->new_with_label("Layers");
        my $layers_submenu = Gtk3::Menu->new();
        
        my $raise_to_top_item = Gtk3::MenuItem->new_with_label("Raise to Top");
        $raise_to_top_item->signal_connect('activate' => sub { 
       
            foreach my $item (sort { $a->{timestamp} <=> $b->{timestamp} } @selected_items) { raise_to_top($item); } 
        });
        $layers_submenu->append($raise_to_top_item);

        my $raise_one_item = Gtk3::MenuItem->new_with_label("Raise One Step");
        $raise_one_item->signal_connect('activate' => sub { 
            foreach my $item (@selected_items) { raise_one_step($item); } 
        });
        $layers_submenu->append($raise_one_item);

        my $lower_one_item = Gtk3::MenuItem->new_with_label("Lower One Step");
        $lower_one_item->signal_connect('activate' => sub { 
            foreach my $item (@selected_items) { lower_one_step($item); } 
        });
        $layers_submenu->append($lower_one_item);

        my $lower_to_bottom_item = Gtk3::MenuItem->new_with_label("Lower to Bottom");
        $lower_to_bottom_item->signal_connect('activate' => sub { 
            foreach my $item (@selected_items) { lower_to_bottom($item); } 
        });
        $layers_submenu->append($lower_to_bottom_item);

        $layers_menu_item->set_submenu($layers_submenu);
        $menu->append($layers_menu_item);

        $menu->append(Gtk3::SeparatorMenuItem->new());

        my $handle_size_item = Gtk3::MenuItem->new_with_label("Handle Size");
        my $handle_size_submenu = Gtk3::Menu->new();

        my @handle_sizes = (3, 4, 5, 6, 7, 8, 9, 10);
        foreach my $size (@handle_sizes) {
            my $size_item = Gtk3::CheckMenuItem->new_with_label("${size}px");
            $size_item->set_active($handle_size == $size);
            $size_item->signal_connect('activate' => sub {
                $handle_size = $size;
                $drawing_area->queue_draw();
            });
            $handle_size_submenu->append($size_item);
        }

        $handle_size_submenu->append(Gtk3::SeparatorMenuItem->new());

        my $custom_item = Gtk3::MenuItem->new_with_label('Custom...');
        $custom_item->signal_connect('activate' => sub { show_handle_size_dialog($window); });
        $handle_size_submenu->append($custom_item);

        $handle_size_item->set_submenu($handle_size_submenu);
        $menu->append($handle_size_item);

        $menu->append(Gtk3::SeparatorMenuItem->new());

        my $copy_item = Gtk3::MenuItem->new_with_label("Copy");
        $copy_item->signal_connect('activate' => \&copy_item);
        $menu->append($copy_item);

        my $cut_item = Gtk3::MenuItem->new_with_label("Cut");
        $cut_item->signal_connect('activate' => \&cut_item);
        $menu->append($cut_item);

        my $delete_item = Gtk3::MenuItem->new_with_label("Delete");
        $delete_item->signal_connect('activate' => \&delete_item);
        $menu->append($delete_item);

        $menu->show_all();
        $menu->popup(undef, undef, undef, undef, $event->button, $event->time);

        return TRUE;
    }

    my $menu = Gtk3::Menu->new();

    if ($current_item->{type} eq 'text') {
        my $edit_text_item = Gtk3::MenuItem->new_with_label("Edit Text");
        $edit_text_item->signal_connect('activate' => sub {
            show_text_edit_dialog($current_item, $window);
        });
        $menu->append($edit_text_item);
        $menu->append(Gtk3::SeparatorMenuItem->new());
    }

    my $layers_menu_item = Gtk3::MenuItem->new_with_label("Layers");
    my $layers_submenu = Gtk3::Menu->new();
    my $raise_to_top_item = Gtk3::MenuItem->new_with_label("Raise to Top");
    $raise_to_top_item->signal_connect('activate' => sub { raise_to_top($current_item); });
    $layers_submenu->append($raise_to_top_item);
    my $raise_one_item = Gtk3::MenuItem->new_with_label("Raise One Step");
    $raise_one_item->signal_connect('activate' => sub { raise_one_step($current_item); });
    $layers_submenu->append($raise_one_item);
    my $lower_one_item = Gtk3::MenuItem->new_with_label("Lower One Step");
    $lower_one_item->signal_connect('activate' => sub { lower_one_step($current_item); });
    $layers_submenu->append($lower_one_item);
    my $lower_to_bottom_item = Gtk3::MenuItem->new_with_label("Lower to Bottom");
    $lower_to_bottom_item->signal_connect('activate' => sub { lower_to_bottom($current_item); });
    $layers_submenu->append($lower_to_bottom_item);
    $layers_menu_item->set_submenu($layers_submenu);
    $menu->append($layers_menu_item);

    $menu->append(Gtk3::SeparatorMenuItem->new());

    my $handle_size_item = Gtk3::MenuItem->new_with_label("Handle Size");
    my $handle_size_submenu = Gtk3::Menu->new();
    my @handle_sizes = (3, 4, 5, 6, 7, 8, 9, 10);
    foreach my $size (@handle_sizes) {
        my $size_item = Gtk3::CheckMenuItem->new_with_label("${size}px");
        $size_item->set_active($handle_size == $size);
        $size_item->signal_connect('activate' => sub {
            $handle_size = $size;
            $drawing_area->queue_draw();
        });
        $handle_size_submenu->append($size_item);
    }
    $handle_size_submenu->append(Gtk3::SeparatorMenuItem->new());
    my $custom_item = Gtk3::MenuItem->new_with_label('Custom...');
    $custom_item->signal_connect('activate' => sub { show_handle_size_dialog($window); });
    $handle_size_submenu->append($custom_item);
    $handle_size_item->set_submenu($handle_size_submenu);
    $menu->append($handle_size_item);

    $menu->append(Gtk3::SeparatorMenuItem->new());

    my $anchor_item;
    if (defined $current_item->{anchored} && $current_item->{anchored}) {
        $anchor_item = Gtk3::MenuItem->new_with_label("Unanchor");
        $anchor_item->signal_connect('activate' => sub { unanchor_item($current_item); });
    } else {
        $anchor_item = Gtk3::MenuItem->new_with_label("Anchor");
        $anchor_item->signal_connect('activate' => sub { anchor_item($current_item); });
    }
    $menu->append($anchor_item);

    my $item_type = $current_item->{type};
    if ($item_type =~ /^(line|dashed-line|rectangle|tetragon|pyramid)$/) {
        $menu->append(Gtk3::SeparatorMenuItem->new());

        if (defined $current_item->{show_measures} && $current_item->{show_measures}) {
            $current_item->{show_angles} = 1 unless defined $current_item->{show_angles};
            $current_item->{show_edges} = 1 unless defined $current_item->{show_edges};
            $current_item->{show_area} = 1 unless defined $current_item->{show_area};
            delete $current_item->{show_measures};
        }
        
        my $measures_menu_item = Gtk3::MenuItem->new_with_label("Show Measures");
        my $measures_submenu = Gtk3::Menu->new();

        my $angles_item = Gtk3::CheckMenuItem->new_with_label("Angles");
        $angles_item->set_active($current_item->{show_angles} // 0);
        $angles_item->signal_connect('activate' => sub { 
            toggle_measure_type($current_item, 'angles'); 
        });
        $measures_submenu->append($angles_item);

        my $edges_item = Gtk3::CheckMenuItem->new_with_label("Edges");
        $edges_item->set_active($current_item->{show_edges} // 0);
        $edges_item->signal_connect('activate' => sub { 
            toggle_measure_type($current_item, 'edges'); 
        });
        $measures_submenu->append($edges_item);

        my $area_item = Gtk3::CheckMenuItem->new_with_label("Area");
        $area_item->set_active($current_item->{show_area} // 0);
        $area_item->signal_connect('activate' => sub { 
            toggle_measure_type($current_item, 'area'); 
        });
        $measures_submenu->append($area_item);
        
        $measures_menu_item->set_submenu($measures_submenu);
        $menu->append($measures_menu_item);
    }

    if ($current_item->{type} eq 'numbered-circle') {
        $menu->append(Gtk3::SeparatorMenuItem->new());
        my $anchor_seq = Gtk3::MenuItem->new_with_label("Anchor Sequence (Reset Count)");
        $anchor_seq->signal_connect('activate' => sub {
            foreach my $c (@{$items{'numbered-circles'}}) {
                $c->{anchored} = 1; 
                $c->{selected} = 0;
            }
            $current_item = undef;
            $drawing_area->queue_draw();
        });
        $menu->append($anchor_seq);
    }

    $menu->append(Gtk3::SeparatorMenuItem->new());

    my $copy_item = Gtk3::MenuItem->new_with_label("Copy");
    $copy_item->signal_connect('activate' => \&copy_item);
    $menu->append($copy_item);

    my $cut_item = Gtk3::MenuItem->new_with_label("Cut");
    $cut_item->signal_connect('activate' => \&cut_item);
    $menu->append($cut_item);

    my $delete_item = Gtk3::MenuItem->new_with_label("Delete");
    $delete_item->signal_connect('activate' => \&delete_item);
    $menu->append($delete_item);

    $menu->show_all();
    $menu->popup(undef, undef, undef, undef, $event->button, $event->time);
    
    return;
}

sub toggle_measure_type {
    my ($item, $type) = @_;
    return unless $item;
    
    if ($type eq 'angles') {
        if (defined $item->{show_angles} && $item->{show_angles}) {
            $item->{show_angles} = 0;
        } else {
            $item->{show_angles} = 1;
        }
    }
    elsif ($type eq 'edges') {
        if (defined $item->{show_edges} && $item->{show_edges}) {
            $item->{show_edges} = 0;
        } else {
            $item->{show_edges} = 1;
        }
    }
    elsif ($type eq 'area') {
        if (defined $item->{show_area} && $item->{show_area}) {
            $item->{show_area} = 0;
        } else {
            $item->{show_area} = 1;
        }
    }
    
    $drawing_area->queue_draw();
    
    return;
}


# Operations:

sub load_icon_sizes {
    return unless -f $icon_sizes_file;

    open(my $fh, '<', $icon_sizes_file) or return;
    
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^main_toolbar=(\d+)$/) {
            $main_toolbar_icon_size = $1;
            print "Loaded main toolbar icon size: $main_toolbar_icon_size\n";
        }
        elsif ($line =~ /^drawing_toolbar=(\d+)$/) {
            $drawing_toolbar_icon_size = $1;
            print "Loaded drawing toolbar icon size: $drawing_toolbar_icon_size\n";
        }
        elsif ($line =~ /^drawing_toolbar_position=(left|top)$/) {
            $drawing_toolbar_on_left = ($1 eq 'left') ? 1 : 0;
            print "Loaded drawing toolbar position: $1\n";
        }
    }
    
    close $fh;
    
    return;
}

sub get_gtk_icon_size {
    my ($size) = @_;
    
    if ($size <= 16) {
        return 'menu';  
    } elsif ($size <= 24) {
        return 'small-toolbar';  
    } elsif ($size <= 32) {
        return 'large-toolbar'; 
    } else {
        return 'dialog';  
    }
}

sub zoom_in {
    return unless $image_surface;

    $scale_factor *= 1.1;  

    update_drawing_area_size();

    $drawing_area->signal_connect('size-allocate' => sub {
        my ($drawing_area, $allocation) = @_;

        my $scrolled_window = $drawing_area->get_parent;
        while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
            $scrolled_window = $scrolled_window->get_parent;
        }
        return unless $scrolled_window;

        my $viewport = $scrolled_window->get_child;
        my $view_width = $viewport->get_allocated_width;
        my $view_height = $viewport->get_allocated_height;

        center_image($scrolled_window, $view_width, $view_height);

        $drawing_area->signal_handler_disconnect($drawing_area->signal_connect('size-allocate' => sub {}));
    });

    $drawing_area->queue_resize();
    $drawing_area->queue_draw();
    
    return;
}

sub zoom_out {
    return unless $image_surface;

    $scale_factor *= 0.9;
    if ($scale_factor < 0.1) { $scale_factor = 0.1; }

    update_drawing_area_size();

    $drawing_area->signal_connect('size-allocate' => sub {
        my ($drawing_area, $allocation) = @_;

        my $scrolled_window = $drawing_area->get_parent;
        while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
            $scrolled_window = $scrolled_window->get_parent;
        }
        return unless $scrolled_window;

        my $viewport = $scrolled_window->get_child;
        my $view_width = $viewport->get_allocated_width;
        my $view_height = $viewport->get_allocated_height;

        center_image($scrolled_window, $view_width, $view_height);

        $drawing_area->signal_handler_disconnect($drawing_area->signal_connect('size-allocate' => sub {}));
    });

    $drawing_area->queue_resize();
    $drawing_area->queue_draw();
    
    return;
}

sub zoom_original {
    return unless $image_surface;

    my $monitor_scale = 1;
    if (defined $window && $window->get_window()) {
        $monitor_scale = $window->get_scale_factor();
    }

    $scale_factor = 1.0 / $monitor_scale;

    my ($win_width, $win_height) = $window->get_size();

    update_drawing_area_size();

    $window->resize($win_width, $win_height);

    my $scrolled_window = $drawing_area->get_parent;
    while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
        $scrolled_window = $scrolled_window->get_parent;
    }

    if ($scrolled_window) {
        my $viewport = $scrolled_window->get_child;
        my $view_width = $viewport->get_allocated_width;
        my $view_height = $viewport->get_allocated_height;
        center_image($scrolled_window, $view_width, $view_height);
    }

    $drawing_area->queue_draw();
    
    return;
}

sub center_image {
    my ($scrolled_window, $view_width, $view_height) = @_;

    return unless $image_surface;

    my $hadj = $scrolled_window->get_hadjustment;
    my $vadj = $scrolled_window->get_vadjustment;

    return unless $hadj && $vadj;

    my $image_width = $image_surface->get_width * $scale_factor;
    my $image_height = $image_surface->get_height * $scale_factor;

    my $h_value = max(0, ($image_width - $view_width) / 2);
    my $v_value = max(0, ($image_height - $view_height) / 2);

    $hadj->set_value($h_value);
    $vadj->set_value($v_value);
    
    return;
}

sub zoom_fit_best {

    return unless ($image_surface && $drawing_area);

    my $scrolled_window = $drawing_area->get_parent;
    while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
        $scrolled_window = $scrolled_window->get_parent;
    }
    return unless $scrolled_window;

    my $viewport = $scrolled_window->get_child;
    my $view_width = $viewport->get_allocated_width;
    my $view_height = $viewport->get_allocated_height;

    my $image_width = $image_surface->get_width;
    my $image_height = $image_surface->get_height;

    my $scale_x = $view_width / $image_width;
    my $scale_y = $view_height / $image_height;

    $scale_factor = min($scale_x, $scale_y);

    $scale_factor *= 0.99;

    update_drawing_area_size();

    $drawing_area->signal_connect('size-allocate' => sub {
        my ($drawing_area, $allocation) = @_;

        my $scrolled_window = $drawing_area->get_parent;
        while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
            $scrolled_window = $scrolled_window->get_parent;
        }
        return unless $scrolled_window;

        my $viewport = $scrolled_window->get_child;
        my $view_width = $viewport->get_allocated_width;
        my $view_height = $viewport->get_allocated_height;

        center_image($scrolled_window, $view_width, $view_height);

        $drawing_area->signal_handler_disconnect($drawing_area->signal_connect('size-allocate' => sub {}));
    });

    $drawing_area->queue_resize();
    $drawing_area->queue_draw();
    
    return;
}

sub start_panning {
    my ($x, $y) = @_;

    $is_panning = 1;
    $pan_start_x = $x;
    $pan_start_y = $y;

    my $scrolled_window = $drawing_area->get_parent;
    while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
        $scrolled_window = $scrolled_window->get_parent;
    }

    if ($scrolled_window) {
        my $hadj = $scrolled_window->get_hadjustment();
        my $vadj = $scrolled_window->get_vadjustment();
        $pan_start_scroll_x = $hadj ? $hadj->get_value() : 0;
        $pan_start_scroll_y = $vadj ? $vadj->get_value() : 0;

        $hadj->signal_handlers_block_by_func(\&on_scroll_value_changed) if $hadj;
        $vadj->signal_handlers_block_by_func(\&on_scroll_value_changed) if $vadj;
    }

    my $window = $drawing_area->get_window();
    if ($window) {
        my $cursor = Gtk3::Gdk::Cursor->new_for_display(
            $window->get_display(),
            'fleur'  
        );
        $window->set_cursor($cursor);
    }
    
    return;
}

sub update_controls_for_item {
    my ($item) = @_;

    if (defined $item->{line_width}) {
        $line_width = $item->{line_width};
        $line_width_spin_button->set_value($line_width);
    }

    if (defined $item->{line_style}) {
        $current_line_style = $item->{line_style};
        $line_style_combo->set_active_id($current_line_style);
    }

    if (defined $item->{fill_color}) {
        $fill_color = $item->{fill_color}->copy();
        $fill_color_button->set_rgba($fill_color);

        if ($fill_transparency_scale) {
            $fill_transparency_scale->set_value($fill_color->alpha);
        }
    }

    if (defined $item->{stroke_color}) {
        $stroke_color = $item->{stroke_color}->copy();
        $stroke_color_button->set_rgba($stroke_color);

        if ($stroke_transparency_scale) {
            $stroke_transparency_scale->set_value($stroke_color->alpha);
        }
    }

    if ($item->{type} eq 'text' && defined $item->{font}) {
        if ($font_btn_w) {
            $font_btn_w->set_font_name($item->{font});
        }
    }
    
    if ($shadow_check) {
        my $is_shadowed = defined $item->{drop_shadow} ? $item->{drop_shadow} : $drop_shadow_enabled;
        $shadow_check->set_active($is_shadowed);
    }
    
    return;
}

sub update_panning {
    my ($x, $y) = @_;

    return unless $is_panning;

    my $dx = $x - $pan_start_x;
    my $dy = $y - $pan_start_y;

    my $scrolled_window = $drawing_area->get_parent;
    while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
        $scrolled_window = $scrolled_window->get_parent;
    }

    return unless $scrolled_window;

    my $hadj = $scrolled_window->get_hadjustment();
    my $vadj = $scrolled_window->get_vadjustment();

    if ($hadj && $vadj) {

        my $new_h = $pan_start_scroll_x - $dx;
        my $new_v = $pan_start_scroll_y - $dy;

        my $h_max = max(0, $hadj->get_upper() - $hadj->get_page_size());
        my $v_max = max(0, $vadj->get_upper() - $vadj->get_page_size());

        $new_h = max(0, min($new_h, $h_max));
        $new_v = max(0, min($new_v, $v_max));

        $hadj->set_value($new_h);
        $vadj->set_value($new_v);

        $scrolled_window->queue_draw();
    }
    
    return;
}

sub stop_panning {
    $is_panning = 0;

    my $scrolled_window = $drawing_area->get_parent;
    while ($scrolled_window && !$scrolled_window->isa('Gtk3::ScrolledWindow')) {
        $scrolled_window = $scrolled_window->get_parent;
    }

    if ($scrolled_window) {
        my $hadj = $scrolled_window->get_hadjustment();
        my $vadj = $scrolled_window->get_vadjustment();

        $hadj->signal_handlers_unblock_by_func(\&on_scroll_value_changed) if $hadj;
        $vadj->signal_handlers_unblock_by_func(\&on_scroll_value_changed) if $vadj;
    }

    my $window = $drawing_area->get_window();
    if ($window) {
        $window->set_cursor(undef); 
    }
    
    return;
}

sub on_scroll_value_changed {
    return if $is_panning;
    
    return;
}

sub downscale_image {
    my ($surface, $scale) = @_;
    return unless $surface;

    my ($width, $height) = ($surface->get_width(), $surface->get_height());
    my $scaled_surface = Cairo::ImageSurface->create('argb32', int($width / $scale), int($height / $scale));
    my $cr = Cairo::Context->create($scaled_surface);
    $cr->scale(1 / $scale, 1 / $scale);
    $cr->set_source_surface($surface, 0, 0);
    $cr->paint();
    return $scaled_surface;
}

sub pixelize_area {
    my ($item, $surface) = @_;

    my $x = min($item->{x1}, $item->{x2});
    my $y = min($item->{y1}, $item->{y2});
    my $width = abs($item->{x2} - $item->{x1});
    my $height = abs($item->{y2} - $item->{y1});

    return unless $width > 0 && $height > 0;

    my $pixel_size = 10;  

    my $pixelated = Cairo::ImageSurface->create('argb32', $width, $height);
    my $cr = Cairo::Context->create($pixelated);

    $cr->set_source_surface($surface, -$x, -$y);
    $cr->paint();

    for (my $px = 0; $px < $width; $px += $pixel_size) {
        for (my $py = 0; $py < $height; $py += $pixel_size) {
         
            my $block_width = min($pixel_size, $width - $px);
            my $block_height = min($pixel_size, $height - $py);

            my $temp_surface = Cairo::ImageSurface->create('argb32', $block_width, $block_height);
            my $temp_cr = Cairo::Context->create($temp_surface);

            $temp_cr->set_source_surface($pixelated, -$px, -$py);
            $temp_cr->paint();

            my $mid_x = int($block_width / 2);
            my $mid_y = int($block_height / 2);
            my ($r, $g, $b, $a) = get_pixel_color($temp_surface, $mid_x, $mid_y);

            $cr->set_source_rgba($r/255, $g/255, $b/255, $a/255);
            $cr->rectangle($px, $py, $block_width, $block_height);
            $cr->fill();

            $temp_surface->finish();
        }
    }

    $item->{pixelated_surface} = $pixelated;
    
    return;
}

sub get_pixel_color {
    my ($surface, $x, $y) = @_;

    my $temp = Cairo::ImageSurface->create('argb32', 1, 1);
    my $temp_cr = Cairo::Context->create($temp);

    $temp_cr->set_source_surface($surface, -$x, -$y);
    $temp_cr->paint();

    my $data = $temp->get_data();
    my @bytes = unpack('C*', $data);

    $temp->finish();

    return ($bytes[2], $bytes[1], $bytes[0], $bytes[3]); 
}

sub apply_lighting_to_color {
    my ($base_color, $lighting_factor) = @_;

    return Gtk3::Gdk::RGBA->new(
        min(1.0, $base_color->red * $lighting_factor),
        min(1.0, $base_color->green * $lighting_factor),
        min(1.0, $base_color->blue * $lighting_factor),
        $base_color->alpha
    );
    
    return;
}

sub color_to_hash {
    my ($rgba) = @_;
    return unless defined $rgba;
    return {
        red   => $rgba->red,
        green => $rgba->green,
        blue  => $rgba->blue,
        alpha => $rgba->alpha
    };
    
    return;
}

sub hash_to_color {
    my ($hash) = @_;
    return unless defined $hash;
    return Gtk3::Gdk::RGBA->new(
        $hash->{red},
        $hash->{green},
        $hash->{blue},
        $hash->{alpha}
    );
    
    return;
}

sub select_item {
    my ($item, $handle) = @_;

    if (($is_drawing || $is_drawing_freehand) && $current_tool ne 'select') {
        return;
    }

    if ($current_tool eq 'select' && $is_multi_selecting) {
     
        unless (grep { $_ == $item } @selected_items) {
            push @selected_items, $item;
            $item->{selected} = 1;
            $item->{selection_order} = scalar(@selected_items);
            $current_item = $item;
            update_controls_for_item($item);
        }
    } else {
     
        deselect_all_items();
        return unless $item;

        $item->{selected} = 1;
        $current_item = $item;
        @selected_items = ($item);
        update_controls_for_item($item);
    }

    if ($handle) {
        $dragging = 1;
        $drag_handle = $handle;
    } else {
        $dragging = 0;
        $drag_handle = undef;
    }
    
    if ($item->{type} eq 'text') {
        if ($handle eq 'drag') {
            $item->{is_editing} = 0;
            $is_text_editing = 0;
        } else {
            $item->{is_editing} = 1;
            $is_text_editing = 1;
            start_cursor_blink();
        }
    }

    $drawing_area->grab_focus();
    $drawing_area->queue_draw();
    
    return;
}

sub deselect_all_items {
    foreach my $type (qw(lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines numbered-circles text_items svg_items magnifiers pixelize_items)) {
        next unless exists $items{$type} && defined $items{$type};
        foreach my $item (@{$items{$type}}) {
            if ($item->{type} eq 'text' && $item->{is_editing}) {
                cleanup_text_editing($item);
            }
            $item->{selected} = 0;
            $item->{selection_order} = undef;
        }
    }
    @selected_items = (); 
    $current_item = undef;
    $dragging = 0;
    $drag_handle = undef;
    
    return;
}


sub delete_selected_text {
    my ($text_item) = @_;
    return unless $text_item && has_selection($text_item);

    my $start = min($text_item->{selection_start}, $text_item->{selection_end});
    my $end = max($text_item->{selection_start}, $text_item->{selection_end});

    substr($text_item->{text}, $start, $end - $start) = '';

    $text_item->{cursor_pos} = $start;
    clear_selection($text_item);
    
    return;
}

sub get_array_type {
    my ($type) = @_;

    my %type_map = (
        'line' => 'lines',
        'single-arrow' => 'arrows',
        'double-arrow' => 'arrows',
        'rectangle' => 'rectangles',
        'ellipse' => 'ellipses',
        'triangle' => 'triangles',
        'tetragon' => 'tetragons',
        'pentagon' => 'pentagons',
        'pyramid' => 'pyramids',
        'cuboid' => 'cuboids',
        'freehand' => 'freehand-items',
        'highlighter' => 'highlighter-lines',
        'text' => 'text_items',
        'numbered-circle' => 'numbered-circles',
        'magnifier' => 'magnifiers',
        'pixelize' => 'pixelize_items',
        'svg' => 'svg_items',
        'crop_rect' => 'rectangles' 
    );

    return $type_map{$type} || $type . 's';
}

sub copy_item {
  
    my @targets = @selected_items ? @selected_items : ($current_item ? ($current_item) : ());
    return unless @targets;

    $clipboard_item = [ map { clone_item($_) } @targets ];
    
    $clipboard_action = 'copy';
    print scalar(@targets) . " items copied to clipboard.\n";
    
    return;
}

sub cut_item {

    copy_item();

    delete_item(); 
    
    $clipboard_action = 'cut';
    
    return;
}

sub paste_item {
    return unless defined $clipboard_item;

    my @items_to_paste;
    if (ref($clipboard_item) eq 'ARRAY') {
        @items_to_paste = @{$clipboard_item};
    } elsif (ref($clipboard_item) eq 'HASH') {
        @items_to_paste = ($clipboard_item);
    }
    return unless @items_to_paste;

    deselect_all_items();

    if (scalar(@items_to_paste) > 1) {
     
        my $previous_state = clone_current_state();
        push @undo_stack, {
            action => 'clear_all', 
            previous_state => $previous_state
        };
        if (scalar(@undo_stack) > $max_undo_levels) { shift @undo_stack; }
        @redo_stack = ();
        update_undo_redo_ui();
    }

    my $offset = 20; 

    foreach my $source_item (@items_to_paste) {
        my $new_item = clone_item($source_item);
        my $type = $new_item->{type};
        my $array_type = get_array_type($type);

        $new_item->{timestamp} = ++$global_timestamp;

        if ($type =~ /^(rectangle|ellipse|pixelize|crop_rect)$/) {
            $new_item->{x1} += $offset; $new_item->{y1} += $offset;
            $new_item->{x2} += $offset; $new_item->{y2} += $offset;
        }
        elsif ($type =~ /^(line|single-arrow|double-arrow)$/) {
            $new_item->{start_x} += $offset; $new_item->{start_y} += $offset;
            $new_item->{end_x} += $offset; $new_item->{end_y} += $offset;
            if ($new_item->{is_curved}) {
                $new_item->{control_x} += $offset; $new_item->{control_y} += $offset;
            }
        }
        elsif ($type =~ /^(triangle|tetragon|pentagon)$/) {
            foreach my $vertex (@{$new_item->{vertices}}) {
                $vertex->[0] += $offset; $vertex->[1] += $offset;
            }
            if ($type eq 'triangle') { update_triangle_midpoints($new_item); }
            elsif ($type eq 'tetragon') { update_tetragon_midpoints($new_item); }
            elsif ($type eq 'pentagon') { update_pentagon_midpoints($new_item); }
        }
        elsif ($type =~ /^(text|numbered-circle|svg|magnifier)$/) {
            $new_item->{x} += $offset;
            $new_item->{y} += $offset;
        }
        elsif ($type eq 'freehand' || $type eq 'highlighter') {
            for (my $i = 0; $i < @{$new_item->{points}}; $i += 2) {
                $new_item->{points}[$i] += $offset;
                $new_item->{points}[$i + 1] += $offset;
            }
        }
        elsif ($type eq 'pyramid') {
            $new_item->{base_left} += $offset; $new_item->{base_right} += $offset;
            $new_item->{base_front} += $offset; $new_item->{base_back} += $offset;
            $new_item->{apex_x} += $offset; $new_item->{apex_y} += $offset;
            update_pyramid_geometry($new_item);
        }
        elsif ($type eq 'cuboid') {
            $new_item->{front_left} += $offset; $new_item->{front_right} += $offset;
            $new_item->{front_top} += $offset; $new_item->{front_bottom} += $offset;
            $new_item->{back_left} += $offset; $new_item->{back_right} += $offset;
            $new_item->{back_top} += $offset; $new_item->{back_bottom} += $offset;
            update_cuboid_faces($new_item);
        }

        push @{$items{$array_type}}, $new_item;

        $new_item->{selected} = 1;
        push @selected_items, $new_item;

        if (scalar(@items_to_paste) == 1) {
            $current_item = $new_item;
            store_state_for_undo('create', $new_item);
        }
    }

    $current_item = $selected_items[-1] if @selected_items;

    $drawing_area->queue_draw();
    print scalar(@items_to_paste) . " items pasted.\n";
    
    return;
}

sub delete_item {

    my @targets = @selected_items;

    if (!@targets && $current_item) {
        @targets = ($current_item);
    }

    return unless @targets;

    if (scalar(@targets) > 1) {

        my $previous_state = clone_current_state();
        
        push @undo_stack, {
            action => 'clear_all', 
            previous_state => $previous_state
        };

        if (scalar(@undo_stack) > $max_undo_levels) { shift @undo_stack; }
        @redo_stack = ();
        update_undo_redo_ui();
        
    } else {

        store_state_for_undo('delete', $targets[0]);
    }

    foreach my $item (@targets) {
        my $type = $item->{type};
        my $array_type = get_array_type($type);

        if (exists $items{$array_type}) {
         
            @{$items{$array_type}} = grep { $_ != $item } @{$items{$array_type}};
        }
    }

    deselect_all_items();
    $drawing_area->queue_draw();
    
    print "Deleted " . scalar(@targets) . " items.\n";
    
    return;
}


sub anchor_item {
    my ($item) = @_;
    return unless defined $item;

    store_state_for_undo('modify', clone_item($item));

    $item->{anchored} = 1;

    $item->{selected} = 0;
    $current_item = undef;

    $drawing_area->queue_draw();

    print "Item anchored: type=$item->{type}, timestamp=$item->{timestamp}\n";
    
    return;
}

sub unanchor_item {
    my ($item) = @_;
    return unless defined $item;

    store_state_for_undo('modify', clone_item($item));

    $item->{anchored} = 0;

    $item->{selected} = 1;
    $current_item = $item;

    $drawing_area->queue_draw();

    print "Item unanchored: type=$item->{type}, timestamp=$item->{timestamp}\n";
    
    return;
}

sub clear_all_annotations {

    if (@selected_items || $current_item) {
        delete_item();
        return;
    }

    my $previous_state = clone_current_state();

    %items = (
        'lines' => [],
        'dashed-lines' => [],
        'arrows' => [],
        'rectangles' => [],
        'ellipses' => [],
        'triangles' => [],
        'tetragons' => [],
        'pentagons' => [],
        'pyramids' => [],
        'cuboids' => [],
        'freehand-items' => [],
        'highlighter-lines' => [],
        'numbered-circles' => [],
        'text_items' => [],
        'magnifiers' => [],
        'pixelize_items' => [],
        'svg_items' => []
    );

    $current_item = undef;
    $is_drawing = 0;
    $dragging = 0;
    $drag_handle = undef;
    $is_text_editing = 0;
    $current_number = 1;
    @selected_items = ();

    push @undo_stack, {
        action => 'clear_all',
        previous_state => $previous_state
    };

    if (scalar(@undo_stack) > $max_undo_levels) { shift @undo_stack; }
    @redo_stack = ();
    update_undo_redo_ui();

    $drawing_area->queue_draw();
    print "Canvas cleared.\n";
    
    return;
}

sub start_cursor_blink {
    return if $cursor_blink_timeout;
    $cursor_visible = 1;
    $cursor_blink_timeout = Glib::Timeout->add(500, sub {
        return FALSE unless $is_text_editing;
        $cursor_visible = !$cursor_visible;
        $drawing_area->queue_draw();
        return TRUE;
    });
    
    return;
}

sub stop_cursor_blink {
    if ($cursor_blink_timeout) {
        Glib::Source->remove($cursor_blink_timeout);
        $cursor_blink_timeout = undef;
    }
    $cursor_visible = 0;
    
    return;
}

sub cleanup_text_editing {
    my ($text_item) = @_;
    
    stop_cursor_blink();
    $text_item->{is_editing} = 0;
    $cursor_visible = 0;
    $is_text_editing = 0;

    $drawing_area->queue_draw();
    
    return;
}

# Layer Management:

sub raise_to_top {
    my ($item) = @_;
    return unless $item;

    store_state_for_undo('modify', clone_item($item));

    my $max_timestamp = get_max_timestamp();
    $item->{timestamp} = $max_timestamp + 1;
    $global_timestamp = $item->{timestamp};

    $drawing_area->queue_draw();
    print "Item raised to top: timestamp=$item->{timestamp}\n";
    
    return;
}

sub raise_one_step {
    my ($item) = @_;
    return unless $item;

    store_state_for_undo('modify', clone_item($item));

    my $next_higher_item = find_next_higher_item($item);
    if ($next_higher_item) {

        my $temp_timestamp = $item->{timestamp};
        $item->{timestamp} = $next_higher_item->{timestamp};
        $next_higher_item->{timestamp} = $temp_timestamp;

        $drawing_area->queue_draw();
        print "Item raised one step: new timestamp=$item->{timestamp}\n";
    }
    
    return;
}

sub lower_one_step {
    my ($item) = @_;
    return unless $item;

    store_state_for_undo('modify', clone_item($item));

    my $next_lower_item = find_next_lower_item($item);
    if ($next_lower_item) {

        my $temp_timestamp = $item->{timestamp};
        $item->{timestamp} = $next_lower_item->{timestamp};
        $next_lower_item->{timestamp} = $temp_timestamp;

        $drawing_area->queue_draw();
        print "Item lowered one step: new timestamp=$item->{timestamp}\n";
    }
    
    return;
}

sub lower_to_bottom {
    my ($item) = @_;
    return unless $item;

    store_state_for_undo('modify', clone_item($item));

    my $min_timestamp = get_min_timestamp();
    $item->{timestamp} = $min_timestamp - 1;

    $drawing_area->queue_draw();
    print "Item lowered to bottom: timestamp=$item->{timestamp}\n";
    
    return;
}

sub get_max_timestamp {
    my $max = 0;

    foreach my $type (qw(text_items svg_items magnifiers numbered-circles lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines pixelize_items)) {
        if (exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY') {
            foreach my $item (grep { defined $_ } @{$items{$type}}) {
                $max = $item->{timestamp} if $item->{timestamp} > $max;
            }
        }
    }

    return $max;
}

sub get_min_timestamp {
    my $min = $global_timestamp;

    foreach my $type (qw(text_items svg_items magnifiers numbered-circles lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines pixelize_items)) {
        if (exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY') {
            foreach my $item (grep { defined $_ } @{$items{$type}}) {
                $min = $item->{timestamp} if $item->{timestamp} < $min;
            }
        }
    }

    return $min;
}

sub find_next_higher_item {
    my ($target_item) = @_;
    my $target_timestamp = $target_item->{timestamp};
    my $next_higher_item = undef;
    my $next_higher_timestamp = undef;

    foreach my $type (qw(text_items svg_items magnifiers numbered-circles lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines pixelize_items)) {
        if (exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY') {
            foreach my $item (grep { defined $_ } @{$items{$type}}) {
                next if $item == $target_item;  

                if ($item->{timestamp} > $target_timestamp) {
                    if (!defined $next_higher_timestamp || $item->{timestamp} < $next_higher_timestamp) {
                        $next_higher_timestamp = $item->{timestamp};
                        $next_higher_item = $item;
                    }
                }
            }
        }
    }

    return $next_higher_item;
}

sub find_next_lower_item {
    my ($target_item) = @_;
    my $target_timestamp = $target_item->{timestamp};
    my $next_lower_item = undef;
    my $next_lower_timestamp = undef;

    foreach my $type (qw(text_items svg_items magnifiers numbered-circles lines dashed-lines arrows rectangles ellipses triangles tetragons pentagons pyramids cuboids freehand-items highlighter-lines pixelize_items)) {
        if (exists $items{$type} && defined $items{$type} && ref($items{$type}) eq 'ARRAY') {
            foreach my $item (grep { defined $_ } @{$items{$type}}) {
                next if $item == $target_item; 

                if ($item->{timestamp} < $target_timestamp) {
                    if (!defined $next_lower_timestamp || $item->{timestamp} > $next_lower_timestamp) {
                        $next_lower_timestamp = $item->{timestamp};
                        $next_lower_item = $item;
                    }
                }
            }
        }
    }

    return $next_lower_item;
}


sub store_state_for_undo {
    my ($action_type, $item) = @_;
    
    $project_is_modified = 1;
    return if not defined $item;
    
    my $state = {
        action => $action_type,
        item => clone_item($item), 
        timestamp => time()
    };

    if ($action_type eq 'modify') {

    }

    push @undo_stack, $state;

    if (scalar(@undo_stack) > $max_undo_levels) {
        shift @undo_stack; 
    }

    @redo_stack = (); 

    update_undo_redo_ui();
    
    return;
}

sub do_undo {
    return unless @undo_stack;

    my $action = pop @undo_stack;
    my $current_state_snapshot = undef;

    my $type = $action->{item}{type};
    my $array_type = get_array_type($type);

    if ($action->{action} eq 'create') {
      
        @{$items{$array_type}} = grep { $_->{timestamp} != $action->{item}{timestamp} } @{$items{$array_type}};
        $current_state_snapshot = $action->{item}; 
    }
    elsif ($action->{action} eq 'modify') {
    
        for my $i (0..$#{$items{$array_type}}) {
            if ($items{$array_type}[$i]{timestamp} == $action->{item}{timestamp}) {
             
                $current_state_snapshot = clone_item($items{$array_type}[$i]);
  
                $items{$array_type}[$i] = clone_item($action->{item});
                last;
            }
        }
    }
    elsif ($action->{action} eq 'delete') {
    
        push @{$items{$array_type}}, clone_item($action->{item});
        $current_state_snapshot = $action->{item};
    }
    elsif ($action->{action} eq 'clear_all') {
   
        %items = %{$action->{previous_state}};
    }
    elsif ($action->{action} eq 'crop') {

        if ($action->{temp_image_file} && -f $action->{temp_image_file}) {
            $image_surface = Cairo::ImageSurface->create_from_png($action->{temp_image_file});
            $original_width = $action->{previous_width};
            $original_height = $action->{previous_height};

            %items = %{$action->{previous_items}};

            if ($action->{crop_rect}) {
                my $restored_crop_rect = clone_item($action->{crop_rect});
                $restored_crop_rect->{selected} = 1;
                push @{$items{rectangles}}, $restored_crop_rect;
                $current_item = $restored_crop_rect;

                $current_tool = 'crop';
                update_tool_widgets('crop');
            }

            if (defined $preview_surface) {
                $preview_surface->finish();
                undef $preview_surface;
                $preview_ratio = 1.0;
            }
            
            $scale_factor = 1.0;
            zoom_fit_best();
        }
    }

    push @redo_stack, {
        action => $action->{action},
        item => $current_state_snapshot, 
        old_state => $action->{item},  
        previous_state => ($action->{action} eq 'clear_all' ? clone_current_state() : undef),

        ($action->{action} eq 'crop' ? (
            temp_image_file => $action->{temp_image_file},
            previous_width => $action->{previous_width},
            previous_height => $action->{previous_height},
            previous_items => $action->{previous_items},
            crop_rect => $action->{crop_rect}
        ) : ())
    };

    unless ($action->{action} eq 'crop') {
        $current_item = undef;
    }
    $dragging = 0;
    $drawing_area->queue_draw();
    update_undo_redo_ui(); 
    print "Undo performed: " . $action->{action} . "\n";
    
    return;
}

sub do_redo {
    return unless @redo_stack;

    my $action = pop @redo_stack;
    
    my $type = $action->{item}{type} if $action->{item};
    my $array_type = get_array_type($type) if $type;

    if ($action->{action} eq 'create') {
    
        push @{$items{$array_type}}, clone_item($action->{item});
    }
    elsif ($action->{action} eq 'modify') {
      
        for my $i (0..$#{$items{$array_type}}) {
            if ($items{$array_type}[$i]{timestamp} == $action->{item}{timestamp}) {
                $items{$array_type}[$i] = clone_item($action->{item});
                last;
            }
        }
    }
    elsif ($action->{action} eq 'delete') {
      
        @{$items{$array_type}} = grep { $_->{timestamp} != $action->{item}{timestamp} } @{$items{$array_type}};
    }
    elsif ($action->{action} eq 'clear_all') {
       
        clear_all_annotations();

        %items = (
            'lines'=>[], 'arrows'=>[], 'rectangles'=>[], 'ellipses'=>[], 
            'triangles'=>[], 'tetragons'=>[], 'pentagons'=>[], 'pyramids'=>[], 'cuboids'=>[],
            'freehand-items'=>[], 'highlighter-lines'=>[], 'numbered-circles'=>[], 
            'text_items'=>[], 'magnifiers'=>[], 'pixelize_items'=>[], 'svg_items'=>[]
        );
    }
    elsif ($action->{action} eq 'crop') {

        print "Crop redo not supported - please crop again if needed\n";
    }

    push @undo_stack, {
        action => $action->{action},
        item => clone_item($action->{old_state}),
        previous_state => $action->{previous_state}
    };

    $drawing_area->queue_draw();
    update_undo_redo_ui();
    print "Redo performed: " . $action->{action} . "\n";
    
    return;
}

sub undo_item {
    do_undo();
    return TRUE;
}

sub redo_item {
    do_redo();
    return TRUE;
}

sub update_undo_redo_ui {
    my $can_undo = scalar(@undo_stack) > 0;
    my $can_redo = scalar(@redo_stack) > 0;

    if ($tool_buttons{'undo'}) {
        $tool_buttons{'undo'}->set_sensitive($can_undo);
    }
    if ($tool_buttons{'redo'}) {
        $tool_buttons{'redo'}->set_sensitive($can_redo);
    }

    eval { $undo_item->set_sensitive($can_undo) if defined $undo_item; };
    eval { $redo_item->set_sensitive($can_redo) if defined $redo_item; };
    
    return;
}

sub store_original_state {
    my ($item) = @_;

    if ($item->{type} =~ /arrow/) {
        $item->{original_end_x} = $item->{end_x};
        $item->{original_end_y} = $item->{end_y};
    }

    if ($item->{type} =~ /^(rectangle|ellipse)$/) {
        $item->{original_x1} = $item->{x1};
        $item->{original_y1} = $item->{y1};
        $item->{original_x2} = $item->{x2};
        $item->{original_y2} = $item->{y2};
        $item->{original_width} = abs($item->{x2} - $item->{x1});
        $item->{original_height} = abs($item->{y2} - $item->{y1});
        $item->{center_x} = ($item->{x1} + $item->{x2}) / 2;
        $item->{center_y} = ($item->{y1} + $item->{y2}) / 2;
    }

    if (defined $item->{stroke_color}) {
        $item->{original_stroke_red} = $item->{stroke_color}->red;
        $item->{original_stroke_green} = $item->{stroke_color}->green;
        $item->{original_stroke_blue} = $item->{stroke_color}->blue;
        $item->{original_stroke_alpha} = $item->{stroke_color}->alpha;
    }

    if (defined $item->{fill_color}) {
        $item->{original_fill_red} = $item->{fill_color}->red;
        $item->{original_fill_green} = $item->{fill_color}->green;
        $item->{original_fill_blue} = $item->{fill_color}->blue;
        $item->{original_fill_alpha} = $item->{fill_color}->alpha;
    }

    $item->{original_line_style} = $item->{line_style} if defined $item->{line_style};

    $item->{original_rotation} = $item->{rotation} // 0;

    print "Stored original state for item type: $item->{type}\n";
    
    return;
}

sub restore_original_state {
    my ($item) = @_;

    if ($item->{type} =~ /arrow/) {
        $item->{end_x} = $item->{original_end_x} if defined $item->{original_end_x};
        $item->{end_y} = $item->{original_end_y} if defined $item->{original_end_y};
    }

    if ($item->{type} =~ /^(rectangle|ellipse)$/) {
        $item->{x1} = $item->{original_x1} if defined $item->{original_x1};
        $item->{y1} = $item->{original_y1} if defined $item->{original_y1};
        $item->{x2} = $item->{original_x2} if defined $item->{original_x2};
        $item->{y2} = $item->{original_y2} if defined $item->{original_y2};
    }

    if (defined $item->{stroke_color} && defined $item->{original_stroke_alpha}) {
        $item->{stroke_color}->red = $item->{original_stroke_red};
        $item->{stroke_color}->green = $item->{original_stroke_green};
        $item->{stroke_color}->blue = $item->{original_stroke_blue};
        $item->{stroke_color}->alpha = $item->{original_stroke_alpha};
    }

    if (defined $item->{fill_color} && defined $item->{original_fill_alpha}) {
        $item->{fill_color}->red = $item->{original_fill_red};
        $item->{fill_color}->green = $item->{original_fill_green};
        $item->{fill_color}->blue = $item->{original_fill_blue};
        $item->{fill_color}->alpha = $item->{original_fill_alpha};
    }

    if (defined $item->{original_line_style}) {
        $item->{line_style} = $item->{original_line_style};
    }
    
    return;
}

# Printing:

sub on_begin_print {
    my ($print_operation, $context) = @_;

    $print_operation->set_n_pages(1);
    
    return;
}

sub on_draw_page {
    my ($print_operation, $context, $page_nr) = @_;

    my $cr = $context->get_cairo_context();
    
    return;
}