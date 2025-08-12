/*
* Copyright (c) 2016-2018 elementary, Inc. (https://elementary.io)
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

public class Sound.DisplayWidget : Gtk.Box {
    public signal void volume_press_event ();
    public signal void mic_press_event ();

    public bool show_mic { get; set; }
    public bool mic_muted { get; set; }
    public string icon_name { get; set; }

    // public signal void volume_scroll_event (Gdk.EventScroll e);
    // public signal void mic_scroll_event (Gdk.EventScroll e);

    construct {
        var volume_icon = new Gtk.Image () {
            pixel_size = 24
        };

        var volume_event_box = new Gtk.EventBox () {
            child = volume_icon
        };
        volume_event_box.events = SCROLL_MASK | SMOOTH_SCROLL_MASK | BUTTON_PRESS_MASK | BUTTON_RELEASE_MASK;

        var mic_icon = new Gtk.Spinner () {
            margin_end = 18
        };
        mic_icon.get_style_context ().add_class ("mic-icon");

        var mic_event_box = new Gtk.EventBox () {
            child = mic_icon
        };
        mic_event_box.events = SCROLL_MASK | SMOOTH_SCROLL_MASK | BUTTON_PRESS_MASK | BUTTON_RELEASE_MASK;

        var mic_revealer = new Gtk.Revealer () {
            child = mic_event_box,
            transition_type = SLIDE_LEFT
        };

        valign = Gtk.Align.CENTER;
        add (mic_revealer);
        add (volume_event_box);

        /* SMOOTH_SCROLL_MASK has no effect on this widget for reasons that are not
         * entirely clear. Only normal scroll events are received even if the SMOOTH_SCROLL_MASK
         * is set. */
        mic_event_box.scroll_event.connect ((e) => {
            // mic_scroll_event (e);
            return Gdk.EVENT_STOP;
        });

        volume_event_box.scroll_event.connect ((e) => {
            // volume_scroll_event (e);
            return Gdk.EVENT_STOP;
        });

        var mic_gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_MIDDLE
        };
        mic_gesture_click.pressed.connect (() => {
            mic_press_event ();
            mic_gesture_click.set_state (CLAIMED);
            mic_gesture_click.reset ();
        });

        mic_event_box.add_controller (mic_gesture_click);

        var volume_gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_MIDDLE
        };
        volume_gesture_click.pressed.connect (() => {
            volume_press_event ();
            volume_gesture_click.set_state (CLAIMED);
            volume_gesture_click.reset ();
        });

        volume_event_box.add_controller (volume_gesture_click);

        bind_property (
            "icon-name",
            volume_icon,
            "icon-name",
            GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE
        );
        bind_property (
            "show-mic",
            mic_revealer,
            "reveal-child",
            GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE
        );

        notify["mic-muted"].connect (() => {
            if (mic_muted) {
                mic_icon.get_style_context ().add_class ("disabled");
            } else {
                mic_icon.get_style_context ().remove_class ("disabled");
            }
        });
    }
}
