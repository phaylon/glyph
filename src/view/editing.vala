using GLib;
using Gtk;
using Glyph;

class Glyph.SourceArea : SourceView {

    public SourceArea(BufferModel buffer) {
        this.buffer = buffer;
    }
}

class Glyph.ContentArea : Paned {

    private SourceArea _src1;
    private SourceArea _src2;

    public ContentArea(BufferModel buffer) {
        _set_src1(buffer);
    }

    private void _set_src1(BufferModel buffer) {
        _clear_src1();
        this.orientation = Orientation.HORIZONTAL;
        var source = new SourceArea(buffer);
        var scrolled = new ScrolledWindow(null, null);
        scrolled.add(source);
        scrolled.shadow_type = ShadowType.IN;
        add1(scrolled);
        _src1 = source;
    }

    private void _clear_src1() {
        if (get_child1() != null) {
            remove(get_child1());
        }
    }
}

class Glyph.EditingView : Object {

    public Widget root;
    public Notebook notebook;

    private void _init_notebook(Glyph.Application app) {
        notebook = new Notebook();
    }

    public EditingView(Glyph.Application app) {
        _init_notebook(app);
        root = notebook;
    }

    public void open_tab(BufferModel buffer) {
        var content = new ContentArea(buffer);
        var label = new Label(buffer.file.get_basename());
        label.show_all();
        content.show_all();
        var page = notebook.append_page(content, label);
        notebook.page = page;
    }
}
