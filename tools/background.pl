#!/usr/bin/perl

use Modern::Perl;

use CGI;
use List::MoreUtils qw( uniq );

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::BackgroundJob;

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
        template_name => 'tools/background.tt',
        query => $input,
        type => "intranet",
        authnotrequired => 0,
        flagsrequired => { tools => 'records_batchmod' },
});

my $sessionID = $input->cookie("CGISESSID");

my $op = $input->param('op');

$template->param( op => $op );

output_html_with_http_headers $input, $cookie, $template->output;

