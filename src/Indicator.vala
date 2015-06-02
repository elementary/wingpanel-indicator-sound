/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Sound.Indicator : Wingpanel.Indicator {

    private const string SETTINGS_EXEC = "/usr/bin/switchboard sound";

    private Widgets.PanelIcon panel_icon;

    private Gtk.Grid main_grid;

    private Widgets.IndicatorScale volume_scale;

    private Widgets.IndicatorScale mic_scale;

    private Wingpanel.Widgets.IndicatorButton settings_button;

    private Services.VolumeControl volume_control;

    private Wingpanel.Widgets.IndicatorSeparator first_seperator;

    private Wingpanel.Widgets.IndicatorSeparator mic_seperator;

    private Notify.Notification notification;

    // TODO make configurable
    double max_volume = 1.0;

    const double volume_step_percentage = 0.06;

    public Indicator () {
        Object (code_name: Wingpanel.Indicator.SOUND,
                display_name: _("Indicator Sound"),
                description:_("The sound indicator"));
        this.visible = true;
        this.volume_control = new Services.VolumeControl ();
        this.volume_control.volume_changed.connect (on_volume_change);
        this.volume_control.mic_volume_changed.connect (on_mic_volume_change);
        this.volume_control.notify["mute"].connect (on_mute_change);
        this.volume_control.notify["micMute"].connect (on_mic_mute_change);
        Notify.init ("wingpanel-indicator-sound");
        this.notification = new Notify.Notification ("indicator-sound", "", "");
        this.notification.set_hint ("x-canonical-private-synchronous", new Variant.string ("indicator-sound"));
    }

    private void on_volume_change (double volume) {
        volume_scale.get_scale ().set_value (volume);
        update_panel_icon (volume);
    }

    private void on_mic_volume_change (double volume) {
        mic_scale.get_scale ().set_value (volume);
    }

    private void on_mute_change () {
        volume_scale.get_switch ().active = !volume_control.mute;
        if (volume_control.mute) {
            panel_icon.set_icon ("audio-volume-muted-panel");
            volume_scale.get_scale ().set_sensitive (false);
        } else {
            update_panel_icon (volume_control.get_volume ());
            volume_scale.get_scale ().set_sensitive (true);
        }
    }

    private void on_mic_mute_change () {
        mic_scale.get_switch ().active = !volume_control.micMute;
        if (volume_control.micMute) {
            mic_scale.get_scale ().set_sensitive (false);
        } else {
            mic_scale.get_scale ().set_sensitive (true);
        }
    }

    private void update_panel_icon (double volume) {
        if (volume <= 0) {
            panel_icon.set_icon ("audio-volume-low-zero-panel");
        } else if (volume <= 0.3) {
            panel_icon.set_icon ("audio-volume-low-panel");
        } else if (volume <= 0.7) {
            panel_icon.set_icon ("audio-volume-medium-panel");
        } else {
            panel_icon.set_icon ("audio-volume-high-panel");
        }
    }

    private void update_volume_icon () {
        string icon;
        var v = volume_scale.get_scale ().get_value ();
        if (v <= 0.0)
            icon = "audio-volume-muted-symbolic";
        else if (v <= 0.3)
            icon = "audio-volume-low-symbolic";
        else if (v <= 0.7)
            icon = "audio-volume-medium-symbolic";
        else
            icon = "audio-volume-high-symbolic";
        volume_scale.set_icon (icon);
    }

    private void update_mic_visibility () {
        // if (volume_control.active_mic) {
            mic_scale.no_show_all = false;
            mic_scale.show_all();
            mic_seperator.no_show_all = false;
            mic_seperator.show ();
        // } else {
        //     mic_scale.no_show_all = true;
        //     mic_scale.hide();
        //     mic_seperator.no_show_all = true;
        //     mic_seperator.hide ();
        // }
    }

    public override Gtk.Widget get_display_widget () {
        if (panel_icon == null) {
            panel_icon = new Widgets.PanelIcon ();
            // toggle mute on middle click
            panel_icon.button_press_event.connect ((e) => {
                if (e.button == Gdk.BUTTON_MIDDLE) {
                    volume_control.toggle_mute ();
                    return Gdk.EVENT_STOP;
                }

                return Gdk.EVENT_PROPAGATE;
            });
            // change volume on scroll
            panel_icon.scroll_event.connect ((e) => {
                int dir = 0;
                if (e.direction == Gdk.ScrollDirection.UP) {
                    dir = 1;
                } else if (e.direction == Gdk.ScrollDirection.DOWN) {
                    dir = -1;
                }
                double v = this.volume_control.get_volume () + volume_step_percentage * dir;
                this.volume_control.set_volume (v.clamp (0.0, this.max_volume));
                if (this.notification != null && v >= -0.05 && v <= (this.max_volume + 0.05)) {
                    string icon;
                    if (v <= 0.0)
                        icon = "notification-audio-volume-off";
                    else if (v <= 0.3)
                        icon = "notification-audio-volume-low";
                    else if (v <= 0.7)
                        icon = "notification-audio-volume-medium";
                    else
                        icon = "notification-audio-volume-high";

                    this.notification.update ("indicator-sound", "", icon);
                    this.notification.set_hint ("value", new Variant.int32 (
                        ((int32) (this.max_volume * 100 * v / this.max_volume)).
                            clamp (-1, ((int)this.max_volume * 100) + 1)));
                    try {
                        this.notification.show ();
                    }
                    catch (Error e) {
                        warning ("unable to show notification: %s", e.message);
                    }
                }
                return Gdk.EVENT_STOP;
            });
        }

        return panel_icon;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            int position = 0;
            main_grid = new Gtk.Grid ();

            var mpris = new Widgets.MprisWidget ();

            mpris.child_count_changed.connect ((count) => {
                if (count > 0) {
                    first_seperator.no_show_all = false;
                    first_seperator.show ();
                } else {
                    first_seperator.no_show_all = true;
                    first_seperator.hide ();
                }
            });

            main_grid.attach (mpris, 0, position++, 1, 1);

            first_seperator = new Wingpanel.Widgets.IndicatorSeparator ();
            first_seperator.no_show_all = true;

            main_grid.attach (first_seperator, 0, position++, 1, 1);

            volume_scale = new Widgets.IndicatorScale ("audio-volume-high-symbolic", true, 0.0, max_volume, 0.01);
            volume_scale.margin_start = 6;

            volume_scale.get_switch ().active = volume_control.mute;
            volume_scale.get_switch ().notify["active"].connect (() => {
                if (volume_scale.get_switch ().active) {
                    volume_control.set_mute (false);
                    volume_scale.get_image ().set_sensitive (true);
                } else {
                    volume_control.set_mute (true);
                    volume_scale.get_image ().set_sensitive (false);
                }
            });

            volume_scale.get_scale ().value_changed.connect (() => {
                volume_control.set_volume (volume_scale.get_scale ().get_value ());
                update_volume_icon ();
            });

            volume_scale.get_scale ().set_value (volume_control.get_volume ());

            update_volume_icon ();

            main_grid.attach (volume_scale, 0, position++, 1, 1);

            main_grid.attach (new Wingpanel.Widgets.IndicatorSeparator (), 0, position++, 1, 1);

            mic_scale = new Widgets.IndicatorScale ("audio-input-microphone-symbolic", true, 0.0, 1.0, 0.01);
            mic_scale.margin_start = 6;

            mic_scale.get_switch ().notify["active"].connect (() => {
                if (mic_scale.get_switch ().active) {
                    volume_control.set_mic_mute (false);
                    mic_scale.get_image ().set_sensitive (true);
                } else {
                    volume_control.set_mic_mute (true);
                    mic_scale.get_image ().set_sensitive (false);
                }
            });

            mic_scale.get_scale ().value_changed.connect (() => {
                volume_control.set_mic_volume (mic_scale.get_scale ().get_value ());
            });


            volume_control.notify["active_mic"].connect (update_mic_visibility);

            main_grid.attach (mic_scale, 0, position++, 1, 1);

            mic_seperator = new Wingpanel.Widgets.IndicatorSeparator ();

            update_mic_visibility ();

            main_grid.attach (mic_seperator, 0, position++, 1, 1);

            settings_button = new Wingpanel.Widgets.IndicatorButton (_("Sound Settings…"));
            settings_button.clicked.connect (() => {
                show_settings ();
            });

            main_grid.attach (settings_button, 0, position++, 1, 1);
        }

        return main_grid;
    }

    public override void opened () {

    }

    public override void closed () {
    }

    private void show_settings () {
        var cmd = new Granite.Services.SimpleCommand ("/usr/bin", SETTINGS_EXEC);
        cmd.run ();
    }
}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating Sound Indicator");
    var indicator = new Sound.Indicator ();
    return indicator;
}
