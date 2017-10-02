/*
* Copyright (c) 2015-2017 elementary LLC. (http://launchpad.net/wingpanel-indicator-sound)
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

public class Sound.Indicator : Wingpanel.Indicator {
    private DisplayWidget display_widget;
    private Gtk.Grid main_grid;
    private Widgets.Scale volume_scale;
    private Widgets.Scale mic_scale;
    private Wingpanel.Widgets.Button settings_button;
    private Wingpanel.Widgets.Separator first_seperator;
    private Wingpanel.Widgets.Separator mic_seperator;
    private Notify.Notification notification;
    private Services.Settings settings;
    private Services.VolumeControlPulse volume_control;

    bool open = false;
    bool mute_blocks_sound = false;
    uint sound_was_blocked_timeout_id;

    double max_volume = 1.0;
    const double volume_step_percentage = 0.06;

    unowned Canberra.Context? ca_context = null;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.SOUND,
                display_name: _("Indicator Sound"),
                description: _("The sound indicator"));        
    }

    construct {
        visible = true;

        display_widget = new DisplayWidget ();

        volume_control = new Services.VolumeControlPulse ();
        volume_control.notify["volume"].connect (on_volume_change);
        volume_control.notify["mic-volume"].connect (on_mic_volume_change);
        volume_control.notify["mute"].connect (on_mute_change);
        volume_control.notify["micMute"].connect (on_mic_mute_change);
        volume_control.notify["is-playing"].connect(on_is_playing_change);
        volume_control.notify["is-listening"].connect(update_mic_visibility);

        Notify.init ("wingpanel-indicator-sound");

        notification = new Notify.Notification ("indicator-sound", "", "");
        notification.set_hint ("x-canonical-private-synchronous", new Variant.string ("indicator-sound"));

        settings = new Services.Settings ();
        settings.notify["max-volume"].connect (set_max_volume);
    
        var locale = Intl.setlocale (LocaleCategory.MESSAGES, null);

        display_widget.button_press_event.connect ((e) => {
            if (e.button == Gdk.BUTTON_MIDDLE) {
                volume_control.toggle_mute ();
                return Gdk.EVENT_STOP;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        display_widget.icon_name = get_volume_icon (volume_control.volume.volume);
        display_widget.scroll_event.connect (on_icon_scroll_event);

        volume_scale = new Widgets.Scale ("audio-volume-high-symbolic", true, 0.0, max_volume, 0.01);
        mic_scale = new Widgets.Scale ("audio-input-microphone-symbolic", true, 0.0, 1.0, 0.01);

        ca_context = CanberraGtk.context_get ();
        ca_context.change_props (Canberra.PROP_APPLICATION_NAME, "indicator-sound",
                                 Canberra.PROP_APPLICATION_ID, "wingpanel-indicator-sound",
                                 Canberra.PROP_APPLICATION_NAME, "start-here",
                                 Canberra.PROP_APPLICATION_LANGUAGE, locale,
                                 null);
        ca_context.open ();
    }

    ~Indicator () {
        if (this.sound_was_blocked_timeout_id > 0) {
            Source.remove (this.sound_was_blocked_timeout_id);
            this.sound_was_blocked_timeout_id = 0;
        }
    }

    private void set_max_volume () {
        var max = settings.max_volume / 100;
        // we do not allow more than 11db over the NORM volume
        var cap_volume = (double)PulseAudio.Volume.sw_from_dB(11.0) / PulseAudio.Volume.NORM;
        if (max > cap_volume) {
            max = cap_volume;
        }

        this.max_volume = max;
        on_volume_change ();
    }

    private void on_volume_change () {
        var volume = volume_control.volume.volume / this.max_volume;
        volume_scale.get_scale ().set_value (volume);
        display_widget.icon_name = get_volume_icon (volume);
    }

    private void on_mic_volume_change () {
        var volume = volume_control.mic_volume;
        mic_scale.get_scale ().set_value (volume);
    }

    private void on_mute_change () {
        volume_scale.get_switch ().active = !volume_control.mute;

        string volume_icon = get_volume_icon (volume_control.volume.volume);
        display_widget.icon_name = volume_icon;

        if (volume_control.mute) {
            volume_scale.set_icon ("audio-volume-muted-symbolic");
        } else {
            volume_scale.set_icon (volume_icon);
        }
    }

    private void on_mic_mute_change () {
        mic_scale.get_switch ().active = !volume_control.micMute;
    }

    private void on_is_playing_change () {
        if (!this.volume_control.mute) {
            this.mute_blocks_sound = false;
            return;
        }
        if (this.volume_control.is_playing) {
            this.mute_blocks_sound = true;
        } else if (this.mute_blocks_sound) {
            /* Continue to show the blocking icon five seconds after a player has tried to play something */
            if (this.sound_was_blocked_timeout_id > 0) {
                Source.remove (this.sound_was_blocked_timeout_id);
            }

            this.sound_was_blocked_timeout_id = Timeout.add_seconds (5, () => {
                this.mute_blocks_sound = false;
                this.sound_was_blocked_timeout_id = 0;
                display_widget.icon_name = get_volume_icon (volume_control.volume.volume);
                return false;
            });
        }

        display_widget.icon_name = get_volume_icon (volume_control.volume.volume);
    }

    private bool on_icon_scroll_event (Gdk.EventScroll e) {
        var vol = new Services.VolumeControl.Volume ();
        vol.reason = Services.VolumeControl.VolumeReasons.USER_KEYPRESS;

        int dir = 0;
        if (e.direction == Gdk.ScrollDirection.UP) {
            dir = 1;
        } else if (e.direction == Gdk.ScrollDirection.DOWN) {
            dir = -1;
        }

        var sss = SettingsSchemaSource.get_default ();
        var schema = sss.lookup ("org.gnome.desktop.peripherals.touchpad", true);
        if (schema != null) {
            var touchpad_settings = new Settings.full (schema, null, null);
            var natural_scrolling = touchpad_settings.get_boolean ("natural-scroll");
            dir = natural_scrolling ? -dir : dir;
        }

        double v = this.volume_control.volume.volume + volume_step_percentage * dir;
        vol.volume = v.clamp (0.0, this.max_volume);
        this.volume_control.volume = vol;

        if (open == false && this.notification != null && v >= -0.05 && v <= (this.max_volume + 0.05)) {

            string icon = get_volume_icon (v);

            this.notification.update ("indicator-sound", "", icon);
            this.notification.set_hint ("value", new Variant.int32 (
                (int32)Math.round(volume_control.volume.volume / this.max_volume * 100.0)));
            try {
                this.notification.show ();
            } catch (Error e) {
                warning ("Unable to show sound notification: %s", e.message);
            }
        } else if (v <= (this.max_volume + 0.05)) {
            play_sound_blubble ();
        }

        return Gdk.EVENT_STOP;
    }

    private void update_mic_visibility () {
        if (this.volume_control.is_listening) {
            mic_scale.no_show_all = false;
            mic_scale.show_all();
            mic_seperator.no_show_all = false;
            mic_seperator.show ();
            display_widget.show_mic = true;
        } else {
            mic_scale.no_show_all = true;
            mic_scale.hide();
            mic_seperator.no_show_all = true;
            mic_seperator.hide ();
            display_widget.show_mic = false;
        }
    }

    private string get_volume_icon (double volume) {
        if (volume <= 0 || this.volume_control.mute) {
            return this.mute_blocks_sound ? "audio-volume-muted-blocking-symbolic" : "audio-volume-muted-symbolic";
        } else if (volume <= 0.3) {
            return "audio-volume-low-symbolic";
        } else if (volume <= 0.7) {
            return "audio-volume-medium-symbolic";
        } else {
            return "audio-volume-high-symbolic";
        }
    }

    private void on_volume_switch_change () {
        if (volume_scale.get_switch ().active) {
            volume_control.set_mute (false);
        } else {
            volume_control.set_mute (true);
        }
    }

    private void on_mic_switch_change () {
        if (mic_scale.get_switch ().active) {
            volume_control.set_mic_mute (false);
        } else {
            volume_control.set_mic_mute (true);
        }
    }

    public override Gtk.Widget get_display_widget () {
        return display_widget;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            int position = 0;
            main_grid = new Gtk.Grid ();

            var mpris = new Widgets.MprisWidget ();

            mpris.close.connect (() => {
                close ();
            });
            volume_control.notify["headphone-plugged"].connect(() => {
                if (!volume_control.headphone_plugged)
                    mpris.pause_all ();
            });

            main_grid.attach (mpris, 0, position++, 1, 1);

            first_seperator = new Wingpanel.Widgets.Separator ();

            main_grid.attach (first_seperator, 0, position++, 1, 1);

            volume_scale.margin_start = 6;
            volume_scale.get_switch ().active = !volume_control.mute;
            volume_scale.get_switch ().notify["active"].connect (on_volume_switch_change);

            volume_scale.get_scale ().value_changed.connect (() => {
                var vol = new Services.VolumeControl.Volume();
                var v = volume_scale.get_scale ().get_value () * this.max_volume;
                vol.volume = v.clamp (0.0, this.max_volume);
                vol.reason = Services.VolumeControl.VolumeReasons.USER_KEYPRESS;
                this.volume_control.volume = vol;
                volume_scale.set_icon (get_volume_icon (volume_scale.get_scale ().get_value ()));
            });

            volume_scale.get_scale ().set_value (volume_control.volume.volume);
            volume_scale.get_scale ().button_release_event.connect ((e) => {
                play_sound_blubble ();
                return false;
            });
            volume_scale.get_scale ().scroll_event.connect ((e) => {
                int dir = 0;
                if (e.direction == Gdk.ScrollDirection.UP || e.direction == Gdk.ScrollDirection.RIGHT ||
                    (e.direction == Gdk.ScrollDirection.SMOOTH && e.delta_y < 0)) {
                    dir = 1;
                } else if (e.direction == Gdk.ScrollDirection.DOWN || e.direction == Gdk.ScrollDirection.LEFT ||
                    (e.direction == Gdk.ScrollDirection.SMOOTH && e.delta_y > 0)) {
                    dir = -1;
                }

                double v = volume_scale.get_scale ().get_value ();
                v = v + volume_step_percentage * dir;

                if (v >= -0.05 && v <= 1.05) {
                    volume_scale.get_scale ().set_value (v);
                    play_sound_blubble ();
                }
                return true;
            });

            volume_scale.set_icon (get_volume_icon (volume_scale.get_scale ().get_value ()));
            set_max_volume ();

            main_grid.attach (volume_scale, 0, position++, 1, 1);

            main_grid.attach (new Wingpanel.Widgets.Separator (), 0, position++, 1, 1);

            mic_scale.margin_start = 6;
            mic_scale.get_switch ().active = !volume_control.micMute;
            mic_scale.get_switch ().notify["active"].connect (on_mic_switch_change);

            mic_scale.get_scale ().value_changed.connect (() => {
                volume_control.mic_volume = mic_scale.get_scale ().get_value ();
            });

            main_grid.attach (mic_scale, 0, position++, 1, 1);

            mic_seperator = new Wingpanel.Widgets.Separator ();

            update_mic_visibility ();

            main_grid.attach (mic_seperator, 0, position++, 1, 1);

            settings_button = new Wingpanel.Widgets.Button (_("Sound Settings…"));
            settings_button.clicked.connect (() => {
                show_settings ();
            });

            main_grid.attach (settings_button, 0, position++, 1, 1);
        }

        return main_grid;
    }

    public override void opened () {
        open = true;
        try {
            notification.close ();
        } catch (Error e) {
            warning ("Unable to close sound notification: %s", e.message);
        }
    }

    public override void closed () {
        open = false;
    }

    private void show_settings () {
        close ();

        try {
            AppInfo.launch_default_for_uri ("settings://sound", null);
        } catch (Error e) {
            warning ("%s\n", e.message);
        }
    }

    private void play_sound_blubble () {
        Canberra.Proplist props;
        Canberra.Proplist.create (out props);
        props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "volatile");
        props.sets (Canberra.PROP_EVENT_ID, "audio-volume-change");
        ca_context.play_full (0, props);
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Sound Indicator");

    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }

    var indicator = new Sound.Indicator ();
    return indicator;
}
