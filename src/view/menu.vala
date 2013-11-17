using GLib;
using Gtk;
using Gdk;
using Glyph;

class Glyph.MenuView : Object {

    public Widget root;
    public Gtk.MenuBar menubar;
    public Gtk.AccelGroup accel_group;

    public MenuView(Glyph.Application app) {
        menubar = new Gtk.MenuBar();
        root = menubar;
        accel_group = new Gtk.AccelGroup();
        _init_file_menu(app);
    }

    private void _accel(Gtk.MenuItem item, uint key, ModifierType mod) {
        item.add_accelerator(
            "activate",
            accel_group,
            key,
            mod,
            Gtk.AccelFlags.VISIBLE
        );
    }

    private void _init_separator(Gtk.Menu menu) {
        menu.append(new Gtk.SeparatorMenuItem());
    }

    private delegate void ItemCallback(Glyph.Application app);

    private Gtk.MenuItem _init_item(
        string label,
        Gtk.Menu menu,
        Glyph.Application app,
        ItemCallback cb
    ) {
        var item = new Gtk.MenuItem.with_mnemonic(label);
        menu.append(item);
        item.activate.connect(() => {
            cb(app);
        });
        return item;
    }

    private void _init_file_menu(Glyph.Application app) {
        var item = new Gtk.MenuItem.with_mnemonic("_File");
        var menu = new Gtk.Menu();
        item.set_submenu(menu);
        menubar.append(item);
        _init_item("_New...", menu, app, (app) => {
            stderr.printf("New\n");
        });
        _init_separator(menu);
        _accel(
            _init_item("_Quit", menu, app, (app) => {
                app.controllers.main.quit();
            }),
            Key.Q, ModifierType.CONTROL_MASK
        );
    }
}
