/*
* Copyright 2015-2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

public class Sound.Widgets.Scale : Gtk.EventBox {
    public string icon { get; set; }
    public bool active { get; construct set; }
    public double max { get; construct; }
    public double min { get; construct; }
    public double step { get; construct; }
    public Gtk.Scale scale_widget { get; private set; }

    public Scale (string icon, bool active = false, double min, double max, double step) {
        Object (
            active: active,
            icon: icon,
            max: max,
            min: min,
            step: step
        );
    }

    class construct {
        set_css_name (Gtk.STYLE_CLASS_MENUITEM);
    }

    construct {
        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.DIALOG) {
            pixel_size = 48
        };

        var image_box = new Gtk.EventBox ();
        image_box.add (image);

        scale_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step) {
            draw_value = false,
            hexpand = true,
            width_request = 175
        };

        var switch_widget = new Gtk.Switch () {
            margin_start = 6,
            valign = Gtk.Align.CENTER
        };

        var grid = new Gtk.Grid () {
            column_spacing = 6,
            hexpand = true,
            margin_start = 6,
            margin_end = 12
        };
        grid.add (image_box);
        grid.add (scale_widget);
        grid.add (switch_widget);

        add (grid);
        add_events (Gdk.EventMask.SMOOTH_SCROLL_MASK);
        set_above_child (false);

        image_box.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
        image_box.button_release_event.connect (() => {
            switch_widget.active = !switch_widget.active;
            return Gdk.EVENT_STOP;
        });

        scale_widget.scroll_event.connect ((e) => {
            /* Re-emit the signal on the eventbox instead of using native handler */
            scroll_event (e);
            return true;
        });

        bind_property ("icon", image, "icon-name");

        bind_property ("active", scale_widget, "sensitive", BindingFlags.SYNC_CREATE);
        bind_property ("active", image, "sensitive", BindingFlags.SYNC_CREATE);
        switch_widget.bind_property ("active", this, "active", BindingFlags.BIDIRECTIONAL);
    }
}
