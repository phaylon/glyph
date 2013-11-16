using GLib;
using Glyph;

class Glyph.ViewManager : Object {

    public MainWindowView main_window { get; private set; }

    public ViewManager(Glyph.Application app) {
        main_window = new MainWindowView(app);
    }
}
