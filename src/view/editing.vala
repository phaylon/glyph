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
        //var buffer = real_buffer;
        if (this.has_focus) {
            this.highlight_current_line = should_highlight_current_line;
            /*if (_cursor_cache != null) {
                TextIter iter;
                buffer.get_iter_at_mark(out iter, _cursor_cache);
                buffer.place_cursor(iter);
                buffer.delete_mark(_cursor_cache);
                _cursor_cache = null;
            }*/
        }
        else {
            this.highlight_current_line = false;
            /*if (_cursor_cache == null) {
                var mark = buffer.get_mark("insert");
                TextIter iter;
                buffer.get_iter_at_mark(out iter, mark);
                _cursor_cache = new TextMark(_cursor_name, false);
                buffer.add_mark(_cursor_cache, iter);
            }*/
        }
    }

    public void replace_buffer(BufferModel buffer) {
        _set_buffer(buffer);
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
    private Glyph.Application _app;

    public EditingView(Glyph.Application app) {
        _settings = app.models.settings;
        _app = app;
        _init_notebook(app);
        root = notebook;
    }

    public void open_tab(BufferModel buffer) {
        var source = new SourceArea(buffer, _settings, _app);
        var content = new ContentArea(source, _settings, _app);
        var label = new Label(buffer.file.get_basename());
        label.ellipsize = Pango.EllipsizeMode.END;
        label.width_chars = 15;
        label.xalign = 0.0f;
        label.show_all();
        content.show_all();
        var page = notebook.append_page(content, label);
        notebook.page = page;
    }

    private void _init_notebook(Glyph.Application app) {
        notebook = new Notebook();
        notebook.tab_pos = PositionType.RIGHT;
    }
}

public struct Glyph.ScrollPosition {
    public double v;
    public double h;
}

class Glyph.SourceArea : EventBox {

    private SourceContentArea _src;
    private ScrolledWindow _scrolled;
    private GLib.Settings _settings;
    private Label _label;
    private BufferModel _buffer;
    private Glyph.Application _app;

    public SourceArea(
        BufferModel buffer,
        GLib.Settings settings,
        Glyph.Application app
    ) {
        _settings = settings;
        _app = app;
        _init_label();
        _init_source(buffer);
        _init_popup();
        var box = new Box(Orientation.VERTICAL, 0);
        add(box);
        box.pack_start(_label, false, true, 0);
        box.pack_start(_scrolled, true, true, 0);
        show_all();
        this.enter_notify_event.connect(() => {
            _src.grab_focus();
            return false;
        });
        TargetEntry target_file = { "STRING", 0, Target.STRING };
        TargetEntry[] targets = { target_file };
        Gtk.drag_dest_set(
            _src,
            Gtk.DestDefaults.ALL,
            targets,
            Gdk.DragAction.COPY
        );
        _src.drag_data_received.connect((w, ctx, x, y, data, type, time) => {
            var src = w as SourceContentArea;
            Signal.stop_emission_by_name(w, "drag_data_received");
            _app.controllers.dnd.source_receive(this, src, ctx, data, type, time);
        });
        _src.drag_motion.connect((w, ctx, x, y, time) => {
            return false;
        });
        _src.drag_drop.connect((w, ctx, x, y, time) => {
            var src = w as SourceContentArea;
            Signal.stop_emission_by_name(w, "drag_drop");
            return _app.controllers.dnd.source_drop(src, ctx, time);
        });
    }

    private void _init_popup() {
        _src.populate_popup.connect((src, menu) => {
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
    }

    private void _init_source(BufferModel buffer) {
        _src = new SourceContentArea(buffer, _settings, this);
        _set_buffer(buffer);
        _scrolled = new ScrolledWindow(null, null);
        _scrolled.add(_src);
        _scrolled.shadow_type = ShadowType.IN;
    }

    private void _init_label() {
        _label = new Label("");
        _label.ellipsize = Pango.EllipsizeMode.START;
        _label.xalign = 0.0f;
        _label.xpad = 5;
        _label.ypad = 1;
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

    public void replace_buffer(BufferModel buffer) {
        _src.replace_buffer(buffer);
        _set_buffer(buffer);
    }

    private void _set_buffer(BufferModel buffer) {
        _buffer = buffer;
        if (buffer.file != null) {
            _label.label = buffer.file.get_path();
        }
        else {
            _label.label = "(None)";
        }
        buffer.rebuffer.connect((old, new_buffer) => {
            _set_buffer(new_buffer);
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
    private Glyph.Application _app;
    public Widget root { get; private set; }

    public ContentArea(
        Widget widget,
        GLib.Settings settings,
        Glyph.Application app
    ) {
        _settings = settings;
        _app = app;
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
        var src_l = new SourceArea(current_buffer, _settings, _app);
        var src_r = new SourceArea(buffer, _settings, _app);
        var split = new ContentSplit(
            ori,
            new ContentArea(src_l, _settings, _app),
            new ContentArea(src_r, _settings, _app)
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
