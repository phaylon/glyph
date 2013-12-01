using GLib;

namespace Glyph {

    private const bool DEBUG = false;

    public void log_debug(string msg) {
        if (DEBUG) {
            stderr.printf("[debug] %s\n", msg);
        }
    }

    public void log_debugf(string format, ...) {
        if (DEBUG) {
            var args = va_list();
            log_debug(format.vprintf(args));
        }
    }
}
