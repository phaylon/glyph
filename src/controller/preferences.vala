using GLib;
using Glyph;

class Glyph.PreferencesController : Object {

    private PreferencesView _view;

    public PreferencesController(ViewManager views) {
        _view = views.preferences;
    }

    public void show() {
        _view.show();
    }
}
