public class Sound.Widgets.DeviceManagerWidget : Gtk.Grid {
    private Gtk.Grid device_grid;
    private Gtk.ListBox device_list;
    private Gtk.ScrolledWindow scrolled_box;
    private Gtk.Label device_list_label;
    public bool is_input_manager;

    private unowned PulseAudioManager pam;

    construct {
        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_changed);
        pam.start ();

        device_grid = new Gtk.Grid ();
        device_grid.show_all ();

        device_list = new Gtk.ListBox ();
        device_list.activate_on_single_click = true;
        device_list.show_all ();

        scrolled_box = new Gtk.ScrolledWindow (null, null);
        scrolled_box.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_box.max_content_height = 256;
        scrolled_box.propagate_natural_height = true;
        scrolled_box.add (device_list);

        int oi = 0;
        device_grid.attach (device_list_label, 0, oi++, 1, 1);
        device_grid.attach (scrolled_box, 0, oi++, 1, 1);

        oi = 0;
        attach (device_grid, 0, 1, 1);
    }

    private void add_device (Device device) {
        if (device.input != is_input_manager) {
            return;
        }

        Gtk.ListBoxRow? row = device_list.get_row_at_index (0);
        var device_item = new DeviceItem (device.display_name, device.is_default, device.get_nice_icon (), row);
        device_list.add (device_item);
        device_list.show_all ();
        show_hide_device_list ();

        device_item.activated.connect (() => {
            pam.set_default_device.begin (device);
        });

        device.removed.connect (() => {
            device_list.remove (device_item);
            device_list.show_all ();
            show_hide_device_list ();
        });

        device.defaulted.connect (() => {
            device_item.set_default ();
        });
    }

    private void show_hide_device_list () {
        if (device_list.get_children ().length () <= 1) {
            visible = false;
            no_show_all = true;
            hide ();
        } else {
            visible = true;
            no_show_all = false;
            show ();
        }
    }

    private void default_changed () {
        pam.default_output.defaulted ();
    }
}
