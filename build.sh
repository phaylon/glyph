#!/bin/bash
#
#   Requirements:
#       gtk+-3.0 (3.4.2)
#       gio-2.0 (2.32.2)
#       gee-1.0 (0.6.8 - don't ask me)
#       gtksourceview-3.0 (3.4.2)
#       pango (1.30.0)
#       json-glib-1.0 (0.14.2 - another weird one)
#
#   Perl 5 Requirements:
#       Path-Tiny
#       Template-Toolkit
#
glib-compile-schemas share/schemas
perl maint/styles/generate.pl
valac -o glyph --verbose -X -w\
    --pkg gtk+-3.0\
    --pkg gio-2.0\
    --pkg gee-1.0\
    --pkg gtksourceview-3.0\
    --pkg pango\
    --pkg json-glib-1.0\
    src/*.vala\
    src/view/*.vala\
    src/controller/*.vala\
    src/model/*.vala
