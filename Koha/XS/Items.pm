package Koha::XS::Items;

use Modern::Perl;

use base qw(Koha::XS::Objects);

sub table { return 'items' }
sub id    { return 'itemnumber' }
1;
