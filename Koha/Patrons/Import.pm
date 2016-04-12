package Koha::Patrons::Import;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;
use Text::CSV;

use C4::Members;
use C4::Branch;
use C4::Members::Attributes qw(:all);

use Koha::DateUtils;

=head1 NAME

Koha::Patrons::Import - Perl Module containing import_patrons method exported from import_borrowers script.

=head1 SYNOPSIS

use Koha::Patrons::Import;

=head1 DESCRIPTION

This module contains one method for importing patrons in bulk.

=head1 FUNCTIONS

=head2 import_patrons

 my $return = Koha::Patrons::Import::import_patrons($params);

Applies various checks and imports patrons in bulk from a csv file.

Further pod documentation needed here.

=cut

sub import_patrons {
    my ($params) = @_;

    my $handle               = $params->{file};
    my $matchpoint           = $params->{matchpoint};
    my $defaults             = $params->{defaults};
    my $ext_preserve         = $params->{preserve_extended_attributes};
    my $overwrite_cardnumber = $params->{overwrite_cardnumber};

    unless( $handle ) { carp("No file handle passed in!"); return; }
    my $extended            = C4::Context->preference('ExtendedPatronAttributes');
    my $set_messaging_prefs = C4::Context->preference('EnhancedMessagingPreferences');

    my @columnkeys = map { $_ ne 'borrowernumber' ? $_ : () } C4::Members::columns();
    push( @columnkeys, 'patron_attributes' ) if $extended;

    our $csv = Text::CSV->new( { binary => 1 } );    # binary needed for non-ASCII Unicode

    my @feedback;
    my @errors;

    my $imported    = 0;
    my $alreadyindb = 0;
    my $overwritten = 0;
    my $invalid     = 0;
    my $matchpoint_attr_type;

    # use header line to construct key to column map
    my $borrowerline = <$handle>;
    my $status       = $csv->parse($borrowerline);
    ($status) or push @errors, { badheader => 1, line => $., lineraw => $borrowerline };
    my @csvcolumns = $csv->fields();
    my %csvkeycol;
    my $col = 0;
    foreach my $keycol (@csvcolumns) {

        # columnkeys don't contain whitespace, but some stupid tools add it
        $keycol =~ s/ +//g;
        $csvkeycol{$keycol} = $col++;
    }

    #warn($borrowerline);
    if ($extended) {
        $matchpoint_attr_type = C4::Members::AttributeTypes->fetch($matchpoint);
    }

    push @feedback, { feedback => 1, name => 'headerrow', value => join( ', ', @csvcolumns ) };
    my $today_iso = output_pref( { dt => dt_from_string, dateonly => 1, dateformat => 'iso' } );
    my @criticals = qw(surname branchcode categorycode);    # there probably should be others
    my @bad_dates;                                          # I've had a few.
  LINE: while ( my $borrowerline = <$handle> ) {
        my %borrower;
        my @missing_criticals;
        my $patron_attributes;
        my $status  = $csv->parse($borrowerline);
        my @columns = $csv->fields();
        if ( !$status ) {
            push @missing_criticals, { badparse => 1, line => $., lineraw => $borrowerline };
        }
        elsif ( @columns == @columnkeys ) {
            @borrower{@columnkeys} = @columns;

            # MJR: try to fill blanks gracefully by using default values
            foreach my $key (@columnkeys) {
                if ( $borrower{$key} !~ /\S/ ) {
                    $borrower{$key} = $defaults->{$key};
                }
            }
        }
        else {
            # MJR: try to recover gracefully by using default values
            foreach my $key (@columnkeys) {
                if ( defined( $csvkeycol{$key} ) and $columns[ $csvkeycol{$key} ] =~ /\S/ ) {
                    $borrower{$key} = $columns[ $csvkeycol{$key} ];
                }
                elsif ( $defaults->{$key} ) {
                    $borrower{$key} = $defaults->{$key};
                }
                elsif ( scalar grep { $key eq $_ } @criticals ) {

                    # a critical field is undefined
                    push @missing_criticals, { key => $key, line => $., lineraw => $borrowerline };
                }
                else {
                    $borrower{$key} = '';
                }
            }
        }

        #warn join(':',%borrower);
        if ( $borrower{categorycode} ) {
            push @missing_criticals,
              {
                key          => 'categorycode',
                line         => $.,
                lineraw      => $borrowerline,
                value        => $borrower{categorycode},
                category_map => 1
              }
              unless GetBorrowercategory( $borrower{categorycode} );
        }
        else {
            push @missing_criticals, { key => 'categorycode', line => $., lineraw => $borrowerline };
        }
        if ( $borrower{branchcode} ) {
            push @missing_criticals,
              {
                key        => 'branchcode',
                line       => $.,
                lineraw    => $borrowerline,
                value      => $borrower{branchcode},
                branch_map => 1
              }
              unless GetBranchName( $borrower{branchcode} );
        }
        else {
            push @missing_criticals, { key => 'branchcode', line => $., lineraw => $borrowerline };
        }
        if (@missing_criticals) {
            foreach (@missing_criticals) {
                $_->{borrowernumber} = $borrower{borrowernumber} || 'UNDEF';
                $_->{surname}        = $borrower{surname}        || 'UNDEF';
            }
            $invalid++;
            ( 25 > scalar @errors ) and push @errors, { missing_criticals => \@missing_criticals };

            # The first 25 errors are enough.  Keeping track of 30,000+ would destroy performance.
            next LINE;
        }
        if ($extended) {
            my $attr_str = $borrower{patron_attributes};
            $attr_str =~ s/\xe2\x80\x9c/"/g;    # fixup double quotes in case we are passed smart quotes
            $attr_str =~ s/\xe2\x80\x9d/"/g;
            push @feedback, { feedback => 1, name => 'attribute string', value => $attr_str };
            delete $borrower{patron_attributes}; # not really a field in borrowers, so we don't want to pass it to ModMember.
            $patron_attributes = extended_attributes_code_value_arrayref($attr_str);
        }

        # Popular spreadsheet applications make it difficult to force date outputs to be zero-padded, but we require it.
        foreach (qw(dateofbirth dateenrolled dateexpiry)) {
            my $tempdate = $borrower{$_} or next;
            $tempdate = eval { output_pref( { dt => dt_from_string( $tempdate ), dateonly => 1, dateformat => 'iso' } ); };
            if ($tempdate) {
                $borrower{$_} = $tempdate;
            } else {
                $borrower{$_} = '';
                push @missing_criticals, { key => $_, line => $., lineraw => $borrowerline, bad_date => 1 };
            }
        }
        $borrower{dateenrolled} = $today_iso unless $borrower{dateenrolled};
        $borrower{dateexpiry} = GetExpiryDate( $borrower{categorycode}, $borrower{dateenrolled} )
          unless $borrower{dateexpiry};
        my $borrowernumber;
        my $member;
        if ( ( $matchpoint eq 'cardnumber' ) && ( $borrower{'cardnumber'} ) ) {
            $member = GetMember( 'cardnumber' => $borrower{'cardnumber'} );
            if ($member) {
                $borrowernumber = $member->{'borrowernumber'};
            }
        }
        elsif ($extended) {
            if ( defined($matchpoint_attr_type) ) {
                foreach my $attr (@$patron_attributes) {
                    if ( $attr->{code} eq $matchpoint and $attr->{value} ne '' ) {
                        my @borrowernumbers = $matchpoint_attr_type->get_patrons( $attr->{value} );
                        $borrowernumber = $borrowernumbers[0] if scalar(@borrowernumbers) == 1;
                        last;
                    }
                }
            }
        }

        if ( C4::Members::checkcardnumber( $borrower{cardnumber}, $borrowernumber ) ) {
            push @errors,
              {
                invalid_cardnumber => 1,
                borrowernumber     => $borrowernumber,
                cardnumber         => $borrower{cardnumber}
              };
            $invalid++;
            next;
        }

        # generate a proper login if none provided
        if ( $borrower{userid} eq '' || !Check_Userid( $borrower{userid} ) ) {
            push @errors, { duplicate_userid => 1, userid => $borrower{userid} };
            $invalid++;
            next LINE;
        }

        if ($borrowernumber) {

            # borrower exists
            unless ($overwrite_cardnumber) {
                $alreadyindb++;
                push(
                    @feedback,
                    {
                        already_in_db => 1,
                        value         => $borrower{'surname'} . ' / ' . $borrowernumber
                    }
                );
                next LINE;
            }
            $borrower{'borrowernumber'} = $borrowernumber;
            for my $col ( keys %borrower ) {

                # use values from extant patron unless our csv file includes this column or we provided a default.
                # FIXME : You cannot update a field with a  perl-evaluated false value using the defaults.

                # The password is always encrypted, skip it!
                next if $col eq 'password';

                unless ( exists( $csvkeycol{$col} ) || $defaults->{$col} ) {
                    $borrower{$col} = $member->{$col} if ( $member->{$col} );
                }
            }
            unless ( ModMember(%borrower) ) {
                $invalid++;

                push(
                    @errors,
                    {
                        name  => 'lastinvalid',
                        value => $borrower{'surname'} . ' / ' . $borrowernumber
                    }
                );
                next LINE;
            }
            if ( $borrower{debarred} ) {

                # Check to see if this debarment already exists
                my $debarrments = GetDebarments(
                    {
                        borrowernumber => $borrowernumber,
                        expiration     => $borrower{debarred},
                        comment        => $borrower{debarredcomment}
                    }
                );

                # If it doesn't, then add it!
                unless (@$debarrments) {
                    AddDebarment(
                        {
                            borrowernumber => $borrowernumber,
                            expiration     => $borrower{debarred},
                            comment        => $borrower{debarredcomment}
                        }
                    );
                }
            }
            if ($extended) {
                if ($ext_preserve) {
                    my $old_attributes = GetBorrowerAttributes($borrowernumber);
                    $patron_attributes = extended_attributes_merge( $old_attributes, $patron_attributes );
                }
                push @errors, { unknown_error => 1 }
                  unless SetBorrowerAttributes( $borrower{'borrowernumber'}, $patron_attributes, 'no_branch_limit' );
            }
            $overwritten++;
            push(
                @feedback,
                {
                    feedback => 1,
                    name     => 'lastoverwritten',
                    value    => $borrower{'surname'} . ' / ' . $borrowernumber
                }
            );
        }
        else {
            # FIXME: fixup_cardnumber says to lock table, but the web interface doesn't so this doesn't either.
            # At least this is closer to AddMember than in members/memberentry.pl
            if ( !$borrower{'cardnumber'} ) {
                $borrower{'cardnumber'} = fixup_cardnumber(undef);
            }
            if ( $borrowernumber = AddMember(%borrower) ) {

                if ( $borrower{debarred} ) {
                    AddDebarment(
                        {
                            borrowernumber => $borrowernumber,
                            expiration     => $borrower{debarred},
                            comment        => $borrower{debarredcomment}
                        }
                    );
                }

                if ($extended) {
                    SetBorrowerAttributes( $borrowernumber, $patron_attributes );
                }

                if ($set_messaging_prefs) {
                    C4::Members::Messaging::SetMessagingPreferencesFromDefaults(
                        {
                            borrowernumber => $borrowernumber,
                            categorycode   => $borrower{categorycode}
                        }
                    );
                }

                $imported++;
                push(
                    @feedback,
                    {
                        feedback => 1,
                        name     => 'lastimported',
                        value    => $borrower{'surname'} . ' / ' . $borrowernumber
                    }
                );
            }
            else {
                $invalid++;
                push @errors, { unknown_error => 1 };
                push(
                    @errors,
                    {
                        name  => 'lastinvalid',
                        value => $borrower{'surname'} . ' / AddMember',
                    }
                );
            }
        }
    }

    return {
        feedback      => \@feedback,
        errors        => \@errors,
        imported      => $imported,
        overwritten   => $overwritten,
        already_in_db => $alreadyindb,
        invalid       => $invalid,
    };
}

END { }    # module clean-up code here (global destructor)

1;

__END__

=head1 AUTHOR

Koha Team

=cut
