#
# PDF.pm, version 1.03 Jan 1998 antro
#
# Copyright (c) 1998 Antonio Rosella Italy
#
# Free usage under the same Perl Licence condition.
#

package PDF;

$PDF::VERSION = "1.03";

require 5.004;
use Carp;
use Exporter ();

#
# Verbose off by default
#

my $Verbose = 0;

@ISA = qw(Exporter);

# @EXPORT = qw( Pages );
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
   Cross_Reference_Size => 0,
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
  close ( $self->{File_Handler} ) if $self->{File_Handler} ;
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

    my $initial_number;
    my $obj_counter=0;
    my $global_obj_counter=0;
    my $buf;
    my $first_level;

    seek $fd, $offset, 0;
    $_=<$fd>;
    die "Can't read cross-reference section, according to trailer\n" if ! /xref\r?\n?/  ;
    while (<$fd>) {
      s/^\n//;
      last if /^trailer\r?\n?/ ;
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
    last if /startxref\r?\n?/ ;
    /Size\s*\d+\r?\n?/ && do { s/\/Size\s*(\d+)\r?\n?/$1/;
		   if ( ! $self->{Cross_Reference_Size}) {
		     $self->{Cross_Reference_Size} = $_ ;
		     $first_level=1;
		   }
		   next;} ;
    /Root/ && do { s/\/Root\s+(\d+\s+\d+)\s+R\r?\n?/$1/;
		   if ( ! $self->{Root_Object}) {
		     $self->{Root_Object}=$_;
		   }
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
    /Prev/ && do { 
		   s/\/Prev\s*(\d+)\r?\n?/$1/;
    		   $self->{Updated}=1;
		   my $old_seek = tell $fd;
		   $global_obj_counter += ReadCrossReference($fd,$_, $self );
		   seek $fd, $old_seek, 0;
		   $PDF::Verbose && warn "Document Updated! Not yet implemented :-(\n";
		   if ($first_level ) {
			$self->{Cross_Reference_Size} != $global_obj_counter &&
			  warn "Cross-reference table corrupted! $global_obj_counter objects read, $self->{Cross_Reference_Size} requested \n";
		   }
		   next;
		 };
  }
  return $global_obj_counter;
}

sub TargetFile {
  my $self = shift;
  my $file = shift;

  croak "Already linked to the file ",$self->{File_Name},"\n" if $self->{File_Name} ;
  
  my $offset;

  if ( $file ) {
    open(FILE, "< $file") or croak "can't open $file: $!";
    $self->{File_Name} = $file ;
    $self->{File_Handler} = \*FILE;
    my $buf;
    read(FILE,$buf,4);
    if ( $buf ne "%PDF" ) {
     print "File $_[0] is not PDF compliant !\n" if $PDF::Verbose ;
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

  croak "PDF File not specified !\n" if ! $self->{File_Name}  ; 

  open (FILE, "$self->{File_Name}");
  if ($self->{Catalog}) {
    my $ro = $self->{Root_Object};
    $ro =~ s/(\d+)\s+\d+/$1/;

    my $ro_gen=$self->{Gen_Num}[$ro];
    seek FILE, $self->{Objects}[$ro] ,0 ;
    my $flag;
    while (<FILE>) {
      next if /$ro\s+$ro_gen\s+obj\r?\n?/ ; 
      next if /<<\r?\n?/  ;
      /\/Pages/ && do { s/\r?\n?\/Pages\s+(\d+)\s+(\d+)\s+R\r?\n?/$1 $2/;
		      $self->{Catalog}->{Pages} = $_;
		      my ($ind,$gen)=split(" ",$self->{Catalog}->{Pages});
		      $self->{Gen_Num}[$ind] != $gen && die "Can't find Pages Node\n";
                      return ReadPage(\*FILE, $self->{Objects}[$ind], $self );
		    };
      last if />>\r?\n?/ ;
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
      next if /<</ ;
      /^\/Type\s+/ && do { croak " Page tree corrupted!\n" if !(/\/Pages/ ); }; 
      $result = $_ if /\/Count\s+/ ;
      next if /\/Parent/  ;
      next if /\/Kids/  ;
      last if />>/ ;
    }
    $result =~ s/\n?\r?\/Count\s+(\d+)\s*\r?\n?/$1/;
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
  print "is a pdf file\n" if ( $pdf->IsaPDF ) ;
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

B<pdf_pages> gives the number of pages of a PDF file. 

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

Returns the number of pages of the object file. As side effect, 
the PDF object contains part of the Catalog structure after 
the call ( more specifically, part of the Root Page ).

=back

=head1 Variables

There are 2 variables that can be accessed:

=over 4

=item B<$PDF::VERSION>

Contain the version of the library installed

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
