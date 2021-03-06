#!/usr/bin/perl

# Copyright 2015 Koha Development team
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 13;
use Test::Warn;

use Koha::Authority::Types;
use Koha::Cities;
use Koha::Patron::Category;
use Koha::Patron::Categories;
use Koha::Patrons;
use Koha::Database;

use t::lib::TestBuilder;

use Try::Tiny;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;

is( ref(Koha::Authority::Types->find('')), 'Koha::Authority::Type', 'Koha::Objects->find should work if the primary key is an empty string' );

my @columns = Koha::Patrons->columns;
my $borrowernumber_exists = grep { /^borrowernumber$/ } @columns;
is( $borrowernumber_exists, 1, 'Koha::Objects->columns should return the table columns' );

subtest 'update' => sub {
    plan tests => 2;

    $builder->build( { source => 'City', value => { city_country => 'UK' } } );
    $builder->build( { source => 'City', value => { city_country => 'UK' } } );
    $builder->build( { source => 'City', value => { city_country => 'UK' } } );
    $builder->build( { source => 'City', value => { city_country => 'France' } } );
    $builder->build( { source => 'City', value => { city_country => 'France' } } );
    $builder->build( { source => 'City', value => { city_country => 'Germany' } } );
    Koha::Cities->search( { city_country => 'UK' } )->update( { city_country => 'EU' } );
    is( Koha::Cities->search( { city_country => 'EU' } )->count, 3, 'Koha::Objects->update should have updated the 3 rows' );
    is( Koha::Cities->search( { city_country => 'UK' } )->count, 0, 'Koha::Objects->update should have updated the 3 rows' );
};

subtest 'pager' => sub {
    plan tests => 1;
    my $pager = Koha::Patrons->search( {}, { page => 1, rows => 2 } )->pager;
    is( ref($pager), 'DBIx::Class::ResultSet::Pager', 'Koha::Objects->pager returns a valid DBIx::Class object' );
};

subtest 'reset' => sub {
    plan tests => 3;

    my $patrons = Koha::Patrons->search;
    my $first_borrowernumber = $patrons->next->borrowernumber;
    my $second_borrowernumber = $patrons->next->borrowernumber;
    is( ref( $patrons->reset ), 'Koha::Patrons', 'Koha::Objects->reset should allow chaining' );
    is( ref( $patrons->reset->next ), 'Koha::Patron', 'Koha::Objects->reset should allow chaining' );
    is( $patrons->reset->next->borrowernumber, $first_borrowernumber, 'Koha::Objects->reset should work as expected');
};

subtest 'delete' => sub {
    plan tests => 2;

    my $patron_1 = $builder->build({source => 'Borrower'});
    my $patron_2 = $builder->build({source => 'Borrower'});
    is( Koha::Patrons->search({ -or => { borrowernumber => [ $patron_1->{borrowernumber}, $patron_2->{borrowernumber}]}})->delete, 2, '');
    is( Koha::Patrons->search({ -or => { borrowernumber => [ $patron_1->{borrowernumber}, $patron_2->{borrowernumber}]}})->count, 0, '');
};

subtest 'not_covered_yet' => sub {
    plan tests => 1;
    warning_is { Koha::Patrons->search->not_covered_yet } { carped => 'The method not_covered_yet is not covered by tests' }, "If a method is not covered by tests, the AUTOLOAD method won't execute the method";
};
subtest 'new' => sub {
    plan tests => 2;
    my $a_cat_code = 'A_CAT_CODE';
    my $patron_category = Koha::Patron::Category->new( { categorycode => $a_cat_code } )->store;
    is( Koha::Patron::Categories->find($a_cat_code)->category_type, 'A', 'Koha::Object->new should set the default value' );
    Koha::Patron::Categories->find($a_cat_code)->delete;
    $patron_category = Koha::Patron::Category->new( { categorycode => $a_cat_code, category_type => undef } )->store;
    is( Koha::Patron::Categories->find($a_cat_code)->category_type, 'A', 'Koha::Object->new should set the default value even if the argument exists but is not defined' );
    Koha::Patron::Categories->find($a_cat_code)->delete;
};

subtest 'search_related' => sub {
    plan tests => 8;
    my $builder   = t::lib::TestBuilder->new;
    my $patron_1  = $builder->build( { source => 'Borrower' } );
    my $patron_2  = $builder->build( { source => 'Borrower' } );
    my $libraries = Koha::Patrons->search( { -or => { borrowernumber => [ $patron_1->{borrowernumber}, $patron_2->{borrowernumber} ] } } )->search_related('branchcode');
    is( ref( $libraries ), 'Koha::Libraries', 'Koha::Objects->search_related should return an instanciated Koha::Objects-based object' );
    is( $libraries->count,            2,                       'Koha::Objects->search_related should work as expected' );
    is( $libraries->next->branchcode, $patron_1->{branchcode}, 'Koha::Objects->search_related should work as expected' );
    is( $libraries->next->branchcode, $patron_2->{branchcode}, 'Koha::Objects->search_related should work as expected' );

    my @libraries = Koha::Patrons->search( { -or => { borrowernumber => [ $patron_1->{borrowernumber}, $patron_2->{borrowernumber} ] } } )->search_related('branchcode');
    is( ref( $libraries[0] ),      'Koha::Library',         'Koha::Objects->search_related should return a list of Koha::Object-based objects' );
    is( scalar(@libraries),        2,                       'Koha::Objects->search_related should work as expected' );
    is( $libraries[0]->branchcode, $patron_1->{branchcode}, 'Koha::Objects->search_related should work as expected' );
    is( $libraries[1]->branchcode, $patron_2->{branchcode}, 'Koha::Objects->search_related should work as expected' );
};

subtest 'single' => sub {
    plan tests => 2;
    my $builder   = t::lib::TestBuilder->new;
    my $patron_1  = $builder->build( { source => 'Borrower' } );
    my $patron_2  = $builder->build( { source => 'Borrower' } );
    my $patron = Koha::Patrons->search({}, { rows => 1 })->single;
    is(ref($patron), 'Koha::Patron', 'Koha::Objects->single returns a single Koha::Patron object.');
    warning_like { Koha::Patrons->search->single } qr/SQL that returns multiple rows/,
    "Warning is presented if single is used for a result with multiple rows.";
};

subtest 'last' => sub {
    plan tests => 3;
    my $builder = t::lib::TestBuilder->new;
    my $patron_1  = $builder->build( { source => 'Borrower' } );
    my $patron_2  = $builder->build( { source => 'Borrower' } );
    my $last_patron = Koha::Patrons->search->last;
    is( $last_patron->borrowernumber, $patron_2->{borrowernumber}, '->last should return the last inserted patron' );
    $last_patron = Koha::Patrons->search({ borrowernumber => $patron_1->{borrowernumber} })->last;
    is( $last_patron->borrowernumber, $patron_1->{borrowernumber}, '->last should work even if there is only 1 result' );
    $last_patron = Koha::Patrons->search({ surname => 'should_not_exist' })->last;
    is( $last_patron, undef, '->last should return undef if search does not return any results' );
};

subtest 'get_column' => sub {
    plan tests => 1;
    my @cities = Koha::Cities->search;
    my @city_names = map { $_->city_name } @cities;
    is_deeply( [ Koha::Cities->search->get_column('city_name') ], \@city_names, 'Koha::Objects->get_column should be allowed' );
};

subtest 'Exceptions' => sub {
    plan tests => 2;

    my $patron_borrowernumber = $builder->build({ source => 'Borrower' })->{ borrowernumber };
    my $patron = Koha::Patrons->find( $patron_borrowernumber );

    try {
        $patron->blah('blah');
    } catch {
        ok( $_->isa('Koha::Exceptions::Object::MethodNotCoveredByTests'),
            'Calling a non-covered method should raise a Koha::Exceptions::Object::MethodNotCoveredByTests exception' );
    };

    try {
        $patron->set({ blah => 'blah' });
    } catch {
        ok( $_->isa('Koha::Exceptions::Object::PropertyNotFound'),
            'Setting a non-existent property should raise a Koha::Exceptions::Object::PropertyNotFound exception' );
    };
};

$schema->storage->txn_rollback;
1;
