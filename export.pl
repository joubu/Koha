use Modern::Perl;
use List::MoreUtils qw( uniq );

my @module_filepaths = ( glob("**/*.pm"), glob("**/**/*.pm"), glob("**/**/*.pm") );
my @script_filepaths = ( glob("*.pl"), glob("**/*.pl"), glob("**/**/*.pl") );
my $subroutines;
MODULE: for my $module_filepath ( @module_filepaths ) {
    open my $fh, '<', $module_filepath;
    my $module = $module_filepath;
    $module =~ s|/|::|g;
    $module =~ s|\.pm$||;
    my $found_EXPORT_OK;
    while( my $line = <$fh> ) {
        chomp $line;
        $found_EXPORT_OK = 1
            if $line =~ m|EXPORT_OK|;
        next unless $line =~ '^sub ';
        my $subroutine = $line;
        $subroutine =~ s|^sub ([\w]+).*|$1|;
        $subroutine =~ s|\s.*||;
        push @{ $subroutines->{$module} }, $subroutine;
    }
    delete $subroutines->{$module} unless $found_EXPORT_OK;
    close $fh;
}

my $uses;
for my $module_filepath ( @module_filepaths ) {
    open my $fh, '<', $module_filepath;
    my $module = $module_filepath;
    $module =~ s|/|::|g;
    $module =~ s|\.pm$||;
    while( my $line = <$fh> ) {
        chomp $line;
        next if $line !~ m|^use Koha::| and $line !~ m|^use C4::|;
        my $module_used = $line;
        $module_used =~ s|^use ([\w:]+)\s.*|$1|;
        $module_used =~ s|^use ([\w:]+);.*|$1|;
        push @{ $uses->{$module} }, $module_used if exists $subroutines->{$module_used};
    }
    close $fh;
}
for my $script_filepath ( @script_filepaths ) {
    open my $fh, '<', $script_filepath;
    while( my $line = <$fh> ) {
        chomp $line;
        next if $line !~ m|^use Koha::| and $line !~ m|^use C4::|;
        my $module_used = $line;
        $module_used =~ s|^use ([\w:]+)\s.*|$1|;
        $module_used =~ s|^use ([\w:]+);.*|$1|;
        push @{ $uses->{$script_filepath} }, $module_used if exists $subroutines->{$module_used};
    }
    close $fh;
}

my $module_calls;
for my $module_filepath ( @module_filepaths ) {
    open my $fh, '<', $module_filepath;
    my $module = $module_filepath;
    $module =~ s|/|::|g;
    $module =~ s|\.pm$||;
    next unless exists $uses->{$module};

    while( my $line = <$fh> ) {
        chomp $line;
        next unless $line;
        next if $line =~ '^use ';
        next if $line =~ '^\s*#';
        for my $module_used ( @{ $uses->{$module} } ) {
            for my $subroutine ( @{ $subroutines->{$module_used} } ) {
                if ( $line =~ m|$subroutine| ) {
                    push @{ $module_calls->{$module}{$module_used} }, $subroutine;
                    @{ $module_calls->{$module}{$module_used} } = uniq @{ $module_calls->{$module}{$module_used} };
                }
            }
        }
    }
    close $fh;
}
my $script_calls;
for my $script_filepath ( @script_filepaths ) {
    open my $fh, '<', $script_filepath;
    next unless exists $uses->{$script_filepath};

    while( my $line = <$fh> ) {
        chomp $line;
        next unless $line;
        next if $line =~ '^use ';
        next if $line =~ '^\s*#';
        for my $module_used ( @{ $uses->{$script_filepath} } ) {
            for my $subroutine ( @{ $subroutines->{$module_used} } ) {
                if ( $line =~ m|$subroutine| ) {
                    push @{ $script_calls->{$script_filepath}{$module_used} }, $subroutine;
                    @{ $script_calls->{$script_filepath}{$module_used} } = uniq @{ $script_calls->{$script_filepath}{$module_used} };
                }
            }
        }
    }
    close $fh;
}

for my $module ( keys %$module_calls ) {
    say $module;
    my $module_filepath = $module;
    $module_filepath =~ s|::|/|g;
    $module_filepath .= '.pm';
    my $fh;
    open $fh, '<', $module_filepath or die "something went wrong $!";
    my @lines;
    while ( my $line = <$fh> ) {
        chomp $line;
        unless ( $line =~ m|^use\s+| ) {
            push @lines, $line;
            next;
        }
        for my $module_used ( keys %{ $module_calls->{$module} } ) {
            next if $module_used eq $module;
            if ( $line =~ m|^use\s+$module_used| ) {
                $line = "use $module_used qw( " . join( ' ', @{ $module_calls->{$module}{$module_used} } ) . " );";
            }
        }
        push @lines, $line;
    }
    close $fh;

    open $fh, '>', $module_filepath;
    print $fh join("\n", @lines ) . "\n";
    close $fh;
}
for my $script_filepath ( keys %$script_calls ) {
    say $script_filepath;
    my $fh;
    open $fh, '<', $script_filepath or die "something went wrong $!";
    my @lines;
    while ( my $line = <$fh> ) {
        chomp $line;
        unless ( $line =~ m|^use\s+| ) {
            push @lines, $line;
            next;
        }
        for my $module_used ( keys %{ $script_calls->{$script_filepath} } ) {
            if ( $line =~ m|^use\s+$module_used| ) {
                $line = "use $module_used qw( " . join( ' ', @{ $script_calls->{$script_filepath}{$module_used} } ) . " );";
            }
        }
        push @lines, $line;
    }
    close $fh;

    open $fh, '>', $script_filepath;
    print $fh join("\n", @lines ) . "\n";
    close $fh;
}
