using GLib;
using Glyph;

class Glyph.ControllerManager : Object {
    public MainController main { get; private set; }
    public NavigationController nav { get; private set; }

    public ControllerManager(ModelManager models, ViewManager views) {
        main = new MainController(models, views);
        nav = new NavigationController(models);
    }
}
