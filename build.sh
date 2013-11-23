#!/bin/bash
glib-compile-schemas share/schemas
perl maint/styles/generate.pl
valac -o glyph --verbose -X -w\
    --pkg gtk+-3.0\
    --pkg gio-2.0\
    --pkg gee-1.0\
    --pkg gtksourceview-3.0\
    --pkg pango\
    src/*.vala\
    src/view/*.vala\
    src/controller/*.vala\
    src/model/*.vala
