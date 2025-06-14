/*
 * Copyright 2014 Ikey Doherty <ikey.doherty@gmail.com>
 *           2016-2018 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

const int ICON_SIZE = 48;

/**
 * A PlayerRow is simply used to control and display information in a two-way
 * fashion with an underlying MPRIS provider (MediaPlayer2)
 * It is "designed" to be self contained and added to a large UI, enabling multiple
 * MPRIS clients to be controlled with multiple widgets
 */
public class Sound.Widgets.PlayerRow : Gtk.Box {
    private const string NOT_PLAYING = _("Not playing");

    public signal void close ();

    private Gtk.Image? background = null;
    private Gtk.Image mask;
    private Gtk.Label title_label;
    private Gtk.Label artist_label;
    private Gtk.Button prev_btn;
    private Gtk.Button play_btn;
    private Gtk.Button next_btn;
    private Icon app_icon;
    private Cancellable load_remote_art_cancel;

    private bool launched_by_indicator = false;
    private string app_name = _("Music player");
    private string last_art_url;

    public string mpris_name = "";

    private AppInfo? ainfo;

    public AppInfo? app_info {
        get {
            return ainfo;
        } set {
            ainfo = value;
            if (ainfo != null) {
                app_name = ainfo.get_display_name ();
                if (app_name == "") {
                    app_name = ainfo.get_name ();
                }
                var icon = value.get_icon ();
                if (icon != null) {
                    app_icon = icon;
                    background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
                }
            }
        }
    }

    private Services.MprisClient? client_ = null;
    private Services.MediaPlayer? mp_client = null;

    public Services.MprisClient? client {
        get {
            return client_;
        } set {
            this.client_ = value;
            if (value != null) {
                string? desktop_entry = client.player.desktop_entry;
                if (desktop_entry != null && desktop_entry != "") {
                    app_info = new DesktopAppInfo ("%s.desktop".printf (desktop_entry));
                }

                connect_to_client ();
                update_play_status ();
                update_from_meta ();
                update_controls ();

                if (launched_by_indicator) {
                    Idle.add (() => {
                        try {
                            launched_by_indicator = false;
                            client.player.play_pause ();
                        } catch (Error e) {
                            warning ("Could not play/pause: %s", e.message);
                        }

                        return false;
                    });
                }
            } else {
                ((Gtk.Image) play_btn.image).icon_name = "media-playback-start-symbolic";
                prev_btn.sensitive = false;
                next_btn.sensitive = false;
                Sound.Indicator.settings.set_strv (
                    "last-title-info",
                    {
                        app_info.get_id (),
                        title_label.get_text (),
                        artist_label.get_text (),
                        last_art_url
                    }
                );
                this.mpris_name = "";
            }
        }
    }

    /**
     * Create a new PlayerRow
     *
     * @param client The underlying MprisClient instance to use
     */
    public PlayerRow (Services.MprisClient mpris_client) {
        Object (client: mpris_client);
    }

    /**
     * Create a new PlayerRow for bluetooth controls
     *
     * @param client The underlying MediaPlayer instance to use
     */
    public PlayerRow.bluetooth (Services.MediaPlayer media_player_client, string name, string icon) {
        mp_client = media_player_client;

        app_icon = new ThemedIcon (icon);
        background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
        title_label.label = name;
        artist_label.label = NOT_PLAYING;

        update_controls ();
    }

    /**
     * Create a new PlayerRow for the default player
     *
     * @param info The AppInfo of the default music player
     */
    public PlayerRow.default (AppInfo info) {
        Object (
            app_info: info,
            client: null
        );

        var title_info = Sound.Indicator.settings.get_strv ("last-title-info");
        if (title_info.length == 4) {
            if (title_info[0] == app_info.get_id ()) {
                title_label.label = title_info[1];
                artist_label.label = title_info[2];
                if (title_info[3] != "") {
                    update_art (title_info[3]);
                }

                return;
            }
        }

        title_label.label = app_name;
        artist_label.label = NOT_PLAYING;
    }

    class construct {
        set_css_name ("player-row");
    }

    construct {
        app_icon = new ThemedIcon ("application-default-icon");

        load_remote_art_cancel = new Cancellable ();

        background = new Gtk.Image () {
            pixel_size = ICON_SIZE
        };

        mask = new Gtk.Image.from_resource ("/io/elementary/wingpanel/sound/image-mask.svg") {
            no_show_all = true,
            pixel_size = 48
        };

        var overlay = new Gtk.Overlay () {
            can_focus = true,
            margin_bottom = 2,
            margin_end = 4,
            margin_start = 4
        };
        overlay.add (background);
        overlay.add_overlay (mask);

        title_label = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            max_width_chars = 16,
            valign = Gtk.Align.END,
            width_chars = 16,
            xalign = 0
        };

        artist_label = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            halign = Gtk.Align.START,
            valign = Gtk.Align.START
        };
        artist_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        artist_label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var titles = new Gtk.Grid () {
            column_spacing = 3
        };
        titles.attach (overlay, 0, 0, 1, 2);
        titles.attach (title_label, 1, 0);
        titles.attach (artist_label, 1, 1);

        var titles_events = new Gtk.EventBox () {
            hexpand = true
        };
        titles_events.add (titles);

        prev_btn = new Gtk.Button.from_icon_name (
            "media-skip-backward-symbolic"
        ) {
            sensitive = false,
            valign = Gtk.Align.CENTER
        };
        prev_btn.get_style_context ().add_class ("circular");

        play_btn = new Gtk.Button.from_icon_name (
            "media-playback-start-symbolic"
        ) {
            sensitive = true,
            valign = Gtk.Align.CENTER
        };
        play_btn.get_style_context ().add_class ("circular");

        next_btn = new Gtk.Button.from_icon_name (
            "media-skip-forward-symbolic"
        ) {
            sensitive = false,
            valign = Gtk.Align.CENTER
        };
        next_btn.get_style_context ().add_class ("circular");

        spacing = 6;
        margin_end = 12;
        add (titles_events);
        add (prev_btn);
        add (play_btn);
        add (next_btn);

        if (client != null) {
            connect_to_client ();
            update_play_status ();
            update_from_meta ();
            update_controls ();
        }

        titles_events.button_press_event.connect (raise_player);

        prev_btn.clicked.connect (() => {
            Idle.add (() => {
                if (!Thread.supported ()) {
                    warning ("Threading is not supported. DBus timeout could be blocking UI");
                    try {
                        if (mp_client == null && client.player.can_go_previous) {
                            client.player.previous ();
                        } else if (mp_client != null) {
                            mp_client.previous ();
                        }
                    } catch (Error e) {
                        warning ("Going to previous track probably failed (faulty MPRIS interface): %s", e.message);
                    }
                } else {
                    new Thread <void*> ("wingpanel_indicator_sound_dbus_backward_thread", () => {
                        try {
                            if (mp_client == null) {
                                client.player.previous ();
                            } else if (mp_client != null) {
                                mp_client.previous ();
                            }
                        } catch (Error e) {
                            warning ("Going to previous track probably failed (faulty MPRIS interface): %s", e.message);
                        }

                        return null;
                    });
                }

                return false;
            });
        });

        play_btn.clicked.connect (() => {
            Idle.add (() => {
                if (!Thread.supported ()) {
                    warning ("Threading is not supported. DBus timeout could be blocking UI");
                    try {
                        if (mp_client == null) {
                            client.player.play_pause ();
                        } else if (mp_client != null) {
                            if (mp_client.status == "playing") {
                                mp_client.pause ();
                            } else {
                                mp_client.play ();
                            }
                            update_play_status ();
                        }
                    } catch (Error e) {
                        warning ("Playing/Pausing probably failed (faulty MPRIS interface): %s", e.message);
                    }
                } else {
                    new Thread <void*> ("wingpanel_indicator_sound_dbus_backward_thread", () => {
                        try {
                            if (mp_client == null) {
                                client.player.play_pause ();
                            } else if (mp_client != null) {
                                if (mp_client.status == "playing") {
                                    mp_client.pause ();
                                } else {
                                    mp_client.play ();
                                }
                                update_play_status ();
                            }
                        } catch (Error e) {
                            warning ("Playing/Pausing probably failed (faulty MPRIS interface): %s", e.message);
                        }

                        return null;
                    });
                }

                return false;
            });
        });

        next_btn.clicked.connect (() => {
            Idle.add (() => {
                if (!Thread.supported ()) {
                    warning ("Threading is not supported. DBus timeout could be blocking UI");
                    try {
                        if (mp_client == null && client.player.can_go_next) {
                            client.player.next ();
                        } else if (mp_client != null) {
                            mp_client.next ();
                        }
                    } catch (Error e) {
                        warning ("Going to next track probably failed (faulty MPRIS interface): %s", e.message);
                    }
                } else {
                    new Thread <void*> ("wingpanel_indicator_sound_dbus_forward_thread", () => {
                        try {
                            if (mp_client == null) {
                                client.player.next ();
                            } else if (mp_client != null) {
                                mp_client.next ();
                            }
                        } catch (Error e) {
                            warning ("Going to next track probably failed (faulty MPRIS interface): %s", e.message);
                        }

                        return null;
                    });
                }

                return false;
            });
        });
    }

    private void connect_to_client () {
        client.prop.properties_changed.connect ((i, p, inv) => {
            if (i == "org.mpris.MediaPlayer2.Player") {
                /* Handle mediaplayer2 iface */
                p.foreach ((k, v) => {
                    if (k == "Metadata") {
                        Idle.add (() => {
                            update_from_meta ();
                            return false;
                        });
                    } else if (k == "PlaybackStatus") {
                        Idle.add (() => {
                            update_play_status ();
                            return false;
                        });
                    } else if (k == "CanGoNext" || k == "CanGoPrevious") {
                        Idle.add (() => {
                            update_controls ();
                            return false;
                        });
                    }
                });
            }
        });
    }

    private bool raise_player () {
        try {
            close ();
            if (client != null && client.player.can_raise) {
                if (!Thread.supported ()) {
                    warning ("Threading is not supported. DBus timeout could be blocking UI");
                    try {
                        client.player.raise ();
                    } catch (Error e) {
                        warning ("Raising the player probably failed (faulty MPRIS interface): %s", e.message);
                    }
                } else {
                    new Thread <void*> ("wingpanel_indicator_sound_dbus_backward_thread", () => {
                        try {
                            client.player.raise ();
                        } catch (Error e) {
                            warning ("Raising the player probably failed (faulty MPRIS interface): %s", e.message);
                        }
                        return null;
                      });
                }
            } else if (app_info != null) {
                app_info.launch (null, null);
            }
        } catch (Error e) {
            warning ("Could not launch player");
        }

        return Gdk.EVENT_STOP;
    }

    /**
     * Update play status based on player requirements
     */
    private void update_play_status () {
        if (client.player.playback_status == "Playing") {
            ((Gtk.Image) play_btn.image).icon_name = "media-playback-pause-symbolic";
        } else {
            ((Gtk.Image) play_btn.image).icon_name = "media-playback-start-symbolic";
        }

        /**
         * If a player is no longer playing and doesn't have a desktop info,
         * hide it since it offers no value to display it. This applies for web
         * browsers, but in theory any app could have temporary MPRIS playback.
         */
        if (client.player.playback_status == "Stopped" && app_info == null) {
            no_show_all = true;
            hide ();
        } else {
            no_show_all = false;
            show ();
        }
    }

    /**
     * Update prev/next sensitivity based on player requirements
     */
    private void update_controls () {
        if (mp_client == null) {
            prev_btn.sensitive = client.player.can_go_previous;
            next_btn.sensitive = client.player.can_go_next;
        } else {
            prev_btn.sensitive = true;
            next_btn.sensitive = true;
        }
    }

    /**
     * Utility, handle updating the album art
     */
    private void update_art (string uri) {
        var scale = get_style_context ().get_scale ();
        if (!uri.has_prefix ("file://") && !uri.has_prefix ("http")) {
            background.gicon = app_icon;
            background.get_style_context ().set_scale (scale);
            mask.no_show_all = true;
            mask.hide ();
            return;
        }

        if (uri.has_prefix ("file://")) {
            string fname = uri.split ("file://")[1];

            /**
            * For some MPRIS sources, e.g. flatpak based Chromium, we can see strange file uri like "file:///tmp/.com.google.Chrome.{Hash}",
            * but files being stored in users runtime directory, and we should handle it properly to display albumArt.
            * According to MPRIS spec (https://specifications.freedesktop.org/mpris-spec/latest/#Bus-Name-Policy)
            * we wont get actual app name, because chrome developers set it to `chromium` as DBUS name,
            * e.g. 'org.mpris.MediaPlayer2.chromium.instance33959'. But it has no connection to actual app name and files folder.
            *
            * Tested version of Chrom(e/ium): 129.0.6668.100
            * One of possible solutions: to use RegExp.
            *
            * To be reviewed in future.
            */
            if (! FileUtils.test (fname, FileTest.EXISTS)) {
                string folder_pattern = "^(/tmp/.)(?<appName>([a-zA-Z]*[.]){2}([a-zA-Z]*)).*$";
                Regex temp_regex = new Regex (folder_pattern);
                MatchInfo regex_match;
                if (temp_regex.match (fname, 0, out regex_match)) {
                    var app_name = regex_match.fetch_named ("appName");

                    fname = Path.build_path (Path.DIR_SEPARATOR_S, GLib.Environment.get_user_runtime_dir (), ".flatpak", app_name, fname);
                }
            }

            try {
                var pbuf = new Gdk.Pixbuf.from_file_at_size (fname, ICON_SIZE * scale, ICON_SIZE * scale);
                background.gicon = mask_pixbuf (pbuf, scale);
                background.get_style_context ().set_scale (1);
                mask.no_show_all = false;
                mask.show ();
            } catch (Error e) {
                warning (e.message);
                //background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
            }
        } else {
            load_remote_art_cancel.cancel ();
            load_remote_art_cancel.reset ();
            load_remote_art.begin (uri);
        }
    }

    private async void load_remote_art (string uri) {
        var scale = get_style_context ().get_scale ();
        GLib.File file = GLib.File.new_for_uri (uri);
        try {
            GLib.InputStream stream = yield file.read_async (Priority.DEFAULT, load_remote_art_cancel);
            Gdk.Pixbuf pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream, load_remote_art_cancel);
            if (pixbuf != null) {
                background.gicon = mask_pixbuf (pixbuf, scale);
                background.get_style_context ().set_scale (1);
                mask.no_show_all = false;
                mask.show ();
            }
        } catch (Error e) {
            background.gicon = app_icon;
            background.get_style_context ().set_scale (scale);
            mask.no_show_all = true;
            mask.hide ();
        }
    }

    /**
     * Update display info such as artist, the background image, etc.
     */
    protected void update_from_meta () {
        var metadata = client.player.metadata;
        if ("mpris:artUrl" in metadata) {
            var url = metadata["mpris:artUrl"].get_string ();
            if (url != last_art_url) {
                update_art (url);
                last_art_url = url;
            }
        } else {
            last_art_url = "";
            background.pixel_size = ICON_SIZE;
            background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
            mask.no_show_all = true;
            mask.hide ();
        }

        string title;
        if ("xesam:title" in metadata && metadata["xesam:title"].is_of_type (VariantType.STRING)
            && metadata["xesam:title"].get_string () != "") {
            title = metadata["xesam:title"].get_string ();
        } else {
            title = app_name;
        }

        title_label.label = title;

        if ("xesam:artist" in metadata && metadata["xesam:artist"].is_of_type (VariantType.STRING_ARRAY)) {
            (unowned string)[] artists = metadata["xesam:artist"].get_strv ();
            artist_label.label = string.joinv (", ", artists);
        } else {
            if (client.player.playback_status == "Playing") {
                artist_label.label = _("Unknown Artist");
            } else {
                artist_label.label = NOT_PLAYING;
            }
        }
    }

    private static Gdk.Pixbuf? mask_pixbuf (Gdk.Pixbuf pixbuf, int scale) {
        var size = ICON_SIZE * scale;
        var mask_offset = 4 * scale;
        var mask_size_offset = mask_offset * 2;
        var mask_size = ICON_SIZE * scale;
        var offset_x = mask_offset;
        var offset_y = mask_offset + scale;
        size = size - mask_size_offset;

        var input = pixbuf.scale_simple (size, size, Gdk.InterpType.BILINEAR);
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, mask_size, mask_size);
        var cr = new Cairo.Context (surface);

        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, offset_x, offset_y, size, size, mask_offset);
        cr.clip ();

        Gdk.cairo_set_source_pixbuf (cr, input, offset_x, offset_y);
        cr.paint ();

        return Gdk.pixbuf_get_from_surface (surface, 0, 0, mask_size, mask_size);
    }

    public void update_play (string playing, string title, string artist) {
        if (playing != "") {
            switch (playing) {
                case "playing":
                    ((Gtk.Image) play_btn.image).icon_name = "media-playback-pause-symbolic";
                    break;
                default:
                    /* Stopped, Paused */
                    ((Gtk.Image) play_btn.image).icon_name = "media-playback-start-symbolic";
                    break;
            }
        }

        if (title != "" && artist != "") {
            title_label.label = title;
            artist_label.label = artist;
        }
    }
}
