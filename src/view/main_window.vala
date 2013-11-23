using GLib;
using Gtk;
using Glyph;

class Glyph.MainWindowView : Object {

    public Window window { get; private set; }
    public Paned pane { get; private set; }
    public NavigationView nav { get; private set; }
    public Statusbar statusbar { get; private set; }
    public MenuView menubar { get; private set; }
    public EditingView editing { get; private set; }

    private Box _box;

    private void _init_window(Glyph.Application app) {
        window = new Gtk.ApplicationWindow(app);
        var path = app.models.working_path.get_path();
        window.title = @"Glyph IDE - $path";
        window.has_resize_grip = true;
        window.add(_box);
        window.add_accel_group(menubar.accel_group);
        window.delete_event.connect(() => {
            app.controllers.main.quit();
            return false;
        });
    }

    private void _init_box(Glyph.Application app) {
        _box = new Box(Orientation.VERTICAL, 0);
        _box.homogeneous = false;
        _box.pack_start(menubar.root, false, true, 0);
        _box.pack_start(pane, true, true, 0);
        _box.pack_start(statusbar, false, true, 0);
    }

    private void _init_pane(Glyph.Application app) {
        pane = new Paned(Orientation.HORIZONTAL);
        pane.position = 150;
        pane.add1(nav.root);
        pane.add2(editing.root);
        app.models.settings.bind(
            "navpane-position",
            pane,
            "position",
            SettingsBindFlags.DEFAULT
        );
    }

    private void _init_navigation(Glyph.Application app) {
        nav = new NavigationView(app);
        nav.root.show_all();
        nav.root.no_show_all = true;
        app.models.settings.bind(
            "show-navpane",
            nav.root,
            "visible",
            SettingsBindFlags.GET
        );
    }

    private void _init_statusbar(Glyph.Application app) {
        statusbar = new Statusbar();
    }

    private void _init_menubar(Glyph.Application app) {
        menubar = new MenuView(app);
    }

    private void _init_editing(Glyph.Application app) {
        editing = new EditingView(app);
    }

    public MainWindowView(Glyph.Application app) {
        // individual parts
        _init_navigation(app);
        _init_editing(app);
        _init_statusbar(app);
        _init_menubar(app);
        _init_pane(app);
        // layout
        _init_box(app);
        _init_window(app);
    }
}
