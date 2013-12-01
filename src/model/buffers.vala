using GLib;
using Gtk;
using Glyph;

class Glyph.BufferModel : SourceBuffer {

    public File file { get; private set; }
    public uint id { get; private set; }
    private ulong _style_h;
    private GLib.Settings _settings;
    private SourceStyleSchemeManager _styles;
    private weak BufferManager _manager;

    private const string[] _direct = {
        "max-undo-levels"
    };

    public BufferModel.unnamed(
        uint idx,
        GLib.Settings settings,
        SourceStyleSchemeManager styles,
        BufferManager manager
    ) {
        id = idx;
        _settings = settings;
        _styles = styles;
        _manager = manager;
        _init_bindings();
        set_modified(true);
    }

    public BufferModel.from_file(
        uint idx,
        File path,
        GLib.Settings settings,
        SourceStyleSchemeManager styles,
        BufferManager manager
    ) {
        id = idx;
        file = path;
        _settings = settings;
        _styles = styles;
        _manager = manager;
        _load_contents(file);
        _init_bindings();
        set_modified(false);
    }

    ~BufferModel() {
        _settings.disconnect(_style_h);
    }

    public string? get_relative_path() {
        if (file == null) {
            return null;
        }
        return _manager.root.get_relative_path(file);
    }

    public override void changed() {
        set_modified(true);
        base.changed();
    }

    public void close() {
        _manager.close(this);
    }

    private void _init_bindings() {
        _style_h = _settings.changed["style-scheme"].connect(
            (settings, key) => {
                var id = settings.get_string("style-scheme");
                this.style_scheme = _styles.get_scheme(id);
            }
        );
        var id = _settings.get_string("style-scheme");
        this.style_scheme = _styles.get_scheme(id);
        foreach (var key in _direct) {
            _settings.bind(key, this, key, SettingsBindFlags.GET);
        }
    }

    private void _load_contents(File path) {
        try {
            var input = new DataInputStream(path.read());
            string body = "";
            string line;
            while ((line = input.read_line(null)) != null) {
                var tmp = body.concat(line, "\n");
                body = tmp;
            }
            this.text = body.chomp();
            TextIter iter;
            get_iter_at_offset(out iter, 0);
            place_cursor(iter);
        }
        catch (Error e) {
            stderr.printf("Unable to load file: %s\n", e.message);
        }
    }
}

class Glyph.ActiveBuffer : Object {

    private BufferModel? _buffer;
    private ulong _file_h;
    private ulong _modified_h;

    public signal void changed(BufferModel? b);

    public ActiveBuffer() {}

    public void set_buffer(BufferModel? new_buffer) {
        if (_buffer != null) {
            _unregister();
        }
        _register(new_buffer);
    }

    public BufferModel? get_buffer() {
        return _buffer;
    }

    private void _unregister() {
        _buffer.disconnect(_file_h);
        _buffer.disconnect(_modified_h);
    }

    private void _register(BufferModel? new_buffer) {
        _buffer = new_buffer;
        if (_buffer != null) {
            _file_h = _buffer.notify["file"].connect(() => {
                changed(_buffer);
            });
            _modified_h = _buffer.modified_changed.connect(() => {
                changed(_buffer);
            });
        }
        changed(_buffer);
    }
}

class Glyph.BufferManager : Object {

    private Gee.ArrayList<BufferModel> _buffers;
    private SourceLanguageManager _languages;
    private SourceStyleSchemeManager _styles;
    private GLib.Settings _settings;
    private uint _index;

    public ActiveBuffer active { get; private set; }
    public CountSensitivity count_sensitivity { get; private set; }
    public File root { get; private set; }

    public virtual signal void changed() {
        count_sensitivity.count = _buffers.size;
    }

    public virtual signal void buffer_added(BufferModel b, int idx) {
        log_debug("buffer added");
        changed();
    }

    public virtual signal void buffer_removed(BufferModel b) {
        log_debug("buffer removed");
        changed();
    }

    public BufferManager(
        SourceLanguageManager languages,
        SourceStyleSchemeManager styles,
        GLib.Settings settings,
        File working_path
    ) {
        _index = 0;
        _root = working_path;
        _buffers = new Gee.ArrayList<BufferModel>();
        _languages = languages;
        _styles = styles;
        _settings = settings;
        count_sensitivity = new CountSensitivity();
        active = new ActiveBuffer();
    }

    public delegate void BufferCallback(BufferModel buffer);

    public int get_index(BufferModel buffer) {
        return _buffers.index_of(buffer);
    }

    public void foreach_named(BufferCallback cb) {
        foreach (var buffer in _buffers) {
            if (buffer.file != null) {
                cb(buffer);
            }
        }
    }

    public void move(BufferModel buffer, uint to) {
        var index = (int) to;
        _buffers.remove(buffer);
        _buffers.insert(index, buffer);
        log_debugf("moved %s to %d", buffer.file.get_path(), index);
    }

    private void _add_buffer(BufferModel buffer) {
        BufferModel active_buffer;
        if ((active_buffer = active.get_buffer()) != null) {
            var idx = _buffers.index_of(active_buffer) + 1;
            _buffers.insert(idx, buffer);
            buffer_added(buffer, idx);
        }
        else {
            _buffers.add(buffer);
            buffer_added(buffer, 0);
        }
    }

    private void _remove_buffer(BufferModel buffer) {
        _buffers.remove(buffer);
        buffer_removed(buffer);
    }

    public BufferModel create_unnamed() {
        var buffer = new BufferModel.unnamed(
            _index++,
            _settings,
            _styles,
            this
        );
        _add_buffer(buffer);
        return buffer;
    }

    public BufferModel find_or_create_for_file(File file) {
        BufferModel buffer;
        if ((buffer = _find_buffer(file)) != null) {
            return buffer;
        }
        buffer = new BufferModel.from_file(
            _index++,
            file,
            _settings,
            _styles,
            this
        );
        var language = _find_language(file);
        if (language != null) {
            buffer.language = language;
        }
        _add_buffer(buffer);
        return buffer;
    }

    public void close(BufferModel buffer) {
        _remove_buffer(buffer);
    }

    private BufferModel? _find_buffer(File file) {
        foreach (var buffer in _buffers) {
            if (buffer.file != null) {
                if (buffer.file.get_path() == file.get_path()) {
                    return buffer;
                }
            }
        }
        return null;
    }

    private SourceLanguage? _find_language(File file) {
        try {
            var info = file.query_info("*", FileQueryInfoFlags.NONE, null);
            var ctype = info.get_content_type();
            return _languages.guess_language(file.get_path(), ctype);
        }
        catch (Error e) {
            stderr.printf("Unable to detect language %s\n", e.message);
            return null;
        }
    }
}
