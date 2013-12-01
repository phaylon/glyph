using GLib;
using Gtk;
using Glyph;

class Glyph.SourceContentArea : SourceView {

    private EditingPage _page;

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
        { "indent-width", "tab-width" }
    };

    public SourceContentArea(EditingPage page, BufferModel buffer) {
        _page = page;
        this.indent_on_tab = true;
        this.buffer = buffer;
        _init_updates();
    }

    public override void populate_popup(Gtk.Menu menu) {
        menu.append(new SeparatorMenuItem());
        var cl = new Gtk.MenuItem.with_mnemonic("Close");
        menu.append(cl);
        cl.activate.connect(() => {
            _page.close();
        });
        menu.show_all();
    }

    private void _init_updates() {
        _page.settings.changed["source-font"].connect(
            (settings, key) => {
                _update_font();
            }
        );
        _update_font();
        foreach (var key in _direct) {
            _page.settings.bind(key, this, key, SettingsBindFlags.GET);
        }
        foreach (var r in _redirect) {
            _page.settings.bind(r.from, this, r.to, SettingsBindFlags.GET);
        }
    }

    private void _update_font() {
        var name = _page.settings.get_string("source-font");
        var font = Pango.FontDescription.from_string(name);
        override_font(font);
    }
}

class Glyph.SnapAdjustment : Adjustment {

    private SourceContentArea _src;
    private int _line = 0;
    private bool _allow = false;

    public SnapAdjustment(SourceContentArea src) {
        _src = src;
        this.notify["value"].connect(() => {
            _current_line_check();
        });
    }

    private void _current_line_check() {
        var pos = this.value;
        TextIter iter;
        int top;
        _src.get_line_at_y(out iter, (int)pos, out top);
        var line = iter.get_line();
        if (line != _line) {
            _line = line;
            _allow = true;
            this.value = top;
            value_changed();
        }
    }

    public override void value_changed() {
        if (_allow) {
            _allow = false;
        }
        else {
            GLib.Signal.stop_emission_by_name(this, "value-changed");
        }
    }
}

class Glyph.EditingPage : Box {

    public EventBox tab_root { get; private set; }
    public Button tab_close { get; private set; }
    public Box tab_widget { get; private set; }
    public Label tab_label { get; private set; }
    public Label menu_label { get; private set; }
    public GLib.Settings settings { get; private set; }
    public BufferModel buffer { get; private set; }

    private SourceContentArea _src;
    private Glyph.Application _app;

    public EditingPage(Glyph.Application app, BufferModel b) {
        _app = app;
        buffer = b;
        settings = app.models.settings;
        this.orientation = Orientation.VERTICAL;
        _init_content();
        _init_label();
        _update_label();
        buffer.modified_changed.connect(() => {
            _update_label();
        });
    }

    public void close() {
        _app.controllers.tabs.close(buffer);
    }

    public bool holds_buffer(BufferModel b) {
        return buffer.id == b.id;
    }

    private void _init_content() {
        _src = new SourceContentArea(this, buffer);
        var adj = new SnapAdjustment(_src);
        var scrolled = new ScrolledWindow(null, adj);
        scrolled.add(_src);
        scrolled.shadow_type = ShadowType.IN;
        scrolled.size_allocate.connect((alloc) => {
            _recalc_end_margin(alloc);
        });
        pack_start(scrolled, true, true, 0);
    }

    private void _recalc_end_margin(Gtk.Allocation alloc) {
        Gdk.Rectangle rect;
        _src.get_visible_rect(out rect);
        TextIter last_line_iter;
        int last_line_top;
        _src.get_line_at_y(
            out last_line_iter,
            rect.y + (rect.height - 1) + _src.margin_bottom,
            out last_line_top
        );
        int last_line_window_top;
        int __ignore;
        int last_line_height;
        _src.get_line_yrange(
            last_line_iter,
            out __ignore,
            out last_line_height
        );
        _src.buffer_to_window_coords(
            TextWindowType.WIDGET,
            1,
            last_line_top,
            null,
            out last_line_window_top
        );
        if (_content_size_exceeds(alloc.height)) {
            var left = alloc.height - last_line_window_top;
            _src.margin_bottom = left - 2;
        }
    }

    private bool _content_size_exceeds(int size) {
        TextIter start;
        TextIter end;
        buffer.get_bounds(out start, out end);
        int top;
        int height;
        _src.get_line_yrange(end, out top, out height);
        return size < (top + height);
    }

    private void _init_label() {
        tab_label = new Label("");
        tab_label.ellipsize = Pango.EllipsizeMode.END;
        tab_label.width_chars = 15;
        tab_label.xalign = 0.0f;
        tab_label.xpad = 3;
        menu_label = new Label("");
        menu_label.ellipsize = Pango.EllipsizeMode.END;
        menu_label.xalign = 0.0f;
        menu_label.show_all();
    }

    private void _update_label() {
        if (buffer.file != null) {
            var prefix = "";
            if (buffer.get_modified()) {
                prefix = "* ";
            }
            tab_label.label = prefix + buffer.file.get_basename();
            menu_label.label = prefix + (
                buffer.get_relative_path() ?? buffer.file.get_path()
            );
        }
        else {
            tab_label.label = "* (New File)";
            menu_label.label = "* (New File)";
        }
    }
}

class Glyph.EditingView : Object {

    public Widget root;
    public Notebook book;

    private Glyph.Application _app;

    public EditingView(Glyph.Application app) {
        _app = app;
        book = _build_notebook();
        root = book;
    }

    private Notebook _build_notebook() {
        book = new Notebook();
        book.tab_pos = PositionType.RIGHT;
        book.scrollable = true;
        book.enable_popup = true;
        book.show_border = true;
        _app.models.buffers.buffer_added.connect((buffer, idx) => {
            _create_page(buffer, idx);
        });
        _app.models.buffers.buffer_removed.connect((buffer) => {
            _close_page(buffer);
        });
        _app.models.settings.bind(
            "show-tabs",
            book,
            "show-tabs",
            SettingsBindFlags.GET
        );
        book.notify["page"].connect(() => {
            var page = book.get_nth_page(book.page) as EditingPage;
            _app.models.active_buffer.set_buffer(page.buffer);
        });
        book.page_reordered.connect((widget, idx) => {
            var page = widget as EditingPage;
            _app.models.buffers.move(page.buffer, idx);
        });
        return book;
    }

    private void _create_page(BufferModel buffer, int idx) {
        var page = new EditingPage(_app, buffer);
        page.show_all();
        book.insert_page_menu(
            page, page.tab_label, page.menu_label,
            idx
        );
        book.set_tab_reorderable(page, true);
        log_debug("page added");
    }

    private void _close_page(BufferModel buffer) {
        _foreach_page((page, idx) => {
            if (page.holds_buffer(buffer)) {
                log_debug("page closed");
                book.remove_page(idx);
                return true;
            }
            return false;
        });
    }

    private delegate bool PageCallback(EditingPage page, int index);

    private void _foreach_page(PageCallback cb) {
        var last_idx = book.get_n_pages() - 1;
        var page_idx = 0;
        while (page_idx <= last_idx) {
            var page = book.get_nth_page(page_idx) as EditingPage;
            var res = cb(page, page_idx);
            if (res) {
                page_idx = last_idx + 1;
            }
            else {
                page_idx++;
            }
        }
    }
}
