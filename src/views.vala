using GLib;
using Glyph;

class Glyph.ViewManager : Object {

    public MainWindowView main_window { get; private set; }
    public PreferencesView preferences { get; private set; }

    public ViewManager(Glyph.Application app) {
        main_window = new MainWindowView(app);
        preferences = new PreferencesView(app, main_window.window);
    }
}
