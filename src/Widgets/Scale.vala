/*
* SPDX-License-Identifier: GPL-2.0-or-later
* SPDX-FileCopyrightText: 2015-2025 elementary, Inc. (https://elementary.io)
*/

public class Sound.Widgets.Scale : Gtk.EventBox {
    public signal void slider_dropped ();

    public Gtk.Adjustment adjustment { get; construct; }
    public string icon { get; set; }

    public bool active { get; set; default = true; }

    private Gtk.GestureMultiPress gesture_click;

    public Scale (Gtk.Adjustment adjustment) {
        Object (adjustment: adjustment);
    }

    class construct {
        set_css_name ("device-scale");
    }

    construct {
        var image = new Gtk.Image ();

        var toggle = new Gtk.ToggleButton ();
        toggle.image = image;

        var scale_widget = new Gtk.Scale (HORIZONTAL, adjustment) {
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

        child = box;
        add_events (Gdk.EventMask.SMOOTH_SCROLL_MASK);
        above_child = false;

        gesture_click = new Gtk.GestureMultiPress (scale_widget);
        gesture_click.released.connect (() => {
            slider_dropped ();
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
