using GLib;
using Glyph;

interface Glyph.Sensitivity : Object {

    public abstract bool sensitivity { get; protected set; }
}

class Glyph.CountSensitivity : Object, Sensitivity {

    private int _count;

    public bool sensitivity { get; protected set; }
    public int count {
        get { return _count; }
        set {
            _count = value;
            sensitivity = _count > 0;
        }
    }

    public CountSensitivity() { }
}
