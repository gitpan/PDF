#
# PDF.pm, version 1.02 Jan 1998 antro
#
# Copyright (c) 1998 Antonio Rosella Italy
#
# Free usage under the same Perl Licence condition.
#

package PDF;

$PDF::VERSION = "1.02";

require 5.004;
use Carp;
use Exporter ();

#
# Verbose off by default
#

my $Verbose = 0;

@ISA = qw(Exporter);

@EXPORT = qw( Pages );
@EXPORT_OK = qw( IsaPDF Pages TargetFile Version );
use vars qw( $Verbose ) ;

sub new {

my %PDF_Fields = (
   File_Handler => undef,
   File_Name => undef,
   Header => undef,
   Objects => [],
   Gen_Num => [],
   Root_Object => undef,
   Catalog => {},
   PageTree => {},
   Updated => 0, 
);

  $/="\r";
  my $that = shift;
  my $class=ref($that) || $that ;
  my $self = \%PDF_Fields ;
  my $buf2=bless $self, $class;
  if ( @_ ) { 			# I have the filename
    $buf2->TargetFile($_[0]) ; # if Verbose is on TargetFile exit;
  }
  return bless $self, $class;
};

sub DESTROY {
#
# Close the file if not empty
#
  my $self = shift;
  $self->{File_Handler} && do {
    close ( $self->{File_Handler} );
  };
}

sub Version { 
  return $_[0]->{Header}; 
}

sub IsaPDF { 
  return ($_[0]->{Header} != undef) ; 
}

sub ReadCrossReference {
    my $fd = shift;
    my $offset=shift;
    my $self=shift;

    my $object_nr;
    my $object_offset;
    my $initial_number;
    my $obj_counter=0;
    my $global_obj_counter=0;
    my $buf;

    seek $fd, $offset, 0;
    $_=<$fd>;
    ! /xref\r?\n?/ && die "Can't read cross-reference section, according to trailer\n";
    while (<$fd>) {
      s/^\n//;
      last if ( /^trailer\r?\n?/ ) ;
#
# An Object
#
      /^\d+\s+\d+\s+n\r?\n?/ && do { my $buf =$_;
		       my $ind = $initial_number + ($obj_counter++);
		       $self->{Objects}[$ind] >= 0 && 
			  do { $self->{Objects}[$ind] = int substr($buf,0,10);
			       $self->{Gen_Num}[$ind] = int substr($buf,11,5);
			     };
		       $_=$buf;
		       s/^.{18}//; 
		       next ;
     }; 
#
# A Freed Object
#
      /^\d+\s+\d+\s+f\r?\n?/ && do { my $buf =$_;
      		       my $objects_generation_nr = substr($buf,11,5);
		       my $Num=substr($buf,0,10);
		       my $ind = $initial_number + ($obj_counter++);
		       # $ind = $ind . "_" . $objects_generation_nr;
		       $self->{Objects}[$ind] = - $Num;
		       $self->{Gen_Num}[$ind] = $objects_generation_nr;
		       $_=$buf;
		       s/^.{18}//; 
		       next ;
     };
#
# A subsection
#
      /^\d+\s+\d+\r?\n?/  && do { 
 	 my $buf = $_ ; 
 	 $initial_number = $buf; 
 	 $initial_number=~ s/^(\d+)\s+\d+\r?\n?.*/$1/; 
	 $global_obj_counter += $obj_counter;
 	 $obj_counter=0; 
	 next ;
      };
  }

  $global_obj_counter +=$obj_counter;

#
# Now the trailer
#
  while(<$fd>) {
    /startxref\r?\n?/ && last ;
    /Size\s*\d+\r?\n?/ && do { s/\/Size\s*(\d+)\r?\n?/$1/;
 		   $_ != $obj_counter && warn "Cross-reference table corrupted! or document updated ( not yet implemented :-(\n";
		   next;} ;
    /Root/ && do { s/\/Root\s+(\d+\s+\d+)\s+R\r?\n?/$1/;
		   $self->{Root_Object}=$_;
		   next;
		 };
    /Info/ && do { 
		   $PDF::Verbose && warn "Info! Not yet implemented :-(\n";
		   next;
		 };
    /ID/ && do { 
		   $PDF::Verbose && warn "ID! Not yet implemented :-(\n";
		   next;
		 };
    /Encrypt/ && do { 
		   $PDF::Verbose && warn "Encrypt! Not yet implemented :-(\n";
		   next;
		 };
    /Prev/ && do { $Updated++;
		   $PDF::Verbose && warn "Document Updated! Not yet implemented :-(\n";
		   next;
		 };
  }
}

sub TargetFile {
  my $self = shift;
  my $file = shift;
  $self->{File_Name} && croak "Already linked to the file ",$self->{File_Name},"\n";
  
  if ( $file ) {
    open(FILE, "< $file") or croak "can't open $file: $!";
    $self->{File_Name} = $file ;
    $self->{File_Handler} = \*FILE;
    my $buf;
    read(FILE,$buf,4);
    if ( $buf ne "%PDF" ) {
      $PDF::Verbose && print "File $_[0] is not PDF compliant !\n"; 
      return 0 ;
    }
    read(FILE,$buf,4);
    $buf =~ s/-//;
    $self->{Header}= $buf;
#
# Attempt for endline
#
    read(FILE,$_,1);
    $/ = "\r" if /\r/ ;
    read(FILE,$_,1);
    $/ = "\n" if /\n/ ;

    seek FILE,-50,2;
    my $offset;
    read( FILE, $offset, 50 );
    $offset =~ s/[^s]*startxref\r?\n?(\d*)\r?\n?%%EOF\r?\n?/$1/;

    ReadCrossReference(\*FILE, $offset, $self );

    $self->{File_Handler} = \*FILE;
    return 1;
  } else {
    croak "I need a file name (!)";
  }
}

sub Pages {
  my $self = shift;
  !($self->{File_Name}) && croak "PDF File not specified !\n";
  open (FILE, "$self->{File_Name}");
  if ($self->{Catalog}) {
    my $ro = $self->{Root_Object};
    $ro =~ s/(\d+)\s+\d+/$1/;
    my $ro_gen=$self->{Gen_Num}[$ro];
    seek FILE, $self->{Objects}[$ro] ,0 ;
    while (<FILE>) {
      /$ro\s+$ro_gen\r?\n?/ && next;
      /<<\r?\n?/ && next;
      /\/Pages/ && do { s/\/Pages\s+(\d+)\s+(\d+)\s+R/$1 $2/;
		      $self->{Catalog}->{Pages} = $_;
		      my ($ind,$gen)=split(" ",$self->{Catalog}->{Pages});
		      $self->{Gen_Num}[$ind] != $gen && die "Can't find Pages Node\n";
                      return ReadPage(\*FILE, $self->{Objects}[$ind], $self );
		    };
      />>\r?\n?/ && last ;
    }
  }
  close(FILE);
}

sub ReadPage {
  my $fd = shift;
  my $offset=shift;
  my $self=shift;

  my $result;

  seek $fd, $offset, 0;

  $_=<$fd>;
  while(<$fd>) {
    /<</ && next;
    /^\/Type\s+/ && do { croak " Page tree corrupted!\n" if !(/\/Pages/ ); }; 
    $result = $_ if ( /\/Count\s+/ ) ;
    /\/Parent/ && next;
    /\/Kids/ && next;
    />>/ && last;
  }
  $result =~ s/\/Count\s+(\d+)\r?\n?/$1/;
  return $result;
}

1;
__END__

=head1 NAME

PDF - Library for PDF manipulation in Perl

=head1 SYNOPSIS

  use PDF;
  $pdf=PDF->new ;
  $pdf=PDF->new(filename);
  $result=$pdf->TargetFile( filename );
  print " is a pdf file\n" if ( $pdf->IsaPDF ) ;
  print "Has ",$pdf->Pages," Pages \n";
  print "Use a PDF Version  ",$pdf->Version ," \n";


=head1 Description

The main purpose of the PDF library is to provide classes and functions 
that allow to read and manipulate PDF files with perl. PDF stands for
Portable Document Format and is a format proposed by Adobe. For
more details abour PDF, refer to:

B<http://www.adobe.com/> 

The library is at is very beginning of development. 
The main idea is to provide some "basic" modules for access 
the information contained in a PDF file. Even if at this
moment is in an early development stage, the three little 
scripts provided with the library ( B<is_pdf>, B<pdf_version>, and 
B<pdf_pages> ) show that it is usable. 

B<is_pdf> script test a list of files in order divide the PDF file
from the non PDF using the info provided by the files 
themselves. It doesn't use the I<.pdf> extension, it uses the information
contained in the file.

B<pdf_version> returns the PDF level used for writing a file.

B<pdf_pages> gives the number of pages of a PDF file. This at the moment works
only for un-updated files.

=head1 Constructor

=over 4

=item B<new ( [ filename ] )>

This is the constructor of a new PDF object. If the filename is missing, it returns an
empty PDF descriptor ( can be filled with $pdf->TargetFile). Otherwise, It acts as the
B<TargetFile> method.

=back

=head1 Methods

The available methods are :

=over 4

=item B<TargetFile ( filename ) >

This method links the filename to the pdf descriptor and check the header.

=item B<Version>

Returns the PDF version used for writing the object file.

=item B<Pages>

Returns the number of pages of the object file. At this 
moment, it doesn't take into account the update section. 
So, if a file was updated and new pages are added, it may 
return the wrong number of pages . Setting the variable 
B<$PDF::Verbose> can give some hints; As side effect, the 
PDF object contains part of the Catalog structure after 
the call.

=back

=head1 Variables

There are 2 variables that can be accessed:

=over 4

=item B<$PDF::VERSION>

Contain the version of 
the library installed

=item B<$PDF::Verbose>

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
