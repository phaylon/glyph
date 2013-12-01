using GLib;
using Gtk;
using Glyph;

class Glyph.NavigationView : Object {

    public Widget root { get; private set; }
    public TreeView file_view { get; private set; }

    public NavigationView(Glyph.Application app) {
        _init_file_view(app);
        var scrolled_file_view = new ScrolledWindow(null, null);
        scrolled_file_view.add(file_view);
        scrolled_file_view.shadow_type = ShadowType.IN;
        root = scrolled_file_view;
    }

    private void _init_file_view(Glyph.Application app) {
        file_view = new TreeView();
        var filter = new TreeModelFilter(app.models.files, null);
        filter.set_visible_column(FileModel.COL_IS_VISIBLE);
        file_view.set_model(filter);
        file_view.headers_visible = false;
        var col = new TreeViewColumn();
        var c_name = new CellRendererText();
        var c_icon = new CellRendererPixbuf();
        col.pack_start(c_icon, false);
        col.pack_start(c_name, true);
        col.add_attribute(c_name, "text", Glyph.FileModel.COL_NAME);
        col.add_attribute(c_icon, "stock-id", Glyph.FileModel.COL_ICON);
        file_view.append_column(col);
        _on_activation(app, file_view);
    }

    private void _on_activation(Glyph.Application app, TreeView view) {
        view.row_activated.connect((view, path, col) => {
            var model = view.model;
            TreeIter iter;
            model.get_iter(out iter, path);
            Value is_dir_val = Value(typeof(bool));
            model.get_value(iter, FileModel.COL_IS_DIR, out is_dir_val);
            Value file_val = Value(typeof(File));
            model.get_value(iter, FileModel.COL_FILE, out file_val);
            if (is_dir_val.get_boolean()) {
                if (view.is_row_expanded(path)) {
                    view.collapse_row(path);
                }
                else {
                    view.expand_row(path, false);
                }
            }
            else {
                var file = (File)file_val.dup_object();
                app.controllers.tabs.open_file(file);
            }
        });
    }
}
