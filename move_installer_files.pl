#!/usr/bin/perl

use Modern::Perl;
my $koha_root = '/home/vagrant/kohaclone';
my $installer_root = $koha_root . '/installer/data/mysql';

# Launch me with  de-DE es-ES fr-CA fr-FR it-IT nb-NO pl-PL ru-RU uk-UA
for my $lang ( qw ( de-DE ) ) {
    my $lang_root = $installer_root . '/' . $lang;
    `mkdir $lang_root/default`;

    my $optional = 'optional';
    my $mandatory = 'mandatory';
    if ( $lang eq 'fr-CA' ) {
        $optional = 'facultatif';
        $mandatory = 'obligatoire';
    } elsif ( $lang eq 'fr-FR' ) {
        $optional = '2-Optionel';
        $mandatory = '1-Obligatoire';
    } elsif ( $lang eq 'it-IT' ) {
        $mandatory = 'necessari';
        $optional  = 'necessari';
    } elsif ( $lang eq 'nb-NO' ) {
        $mandatory = '1-Obligatorisk';
        $optional = '2-Valgfritt';
    }
    # optional to default
    `git mv $lang_root/$optional/auth_val.sql $lang_root/default/`;
    `git mv $lang_root/$optional/auth_val.txt $lang_root/default/`;
    `git mv $lang_root/$optional/csv_profiles.sql $lang_root/default/`;
    `git mv $lang_root/$optional/csv_profiles.txt $lang_root/default/`;
    `git mv $lang_root/$optional/parameters.sql $lang_root/default/`;
    `git mv $lang_root/$optional/parameters.txt $lang_root/default/`;


    # mandatory to default
    `git mv $lang_root/$mandatory/auth_values.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/auth_values.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/class_sources.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/class_sources.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/message_transport_types.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/message_transport_types.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_frequencies.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_frequencies.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_notices.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_notices.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_notices_message_attributes.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_notices_message_attributes.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_notices_message_transports.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_notices_message_transports.txt $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_numberpatterns.sql $lang_root/default/`;
    `git mv $lang_root/$mandatory/sample_numberpatterns.txt $lang_root/default/`;
;
    `mkdir $lang_root/marcflavour/marc21/default > /dev/null`;
    `git mv $lang_root/marcflavour/marc21/*/* $lang_root/marcflavour/marc21/default/`;

    if ( $lang eq 'fr-FR' ) {
        for my $f ( qw( unimarc_complet unimarc_lecture_pub ) ) {
            `mkdir $lang_root/marcflavour/$f/default > /dev/null`;
            `git mv $lang_root/marcflavour/$f/*/* $lang_root/marcflavour/$f/default`
        }
    }
    last;
}
