using GLib;
using Glyph;

struct Glyph.SessionSet {
    public File? active;
    public File[] files;
}

class Glyph.Session : Object {

    private BufferManager _buffers;
    private ActiveBuffer _active;
    private File _file;
    private bool _loaded = false;

    public Session(ModelManager models) {
        _file = models.working_path.get_child(".glyph-session");
        _buffers = models.buffers;
        _active = models.active_buffer;
        _buffers.changed.connect(() => {
            if (_loaded) store();
        });
        _active.changed.connect(() => {
            if (_loaded) store();
        });
    }

    public SessionSet load() {
        File[] session_files = {};
        File? session_active = null;
        if (_file.query_exists(null)) {
            uint8[] contents;
            string etag;
            try {
                _file.load_contents(null, out contents, out etag);
                var body = (string) contents;
                var lines = body.split("\n");
                foreach (var line in lines) {
                    var parts = line.split("\t");
                    File file;
                    switch (parts[1]) {
                        case "abs":
                            file = File.new_for_path(parts[2]);
                            break;
                        case "rel":
                            file = File.new_for_path(
                                _buffers.root.get_path() + "/" + parts[2]
                            );
                            break;
                        default:
                            assert_not_reached();
                    }
                    if (file.query_exists()) {
                        session_files += file;
                        if (parts[0] == "A") {
                            session_active = file;
                        }
                    }
                }
            }
            catch (Error e) {
                stderr.printf("Unable to read session: %s\n", e.message);
            }
        }
        var ret = SessionSet() {
            files = session_files,
            active = session_active
        };
        _loaded = true;
        return ret;
    }

    public void store() {
        string[] lines = {};
        string? active_type = null;
        string? active_path = null;
        uint? active_id = null;
        BufferModel? active_buffer;
        if ((active_buffer = _active.get_buffer()) != null) {
            active_id = active_buffer.id;
        }
        _buffers.foreach_named((buffer) => {
            var path = buffer.get_relative_path();
            string type;
            if (path != null) {
                type = "rel";
            }
            else {
                type = "abs";
                var file = buffer.file;
                path = file.get_path();
            }
            if ((active_id != null) && (buffer.id == active_id)) {
                active_type = type;
                active_path = path;
            }
            var line = string.join("\t",
                (active_id != null && buffer.id == active_id)
                    ? "A"
                    : "-",
                type,
                path
            );
            lines += line;
        });
        var res = string.joinv("\n", lines);
        try {
            _file.replace_contents(
                res.data,
                null, false, FileCreateFlags.NONE, null
            );
        }
        catch (Error e) {
            stderr.printf("Unable to write session: %s\n", e.message);
        }
    }

    /*private File? _json_file(Json.Reader r) {
        stderr.printf("json file\n");
   //     if (!r.is_object()) {
   //         stderr.printf("read %s\n", r.get_value().type_name());
   //     }
    //    assert (r.is_object());
        var root = _buffers.root;
        //File? file = null;
        var names = r.list_members();
        stderr.printf("names\n");
        foreach (var name in names) {
            stderr.printf("kind %s\n", name);
            switch (name) {
                case "abs":
                    stderr.printf("got abs\n");
                    r.read_member(name);
                    var abs_path = r.get_string_value();
                    var file = File.new_for_path(abs_path);
                    r.end_member();
                    return file;
                case "rel":
                    stderr.printf("got rel\n");
                    r.read_member(name);
                    var rel_path = r.get_string_value();
                    var file = File.new_for_path(
                        root.get_path() + "/" + rel_path
                    );
                    r.end_member();
                    return file;
                default:
                    stderr.printf("unexpected type %s\n", name);
                    assert_not_reached();
            }
        }
        return null;
    }

    private File[] _load_tabs(Json.Reader r) {
    //    stderr.printf("read tabs %s\n", r.get_value().type_name());
        assert (r.is_array());
        File[] files = {};
        var last = r.count_elements() - 1;
        var idx = 0;
        while (idx <= last) {
            r.read_element(idx);
            var file = _json_file(r);
            if (file.query_exists()) {
                files += file;
            }
            r.end_element();
            idx++;
        }
        return files;
    }

    private SessionSet _load_json(Json.Node node) {
        var sess = SessionSet();
        File[] files = {};
        var r = new Json.Reader(node);
        foreach (var name in r.list_members()) {
            stderr.printf("at %s\n", name);
            switch (name) {
                case "tabs":
                    r.read_member(name);
                    //files = _load_tabs(new Json.Reader(r.get_value()));
                    files = _load_tabs(r);
                    r.end_member();
                    break;
                case "active":
                    r.read_member("active");
                    //stderr.printf("read %s\n", r.get_value().type_name());
                    //if (r.is_value()) {
                        stderr.printf("getting active\n");
                        sess.active = _json_file(r);
                        stderr.printf("got active\n");
                    //}
                    r.end_member();
                    break;
                default:
                    assert_not_reached();
            }
        }
        sess.files = files;
        return sess;
    }

    private Json.Node _read_json() {
        var parser = new Json.Parser();
        try {
            uint8[] contents;
            string etag;
            _file.load_contents(null, out contents, out etag);
            var json = (string) contents;
            parser.load_from_data(json, json.length);
        }
        catch (Error e) {
            stderr.printf("Error: %s\n", e.message);
        }
        return parser.get_root();
    }

    private void _write_json(Json.Node node) {
        var gen = new Json.Generator();
        gen.root = node;
        try {
            gen.to_file(_file.get_path());
            //stderr.printf("JSON %s\n", gen.to_data(null));
        }
        catch (Error e) {
            stderr.printf("Error: %s\n", e.message);
        }
    }

    private Json.Node _build_json() {
        var b = new Json.Builder();
        b.begin_object();
        b.set_member_name("tabs");
        b.begin_array();
        string? active_type = null;
        string? active_path = null;
        uint? active_id = null;
        BufferModel? active_buffer;
        if ((active_buffer = _active.get_buffer()) != null) {
            active_id = active_buffer.id;
        }
        _buffers.foreach_named((buffer) => {
            b.begin_object();
            var path = buffer.get_relative_path();
            string type;
            if (path != null) {
                type = "rel";
                b.set_member_name("rel");
                b.add_string_value(path);
            }
            else {
                type = "abs";
                var file = buffer.file;
                b.set_member_name("abs");
                path = file.get_path();
                b.add_string_value(path);
            }
            if ((active_id != null) && (buffer.id == active_id)) {
                //stderr.printf("active %s\n", path);
                active_type = type;
                active_path = path;
            }
            b.end_object();
        });
        b.end_array();
        b.set_member_name("active");
        if (active_path != null) {
            //stderr.printf("set %s\n", active_path);
            b.begin_object();
            b.set_member_name(active_type);
            b.add_string_value(active_path);
            b.end_object();
        }
        else {
            b.add_null_value();
        }
        b.end_object();
        return b.get_root();
    }*/
}
