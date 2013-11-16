using GLib;
using Gtk;
using Glyph;

class Glyph.FileModel : TreeStore {
    
    public const int COL_NAME = 0;
    public const int COL_IS_DIR = 1;
    public const int COL_ICON = 2;
    public const int COL_ORDER = 3;
    public const int COL_PATH = 4;
    public const int COL_MTIME = 5;
    public const int COL_FILE = 6;

    private File _root;

    public FileModel() {
        _root = File.new_for_path(".");
        Type[] types = {
            typeof(string),
            typeof(bool),
            typeof(string),
            typeof(string),
            typeof(string),
            typeof(long),
            typeof(File)
        };
        set_column_types(types);
        set_sort_column_id(COL_ORDER, SortType.ASCENDING);
        _load_children(_root, null);
    }

    public void update() {
        _update_directory(null);
    }

    private bool _has_changed(TreeIter? iter) {
        if (iter == null) {
            return true;
        }
        var path = _get_file(iter);
        try {
            var info = path.query_info("*", FileQueryInfoFlags.NONE);
            var mtime = info.get_modification_time();
            var new_time = mtime.tv_sec;
            var old_time = _get_mtime(iter);
            return new_time != old_time;
        }
        catch (Error e) {
            stderr.printf("Error: %s\n", e.message);
            return false;
        }
    }

    private Gee.HashMap<string,File> _load_contents_map(File path) {
        var map = new Gee.HashMap<string,File>();
        try {
            var item_enum = path.enumerate_children(
                "standard::name,time::modified",
                FileQueryInfoFlags.NONE,
                null
            );
            FileInfo info;
            while ((info = item_enum.next_file(null)) != null) {
                var name = info.get_name();
                var file = path.get_child(name);
                map.set(file.get_path(), file);
            }
        }
        catch (Error e) {
            stderr.printf("Error %s\n", e.message);
        }
        return map;
    }

    private void _update_contents(TreeIter? iter) {
        var path = _get_file(iter);
        var map = _load_contents_map(path);
        var index = iter_n_children(iter) - 1;
        while (index >= 0) {
            TreeIter item_iter;
            iter_nth_child(out item_iter, iter, index);
            index--;
            var file = _get_file(item_iter);
            if (map.has_key(file.get_path())) {
                map.unset(file.get_path());
            }
            else {
                remove(item_iter);
            }
        }
        foreach (File file in map.values) {
            _add_child(iter, file);
        }
    }

    private void _add_child(TreeIter? parent_iter, File file) {
        try {
            var type = file.query_file_type(
                FileQueryInfoFlags.NONE,
                null
            );
            var info = file.query_info("*", FileQueryInfoFlags.NONE);
            var is_dir = type == FileType.DIRECTORY;
            TreeIter iter;
            append(out iter, parent_iter);
            var mtime = info.get_modification_time();
            set(iter,
                COL_FILE, file,
                COL_PATH, file.get_path(),
                COL_NAME, file.get_basename(),
                COL_IS_DIR, is_dir,
                COL_ICON, is_dir ? "gtk-directory" : "gtk-file",
                COL_ORDER, _order_string(file, is_dir),
                COL_MTIME, mtime.tv_sec
            );
            if (is_dir) {
                _load_children(file, iter);
            }
        }
        catch (Error e) {
            stderr.printf("Error %s\n", e.message);
        }
    }

    private void _update_directory(TreeIter? iter) {
        if (_has_changed(iter)) {
            _update_contents(iter);
        }
        var index = 0;
        var last = iter_n_children(iter) - 1;
        while (index <= last) {
            TreeIter item_iter;
            iter_nth_child(out item_iter, iter, index);
            index++;
            if (_is_dir(item_iter)) {
                _update_directory(item_iter);
            }
        }
    }

    private long _get_mtime(TreeIter iter) {
        var val = Value(typeof(long));
        get_value(iter, COL_MTIME, out val);
        return val.get_long();
    }

    private File _get_file(TreeIter? iter) {
        if (iter == null) {
            return _root;
        }
        var val = Value(typeof(File));
        get_value(iter, COL_FILE, out val);
        return (File)val.dup_object();
    }

    private bool _is_dir(TreeIter? iter) {
        if (iter == null) {
            return true;
        }
        var val = Value(typeof(bool));
        get_value(iter, COL_IS_DIR, out val);
        return val.get_boolean();
    }

    private string _order_string(File path, bool is_dir) {
        var prefix = is_dir ? "0" : "1";
        var name = path.get_basename();
        return @"$prefix $name";
    }

    private void _load_children(File path, TreeIter? parent_iter) {
        try {
            var item_enum = path.enumerate_children(
                "standard::name,time::modified",
                FileQueryInfoFlags.NONE,
                null
            );
            FileInfo info;
            while ((info = item_enum.next_file(null)) != null) {
                var name = info.get_name();
                var file = path.get_child(name);
                _add_child(parent_iter, file);
            }
        }
        catch (Error e) {
            stderr.printf("Error: %s\n", e.message);
        }
    }
}
