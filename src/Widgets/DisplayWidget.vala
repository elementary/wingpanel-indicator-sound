/*
* Copyright (c) 2016-2017 elementary LLC. (http://launchpad.net/wingpanel-indicator-sound)
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
* You should have received a copy of the GNU Library General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

public class DisplayWidget : Gtk.Grid {
    private Gtk.Image volume_icon;
    private Gtk.Revealer mic_revealer;

    public bool show_mic {
        set {
            mic_revealer.reveal_child = value;
        }
    }

    public string icon_name {
        set {
            volume_icon.icon_name = value;
        }
    }

    construct {
        volume_icon = new Gtk.Image ();
        volume_icon.icon_name = "audio-volume-high-symbolic";
        volume_icon.icon_size = Gtk.IconSize.LARGE_TOOLBAR;

        var mic_icon = new Gtk.Image.from_icon_name ("audio-input-microphone-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        mic_icon.margin_start = 12;

        mic_revealer = new Gtk.Revealer ();
        mic_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        mic_revealer.add (mic_icon);

        add (volume_icon);
        add (mic_revealer);
    }
}
