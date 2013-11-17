using GLib;
using Glyph;

class Glyph.NavigationController : Object {

    private TimeoutSource _nav_ticker;
    private FileModel _files;

    public NavigationController(ModelManager models) {
        _files = models.files;
        _nav_ticker = new TimeoutSource.seconds(3);
        _nav_ticker.set_callback(() => {
            _files.update();
            return true;
        });
        _nav_ticker.attach(null);
    }
}
