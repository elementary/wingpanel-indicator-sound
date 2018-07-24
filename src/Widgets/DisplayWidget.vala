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

    construct {
        var volume_icon = new Gtk.Image ();
        volume_icon.pixel_size = 24;

        var mic_icon = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        mic_icon.margin_end = 18;

        var mic_revealer = new Gtk.Revealer ();
        mic_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        mic_revealer.add (mic_icon);

        valign = Gtk.Align.CENTER;
        add (mic_revealer);
        add (volume_icon);

        bind_property ("icon-name", volume_icon, "icon-name", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);
        bind_property ("show-mic", mic_revealer, "reveal-child", GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE);
    }
}
