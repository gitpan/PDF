#
# PDF.pm, version 1.0 Jan 1998 antro
#
# Copyright (c) 1998 Antonio Rosella Italy
#
# Free usage under the same Perl Licence condition.
#

package PDF;

$PDF::VERSION = "1.0";

require 5.004;
use Carp;
use Exporter ();

#
# Verbose off by default
#

$Verbose = 0;

@ISA = qw(Exporter);

@EXPORT = qw();
@EXPORT_OK = qw( TargetFile Version );
use vars qw( $Verbose ) ;

my %PDF_Fields = (
   File_Handler => undef,
   File_Name => undef,
   Header => undef,
);

sub new {
  my $that = shift;
  my $class=ref($that) || $that ;
  my $self ={ \%PDF_Fields, } ;

  $/="\r";

  if ( @_ ) { 			# I have the filename
    open(FILE, "< @_[0]") or croak "can't open @_[0]: $!";
    $_=<FILE>;
    if ( ! /^%PDF/ ) {
     $Verbose && croak "File @_[0] is not PDF compliant !"; 
     return 0 ;
    }
    s/%PDF-// ;
    $self->{Header}= $_;
    $self->{File_Handler} = \*FILE;
    $self->{File_Name} = @_[0];
  }
  $/="\n";
  return bless $self, $class;
};

sub DESTROY {
#
# Close the file if not empty
#
  my $self = shift;
  $self->{File_Handler} && close ( $self->{PDF_Fields}->{File_Handler} );
#  print "Chiudo $self->{File_Name} \n";
}

sub Version { 
  return @_[0]->{Header}; 
}

sub TargetFile {
  my $self = shift;
  my $file = shift;
  $self->{File_Name} && croak "Already linked to the file ",$self->{File_Name},"\n";
  
  if ( $file ) {
    open(FILE, "< $file") or croak "can't open $file: $!";
    $self->{File_Handler} = \*FILE;
  } else {
    croak "I need a file name (!)";
  }
}

1;
__END__

=head1 NAME

PDF - Library for PDF manipulation in Perl

=head1 SYNOPSIS

  use PDF;
  $pdf=new ;
  $pdf=new(filename);
  $result=$pdf->TargetFile( filename );


=head1 Description

The main purpose of the PDF library is to provide classes and functions 
that allow to read and manipulate PDF files with perl. PDF stands for
Portable Document Format and is a format proposed by Adobe. For
more details abour PDF, refer to:

B<http://www.adobe.com/> 

The library is at is very beginning of development. 
The main idea is to provide some "basic" modules for access 
the information contained in a PDF file. Even if at this
moment only the constructor is available, the two little 
scripts provided with the library ( B<is_pdf> and B<pdf_version> ) 
show that it is usable. 

The first script test a list of files in order divide the PDF file
from the non PDF using the info provided by the files 
themselves. It doesn't use the I<.pdf> extension, it uses the information
contained in the file.

The second returns the PDF level used for writing a file.

=head1 Constructor

=over 4

=item B<new ( [ filename ] )>

This is the constructor of a new PDF object. If the filename is missing, it returns an
empty PDF descriptor ( can be filled with $pdf->TargetFile). Otherwise, It acts as the
B<TargetFile> method.

=back

=head1 Methods

The only available method ( at the moment ) is :

=over 4

=item B<TargetFile ( filename ) >

This method links the filename to the pdf descriptor and check the header.

=back

=head1 Variables

There are 2 variables that can be accessed:

=over 4

=item B<$PDF::Version>

Contain the version of 
the library installed

=item B<Verbose>

This variable is false by default. Change the value if you want 
more verbose output messages from library

=back 4

=head1 Copyright

  Copyright 1998, Antonio Rosella antro@technologist.com

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 Availability

The latest version of this library is likely to be available from:

http://www.geocities.com/CapeCanaveral/Hangar/4794/

=cut
