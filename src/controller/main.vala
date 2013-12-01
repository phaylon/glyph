using GLib;
using Glyph;

class Glyph.MainController : Object {

    private MainWindowView _main_window;
    private Settings _settings;

    public MainController(ModelManager models, ViewManager views) {
        _main_window = views.main_window;
        _settings = models.settings;
    }

    public void startup() {
        var window = _main_window.window;
        window.set_default_size(
            _settings.get_int("window-width"),
            _settings.get_int("window-height")
        );
        window.show_all();
    }

    public void quit() {
        var window = _main_window.window;
        var width = window.get_allocated_width();
        var height = window.get_allocated_height();
        if (height > 50 && width > 50) {
            _settings.set_int("window-width", width);
            _settings.set_int("window-height", height);
        }
        GLib.Settings.sync();
        //_settings.sync();
        _main_window.window.destroy();
    }
}
