use utf8;
package Koha::Schema::Result::BackgroundJob;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::BackgroundJob

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<background_jobs>

=cut

__PACKAGE__->table("background_jobs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 job_id

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 job_status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 progress

  data_type: 'integer'
  is_nullable: 1

=head2 job_type

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 job_size

  data_type: 'integer'
  is_nullable: 1

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 1

=head2 data

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "job_id",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "job_status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "progress",
  { data_type => "integer", is_nullable => 1 },
  "job_type",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "job_size",
  { data_type => "integer", is_nullable => 1 },
  "borrowernumber",
  { data_type => "integer", is_nullable => 1 },
  "data",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<job_id>

=over 4

=item * L</job_id>

=back

=cut

__PACKAGE__->add_unique_constraint("job_id", ["job_id"]);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-03-28 15:48:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+cDMKjzg+Sf9o0pck/8hjA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
