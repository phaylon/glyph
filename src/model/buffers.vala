using GLib;
using Gtk;
using Glyph;

class Glyph.BufferModel : SourceBuffer {

    public File file { get; private set; }
    private ulong _style_h;
    private GLib.Settings _settings;
    private SourceStyleSchemeManager _styles;
    private weak BufferManager _manager;

    private const string[] _direct = {
        "max-undo-levels"
    };

    public signal void rebuffer(BufferModel new_buffer);
    public signal void reorg_begin();
    public signal void reorg_end();

    public BufferModel.from_file(
        File path,
        GLib.Settings settings,
        SourceStyleSchemeManager styles,
        BufferManager manager
    ) {
        file = path;
        _settings = settings;
        _styles = styles;
        _manager = manager;
        _load_contents(file);
        _init_bindings();
    }

    private BufferModel.from_other(
        BufferModel other,
        GLib.Settings settings,
        SourceStyleSchemeManager styles,
        BufferManager manager
    ) {
        file = other.file;
        _settings = settings;
        _styles = styles;
        _init_bindings();
        _manager = manager;
        this.text = other.text;
        /*other.bind_property(
            "text", this, "text",
            BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
        );*/
        //bind_property("text", other, "text", BindingFlags.DEFAULT);
    }

    ~BufferModel() {
        _settings.disconnect(_style_h);
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

    public void request_rebuffer() {
        var new_buffer = new BufferModel.from_other(
            this,
            _settings,
            _styles,
            _manager
        );
        if (this.language != null) {
            new_buffer.language = this.language;
        }
        _manager.replace(this, new_buffer);
        rebuffer(new_buffer);
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

class Glyph.BufferManager : Object {

    private Gee.ArrayList<BufferModel> _buffers;
    //private Gee.HashMap<string, BufferModel> _buffers;
    private SourceLanguageManager _languages;
    private SourceStyleSchemeManager _styles;
    private GLib.Settings _settings;

    public BufferManager(
        SourceLanguageManager languages,
        SourceStyleSchemeManager styles,
        GLib.Settings settings
    ) {
        //_buffers = new Gee.HashMap<string, BufferModel>();
        _buffers = new Gee.ArrayList<BufferModel>();
        _languages = languages;
        _styles = styles;
        _settings = settings;
    }

    public BufferModel get_for_file(File file)
    requires (_buffers != null) {
        BufferModel buffer;
        if ((buffer = _find_buffer(file)) != null) {
            return buffer;
        }
        /*if (_buffers.has_key(file.get_path())) {
            return _buffers.get(file.get_path());
        }*/
        buffer = new BufferModel.from_file(
            file,
            _settings,
            _styles,
            this
        );
        var language = _find_language(file);
        if (language != null) {
            buffer.language = language;
        }
        _buffers.add(buffer);
        //_buffers.set(file.get_path(), buffer);
        return buffer;
    }

    private BufferModel? _find_buffer(File file) {
        foreach (var buffer in _buffers) {
            if (buffer.file.get_path() == file.get_path()) {
                return buffer;
            }
        }
        return null;
    }

    public void replace(BufferModel old_buffer, BufferModel new_buffer) {
        _buffers.remove(old_buffer);
        _buffers.add(new_buffer);
    }

    private SourceLanguage? _find_language(File file)
    requires (_languages != null) {
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
