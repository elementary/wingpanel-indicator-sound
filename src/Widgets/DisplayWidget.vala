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

public class DisplayWidget : Gtk.Grid {
    public bool show_mic { get; set; }
    public string icon_name { get; set; }
    private bool ignore_next_event = false;
    public string mic_icon_name { get; set; }

    public signal void volume_scroll_event (Gdk.EventScroll e);
    public signal void mic_scroll_event (Gdk.EventScroll e);

    public signal void volume_press_event (Gdk.EventButton e);
    public signal void mic_press_event (Gdk.EventButton e);

    construct {
        var volume_icon = new Gtk.Image ();
        volume_icon.pixel_size = 24;

        var mic_icon = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        mic_icon.pixel_size = 24;
        mic_icon.margin_end = 18;

        var mic_revealer = new Gtk.Revealer ();
        mic_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        mic_revealer.add (mic_icon);

        valign = Gtk.Align.CENTER;
        add (mic_revealer);
        add (volume_icon);

        /* SMOOTH_SCROLL_MASK has no effect on this widget for reasons that are not
         * entirely clear.  Only normal scroll events are received even if the SMOOTH_SCROLL_MASK
         * is set. */
        scroll_event.connect ((e) => {
            /* Ignore horizontal scrolling on wingpanel indicator */
            if (e.direction != Gdk.ScrollDirection.LEFT && e.direction != Gdk.ScrollDirection.RIGHT) {
                /* Determine whether scrolling on mic icon or not */
                if (show_mic && e.x < mic_icon.pixel_size + mic_icon.margin_end) {
                    mic_scroll_event (e);
                } else {
                    volume_scroll_event (e);
                }
            }

            return true;
        });

        button_press_event.connect ((e) => {
            /* Determine whether scrolling on mic icon or not */
            if (show_mic && e.x < mic_icon.pixel_size + mic_icon.margin_end) {
                mic_press_event (e);
            } else {
                volume_press_event (e);
            }
            return Gdk.EVENT_PROPAGATE;
        });

        bind_property ("icon-name", volume_icon, "icon-name", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);
        bind_property ("mic-icon-name", mic_icon, "icon-name", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);
        bind_property ("show-mic", mic_revealer, "reveal-child", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);
    }

    /* Diagonal scrolling causes a mixture of horizontal and vertical events.
     * We ignore horizontal and "impure" scrolling by only passing on every other vertical event.
     * This avoids jerky changes when horizontal scrolling with touchpad is attempted.
     */
    private bool ignore_scroll_event (Gdk.EventScroll e) {
        if (ignore_next_event) {
            ignore_next_event = false;
            return true;
        } else {
            ignore_next_event = true;
        }

        if (e.direction == Gdk.ScrollDirection.LEFT || e.direction == Gdk.ScrollDirection.RIGHT) {
            return true;
        } else {
            return false;
        }
    }
}
