#!/usr/bin/perl
use Modern::Perl;
use C4::Context;
use Koha::Database;
use t::lib::Mocks;
use Time::HiRes qw(gettimeofday tv_interval);

t::lib::Mocks::mock_preference('item-level_itypes', '1');

#BEGIN{$ENV{DBIC_TRACE}=1;};

my $biblionumbers = C4::Context->dbh->selectcol_arrayref(qq{SELECT biblionumber FROM biblio});
sub search_unblessed {
    my ($biblionumber) = @_;
    my $items = [];
    my $sth = C4::Context->dbh->prepare(qq{SELECT * FROM items WHERE biblionumber=?});
    $sth->execute($biblionumber);
    while (my $item = $sth->fetchrow_hashref) {
        push @{$items}, $item;
    }
    return wantarray ? @{$items} : $items;
}
sub search_dbic {
    my ($biblionumber) = @_;
    return [Koha::Database->new->schema->resultset('Item')->search(
            { biblionumber => $biblionumber },
            { result_class => 'DBIx::Class::ResultClass::HashRefInflator' }
        )->all
    ];
}

my ($t0, $elapsed);
$t0 = [gettimeofday];
for my $biblionumber (@$biblionumbers ) {
    search_unblessed($biblionumber);
}
$elapsed = tv_interval ( $t0, [gettimeofday]);
print "plain SQL=${elapsed}s\n";

$t0 = [gettimeofday];
for my $biblionumber (@$biblionumbers ) {
    search_dbic($biblionumber);
}
$elapsed = tv_interval ( $t0, [gettimeofday]);
print "DBIC=${elapsed}s\n";
