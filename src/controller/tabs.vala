using GLib;
using Glyph;

class Glyph.TabController : Object {

    private BufferManager _buffers;
    private EditingView _editing;

    public TabController(ModelManager models, ViewManager views) {
        _buffers = models.buffers;
        _editing = views.main_window.editing;
    }

    public void open_file(File file) {
        var buffer = _buffers.get_for_file(file);
        _editing.open_tab(buffer);
    }
}
