using GLib;
using Gtk;
using Glyph;

class Glyph.Application : Gtk.Application {
    public ViewManager views { get; private set; }
    public ControllerManager controllers { get; private set; }
    public ModelManager models { get; private set; }

    public Application() {
        Object(
            application_id: "org.dev.phaylon.editor.glyph",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    public override void activate() {
        _init_components();
        controllers.main.startup();
    }

    private void _init_components() {
        models = new ModelManager();
        views = new ViewManager(this);
        controllers = new ControllerManager(models, views);
    }
}
