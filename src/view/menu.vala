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
        _init_edit_menu(app);
        _init_view_menu(app);
        _init_help_menu(app);
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

    private Gtk.CheckMenuItem _init_toggle(
        string label,
        Gtk.Menu menu,
        Glyph.Application app,
        string setting_name
    ) {
        var item = new Gtk.CheckMenuItem.with_mnemonic(label);
        menu.append(item);
        app.models.settings.bind(
            "show-navpane",
            item,
            "active",
            SettingsBindFlags.DEFAULT
        );
        return item;
    }

    private Gtk.Menu _init_menu(Glyph.Application app, string label) {
        var item = new Gtk.MenuItem.with_mnemonic(label);
        var menu = new Gtk.Menu();
        item.set_submenu(menu);
        menubar.append(item);
        return menu;
    }

    private void _init_view_menu(Glyph.Application app) {
        var menu = _init_menu(app, "_View");
        _accel(
            _init_toggle("Show _Navigation", menu, app, "show-navpane"),
            Key.N, ModifierType.CONTROL_MASK
        );
    }

    private void _init_help_menu(Glyph.Application app) {
        var menu = _init_menu(app, "_Help");
        _init_item("_About...", menu, app, (app) => {
            stderr.printf("About\n");
        });
    }

    private void _init_edit_menu(Glyph.Application app) {
        var menu = _init_menu(app, "_Edit");
        _init_item("_Preferences...", menu, app, (app) => {
            app.controllers.prefs.show();
        });
    }

    private void _init_file_menu(Glyph.Application app) {
        var menu = _init_menu(app, "_File");
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
