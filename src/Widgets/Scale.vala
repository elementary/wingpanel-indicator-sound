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

    private static Gtk.CssProvider provider;

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

    static construct {
        provider = new Gtk.CssProvider ();
        provider.load_from_resource ("io/elementary/wingpanel/sound/Indicator.css");
    }

    construct {
        var image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.MENU);
        image.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        image.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var image_box = new Gtk.EventBox () {
            halign = Gtk.Align.START
        };
        image_box.add (image);

        scale_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step) {
            draw_value = false,
            hexpand = true
        };
        scale_widget.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var overlay = new Gtk.Overlay ();
        overlay.add (scale_widget);
        overlay.add_overlay (image_box);

        margin_top = 6;
        margin_start = 12;
        margin_end = 12;
        add (overlay);
        add_events (Gdk.EventMask.SMOOTH_SCROLL_MASK);
        above_child = false;

        image_box.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
        image_box.button_release_event.connect (() => {
            active = !active;
            return Gdk.EVENT_STOP;
        });

        scale_widget.scroll_event.connect ((e) => {
            /* Re-emit the signal on the eventbox instead of using native handler */
            scroll_event (e);
            return Gdk.EVENT_STOP;
        });

        bind_property ("icon", image, "icon-name");
        bind_property ("active", scale_widget, "sensitive", BindingFlags.SYNC_CREATE);
        bind_property ("active", image, "sensitive", BindingFlags.SYNC_CREATE);
    }
}
