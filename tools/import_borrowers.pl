#!/usr/bin/perl

# Copyright 2007 Liblime
# Parts copyright 2010 BibLibre
#
# This file is part of Koha.
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

# Script to take some borrowers data in a known format and load it into Koha
#
# File format
#
# cardnumber,surname,firstname,title,othernames,initials,streetnumber,streettype,
# address line , address line 2, city, zipcode, contry, email, phone, mobile, fax, work email, work phone,
# alternate streetnumber, alternate streettype, alternate address line 1, alternate city,
# alternate zipcode, alternate country, alternate email, alternate phone, date of birth, branchcode,
# categorycode, enrollment date, expiry date, noaddress, lost, debarred, contact surname,
# contact firstname, contact title, borrower notes, contact relationship
# gender, username, opac note, contact note, password, sort one, sort two
#
# any fields except cardnumber can be blank but the number of fields must match
# dates should be in the format you have set up Koha to expect
# branchcode and categorycode need to be valid

use Modern::Perl;

use C4::Auth;
use C4::Output;
use C4::Templates;
use Koha::Patron::Debarments;
use Koha::DateUtils;

use C4::Branch;
use C4::Members;

use Koha::Patrons::Import qw(import_patrons);

use Text::CSV;

# Text::CSV::Unicode, even in binary mode, fails to parse lines with these diacriticals:
# ė
# č

use CGI qw ( -utf8 );

# use encoding 'utf8';    # don't do this

my ( @errors, @feedback );
my $extended = C4::Context->preference('ExtendedPatronAttributes');

my @columnkeys = map { $_ ne 'borrowernumber' ? $_ : () } C4::Members::columns();
push( @columnkeys, 'patron_attributes' ) if $extended;

my $input = CGI->new();

#push @feedback, {feedback=>1, name=>'backend', value=>$csv->backend, backend=>$csv->backend}; #XXX

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/import_borrowers.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'import_patrons' },
        debug           => 1,
    }
);

# get the branches and pass them to the template
my $branches = GetBranchesLoop();
$template->param( branches => $branches ) if ($branches);

# get the patron categories and pass them to the template
my $categories = GetBorrowercategoryList();
$template->param( categories => $categories ) if ($categories);
my $columns = C4::Templates::GetColumnDefs($input)->{borrowers};
$columns = [ grep { $_->{field} ne 'borrowernumber' ? $_ : () } @$columns ];
$template->param( borrower_fields => $columns );

if ( $input->param('sample') ) {
    our $csv = Text::CSV->new( { binary => 1 } );    # binary needed for non-ASCII Unicode
    print $input->header(
        -type       => 'application/vnd.sun.xml.calc',    # 'application/vnd.ms-excel' ?
        -attachment => 'patron_import.csv',
    );
    $csv->combine(@columnkeys);
    print $csv->string, "\n";
    exit 0;
}

my $uploadborrowers = $input->param('uploadborrowers');
my $matchpoint      = $input->param('matchpoint');
if ($matchpoint) {
    $matchpoint =~ s/^patron_attribute_//;
}

$template->param( SCRIPT_NAME => '/cgi-bin/koha/tools/import_borrowers.pl' );

if ( $uploadborrowers && length($uploadborrowers) > 0 ) {
    my $handle   = $input->upload('uploadborrowers');
    my %defaults = $input->Vars;

    my $return = Koha::Patrons::Import::import_patrons(
        {
            file                         => $handle,
            defaults                     => \%defaults,
            matchpoint                   => $matchpoint,
            overwrite_cardnumber         => $input->param('overwrite_cardnumber'),
            preserve_extended_attributes => $input->param('ext_preserve') || 0,
        }
    );

    my $feedback    = $return->{feedback};
    my $errors      = $return->{errors};
    my $imported    = $return->{imported};
    my $overwritten = $return->{overwritten};
    my $alreadyindb = $return->{already_in_db};
    my $invalid     = $return->{invalid};

    my $uploadinfo = $input->uploadInfo($uploadborrowers);
    foreach ( keys %$uploadinfo ) {
        push @$feedback, { feedback => 1, name => $_, value => $uploadinfo->{$_}, $_ => $uploadinfo->{$_} };
    }

    push @$feedback, { feedback => 1, name => 'filename', value => $uploadborrowers, filename => $uploadborrowers };

    $template->param(
        uploadborrowers => 1,
        errors          => $errors,
        feedback        => $feedback,
        imported        => $imported,
        overwritten     => $overwritten,
        alreadyindb     => $alreadyindb,
        invalid         => $invalid,
        total           => $imported + $alreadyindb + $invalid + $overwritten,
    );

}
else {
    if ($extended) {
        my @matchpoints = ();
        my @attr_types = C4::Members::AttributeTypes::GetAttributeTypes( undef, 1 );
        foreach my $type (@attr_types) {
            my $attr_type = C4::Members::AttributeTypes->fetch( $type->{code} );
            if ( $attr_type->unique_id() ) {
                push @matchpoints,
                  { code => "patron_attribute_" . $attr_type->code(), description => $attr_type->description() };
            }
        }
        $template->param( matchpoints => \@matchpoints );
    }
}

output_html_with_http_headers $input, $cookie, $template->output;

