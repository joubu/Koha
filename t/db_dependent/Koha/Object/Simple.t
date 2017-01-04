use Modern::Perl;
use Test::More;

use Koha::AuthorisedValues;
use Koha::Object::Simple::AuthorisedValue;
use Benchmark;

plan tests => 2;

subtest 'Simple' => sub {
    plan tests => 5;
    my $av = Koha::AuthorisedValues->search->next;
    is( ref($av), 'Koha::AuthorisedValue' );
    my $category = $av->category;
    my $av_unblessed = $av->unblessed;
    my $simple_av = Koha::Object::Simple::AuthorisedValue->new( $av_unblessed );
    is( $simple_av->category, $av->category );
    is( ref($simple_av), 'Koha::Object::Simple::AuthorisedValue' );

    is( $simple_av->opac_description, $av->opac_description );
    is( $simple_av->opac_description, $av->opac_description );
    is( ref($simple_av), 'Koha::Object::Simple::AuthorisedValue' );
};

subtest 'bench_search' => sub {
    plan tests => 1;
    # To do with and without opac_description
    timethese ( 1000, {
        search => sub {
            my $avs = Koha::AuthorisedValues->bench_search;
            for my $av ( @$avs ) {
                $av->authorised_value;
                $av->opac_description;
            }
        },
        search_no_cache_it => sub {
            my $avs = Koha::AuthorisedValues->bench_search_no_cache;
            while ( my $av = $avs->next ) {
                $av->authorised_value;
                $av->opac_description;
            }
        },
        search_no_cache_arrayref => sub {
            my @avs = Koha::AuthorisedValues->bench_search_no_cache;
            for my $av ( @avs ) {
                $av->authorised_value;
                $av->opac_description;
            }
        },

    });

    ok(1);
};
