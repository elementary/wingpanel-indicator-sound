public class Sound.Widgets.DeviceManagerWidget : Gtk.Grid {
    private Gtk.Grid device_grid;
    private Gtk.ListBox device_list;
    private Gtk.ScrolledWindow scrolled_box;
    public bool is_input_manager;

    private unowned PulseAudioManager pam;

    construct {
        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_output_changed);
        pam.notify["default-input"].connect (default_input_changed);
        pam.start ();

        device_list = new Gtk.ListBox ();
        device_list.activate_on_single_click = true;
        device_list.show ();

        scrolled_box = new Gtk.ScrolledWindow (null, null);
        scrolled_box.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_box.max_content_height = 256;
        scrolled_box.propagate_natural_height = true;
        scrolled_box.add (device_list);
        scrolled_box.no_show_all = true;

        attach (scrolled_box, 0, 1, 1);

        update_showable ();
    }

    private void add_device (Device device) {
        if (device.input != is_input_manager) {
            return;
        }

        Gtk.ListBoxRow? row = device_list.get_row_at_index (0);
        var device_item = new DeviceItem (device.display_name, device.is_default, device.is_priority, device.get_nice_icon (), row);
        device_list.add (device_item);

        device_item.activated.connect (() => {
            pam.set_default_device.begin (device);
        });

        device.removed.connect (() => {
            device_list.remove (device_item);
            device_list.show_all ();
            update_showable ();
        });

        device.defaulted.connect (() => {
            device_item.set_default ();
            update_showable ();
        });

        update_showable ();
    }

    private uint n_visible_items () {
        uint n = 0;
        foreach (var device in device_list.get_children ()) {
            if (device.visible) {
                n++;
            }
        }
        return n;
    }

    private void update_showable () {
        if (n_visible_items () <= 1) {
            scrolled_box.hide();
        } else {
            scrolled_box.show();
        }
    }

    private void default_output_changed () {
        pam.default_output.defaulted ();
    }

    private void default_input_changed () {
        pam.default_input.defaulted ();
    }
}
