#
# PDF.pm, version 1.10 November 1999 antro
#
# Copyright (c) 1998 -1999 Antonio Rosella Italy antro@tiscalinet.it
#
# Free usage under the same Perl Licence condition.
#

package PDF;

$PDF::VERSION = "1.10";

require 5.004;

require PDF::Core;  
require PDF::Parse;  

use Carp;
use Exporter ();

#
# Verbose off by default
#

my $Verbose = 0;

@ISA = qw(Exporter PDF::Core PDF::Parse);

@EXPORT_OK = qw( IsaPDF Version IscryptPDF );

use vars qw( $Verbose ) ;

sub Version { 
  return ($_[0]->{Header}); 
}

sub IsaPDF { 
  return ($_[0]->{Header} != undef) ; 
}

sub IscryptPDF { 
  return ($_[0]->{Crypt_Object} != undef) ; 
}

1;

__END__

=head1 NAME

PDF - Library for PDF access and manipulation in Perl

=head1 SYNOPSIS

  use PDF;

  $pdf=PDF->new ;
  $pdf=PDF->new(filename);

  $result=$pdf->TargetFile( filename );

  print "is a pdf file\n" if ( $pdf->IsaPDF ) ;
  print "Has ",$pdf->Pages," Pages \n";
  print "Use a PDF Version  ",$pdf->Version ," \n";
  print "and it is crypted  " if ( $pdf->IscryptedPDF) ;

  print "filename with title",$pdf->GetInfo("Title"),"\n";
  print "and with subject ",$pdf->GetInfo("Subject"),"\n";
  print "was written by ",$pdf->GetInfo("Author"),"\n";
  print "in date ",$pdf->GetInfo("CreationDate"),"\n";
  print "using ",$pdf->GetInfo("Creator"),"\n";
  print "and converted with ",$pdf->GetInfo("Producer"),"\n";
  print "The last modification occurred ",$pdf->GetInfo("ModDate"),"\n";
  print "The associated keywords are ",$pdf->GetInfo("Keywords"),"\n";

  my (startx,starty, endx,endy) = $pdf->PageSize ;

=head1 DESCRIPTION

The main purpose of the PDF library is to provide classes and functions 
that allow to read and manipulate PDF files with perl. PDF stands for
Portable Document Format and is a format proposed by Adobe. For
more details abour PDF, refer to:

B<http://www.adobe.com/> 

The main idea is to provide some "basic" modules for access 
the information contained in a PDF file. Even if at this
moment is in an early development stage, the scripts in the 
example directory show that it is usable. 

B<is_pdf> script test a list of files in order divide the PDF file
from the non PDF using the info provided by the files 
themselves. It doesn't use the I<.pdf> extension, it uses the information
contained in the file.

B<pdf_version> returns the PDF level used for writing a file.

B<pdf_pages> gives the number of pages of a PDF file. 

The original library is now splitted in 3 section :

B<PDF::Core> that contains the data structure and the constructor;
B<PDF::Parse> that read a PDF from an external file.
B<PDF::Pages> that deal with the PDF page tree.

=head1 Constructor

=over 4

=item B<new ( [ filename ] )>

This is the constructor of a new PDF object. If the filename is missing, it returns an
empty PDF descriptor ( can be filled with $pdf->TargetFile ). Otherwise, It acts as the
B<TargetFile> method.

=back

=head1 Methods

The available methods are :

=over 4

=item B<TargetFile ( filename ) >

This method links the filename to the pdf descriptor and check the header.

=item B<IsaPDF>

Returns true if the parsed file is a PDF one.

=item B<IscryptPDF>

Returns true if the parsed PDFfile is a crypted PDF.

=item B<Version>

Returns the PDF version used for writing the object file.

=item B<Pages>

Returns the number of pages of the object file. As side effect, 
the PDF object contains part of the Catalog structure after 
the call ( more specifically, part of the Root Tree ).

=item B<GetInfo>

  Return the various information contained in the info section of
  a PDF file ( if present ). A PDF file can have :

  a title ( B<GetInfo("Title")> )
  a subject ( B<GetInfo("Subject") )
  an author ( B<GetInfo("Author") )
  a creation date ( B<GetInfo("CreationDate") )
  a creator ( B<GetInfo("Creator") )
  a producer ( B<GetInfo("Producer") )
  a modification date ( B<GetInfo("ModDate") )
  some keywords ( B<GetInfo("Keywords") )

Note: with the current implementation, if the Info object of a PDF was updated one or more
times, only the last modification is found.

=item B<PageSize>

Returns the size of the page of the object file. As side effect, 
the PDF object contains part of the Catalog structure after 
the call ( more specifically, part of the Root Page ).

Note: At this development level, you cannot guess the size 
of a single page.  Only the size of the root page is available. 
Generally, the size of all the page is the same, but this could 
not be true if, for example, you merge two different document together.
=back

=head1 Variables

There are 2 variables that can be accessed:

=over 4

=item B<$PDF::VERSION>

Contain the version of the library installed.

=item B<$PDF::Verbose>

This variable is false by default. Change the value if you want 
more verbose output messages from library.

=back 4

=head1 Copyright

  Copyright 1998, Antonio Rosella antro@technologist.com

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 Availability

The latest version of this library is likely to be available from:

http://www.geocities.com/CapeCanaveral/Hangar/4794/

and at any CPAN mirror

=head1 Greetings

Fabrizio Pivari ( pivari@geocities.com ) for all the suggestions about life, the universe and everything.
Brad Appleton ( bradapp@enteract.com ) for his suggestions about the module organization.
Thomas Drillich for the iso latin1 support 
Ross Moore ( ross@ics.mq.edu.au ) for ReadInfo fix

=cut


