using GLib;
using Glyph;

class Glyph.ModelManager : Object {

    public FileModel files { get; private set; }
    public BufferManager buffers { get; private set; }
    public Settings settings { get; private set; }
    public Gtk.SourceLanguageManager languages { get; private set; }
    public Gtk.SourceStyleSchemeManager styles { get; private set; }
    public File working_path { get; private set; }

    public ModelManager() {
        working_path = File.new_for_path(".");
        files = new FileModel(working_path);
        languages = Gtk.SourceLanguageManager.get_default();
        _init_settings();
        _init_styles();
        buffers = new BufferManager(languages, styles, settings);
    }

    private void _init_styles() {
        var def = Gtk.SourceStyleSchemeManager.get_default();
        styles = new Gtk.SourceStyleSchemeManager();
        styles.append_search_path(
            (File.new_for_path("."))
                .get_child("share")
                .get_child("styles")
                .get_path()
        );
        foreach (var path in def.get_search_path()) {
            styles.append_search_path(path);
        }
    }

    private void _init_settings() {
        try {
            var schema_src = new SettingsSchemaSource.from_directory(
                (File.new_for_path("."))
                    .get_child("share")
                    .get_child("schemas")
                    .get_path(),
                null,
                false
            );
            var schema = schema_src.lookup("org.phaylon.glyph", false);
            settings = new Settings.full(schema, null, null);
        }
        catch (Error e) {
            stderr.printf("Error loading schema: %s\n", e.message);
        }
    }
}
