/*
 * Copyright (c) 2014 Ikey Doherty <ikey.doherty@gmail.com>
 *               2016-2017 elementary LLC. (http://launchpad.net/wingpanel)
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
const int MAX_WIDTH_TITLE = 200;

/**
 * A ClientWidget is simply used to control and display information in a two-way
 * fashion with an underlying MPRIS provider (MediaPlayer2)
 * It is "designed" to be self contained and added to a large UI, enabling multiple
 * MPRIS clients to be controlled with multiple widgets
 */
public class Sound.Widgets.ClientWidget : Gtk.Box {
    private const string NOT_PLAYING = _("Not currently playing");

    public signal void close ();

    private Gtk.Revealer player_revealer;
    private Gtk.Image? background = null;
    private Gtk.Image mask;
    private Gtk.Label title_label;
    private Gtk.Label artist_label;
    private Gtk.Button prev_btn;
    private Gtk.Button play_btn;
    private Gtk.Button next_btn;
    private Icon? app_icon = null;
    private Cancellable load_remote_art_cancel;

    private bool launched_by_indicator = false;
    private string app_name = _("Music player");
    private string last_artUrl;

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

                app_icon = value.get_icon ();
                if (app_icon == null) {
                    app_icon = new ThemedIcon ("application-default-icon");
                }

                background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
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
                if  (desktop_entry != null && desktop_entry != "") {
                    app_info = new DesktopAppInfo ("%s.desktop".printf (desktop_entry));
                }

                connect_to_client ();
                update_play_status ();
                update_from_meta ();
                update_controls ();

                if (launched_by_indicator) {
                    Idle.add (()=> {
                        try {
                            launched_by_indicator = false;
                            client.player.play_pause ();
                        } catch  (Error e) {
                            warning ("Could not play/pause: %s", e.message);
                        }

                        return false;
                    });
                }
            } else {
                (play_btn.get_image () as Gtk.Image).set_from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                prev_btn.set_sensitive (false);
                next_btn.set_sensitive (false);
                Sound.Services.Settings.get_instance ().last_title_info = {app_info.get_id (), title_label.get_text (), artist_label.get_text (), last_artUrl};
                this.mpris_name = "";
            }
        }
    }

    /**
     * Create a new ClientWidget
     *
     * @param client The underlying MprisClient instance to use
     */
    public ClientWidget (Services.MprisClient mpris_client) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, client: mpris_client);
    }

    /**
     * Create a new ClientWidget for bluetooth controls
     *
     * @param client The underlying MediaPlayer instance to use
     */
    public ClientWidget.bluetooth (Services.MediaPlayer media_player_client, string name, string icon){
        mp_client = media_player_client;

        app_icon = new ThemedIcon (icon);
        background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
        title_label.set_markup ("<b>%s</b>".printf (Markup.escape_text (name)));
        artist_label.set_text (NOT_PLAYING);

        update_controls ();
    }

    /**
     * Create a new ClientWidget for the default player
     *
     * @param info The AppInfo of the default music player
     */
    public ClientWidget.default (AppInfo info) {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0, app_info: info, client: null);

        if (Sound.Services.Settings.get_instance ().last_title_info.length == 4) {
            string[] title_info = Sound.Services.Settings.get_instance ().last_title_info;
            if (title_info[0] == app_info.get_id ()) {
                title_label.set_markup ("<b>%s</b>".printf (Markup.escape_text (title_info[1])));
                artist_label.set_text (title_info[2]);
                if (title_info[3] != "") {
                    update_art (title_info[3]);
                }

                return;
            }
        }

        title_label.set_markup ("<b>%s</b>".printf (Markup.escape_text (app_name)));
        artist_label.set_text (NOT_PLAYING);
    }

    construct {
        load_remote_art_cancel = new Cancellable ();

        player_revealer = new Gtk.Revealer ();
        player_revealer.reveal_child = true;
        var player_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        background = new Gtk.Image ();
        mask = new Gtk.Image.from_resource ("/io/elementary/wingpanel/sound/image-mask.svg");
        mask.no_show_all = true;
        mask.pixel_size = 48;
        var overlay = new Gtk.Overlay ();
        overlay.add (background);
        overlay.add_overlay (mask);
        overlay.margin_start = 4;
        overlay.margin_end = 4;
        overlay.margin_bottom = 2;
        overlay.can_focus = true;
        var background_box = new Gtk.EventBox ();
        background_box.add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
        background_box.button_press_event.connect (raise_player);
        background_box.add (overlay);
        player_box.pack_start (background_box, false, false, 0);

        var titles_events = new Gtk.EventBox ();
        var titles = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        titles.set_valign (Gtk.Align.CENTER);
        title_label = new MaxWidthLabel (MAX_WIDTH_TITLE);
        title_label.set_use_markup (true);
        title_label.set_line_wrap (true);
        title_label.set_line_wrap_mode (Pango.WrapMode.WORD);
        title_label.set_ellipsize (Pango.EllipsizeMode.END);
        title_label.halign = Gtk.Align.START;
        titles.pack_start (title_label, false, false, 0);
        artist_label = new MaxWidthLabel (MAX_WIDTH_TITLE);
        artist_label.set_line_wrap (true);
        artist_label.set_line_wrap_mode (Pango.WrapMode.WORD);
        artist_label.set_ellipsize (Pango.EllipsizeMode.END);
        artist_label.halign = Gtk.Align.START;
        titles.pack_start (artist_label, false, false, 0);
        titles_events.add (titles);
        player_box.pack_start (titles_events, false, false, 0);
        titles_events.button_press_event.connect (raise_player);

        var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        var btn = make_control_button ("media-skip-backward-symbolic");
        prev_btn = btn;
        btn.clicked.connect (()=> {
            Idle.add (()=> {
                if (!Thread.supported ()) {
                    warning ("Threading is not supported. DBus timeout could be blocking UI");
                    try {
                        if (mp_client == null && client.player.can_go_previous) {
                            client.player.previous ();
                        } else if (mp_client != null) {
                            mp_client.previous ();
                        }
                    } catch  (Error e) {
                        warning ("Going to previous track probably failed (faulty MPRIS interface): %s", e.message);
                    }
                } else {
                    new Thread <void*> ("wingpanel_indicator_sound_dbus_backward_thread", () => {
                        try {
                            if (mp_client == null) {
                                client.player.previous ();
                            } else if(mp_client != null) {
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

        controls.pack_start (btn, false, false, 0);

        btn = make_control_button ("media-playback-start-symbolic");
        btn.set_sensitive (true);
        play_btn = btn;
        btn.clicked.connect (()=> {
            Idle.add (()=> {
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

        controls.pack_start (btn, false, false, 0);

        btn = make_control_button ("media-skip-forward-symbolic");
        next_btn = btn;
        btn.clicked.connect (()=> {
            Idle.add (()=> {
                if(!Thread.supported ()) {
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

        controls.pack_start (btn, false, false, 0);

        controls.set_halign (Gtk.Align.CENTER);
        controls.set_valign (Gtk.Align.CENTER);
        controls.margin_end = 12;

        player_box.pack_end (controls, false, false, 0);

        if (client != null) {
            connect_to_client ();
            update_play_status ();
            update_from_meta ();
            update_controls ();
        }

        player_revealer.add (player_box);
        pack_start (player_revealer);
    }

    private void connect_to_client () {
        client.prop.properties_changed.connect ((i,p,inv)=> {
            if (i == "org.mpris.MediaPlayer2.Player") {
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
    }

    private bool raise_player (Gdk.EventButton event) {
        try {
            close ();
            if (client != null && client.player.can_raise) {
                if (!Thread.supported ()) {
                    warning ("Threading is not supported. DBus timeout could be blocking UI");
                    try {
                        client.player.raise ();
                    } catch  (Error e) {
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

    private Gtk.Button make_control_button (string icon) {
        var btn = new Gtk.Button.from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
        btn.set_can_focus (false);
        btn.set_sensitive (false);
        btn.set_relief (Gtk.ReliefStyle.NONE);
        btn.enter_notify_event.connect ((e) => {
            btn.can_focus = true;
            btn.grab_focus ();

            return Gdk.EVENT_STOP;
        });
        btn.leave_notify_event.connect ((e) => {
            btn.can_focus = false;
            background.grab_focus ();

            return Gdk.EVENT_STOP;
        });
        return btn;
    }

    /**
     * Update play status based on player requirements
     */
    private void update_play_status () {
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
    private void update_controls () {
        if (mp_client == null) {
            prev_btn.set_sensitive (client.player.can_go_previous);
            next_btn.set_sensitive (client.player.can_go_next);
        } else {
            prev_btn.set_sensitive (true);
            next_btn.set_sensitive (true);
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

        if (uri.has_prefix  ("file://")) {
            string fname = uri.split ("file://")[1];
            try {
                var pbuf = new Gdk.Pixbuf.from_file_at_size (fname, ICON_SIZE * scale, ICON_SIZE * scale);
                background.gicon = mask_pixbuf (pbuf, scale);
                background.get_style_context ().set_scale (1);
                mask.no_show_all = false;
                mask.show ();
            } catch  (Error e) {
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
        if  ("mpris:artUrl" in metadata) {
            var url = metadata["mpris:artUrl"].get_string ();
            last_artUrl = url;
            update_art (url);
        } else {
            last_artUrl = "";
            background.pixel_size = ICON_SIZE;
            background.set_from_gicon (app_icon, Gtk.IconSize.DIALOG);
            mask.no_show_all = true;
            mask.hide ();
        }
        
        string title;
        if  ("xesam:title" in metadata && metadata["xesam:title"].is_of_type (VariantType.STRING)
            && metadata["xesam:title"].get_string () != "") {
            title = metadata["xesam:title"].get_string ();
        } else {
            title = app_name;
        }

        title_label.set_markup ("<b>%s</b>".printf (Markup.escape_text (title)));

        if  ("xesam:artist" in metadata && metadata["xesam:artist"].is_of_type (VariantType.STRING_ARRAY)) {
            (unowned string)[] artists = metadata["xesam:artist"].get_strv ();
            artist_label.set_text (_("by ")+string.joinv (", ", artists));
        } else {
            if  (client.player.playback_status == "Playing") {
                artist_label.set_text (_("Unknown Title"));
            } else {
                artist_label.set_text (NOT_PLAYING);
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

        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr,
            offset_x, offset_y, size, size, mask_offset);
        cr.clip ();

        Gdk.cairo_set_source_pixbuf (cr, input, offset_x, offset_y);
        cr.paint ();

        return Gdk.pixbuf_get_from_surface (surface, 0, 0, mask_size, mask_size);
    }

    public void update_play (string playing, string title, string artist) {
        if (playing != "") {
            switch (playing) {
                case "playing":
                    (play_btn.get_image () as Gtk.Image).set_from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    break;
                default:
                    /* Stopped, Paused */
                    (play_btn.get_image () as Gtk.Image).set_from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
                    break;
            }
        }

        if (title != "" && artist != "") {
            title_label.set_markup ("<b>%s</b>".printf (Markup.escape_text (title)));
            artist_label.set_text (artist);
        }
    }
}
