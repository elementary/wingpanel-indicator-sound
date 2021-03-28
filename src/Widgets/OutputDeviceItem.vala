public class OutputDeviceItem : Gtk.ListBoxRow {
    public signal void activated ();

    Gtk.Image img_type;
    Gtk.RadioButton radio_button;

    public OutputDeviceItem (string display_name, bool is_default, string icon_name, Gtk.ListBoxRow? row) {
        selectable = false;

        radio_button = new Gtk.RadioButton.with_label (null, display_name);
        radio_button.active = is_default;
        radio_button.hexpand = true;
        radio_button.xalign = 0;

        if (row != null) {
            var item = (OutputDeviceItem) row;
            radio_button.set_group (item.get_group ());
        }

        img_type = new Gtk.Image ();
        img_type.icon_name = icon_name;
        img_type.icon_size = Gtk.IconSize.MENU;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 8;
        grid.add (radio_button);
        grid.add (img_type);

        add (grid);

        radio_button.toggled.connect (() => {
            if (radio_button.active) {
                activated ();
            }
        });

        get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
    }

    public void set_default () {
        radio_button.active = true;
    }

    unowned SList get_group () {
        return radio_button.get_group ();
    }
}
