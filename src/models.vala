using GLib;
using Glyph;

class Glyph.ModelManager : Object {

    public FileModel files { get; private set; }
    public BufferManager buffers { get; private set; }

    public ModelManager() {
        files = new FileModel();
        buffers = new BufferManager();
    }
}
