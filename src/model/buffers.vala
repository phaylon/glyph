using GLib;
using Gtk;
using Glyph;

class Glyph.BufferModel : SourceBuffer {

    public File file;

    public BufferModel.from_file(File path) {
        file = path;
        _load_contents(file);
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
        }
        catch (Error e) {
            stderr.printf("Unable to load file: %s\n", e.message);
        }
    }
}

class Glyph.BufferManager : Object {

    Gee.HashMap<string, BufferModel> buffers;

    public BufferManager() {
        buffers = new Gee.HashMap<string, BufferModel>();
    }

    public BufferModel get_for_file(File file) {
        var buffer = new BufferModel.from_file(file);
        buffers.set(file.get_path(), buffer);
        return buffer;
    }
}
