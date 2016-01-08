#!/usr/bin/perl

use Modern::Perl;
use CGI;
use C4::Output;
use Koha::Libraries;
for my $l (qw(CPL MPL IPT )) {
    Koha::Libraries->find($l)->branchname;
}

my $query = CGI->new;
print $query->header({
    type => 'text/html',
    status => '200 OK',
    charset => 'UTF-8',
    Pragma => 'no-cache',
});
print "<html><body>Hello</body></html>";

#my $cookie = undef;
#output_html_with_http_headers $query, $cookie, "<html><body>Hello</body></html>";
