#
# PDF::Core.pm, version 1.08 Dec 1998 antro
#
# Copyright (c) 1998 Antonio Rosella Italy antro@technologist.com
#
# Free usage under the same Perl Licence condition.
#

package PDF::Core;

$PDF::Core::VERSION = "1.08";

require 5.004;
use Carp;
use Exporter ();

use PDF::Pages;

@ISA = qw(Exporter);

sub new {

my %PDF_Fields = (
   Author => "",
   Catalog => {},
   CreationDate => "",
   Creator => "",
   Cross_Reference_Size => 0,
   File_Handler => undef,
   File_Name => undef,
   Gen_Num => [],
   Header => undef,
   Keywords => "",
   ModDate => "",
   Objects => [],
   PageTree => PDF::Pages->new,
   Producer => "",
   Root_Object => undef,
   Subject => "",
   Title => "",
   Updated => 0, 
);

  my $that = shift;
  my $class=ref($that) || $that ;
  my $self = \%PDF_Fields ;
  my $buf2=bless $self, $class;
  if ( @_ ) { 			# I have the filename
    $buf2->TargetFile($_[0]) ; 
  }
  return bless $self, $class;
};

sub DESTROY {
#
# Close the file if not empty
#
  my $self = shift;
  close ( $self->{File_Handler} ) if $self->{File_Handler} ;
}


sub PDFGetline {
    my $fd = shift;
    my $offset=shift;

    my $buffer;
    my $endflag=1;

    binmode $fd;
    seek $fd, $$offset, 0;

    read($fd,$buffer,2);
    $buffer =~ s/^\r?\n?// ;

    $$offset +=2;

    while ($endflag) {
      read($fd,$_,1);
      $$offset++;
      $endflag = 0 if ( $_ eq "\r" || $_ eq "\n");
      $buffer = $buffer . $_ ;
    }
    return $buffer;
}

1;
__END__

=head1 NAME

PDF::Core - Core Library for PDF library

=head1 SYNOPSIS

  use PDF::Core;
  $pdf=PDF::Core->new ;
  $pdf=PDF->new(filename);


=head1 DESCRIPTION

The main purpose of the PDF::Core library is to provide the data structure
and the constructor for the more general PDF library.

=head1 Constructor

=over 4

=item B<new ( [ filename ] )>

This is the constructor of a new PDF object. If the filename is missing, it returns an
empty PDF descriptor ( can be filled with $pdf->TargetFile). Otherwise, It acts as the
B<PDF::Parse::TargetFile> method.

=back

=head1 Variables

The only available variable is :

=over 4

=item B<$PDF::Core::VERSION>

Contain the version of the library installed

=back 4

=head1 Copyright

  Copyright 1998, Antonio Rosella antro@technologist.com

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 Availability

The latest version of this library is likely to be available from:

http://www.geocities.com/CapeCanaveral/Hangar/4794/

=cut
