/*
* SPDX-License-Identifier: GPL-2.0-or-later
* SPDX-FileCopyrightText: 2015-2025 elementary, Inc. (https://elementary.io)
*/

public class Sound.Widgets.Scale : Granite.Bin {
    public signal void scroll_event (Gdk.ScrollEvent e);
    public signal void slider_dropped ();

    public Gtk.Adjustment adjustment { get; construct; }
    public string icon { get; set; }

    public bool active { get; set; default = true; }

    public Scale (Gtk.Adjustment adjustment) {
        Object (adjustment: adjustment);
    }

    class construct {
        set_css_name ("device-scale");
    }

    construct {
        var toggle = new Gtk.ToggleButton ();

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
        box.append (toggle);
        box.append (scale_widget);

        child = box;

        var gesture_click = new Gtk.GestureClick ();
        gesture_click.released.connect (() => {
            slider_dropped ();
        });

        var scroll_controller = new Gtk.EventControllerLegacy ();
        scroll_controller.event.connect_after ((e) => {
            if (e.get_event_type () != Gdk.EventType.SCROLL) {
                return Gdk.EVENT_PROPAGATE;
            }

            scroll_event ((Gdk.ScrollEvent) e);

            return Gdk.EVENT_STOP;
        });

        scale_widget.add_controller (gesture_click);
        scale_widget.add_controller (scroll_controller);

        bind_property ("icon", toggle, "icon-name");

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
