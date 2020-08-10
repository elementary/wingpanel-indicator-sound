public class Sound.Widgets.OutputDeviceManagerWidget : Gtk.Grid {
    private Gtk.Grid output_grid;
    private Gtk.ListBox output_list;
    private Gtk.ScrolledWindow scrolled_box;
    private Gtk.Label output_list_label;
    private Widgets.Toggler toggler;
    private Gtk.Revealer revealer;

    private Gtk.Expander expander;

    private unowned PulseAudioManager pam;

    construct {
        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_changed);
        pam.start ();

        toggler = new Widgets.Toggler ();
        toggler.clicked.connect (() => {
            toggler.expanded = !toggler.expanded;
            on_expanded ();
        });

        revealer = new Gtk.Revealer ();
        revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;

        output_grid = new Gtk.Grid ();
        revealer.add (output_grid);

        output_list = new Gtk.ListBox ();
        output_list.activate_on_single_click = true;
        output_list.show_all ();

        scrolled_box = new Gtk.ScrolledWindow (null, null);
        scrolled_box.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_box.max_content_height = 256;
        scrolled_box.propagate_natural_height = true;
        scrolled_box.add (output_list);

        int oi = 0;
        output_grid.attach (output_list_label, 0, oi++, 1, 1);
        output_grid.attach (scrolled_box, 0, oi++, 1, 1);

        oi = 0;
        attach (new Wingpanel.Widgets.Separator (), 0, oi++, 1, 1);
        attach (toggler, 0, oi++, 1, 1);
        attach (expander, 0, oi++, 1, 1);
        attach (revealer, 0, oi++, 1, 1);

        on_expanded ();
    }

    public void close () {
        toggler.expanded = false;
        on_expanded ();
    }

    private void on_expanded () {
        revealer.reveal_child = toggler.expanded;
    }

    private void add_device (Device device) {
        if (device.input) {
            return;
        }

        Gtk.ListBoxRow? row = output_list.get_row_at_index (0);
        var output_device = new OutputDeviceItem (device.display_name, device.is_default, device.get_nice_icon (), row);
        output_list.add (output_device);
        output_list.show_all ();
        show_hide_output_list ();

        output_device.activated.connect (() => {
            pam.set_default_device.begin (device);
        });

        device.removed.connect (() => {
            output_list.remove (output_device);
            output_list.show_all ();
            show_hide_output_list ();
        });

        device.defaulted.connect (() => {
            output_device.set_default ();
        });
    }

    private void show_hide_output_list () {
        if (output_list.get_children ().length () <= 1) {
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
        toggler.change_primary_device (pam.default_output.display_name);
        expander.set_label (pam.default_output.display_name);
        expander.label_widget.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
    }
}
