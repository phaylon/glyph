using GLib;
using Gdk;
using Glyph;

const int BYTE_BITS = 8;

enum Glyph.Target {
    INT32,
    STRING,
    ROOTWIN
}

class Glyph.DNDController : Object {

    private BufferManager _buffers;

    public DNDController(ModelManager models) {
        _buffers = models.buffers;
    }

    public void navigation_get(
        Gtk.TreeView view,
        Gdk.DragContext ctx,
        Gtk.SelectionData data,
        uint type
    ) {
        switch (type) {
            case Target.STRING:
                var file = _get_selected_file(view);
                string text = file.get_path();
                data.set(
                    data.get_target(),
                    BYTE_BITS,
                    (uchar []) text.to_utf8()
                );
                break;
            default:
                assert_not_reached();
        }
    }

    private File _get_selected_file(Gtk.TreeView view) {
        var select = view.get_selection();
        Gtk.TreeModel model;
        var rows = select.get_selected_rows(out model);
        var path = rows.nth_data(0);
        Gtk.TreeIter iter;
        model.get_iter(out iter, path);
        Value file_val = Value(typeof(File));
        model.get_value(iter, FileModel.COL_FILE, out file_val);
        var file = (File) file_val.dup_object();
        return file;
    }

    public bool source_drop(
        SourceContentArea source,
        Gdk.DragContext ctx,
        uint time
    ) {
        bool valid = true;
        if (ctx.list_targets() != null) {
            var type = (Atom) ctx.list_targets().nth_data(Target.STRING);
            Gtk.drag_get_data(source, ctx, type, time);
        }
        else {
            valid = false;
        }
        return valid;
    }

    public void source_receive(
        SourceArea area,
        SourceContentArea source,
        Gdk.DragContext ctx,
        Gtk.SelectionData? data,
        uint type,
        uint time
    ) {
        bool success = false;
        if ((data != null) && (data.get_length() >= 0)) {
            if (type == Target.STRING) {
                var text = (string) data.get_data();
                stderr.printf("dropped %s\n", text);
                var file = File.new_for_path(text);
                var buffer = _buffers.get_for_file(file);
                area.replace_buffer(buffer);
                success = true;
            }
        }
        Gtk.drag_finish(ctx, success, false, time);
    }
}
