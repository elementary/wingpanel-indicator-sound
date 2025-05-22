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

    public signal void volume_scroll_event (Gdk.EventScroll e);
    public signal void mic_scroll_event (Gdk.EventScroll e);

    construct {
        var volume_icon = new Gtk.Image () {
            pixel_size = 24
        };

        var mic_icon = new Gtk.Spinner () {
            margin_end = 18
        };

        var mic_style_context = mic_icon.get_style_context ();
        mic_style_context.add_class ("mic-icon");

        var mic_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT
        };
        mic_revealer.add (mic_icon);

        valign = Gtk.Align.CENTER;
        add (mic_revealer);
        add (volume_icon);

        /* SMOOTH_SCROLL_MASK has no effect on this widget for reasons that are not
         * entirely clear. Only normal scroll events are received even if the SMOOTH_SCROLL_MASK
         * is set. */
        scroll_event.connect ((e) => {
            /* Determine whether scrolling on mic icon or not */
            if (show_mic && e.x < mic_icon.get_allocated_width () + mic_icon.margin_end) {
                mic_scroll_event (e);
            } else {
                volume_scroll_event (e);
            }

            return Gdk.EVENT_STOP;
        });

        button_press_event.connect ((e) => {
            if (e.button != Gdk.BUTTON_MIDDLE) {
                return Gdk.EVENT_PROPAGATE;
            }

            /* Determine whether scrolling on mic icon or not */
            if (show_mic && e.x < 24 + mic_icon.margin_end) {
                mic_press_event ();
            } else {
                volume_press_event ();
            }

            return Gdk.EVENT_PROPAGATE;
        });

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
                mic_style_context.add_class ("disabled");
            } else {
                mic_style_context.remove_class ("disabled");
            }
        });
    }
}
