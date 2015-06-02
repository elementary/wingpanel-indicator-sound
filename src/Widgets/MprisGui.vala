/*
 * MprisGui.vala
 *
 * Copyright
 * 2014 Ikey Doherty <ikey.doherty@gmail.com>
 * 2015 Wingpanel Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 */

const int ICON_SIZE = 48;

/**
 * A ClientWidget is simply used to control and display information in a two-way
 * fashion with an underlying MPRIS provider  (MediaPlayer2)
 * It is "designed" to be self contained and added to a large UI, enabling multiple
 * MPRIS clients to be controlled with multiple widgets
 */
public class Sound.Widgets.ClientWidget : Gtk.Box {
    Gtk.Revealer player_revealer;
    Gtk.Image? background = null;
    Services.MprisClient client;
    Gtk.Label title_label;
    Gtk.Label artist_label;
    Gtk.Button prev_btn;
    Gtk.Button play_btn;
    Gtk.Button next_btn;
    Icon? app_icon = null;
    string app_name = _("Not available");
    Cancellable load_remote_art_cancel;

    /**
     * Create a new ClientWidget
     *
     * @param client The underlying MprisClient instance to use
     */
    public ClientWidget (Services.MprisClient client) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

        this.client = client;
        load_remote_art_cancel = new Cancellable ();

        player_revealer = new Gtk.Revealer ();
        player_revealer.reveal_child = true;
        var player_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        if  (client.player.desktop_entry != "") {
            var ainfo = new DesktopAppInfo (client.player.desktop_entry + ".desktop");
            if  (ainfo != null) {
                app_icon = ainfo.get_icon ();
                background = new Gtk.Image.from_gicon (app_icon, Gtk.IconSize.DIALOG);
                app_name = ainfo.get_display_name ();
                if  (app_name == "")
                    app_name = ainfo.get_name ();
            }
        }
        if  (app_icon == null) {
            app_icon = new ThemedIcon ("emblem-music-symbolic");
            background.set_from_icon_name ("emblem-music-symbolic", Gtk.IconSize.DIALOG);
        }

        background.margin_start = 6;
        background.margin_end = 6;

        player_box.pack_start (background, false, false, 0);

        var titles = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        titles.set_valign (Gtk.Align.CENTER);
        title_label = new Gtk.Label ("");
        title_label.set_use_markup (true);
        title_label.set_line_wrap (true);
        title_label.set_line_wrap_mode (Pango.WrapMode.WORD);
        title_label.halign = Gtk.Align.START;
        titles.pack_start (title_label, false, false, 0);
        artist_label =  new Gtk.Label ("");
        artist_label.set_line_wrap (true);
        artist_label.set_line_wrap_mode (Pango.WrapMode.WORD);
        artist_label.halign = Gtk.Align.START;
        titles.pack_start (artist_label, false, false, 0);
        player_box.pack_start (titles, false, false, 0);

        var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        var btn = new Gtk.Button.from_icon_name ("media-seek-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        btn.set_sensitive (false);
        btn.set_relief (Gtk.ReliefStyle.NONE);
        prev_btn = btn;
        btn.clicked.connect (()=> {
            Idle.add (()=> {
                if  (client.player.can_go_previous) {
                    try {
                        client.player.previous ();
                    } catch  (Error e) {
                        warning  ("Could not go to previous track: %s", e.message);
                    }
                }
                return false;
            });
        });
        controls.pack_start (btn, false, false, 0);

        btn = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        play_btn = btn;
        btn.set_relief (Gtk.ReliefStyle.NONE);
        btn.clicked.connect (()=> {
            Idle.add (()=> {
                try {
                    client.player.play_pause ();
                } catch  (Error e) {
                    warning ("Could not play/pause: %s", e.message);
                }
                return false;
            });
        });
        controls.pack_start (btn, false, false, 0);

        btn = new Gtk.Button.from_icon_name ("media-seek-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        btn.set_sensitive (false);
        btn.set_relief  (Gtk.ReliefStyle.NONE);
        next_btn = btn;
        btn.clicked.connect (()=> {
            Idle.add (()=> {
                if (client.player.can_go_next) {
                    try {
                        client.player.next ();
                    } catch  (Error e) {
                        warning ("Could not go to next track: %s", e.message);
                    }
                }
                return false;
            });
        });
        controls.pack_start (btn, false, false, 0);

        controls.set_halign (Gtk.Align.CENTER);
        controls.set_valign (Gtk.Align.CENTER);
        controls.margin_end = 12;

        player_box.pack_end (controls, false, false, 0);

        update_from_meta ();
        update_play_status ();
        update_controls ();

        client.prop.properties_changed.connect ((i,p,inv)=> {
            if  (i == "org.mpris.MediaPlayer2.Player") {
                /* Handle mediaplayer2 iface */
                p.foreach ((k,v)=> {
                    if (k == "Metadata") {
                        Idle.add (()=> {
                            update_from_meta ();
                            return false;
                        });
                    } else if (k == "PlaybackStatus") {
                        Idle.add (()=> {
                            update_play_status ();
                            return false;
                        });
                    } else if (k == "CanGoNext" || k == "CanGoPrevious") {
                        Idle.add (()=> {
                            update_controls ();
                            return false;
                        });
                    }
                });
            }
        });

        player_revealer.add (player_box);
        pack_start (player_revealer);
    }

    /**
     * Update play status based on player requirements
     */
    void update_play_status () {
        switch  (client.player.playback_status) {
            case "Playing":
                 (play_btn.get_image () as Gtk.Image).set_from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                break;
            default:
                /* Stopped, Paused */
                 (play_btn.get_image () as Gtk.Image).set_from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                break;
        }
    }

    /**
     * Update prev/next sensitivity based on player requirements
     */
    void update_controls () {
        prev_btn.set_sensitive (client.player.can_go_previous);
        next_btn.set_sensitive (client.player.can_go_next);
    }


    /**
     * Utility, handle updating the album art
     */
    void update_art (string uri) {
        if  (!uri.has_prefix ("file://") && !uri.has_prefix  ("http")) {
            background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
            return;
        }
        if  (uri.has_prefix  ("file://")) {
            string fname = uri.split ("file://")[1];
            try {
                var pbuf = new Gdk.Pixbuf.from_file_at_size (fname, ICON_SIZE, ICON_SIZE);
                background.set_from_pixbuf (mask_pixbuf (pbuf));
            } catch  (Error e) {
                background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
            }
        } else {
            load_remote_art_cancel.cancel ();
            load_remote_art_cancel.reset ();
            load_remote_art.begin (uri);
        }
    }

    async void load_remote_art (string uri) {
      GLib.File file = GLib.File.new_for_uri (uri);
      try {
          GLib.InputStream stream = yield file.read_async (Priority.DEFAULT, load_remote_art_cancel);
          Gdk.Pixbuf pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async
             (stream, ICON_SIZE, ICON_SIZE, true, load_remote_art_cancel);
          background.set_from_pixbuf (mask_pixbuf (pixbuf));
      } catch  (Error e) {
          background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
      }
    }

    /**
     * Update display info such as artist, the background image, etc.
     */
    protected void update_from_meta () {
        if  ("mpris:artUrl" in client.player.metadata) {
            var url = client.player.metadata["mpris:artUrl"].get_string ();
            update_art (url);
        } else {
            background.pixel_size = ICON_SIZE;
            background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
        }
        string title;
        if  ("xesam:title" in client.player.metadata && client.player.metadata["xesam:title"].is_of_type (VariantType.STRING)
            && client.player.metadata["xesam:title"].get_string () != "") {
            title = client.player.metadata["xesam:title"].get_string ();
        } else {
           title = app_name;
        }
        title_label.set_markup ("<b>%s</b>".printf (title));

        if  ("xesam:artist" in client.player.metadata && client.player.metadata["xesam:artist"].is_of_type (VariantType.STRING_ARRAY)) {
            /* get_strv causes a segfault from multiple free's on vala's side. */
            string[] artists = client.player.metadata["xesam:artist"].dup_strv ();
            artist_label.set_text (_("by ")+string.joinv (", ", artists));
        } else {
            if  (client.player.playback_status == "Playing")
                artist_label.set_text (_("Unknown Title"));
            else
                artist_label.set_text (_("Not currently playing"));
        }
    }

    static Gdk.Pixbuf? mask_pixbuf (Gdk.Pixbuf pixbuf) {
        var size = ICON_SIZE;
        var mask_offset = 4;
        var mask_size_offset = mask_offset * 2;
        var mask_size = ICON_SIZE;
        var offset_x = mask_offset;
        var offset_y = mask_offset + 1;
        size = size - mask_size_offset;

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, mask_size, mask_size);
        var cr = new Cairo.Context (surface);

        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr,
            offset_x, offset_y, size, size, 4);
        cr.clip ();

        Gdk.cairo_set_source_pixbuf (cr, pixbuf, offset_x, offset_y);
        cr.paint ();

        cr.reset_clip ();

        var mask = new Cairo.ImageSurface.from_png ("/usr/share/gala/image-mask.png");
        cr.set_source_surface (mask, 0, 0);
        cr.paint ();

        return Gdk.pixbuf_get_from_surface (surface, 0, 0, mask_size, mask_size);
    }
}