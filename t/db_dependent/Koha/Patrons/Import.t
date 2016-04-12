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
use Test::More;
use Test::MockModule;

use Koha::Database;

use File::Temp qw(tempfile tempdir);
my $temp_dir = tempdir('Koha_patrons_import_test_XXXX', CLEANUP => 1, TMPDIR => 1);

use t::lib::TestBuilder;
my $builder = t::lib::TestBuilder->new;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

# ########## Tests start here #############################
# Given ... we can use the module
BEGIN { use_ok('Koha::Patrons::Import'); }

# Given ... we can reach the method(s)
my @methods = ('import_patrons');
can_ok('Koha::Patrons::Import', @methods);

# Tests for Koha::Patrons::Import::import_patrons()
# Given ... nothing much. When ... Then ...
my $result = Koha::Patrons::Import::import_patrons(undef);
is($result, undef, 'Got the expected undef from import_patrons with nothing much');

# Given ... some params but no file handle.
my $params_0 = { some_stuff => 'random stuff', };

# When ... Then ...
my $result_0 = Koha::Patrons::Import::import_patrons($params_0);
is($result_0, undef, 'Got the expected undef from import_patrons with no file handle');

# Given ... a file handle to file with headers only.
my $csv_headers = 'cardnumber,surname,firstname,title,othernames,initials,streetnumber,streettype,address,address2,city,state,zipcode,country,email,phone,mobile,fax,dateofbirth,branchcode,categorycode,dateenrolled,dateexpiry,userid,password';
my $csv_one_line = '1000,Nancy,Jenkins,Dr,,NJ,78,Circle,Bunting,El Paso,Henderson,Texas,79984,United States,ajenkins0@sourceforge.net,7-(388)559-6763,3-(373)151-4471,8-(509)286-4001,16/10/1965,CPL,PT,28/12/2014,01/07/2015,jjenkins0,DPQILy';

my $filename_1 = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_1, "<", $filename_1) or die "cannot open < $filename_1: $!";
my $params_1 = { file => $handle_1, };

# When ...
my $result_1 = Koha::Patrons::Import::import_patrons($params_1);

# Then ...
is($result_1->{imported}, 1, 'Got the expected 1 imported result from import_patrons with no matchpoint defined');
is($result_1->{invalid}, 0, 'Got the expected 0 invalid result from import_patrons with no matchpoint defined');

# Given ... a valid file handle, a bad matchpoint resulting in invalid card number
my $filename_2 = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_2, "<", $filename_2) or die "cannot open < $filename_2: $!";
my $params_2 = { file => $handle_2, matchpoint => 'SHOW_BCODE', };

# When ...
my $result_2 = Koha::Patrons::Import::import_patrons($params_2);

# Then ...
is($result_2->{imported}, 0, 'Got the expected 0 imported result from import_patrons with no matchpoint defined');
is($result_2->{invalid}, 1, 'Got the expected 1 invalid result from import_patrons with no matchpoint defined');
is($result_2->{errors}->[0]->{invalid_cardnumber}, 1, 'Got the expected invalid card number from import patrons with invalid card number');

# Given ... valid file handle, good matchpoint but same input as prior test.
my $filename_3 = make_csv($temp_dir, $csv_headers, $csv_one_line);
open(my $handle_3, "<", $filename_3) or die "cannot open < $filename_3: $!";
my $params_3 = { file => $handle_3, matchpoint => 'cardnumber', };

# When ...
my $result_3 = Koha::Patrons::Import::import_patrons($params_3);

# Then ...
is($result_3->{imported}, 0, 'Got the expected 0 imported result from import_patrons with duplicate userid');
is($result_3->{invalid}, 1, 'Got the expected 1 invalid result from import_patrons with duplicate userid');
is($result_3->{errors}->[0]->{duplicate_userid}, 1, 'Got the expected duplicate userid error from import patrons with duplicate userid');

# Given ... a new input and mocked C4::Context
my $context = new Test::MockModule('C4::Context');
$context->mock('preference', sub { my ($mod, $meth) = @_; if ( $meth eq 'ExtendedPatronAttributes' ) { return 1; } });

my $new_input_line = '1001,Donna,Sullivan,Mrs,Henry,DS,59,Court,Burrows,Reading,Salt Lake City,Pennsylvania,19605,United States,hsullivan1@purevolume.com,3-(864)009-3006,7-(291)885-8423,1-(879)095-5038,19/09/1970,LPL,PT,04/03/2015,01/07/2015,hsullivan1,8j6P6Dmap';
my $filename_4 = make_csv($temp_dir, $csv_headers, $new_input_line);
open(my $handle_4, "<", $filename_4) or die "cannot open < $filename_4: $!";
my $params_4 = { file => $handle_4, matchpoint => 'cardnumber', };

# When ... Then ...
my $result_4 = Koha::Patrons::Import::import_patrons($params_4);
is($result_4->{imported}, 1, 'Got the expected 1 imported result from import_patrons with extended user');

# ###### Test utility ###########
sub make_csv {
    my ($temp_dir, @lines) = @_;

    my ($fh, $filename) = tempfile( DIR => $temp_dir) or die $!;
    print $fh $_."\r\n" foreach @lines;
    close $fh or die $!;

    return $filename;
}

done_testing();

1;