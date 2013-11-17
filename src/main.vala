
int main(string[] args) {
    Gtk.init(ref args);
    var app = new Glyph.Application();
    return app.run(args);
}
