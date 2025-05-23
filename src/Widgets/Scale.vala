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
    public signal void slider_dropped ();

    public Gtk.Adjustment adjustment { get; construct; }
    public string icon { get; construct set; }

    public bool active { get; set; default = true; }
    public Gtk.Scale scale_widget { get; private set; }

    public Scale (string icon, Gtk.Adjustment adjustment) {
        Object (
            icon: icon,
            adjustment: adjustment
        );
    }

    class construct {
        set_css_name (Gtk.STYLE_CLASS_MENUITEM);
    }

    construct {
        var image = new Gtk.Image.from_icon_name (icon, BUTTON);

        var toggle = new Gtk.ToggleButton ();
        toggle.image = image;

        scale_widget = new Gtk.Scale (HORIZONTAL, adjustment) {
            draw_value = false,
            hexpand = true,
            width_request = 175
        };

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            hexpand = true,
            margin_top = 6,
            margin_start = 6,
            margin_bottom = 6,
            margin_end = 12
        };
        box.add (toggle);
        box.add (scale_widget);

        add (box);
        add_events (Gdk.EventMask.SMOOTH_SCROLL_MASK);
        above_child = false;

        scale_widget.button_release_event.connect (() => {
            slider_dropped ();
            return Gdk.EVENT_PROPAGATE;
        });

        scale_widget.scroll_event.connect ((e) => {
            /* Re-emit the signal on the eventbox instead of using native handler */
            scroll_event (e);
            return Gdk.EVENT_STOP;
        });

        bind_property ("icon", image, "icon-name");

        bind_property ("active", scale_widget, "sensitive", BindingFlags.SYNC_CREATE);
        bind_property ("active", toggle, "active", BIDIRECTIONAL | SYNC_CREATE);
        bind_property ("active", toggle, "tooltip-text", SYNC_CREATE, (binding, srcval, ref targetval) => {
            if ((bool) srcval) {
                targetval.set_string (_("Mute"));
            } else {
                targetval.set_string (_("Unmute"));
            }

            return true;
        }, null);
    }
}
