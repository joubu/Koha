package Koha::Object::Simple;

# Copyright 2017 Koha Development Team
#
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

use base qw( Class::Accessor );

sub new {
    my ( $class, $attributes ) = @_;

    return $class->SUPER::new( $attributes );
}

sub AUTOLOAD {
    my $self = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*://;
    return $self->{$method} if exists $self->{$method};

    # FIXME Not sure we want this. That might hide performance issues
    $self = Koha::AuthorisedValue->new( {%$self} );
    return $self->$method;
}

1;
