#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

do {
    package RGB;
    sub new { shift; bless [@_] }
    sub hex { sprintf '#%02x%02x%02x', @{ $_[0] } }
    sub darken { $_[0]->new(map ::min($_), map $_ - $_[1], @{ $_[0] }) }
    sub lighten { $_[0]->new(map ::max($_), map $_ + $_[1], @{ $_[0] }) }
};

my $black = rgb(0, 0, 0);
my $yellow = rgb(255, 255, 0);
my $white = rgb(255, 255, 255);

do {
    my $bg = rgb(30, 30, 30);
    my $fg = rgb(170, 170, 170);
    my $err = rgb(220, 0, 0);
    my $cmt = $fg->darken(50);
    my $const = rgb(125, 150, 125);
    my $const_spec = $const->darken(50);
    my $ident = rgb(100, 150, 100);
    my $type = rgb(150, 150, 200);
    scheme('glyph-default',
        name => 'Glyph Default (Dark)',
        description => 'Dark default color scheme for Glyph',
        author => 'Robert Sedlacek',
        styles => {
            text => { bg => $bg, fg => $fg },
            selection => { bg => $black },
            cursor => { bg => $black },
            current_line => { bg => $bg->darken(10) },
            line_numbers => { bg => $black, fg => $white->darken(100) },
            draw_spaces => { bg => $err, fg => $err },
            bracket_match => { fg => $yellow, , bg => $bg, bold => 1 },
            bracket_mismatch => { fg => $yellow },
            right_margin => {
                fg => $fg->darken(30),
                bg => $bg->darken(30),
            },
            search_match => {
                fg => $yellow->darken(50),
            },
            _comment => { fg => $cmt },
            _shebang => { fg => rgb(255, 120, 0), bold => 1 },
            _doc_comment_element => {
                fg => $cmt->lighten(30),
                bold => 1,
            },
            _constant => { fg => $const },
            _string => { fg => $const },
            _floating_point => { fg => $const },
            _special_char => { fg => $const_spec },
            _special_constant => { fg => $const_spec },
            _type => { fg => $type },
            _identifier => { fg => $ident },
            _statement => { fg => $ident, bold => 1 },
            _preprocessor => { fg => $ident, bold => 1 },
            _error => { fg => $err },
            _note => { fg => $cmt->lighten(30), bold => 1 },
            _builtin => { fg => $ident, bold => 1 },
            _keyword => { fg => $ident },
        },
    );
};

exit;

sub max { $_[0] > 255 ? 255 : $_[0] }
sub min { $_[0] < 0 ? 0 : $_[0] }

sub rgb { RGB->new(@_) }

sub scheme {
    my ($id, %arg) = @_;
    my $output = '';
    my %style;
    my %color;
    for my $style_id (sort keys %{ $arg{styles} }) {
        my $style_def = $arg{styles}{$style_id};
        (my $target_id = $style_id) =~ s{_}{-}g;
        $target_id =~ s{^-}{def:};
        for my $type (qw( fg bg )) {
            if (my $color_obj = $style_def->{$type}) {
                my $color_name = join '-', 'color', $style_id, $type;
                $color{$color_name} = $color_obj;
                $style{$target_id}{$type} = $color_name;
            }
        }
        for my $field (qw( bold italic )) {
            $style{$target_id}{$field} = $style_def->{$field};
        }
    }
    print "$id...\n";
    my $xml = generate_output(
        id => $id,
        %arg,
        styles => \%style,
        colors => \%color,
    );
    my $path = "$FindBin::Bin/../../share/styles";
    my $file = "$path/$id.xml";
    mkdir $path
        or die "Unable to create directory $path: $!\n"
        unless -d $path;
    open my $fh, '>', $file
        or die "Unable to write to $file: $!\n";
    print $fh "$xml\n";
}

sub _indent {
    return map { "  $_" } @_;
}

sub _if_def {
    my ($val, $cb) = @_;
    return defined($val) ? do { local $_ = $val; $cb->() } : ();
}

sub generate_output {
    my %arg = @_;
    return join("\n",
        q{<?xml version="1.0" encoding="UTF-8"?>},
        sprintf(q{<style-scheme id="%s" _name="%s" version="1.0">},
            $arg{id},
            $arg{name},
        ),
        _indent(
            sprintf(q{<author>%s</author>}, $arg{author}),
            sprintf(q{<_description>%s</_description>}, $arg{description}),
            (map {
                sprintf(q{<color name="%s" value="%s"/>},
                    $_,
                    $arg{colors}{ $_ }->hex,
                );
            } sort keys %{ $arg{colors} }),
            (map {
                sprintf(q{<style %s/>}, join " ",
                    map { sprintf '%s="%s"', @$_ }
                    [name => $_],
                    (grep { defined($_->[1]) }
                        [background => $arg{styles}{ $_ }{bg}],
                        [foreground => $arg{styles}{ $_ }{fg}],
                    ),
                    (map { [$_->[0], 'true'] } grep { $_->[1] }
                        [bold => $arg{styles}{ $_ }{bold}],
                        [italic => $arg{styles}{ $_ }{bold}],
                    ),
                );
            } sort keys %{ $arg{styles} }),
        ),
        q{</style-scheme>},
    );
}
