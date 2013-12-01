using GLib;
using Glyph;

class Glyph.TabController : Object {

    private BufferManager _buffers;
    private EditingView _editing;
    private MessageView _message;

    public TabController(ModelManager models, ViewManager views) {
        _buffers = models.buffers;
        _editing = views.main_window.editing;
        _message = views.messages;
        _load_session(models.session);
    }

    private void _load_session(Session session) {
        var sess = session.load();
        foreach (var file in sess.files) {
            _buffers.find_or_create_for_file(file);
        }
        if (sess.active != null) {
            open_file(sess.active);
        }
    }

    public void open_file(File file) {
        var buffer = _buffers.find_or_create_for_file(file);
        _editing.book.page = _buffers.get_index(buffer);
    }

    public void open_new() {
        var buffer = _buffers.create_unnamed();
        _editing.book.page = _buffers.get_index(buffer);
    }

    public void prev_tab() {
        var nb = _editing.book;
        var last = nb.get_n_pages() - 1;
        if (last > -1) {
            var now = nb.page;
            var prev = (now == 0) ? last : now - 1;
            nb.page = prev;
        }
    }

    public void next_tab() {
        var nb = _editing.book;
        var last = nb.get_n_pages() - 1;
        if (last > -1) {
            var now = nb.page;
            var next = (now == last) ? 0 : now + 1;
            nb.page = next;
        }
    }

    public void close(BufferModel buffer) {
        bool close = true;
        if (buffer.get_modified()) {
            var title = (buffer.file != null)
                ? "file " + buffer.file.get_path()
                : "unnamed buffer";
            close = _message.confirm(string.join("",
                "The ", title, " has unsaved modifications. ",
                "Are you sure you want to close?" 
            ));
        }
        if (close) {
            buffer.close();
        }
    }

    public void close_current() {
        BufferModel? active;
        if ((active = _buffers.active.get_buffer()) != null) {
            close(active);
        }
    }
}
