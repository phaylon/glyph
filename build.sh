#!/bin/bash

REQUIRE=""
REQUIRE="$REQUIRE gtk+-3.0 >= 3.4.2"
REQUIRE="$REQUIRE gio-2.0 >= 2.32.2"
REQUIRE="$REQUIRE gee-1.0 >= 0.6.8"
REQUIRE="$REQUIRE gtksourceview-3.0 >= 3.4.2"
REQUIRE="$REQUIRE pango >= 1.30.0"
REQUIRE="$REQUIRE json-glib-1.0 >= 0.14.2"

pkg-config --exists --print-errors $REQUIRE
if [[ $? != 0 ]]
then
    echo "Error: Failed dependency checks"
    exit 13
fi

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
