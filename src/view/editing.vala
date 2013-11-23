using GLib;
using Gtk;
using Glyph;

public int _sv_count = 0;

class Glyph.SourceContentArea : SourceView {

    private ulong _font_h;
    private GLib.Settings _settings;
    private weak SourceArea _area;
    public bool should_highlight_current_line { get; set; }
    public BufferModel real_buffer { get; private set; }
    public int debug_id { get; private set; }

    private const string[] _direct = {
        "show-right-margin",
        "right-margin-position",
        "show-line-numbers",
        "highlight-current-line",
        "auto-indent",
        "indent-width",
        "insert-spaces-instead-of-tabs"
    };

    private struct _Redirect {
        public string from;
        public string to;
    }

    private const _Redirect[] _redirect = {
        { "indent-width", "tab-width" },
        { "highlight-current-line", "should_highlight_current_line" }
    };

    private string _cursor_name;
    private TextMark? _cursor_cache;

    public SourceContentArea(
        BufferModel buffer,
        GLib.Settings settings,
        SourceArea area
    ) {
        _area = area;
        this.indent_on_tab = true;
        debug_id = _sv_count++;
        _cursor_name = @"_cursor_cache_$debug_id";
        _set_buffer(buffer);
        _init_updates(settings);
        _init_focus();
    }

    ~SourceContentArea() {
        real_buffer.request_rebuffer();
        //_settings.disconnect(_font_h);
    }

    // TODO
    /*public override void backspace() {
        stderr.printf("backspace\n");
    }*/


    private void _init_focus() {
        _update_focus_mode();
        this.focus_in_event.connect(() => {
            _update_focus_mode();
            return false;
        });
        this.focus_out_event.connect(() => {
            _update_focus_mode();
            return false;
        });
    }

    private void _update_focus_mode() {
        var buffer = real_buffer;
        if (this.has_focus) {
            this.highlight_current_line = should_highlight_current_line;
            if (_cursor_cache != null) {
                TextIter iter;
                buffer.get_iter_at_mark(out iter, _cursor_cache);
                buffer.place_cursor(iter);
                buffer.delete_mark(_cursor_cache);
                _cursor_cache = null;
            }
        }
        else {
            this.highlight_current_line = false;
            if (_cursor_cache == null) {
                var mark = buffer.get_mark("insert");
                TextIter iter;
                buffer.get_iter_at_mark(out iter, mark);
                _cursor_cache = new TextMark(_cursor_name, false);
                buffer.add_mark(_cursor_cache, iter);
            }
        }
    }

    private void _set_buffer(BufferModel buffer) {
        this.buffer = buffer;
        real_buffer = buffer;
        buffer.rebuffer.connect((old_buffer, new_buffer) => {
            var pos = _area.get_scroll_position();
            _set_buffer(new_buffer);
            while (events_pending()) {
                main_iteration_do(true);
            }
            _area.set_scroll_position(pos);
            if (_cursor_cache != null) {
                TextIter old_iter;
                old_buffer.get_iter_at_mark(out old_iter, _cursor_cache);
                var offset = old_iter.get_offset();
                old_buffer.delete_mark(_cursor_cache);
                TextIter new_iter;
                new_buffer.get_iter_at_offset(out new_iter, offset);
                new_buffer.add_mark(_cursor_cache, new_iter);
            }
        });
    }

    private void _init_updates(GLib.Settings settings) {
        _settings = settings;
        _font_h = _settings.changed["source-font"].connect(
            (settings, key) => {
                _update_font(settings);
            }
        );
        _update_font(settings);
        foreach (var key in _direct) {
            settings.bind(key, this, key, SettingsBindFlags.GET);
        }
        foreach (var r in _redirect) {
            settings.bind(r.from, this, r.to, SettingsBindFlags.GET);
        }
    }

    private void _update_font(GLib.Settings settings) {
        var name = settings.get_string("source-font");
        var font = Pango.FontDescription.from_string(name);
        modify_font(font);
    }
}

class Glyph.EditingView : Object {

    public Widget root;
    public Notebook notebook;
    private GLib.Settings _settings;

    public EditingView(Glyph.Application app) {
        _settings = app.models.settings;
        _init_notebook(app);
        root = notebook;
    }

    public void open_tab(BufferModel buffer) {
        var source = new SourceArea(buffer, _settings);
        var content = new ContentArea(source, _settings);
        var label = new Label(buffer.file.get_basename());
        label.show_all();
        content.show_all();
        var page = notebook.append_page(content, label);
        notebook.page = page;
    }

    private void _init_notebook(Glyph.Application app) {
        notebook = new Notebook();
    }
}

class Glyph.SourceLabel : Label {

    private BufferModel _buffer;

    public SourceLabel(BufferModel buffer) {
        this.xalign = 0.0f;
        this.xpad = 5;
        this.ypad = 1;
        this.use_markup = true;
        this.ellipsize = Pango.EllipsizeMode.START;
        _set_buffer(buffer);
        _update();
    }

    private void _set_buffer(BufferModel buffer) {
        _buffer = buffer;
        buffer.notify["file"].connect(() => {
            _update();
        });
        buffer.rebuffer.connect((old, new_buffer) => {
            _set_buffer(new_buffer);
            _update();
        });
    }

    private void _update() {
        var file = _buffer.file;
        string path;
        string tag;
        if (file != null) {
            path = file.get_path();
            tag = "b";
        }
        else {
            path = "(None)";
            tag = "i";
        }
        var open = @"<$tag>";
        var close = @"</$tag>";
        var path_esc = GLib.Markup.escape_text(path, path.length);
        this.label = @"$open$path_esc$close";
    }
}

public struct Glyph.ScrollPosition {
    public double v;
    public double h;
}

class Glyph.SourceArea : EventBox {

    private Box _box;
    private ulong _popup_h;
    private SourceContentArea _src;
    private ScrolledWindow _scrolled;
    private GLib.Settings _settings;
    private Label _label;
    private BufferModel _buffer;
    private ScrollPosition? _reorg_cache;

    public SourceArea(BufferModel buffer, GLib.Settings settings) {
        //this.orientation = Orientation.VERTICAL;
        _settings = settings;
        _src = new SourceContentArea(buffer, settings, this);
        _set_buffer(buffer);
        _scrolled = new ScrolledWindow(null, null);
        _scrolled.add(_src);
        _scrolled.shadow_type = ShadowType.IN;
        _popup_h = _src.populate_popup.connect((src, menu) => {
            menu.append(new SeparatorMenuItem());
            var s_v = new Gtk.MenuItem.with_mnemonic("Split Vertically");
            menu.append(s_v);
            s_v.activate.connect(() => {
                split(Orientation.HORIZONTAL);
            });
            var s_h = new Gtk.MenuItem.with_mnemonic("Split Horizontally");
            menu.append(s_h);
            s_h.activate.connect(() => {
                split(Orientation.VERTICAL);
            });
            menu.append(new SeparatorMenuItem());
            var cl = new Gtk.MenuItem.with_mnemonic("Close");
            menu.append(cl);
            cl.activate.connect(() => {
                close();
            });
            menu.show_all();
        });
        _label = new SourceLabel(buffer);
        _box = new Box(Orientation.VERTICAL, 0);
        add(_box);
        _box.pack_start(_label, false, true, 0);
        _box.pack_start(_scrolled, true, true, 0);
        show_all();
        this.enter_notify_event.connect(() => {
            _src.grab_focus();
            return false;
        });
    }

    ~SourceArea() {
        //_src.disconnect(_popup_h);
    }

    public void set_scroll_position(ScrollPosition pos) {
        _scrolled.hadjustment.value = pos.h;
        _scrolled.hadjustment.value_changed();
        _scrolled.vadjustment.value = pos.v;
        _scrolled.vadjustment.value_changed();
    }

    public ScrollPosition get_scroll_position() {
        var pos = ScrollPosition() {
            h = _scrolled.hadjustment.value,
            v = _scrolled.vadjustment.value
        };
        return pos;
    }

    private void _set_buffer(BufferModel buffer) {
        _buffer = buffer;
        buffer.rebuffer.connect((old, new_buffer) => {
            _set_buffer(new_buffer);
        });
        buffer.reorg_begin.connect(() => {
            _reorg_cache = get_scroll_position();
        });
        buffer.reorg_begin.connect(() => {
            set_scroll_position(_reorg_cache);
            _reorg_cache = null;
        });
    }

    public BufferModel get_buffer() {
        return _buffer;
    }

    public void split(Orientation ori) {
        var area = this.parent as ContentArea;
        area.split_current(ori, _buffer);
    }

    public void close() {
        var area = this.parent as ContentArea;
        area.close();
    }
}

class Glyph.ContentSplit : Paned {

    private ContentArea _content1;
    private ContentArea _content2;

    public ContentSplit(Orientation ori, ContentArea c1, ContentArea c2) {
        _content1 = c1;
        _content2 = c2;
        this.orientation = ori;
        pack1(c1, true, true);
        pack2(c2, true, true);
    }

    public void close(ContentArea area) {
        ContentArea other;
        if (area == _content1) {
            other = _content2;
        }
        else {
            other = _content1;
        }
        var parent = this.parent as ContentArea;
        parent.keep_only(other.remove_root());
    }
}

class Glyph.ContentArea : Box {

    private GLib.Settings _settings;
    public Widget root { get; private set; }

    public ContentArea(Widget widget, GLib.Settings settings) {
        _settings = settings;
        pack_start(widget, true, true, 0);
        show_all();
        root = widget;
    }

    public Widget remove_root() {
        _clear();
        return root;
    }

    private ScrollPosition _find_child_scroll_position() {
        var widget = _child() as SourceArea;
        var pos = widget.get_scroll_position();
        return pos;
    }

    private BufferModel _find_child_buffer() {
        var widget = _child() as SourceArea;
        var buffer = widget.get_buffer();
        return buffer;
    }

    public void split_current(Orientation ori, BufferModel buffer) {
        var current_buffer = _find_child_buffer();
        var current_pos = _find_child_scroll_position();
        _clear();
        var src_l = new SourceArea(current_buffer, _settings);
        var src_r = new SourceArea(buffer, _settings);
        var split = new ContentSplit(
            ori,
            new ContentArea(src_l, _settings),
            new ContentArea(src_r, _settings)
        );
        pack_start(split, true, true, 0);
        show_all();
        root = split;
        while (events_pending()) {
            main_iteration_do(true);
        }
        src_l.set_scroll_position(current_pos);
        src_r.set_scroll_position(current_pos);
    }

    public void keep_only(Widget widget) {
        _clear();
        pack_start(widget, true, true, 0);
        show_all();
        root = widget;
    }

    public void close() {
        var parent = this.parent;
        if (parent is ContentSplit) {
            var split = parent as ContentSplit;
            split.close(this);
        }
        else if (parent is Notebook) {
            var nb = parent as Notebook;
            nb.remove_page(nb.page);
        }
    }

    private Widget _child() {
        return get_children().nth_data(0);
    }

    private void _clear() {
        foreach (var child in get_children()) {
            remove(child);
        }
    }
}
