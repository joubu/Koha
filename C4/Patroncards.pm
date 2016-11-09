package C4::Patroncards;

our ( @ISA, @EXPORT_OK );

BEGIN {

    require Exporter;
    @ISA       = qw( Exporter );
    @EXPORT_OK = qw(
                     unpack_UTF8
                     text_alignment
                     leading
                     box
                     get_borrower_attributes
                     put_image
                     get_image
                     rm_image
    );
    use C4::Patroncards::Batch;
    use C4::Patroncards::Layout;
    use C4::Patroncards::Lib;
    use C4::Patroncards::Patroncard;
    use C4::Patroncards::Profile;
    use C4::Patroncards::Template;
}

1;
