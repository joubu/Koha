use Modern::Perl;
use List::MoreUtils qw( uniq );

my @module_filepaths = ( glob("**/*.pm"), glob("**/**/*.pm") );
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

my $calls;
#@module_filepaths = ( 'C4/Biblio.pm' );
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
                    push @{ $calls->{$module}{$module_used} }, $subroutine;
                    @{ $calls->{$module}{$module_used} } = uniq @{ $calls->{$module}{$module_used} };
                }
            }
        }
    }
    close $fh;
}

for my $module ( keys %$calls ) {
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
        for my $module_used ( keys %{ $calls->{$module} } ) {
            next if $module_used eq $module;
            if ( $line =~ m|^use\s+$module_used| ) {
                $line = "use $module_used qw( " . join( ' ', @{ $calls->{$module}{$module_used} } ) . " );";
            }
        }
        push @lines, $line;
    }
    close $fh;

    open $fh, '>', $module_filepath;
    print $fh join("\n", @lines ) . "\n";
    close $fh;
}
