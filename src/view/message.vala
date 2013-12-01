using GLib;
using Gtk;
using Glyph;

class Glyph.MessageView : Object {

    private Window _parent_window;

    public MessageView(Glyph.Application app, Window window) {
        _parent_window = window;
    }

    public bool confirm(string message) {
        var dialog = new MessageDialog(
            _parent_window,
            DialogFlags.MODAL,
            MessageType.WARNING,
            ButtonsType.OK_CANCEL,
            message
        );
        dialog.title = "Warning";
        var result = dialog.run();
        dialog.destroy();
        return result == ResponseType.OK;
    }
}
