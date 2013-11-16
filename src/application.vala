using GLib;
using Glyph;

class Glyph.Application : Object {
    public ViewManager views { get; private set; }
    public ControllerManager controllers { get; private set; }
    public ModelManager models { get; private set; }

    public Application() {
        models = new ModelManager();
        views = new ViewManager(this);
        controllers = new ControllerManager(models, views);
    }

    public void run() {
        controllers.main.startup();
        Gtk.main();
    }
}
