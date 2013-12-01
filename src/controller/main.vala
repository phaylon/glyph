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
        _load_window_size();
        _load_window_position();
        window.show_all();
    }

    public void quit() {
        _store_window_size();
        _store_window_position();
        GLib.Settings.sync();
        _main_window.window.destroy();
    }

    private void _load_window_position() {
        var x = _settings.get_int("window-x");
        var y = _settings.get_int("window-y");
        if (x > -1 && y > -1) {
            var window = _main_window.window;
            window.move(x, y);
        }
    }

    private void _store_window_position() {
        var window = _main_window.window;
        int x, y;
        window.get_position(out x, out y);
        _settings.set_int("window-x", x);
        _settings.set_int("window-y", y);
    }

    private void _load_window_size() {
        var window = _main_window.window;
        window.set_default_size(
            _settings.get_int("window-width"),
            _settings.get_int("window-height")
        );
    }

    private void _store_window_size() {
        var window = _main_window.window;
        var width = window.get_allocated_width();
        var height = window.get_allocated_height();
        if (height > 50 && width > 50) {
            _settings.set_int("window-width", width);
            _settings.set_int("window-height", height);
        }
    }
}
