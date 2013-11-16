using GLib;
using Glyph;

class Glyph.MainController : Object {

    private MainWindowView main_window;

    public MainController(ModelManager models, ViewManager views) {
        main_window = views.main_window;
    }

    public void on_window_delete() {
        Gtk.main_quit();
    }

    public void startup() {
        main_window.window.show_all();
    }
}
