using GLib;
using Glyph;

class Glyph.MainController : Object {

    private MainWindowView main_window;

    public MainController(ModelManager models, ViewManager views) {
        main_window = views.main_window;
    }

    public void startup() {
        main_window.window.show_all();
    }

    public void quit() {
        main_window.window.destroy();
    }
}
