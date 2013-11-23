using GLib;
using Gtk;
using Glyph;

class Glyph.PreferencesGrid : Grid {

    private int _last_index = 0;

    public PreferencesGrid() {
        this.margin = 10;
        this.column_spacing = 20;
        this.row_spacing = 5;
        this.expand = true;
    }

    public void add_field(string title, Widget widget) {
        var label = new Label(title);
        var index = _last_index++;
        attach(label, 0, index, 1, 1);
        attach(widget, 1, index, 1, 1);
        label.hexpand = true;
        label.xalign = 0.0f;
    }

    public void add_line(Widget widget) {
        attach(
            widget,
            0, _last_index++,
            2, 1
        );
    }

    public void add_separator() {
        attach(
            new Separator(Orientation.HORIZONTAL),
            0, _last_index++,
            2, 1
        );
    }
}

class Glyph.PreferencesView : Object {

    private Dialog _dialog;
    private Notebook _notebook;
    private PreferencesGrid _appearance;
    private PreferencesGrid _editing;

    public PreferencesView(Glyph.Application app, Window parent) {
        _init_dialog(app, parent);
    }

    public void show() {
        _dialog.show_all();
        _dialog.set_default_response(ResponseType.CLOSE);
        _dialog.run();
        _dialog.hide();
    }

    private void _init_source_font(Glyph.Application app) {
        var source_font = new FontButton();
        _appearance.add_field("Source Font", source_font);
        app.models.settings.bind(
            "source-font",
            source_font,
            "font-name",
            SettingsBindFlags.DEFAULT
        );
    }

    private CheckButton _init_check(
        Glyph.Application app,
        PreferencesGrid grid,
        string name,
        string label
    ) {
        var check = new CheckButton.with_label(label);
        grid.add_line(check);
        app.models.settings.bind(
            name,
            check,
            "active",
            SettingsBindFlags.DEFAULT
        );
        return check;
    }

    private SpinButton _init_range(
        Glyph.Application app,
        PreferencesGrid grid,
        string name,
        string label,
        double min = 1.0,
        double max = 100.0,
        double step = 1.0
    ) {
        var spin = new SpinButton.with_range(min, max, step);
        spin.digits = 0;
        grid.add_field(label, spin);
        app.models.settings.bind(
            name,
            spin,
            "value",
            SettingsBindFlags.DEFAULT
        );
        return spin;
    }

    private void _depend(
        Glyph.Application app,
        string name,
        Widget widget
    ) {
        app.models.settings.bind(
            name,
            widget,
            "sensitive",
            SettingsBindFlags.DEFAULT
        );
    }

    private void _init_line_visuals(Glyph.Application app) {
        _init_check(app,
            _appearance,
            "highlight-current-line",
            "Highlight Current Line"
        );
        _init_check(app,
            _appearance,
            "show-line-numbers",
            "Show Line Numbers"
        );
    }

    private void _init_right_margin(Glyph.Application app) {
        _init_check(app,
            _appearance,
            "show-right-margin",
            "Show Right Margin"
        );
        var position = _init_range(app,
            _appearance,
            "right-margin-position",
            "Right Margin Position",
            1, 300, 1
        );
        position.width_chars = 3;
        _depend(app, "show-right-margin", position);
    }

    private void _init_style_scheme(Glyph.Application app) {
        var styles = app.models.styles;
        var style_box = new ComboBoxText();
        foreach (var id in styles.get_scheme_ids()) {
            var style = styles.get_scheme(id);
            style_box.append(id, style.get_name());
        }
        _appearance.add_field("Style Scheme", style_box);
        app.models.settings.bind(
            "style-scheme",
            style_box,
            "active-id",
            SettingsBindFlags.DEFAULT
        );
    }

    private void _init_editing(Glyph.Application app) {
        _editing = new PreferencesGrid();
        _init_check(app,
            _editing,
            "auto-indent",
            "Automatic Indentation"
        );
        _init_check(app,
            _editing,
            "insert-spaces-instead-of-tabs",
            "Insert Spaces instead of Tabs"
        );
        _init_range(app,
            _editing,
            "indent-width",
            "Indentation Width",
            1, 16, 1
        );
        _init_range(app,
            _editing,
            "max-undo-levels",
            "Undo Level Limit (-1 for Infinite)",
            -1, 5000, 1
        );
    }

    private void _init_appearance(Glyph.Application app) {
        _appearance = new PreferencesGrid();
        _init_source_font(app);
        _init_style_scheme(app);
        _appearance.add_separator();
        _init_line_visuals(app);
        _appearance.add_separator();
        _init_right_margin(app);
    }

    private void _init_notebook(Glyph.Application app) {
        _init_appearance(app);
        _init_editing(app);
        _notebook = new Notebook();
        _notebook.append_page(_appearance, new Label("Appearance"));
        _notebook.append_page(_editing, new Label("Editing"));
    }

    private void _init_dialog(Glyph.Application app, Window parent) {
        _init_notebook(app);
        _dialog = new Dialog.with_buttons(
            "Preferences",
            parent,
            DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
            "Close", ResponseType.CLOSE
        );
        _dialog.get_content_area().add(_notebook);
    }
}
