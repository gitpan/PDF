#
# PDF::Pages.pm, version 1.04 Feb 1998 antro
#
# Copyright (c) 1998 Antonio Rosella Italy
#
# Free usage under the same Perl Licence condition.
#

package PDF::Pages;

$PDF::Pages::VERSION = "1.04";

require 5.004;
use Carp;
use Exporter ();

@ISA = qw(Exporter);

@EXPORT_OK = qw( ReadPageTree );

sub new {

my %PDF_Pages = (
   Count => 0,
   Kids => [],
   MediaBox => 0,
   Page_obj_nr => 0,
   Parent => 0,
);

  $/="\r";
  my $that = shift;
  my $class=ref($that) || $that ;
  my $self = \%PDF_Pages ;
  return bless $self, $class;
};

sub ReadPageTree {
  my $self = shift;
  my $pdf_struct=shift;

  croak "PDF File not specified !\n" if ! $pdf_struct->{File_Name}  ; 

  open (FILE, "$pdf_struct->{File_Name}");
  if ($pdf_struct->{Catalog}) {
    my $ro = $pdf_struct->{Root_Object};
    $ro =~ s/(\d+)\s+\d+/$1/;
    my $ro_gen=$pdf_struct->{Gen_Num}[$ro];
    seek FILE, $pdf_struct->{Objects}[$ro] ,0 ;
    while (<FILE>) {
      next if /$ro\s+$ro_gen\s+obj\r?\n?/ ; 
      next if /<<\r?\n?/  ;
      /\/Pages/ && do { s/\r?\n?\/Pages\s+(\d+)\s+(\d+)\s+R\r?\n?/$1 $2/;
		      $pdf_struct->{Catalog}->{Pages} = $_;
		      my ($ind,$gen)=split(" ",$pdf_struct->{Catalog}->{Pages});
		      $pdf_struct->{Gen_Num}[$ind] != $gen && die "Can't find Pages Node\n";
                      $self->ReadPage(\*FILE, $pdf_struct->{Objects}[$ind], 0 );
		    };
      last if />>\r?\n?/ ;
    }
  }
  close(FILE);
}

sub ReadPage {
    my $self = shift;
    my $fd = shift;
    my $offset=shift;
    my $parent=shift;

    $self->{Parent}=$parent;

    my $result;

    seek $fd, $offset, 0;

    $_=<$fd>;
    while(<$fd>) {
      next if /<</ ;
      /^\/Type\s+/ && do { croak " Page tree corrupted!\n" if !(/\/Pages/ ); }; 
      $self->{Count} = $_ if /\/Count\s+/ ;
      next if /\/Parent/ ;
      next if /\/Kids/ ;
      last if />>/ ;
    }
    $self->{Count} =~ s/\n?\r?\/Count\s+(\d+)\s*\r?\n?/$1/;
    return $result;
}

1;
__END__

=head1 NAME

PDF::Pages - Library for parsing the PDF tree structure in Perl

=head1 SYNOPSIS

  use PDF ;
  use PDF::Pages ;

  $pdf_pages=PDF::Pages->new;
  $pdf_pages->ReadPageTree($pdf_struct);;

=head1 DESCRIPTION

This is a part of the more general PDF library. In this section you
will find the functions related to the page tree of a PDF file. 


=head1 Constructor

=over 4

=item B< new >

  This is the constructor of a new PDF tree object. It returns an
  empty PDF Page tree descriptor ( can be filled with <B ReadPageTree> ). 

=back 4

=head1 Methods

The available methods are :

=over 4

=item B<ReadPageTree ( pdf_struct ) >

This method reads the information contained in the root of the page tree of 
the argument PDF document.

=back 4

=head1 Copyright

  Copyright 1998, Antonio Rosella antro@technologist.com

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 Availability

The latest version of this library is available from:

http://www.geocities.com/CapeCanaveral/Hangar/4794/

and from CPAN .

=cut
