#
# PDF::Parse.pm, version 1.10 November 1999 antro
#
# Copyright (c) 1998-1999 Antonio Rosella Italy antro@tiscalinet.it
#
# Free usage under the same Perl Licence condition.
#

package PDF::Parse;

$PDF::Parse::VERSION = "1.10";

require 5.004;
require PDF::Core;

use Carp;
use Exporter ();

@ISA = qw(Exporter PDF::Core);

@EXPORT_OK = qw( GetInfo TargetFile Pages PageSize PageRotation);

sub ReadCrossReference_pass1 {
  my $fd = shift;
  my $offset=shift;
  my $self=shift;

  my $initial_number;
  my $obj_counter=0;
  my $global_obj_counter=0;
  my $buf;

  binmode $fd;

  $_=PDF::Core::PDFGetline ($fd,\$offset);

  die "Can't read cross-reference section, according to trailer\n" if ! /xref\r?\n?/  ;

  while () {
    $_=PDF::Core::PDFGetline ($fd,\$offset);
    s/^\n//;
    s/^\r//;
    last if /^trailer\r?\n?/ ;
#
# An Object
#
    /^\d+\s+\d+\s+n\r?\n?/ && do { my $buf =$_;
	       my $ind = $initial_number + ($obj_counter++);
               ( not defined $self->{Objects}[$ind] )&& 
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
# Now the trailer for updates 
#
  while () {
    $_=PDF::Core::PDFGetline ($fd,\$offset);
    s/^\n//;
    s/^\r//;
    last if /startxref\r?\n?/ ;
    /Size\s*\d+\r?\n?/ && do { s/\/Size\s*(\d+)\r?\n?/$1/;
		   if ( ! $self->{Cross_Reference_Size}) {
		     $self->{Cross_Reference_Size} = $_ ;
		   }
		   next;} ;
    /Root/ && do { s/\/Root\s+(\d+\s+\d+)\s+R\r?\n?/$1/;
		   if ( ! $self->{Root_Object}) {
		     $self->{Root_Object}=$_;
		   }
		   next;
		 };
    /Info/ && next;
    /ID/ && next;
    /Encrypt/ && do { s/\/Encrypt\s+(\d+\s+\d+)\s+R\r?\n?/$1/;
		   if ( ! $self->{Crypt_Object}) {
		     $self->{Crypt_Object}=$_;
		   }
		   next;
		 };
    /Prev/ && do {  
		   s/\/Prev\s*(\d+)\r?\n?/$1/;
    		   $self->{Updated}=1;
		   my $old_seek = tell $fd;
		   $global_obj_counter += ReadCrossReference_pass1($fd,$_, $self );
		   seek $fd, $old_seek, 0;
		   next;
		 };
  }
  return $global_obj_counter;
}

sub ReadCrossReference_pass2 {
  my $fd = shift;
  my $offset=shift;
  my $self=shift;

  seek $fd, $offset, 0;
  $_=PDF::Core::PDFGetline ($fd,\$offset);

  die "Can't read cross-reference section, according to trailer\n" if ! /xref\r?\n?/  ;

  while() {
    $_=PDF::Core::PDFGetline ($fd,\$offset);
    s/^\n//;
    s/^\r//;
    last if /startxref\r?\n?/ ;
    /Size/ && next;
    /Root/ && next;
    /Info/ && do { 
		   s/\/Info\s+(\d+\s+\d+\s+R)\r?\n?/$1/;
		   my $old_seek = tell $fd;
		   ReadInfo($fd, $self ,$_);
		   seek $fd, $old_seek, 0;
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
		   my $old_seek = tell $fd;
		   ReadCrossReference_pass2($fd,$_, $self );
		   seek $fd, $old_seek, 0;
		   next;
		 };
  }
}

sub ReadInfo {
  my $fd = shift;
  my $self = shift;
  my $info_obj=shift;

  my ($ro, $gen ) = split(" ",$info_obj);
  my $ro_gen=$self->{Gen_Num}[$ro];
  my $offset = $self->{Objects}[$ro] ,0 ;
  seek $fd, $offset ,0 ;
  my $readinfo_buffer;
  while () {
    $_=PDF::Core::PDFGetline ($fd,\$offset);

    last if />>\r?\n?/ ;

#
# iso chars support, courtesy of T. Drillich
#
    my($a,$n)='';
    while(/(\\\d+)/) {
       $a.=$`;
       $_=$';
       $n=$1;
       $n=~s/\\//g;
       $a.=chr(oct($n));
    }
    $a.=$_;
    $_=$a;

    /\\\r?\n?$/ && do { s/\\\r?\n?//;
		  $readinfo_buffer = $readinfo_buffer . $_;
		  next;
		};
    if ( $readinfo_buffer ) {
      $readinfo_buffer = $readinfo_buffer . $_;
      $readinfo_buffer =~ s/\r?\n?$//;
      $_=$readinfo_buffer;
      $readinfo_buffer="";
    }
#
# Courtesy of Ross Moore
#
    my $str;
    /\/Author/ && do { if ( s/\/Author\s*\(((\\\)|[^\)])*)\)\r?\n?/$1/ ) {
                       $str=$1; $str =~ s/\\([()])/$1/g;
                       $self->{Author} = $str if (!($self->{Author}));
		       } else {
			 s/\r?\n?$//;
			 $readinfo_buffer = $_;
		       }
#		       next;
                     };
    /\/CreationDate/ && do { s/\/CreationDate\s\(((\\\)|[^\)])*)\)\r?\n?/$1/;
                             $str=$1; $str =~ s/\\([()])/$1/g;
                             $self->{CreationDate} = $str if (!($self->{CreationDate}));
#		             next;
		           };
    /\/ModDate/ && do { s/\/ModDate\s\(((\\\)|[^\)])*)\)\r?\n?/$1/;
                        $str=$1; $str =~ s/\\([()])/$1/g;
                        $self->{ModDate} = $str if (!($self->{ModDate}));
#		        next;
		      };
    /\/Creator/ && do { if ( s/\/Creator\s\(((\\\)|[^\)])*)\)\r?\n?/$1/ ) {
                          $str=$1; $str =~ s/\\([()])/$1/g;
                          $self->{Creator} = $str if (!($self->{Creator}));
		        } else {
		 	  s/\r?\n?$//;
			  $readinfo_buffer = $_;
		        }
#		        next;
		      };
    /\/Producer/ && do { if ( s/\/Producer\s\(((\\\)|[^\)])*)\)\r?\n?/$1/) {
                           $str=$1; $str =~ s/\\([()])/$1/g;
                           $self->{Producer} = $str if (!($self->{Producer}));
		         } else {
		 	   s/\r?\n?$//;
			   $readinfo_buffer = $_;
		         }
#		         next;
		       };
    /\/Title/ && do { if ( s/\/Title\s\(((\\\)|[^\)])*)\)\r?\n?/$1/) {
                        $str=$1; $str =~ s/\\([()])/$1/g;
                        $self->{Title} = $str if (!($self->{Title}));
		      } else {
		        s/\r?\n?$//;
		        $readinfo_buffer = $_;
		      }
#		      next;
		    };
    /\/Subject/ && do { if ( s/\/Subject\s\(((\\\)|[^\)])*)\)\r?\n?/$1/) {
                          $str=$1; $str =~ s/\\([()])/$1/g;
                          $self->{Subject} = $str if (!($self->{Subject}));
		        } else {
		          s/\r?\n?$//;
		          $readinfo_buffer = $_;
		        }
#		       next;
		    };
    /\/Keywords/ && do { if ( s/\/Keywords\s\(((\\\)|[^\)])*)\)\r?\n?/$1/) {
                           $str=$1; $str =~ s/\\([()])/$1/g;
                           $self->{Keywords} = $str if (!($self->{Keywords}));
		         } else {
		           s/\r?\n?$//;
		           $readinfo_buffer = $_;
		         }
#		         next;
		    };
  }
}

sub TargetFile {
  my $self = shift;
  my $file = shift;

  croak "Already linked to the file ",$self->{File_Name},"\n" if $self->{File_Name} ;
  
  my $offset;

  if ( $file ) {
    open(FILE, "< $file") or croak "can't open $file: $!";
    binmode FILE;
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
    seek FILE,-50,2;
    read( FILE, $offset, 50 );
    $offset =~ s/[^s]*startxref\r?\n?(\d*)\r?\n?%%EOF\r?\n?/$1/;

    ReadCrossReference_pass1(\*FILE, $offset, $self );
    ReadCrossReference_pass2(\*FILE, $offset, $self );

    $self->{File_Handler} = \*FILE;
    return 1;
  } else {
    croak "I need a file name (!)";
  }
}

sub GetInfo {
  my $self = shift;
  $_ = shift;

  croak "PDF File not specified !\n" if ! $self->{File_Name}  ; 

  /Author/ && return $self->{Author}; 
  /CreationDate/ && return $self->{CreationDate}; 
  /ModDate/ && return $self->{ModDate}; 
  /Creator/ && return $self->{Creator}; 
  /Producer/ && return $self->{Producer}; 
  /Title/ && return $self->{Title}; 
  /Subject/ && return $self->{Subject}; 
  /Keywords/ && return $self->{Keywords}; 

}

sub Pages {
  my $self = shift;

  croak "PDF File not specified !\n" if ! $self->{File_Name}  ; 
  $self->{PageTree}->ReadPageTree($self) if ! $self->{PageTree}->{Count};
  return $self->{PageTree}->{Count};
}

sub PageSize {
  my $self = shift;

  croak "PDF File not specified !\n" if ! $self->{File_Name}  ; 
  $self->{PageTree}->ReadPageTree($self) if ! $self->{PageTree}->{Count};
  return @{$self->{PageTree}->{MediaBox}};
}

sub PageRotation {
  my $self = shift;

  my $r=$self->{PageTree}->{Rotation};
  $r=0 if ( ! $r ) ;
  croak "PDF File not specified !\n" if ! $self->{File_Name}  ; 
  $self->{PageTree}->ReadPageTree($self) if ! $self->{PageTree}->{Count};
  $PDF::Verbose && do {
   print "Rotation ",$r,": Portrait" if $r == 0 || $r == 180 ;
   print "Rotation ",$r,": Landscape" if $r == 90 || $r == 270 ;
  };
  return $r;
}
1;
__END__

=head1 NAME

PDF::Parse - Library for parsing a PDF file

=head1 SYNOPSIS

  use PDF::Parse;

  $pdf=PDF::Parse->new ;
  $pdf=PDF::Parse->new(filename);

  $result=$pdf->TargetFile( filename );

  print "is a pdf file\n" if ( $pdf->IsaPDF ) ;
  print "Has ",$pdf->Pages," Pages \n";
  print "Use a PDF Version  ",$pdf->Version ," \n";

  print "filename with title",$pdf->GetInfo("Title"),"\n";
  print "and with subject ",$pdf->GetInfo("Subject"),"\n";
  print "was written by ",$pdf->GetInfo("Author"),"\n";
  print "in date ",$pdf->GetInfo("CreationDate"),"\n";
  print "using ",$pdf->GetInfo("Creator"),"\n";
  print "and converted with ",$pdf->GetInfo("Producer"),"\n";
  print "The last modification occurred ",$pdf->GetInfo("ModDate"),"\n";
  print "The associated keywords are ",$pdf->GetInfo("Keywords"),"\n";

  my (startx,starty, endx,endy) = $pdf->PageSize ;
  my $rotation = $pdf->PageRotation ;

=head1 DESCRIPTION

The main purpose of the PDF library is to provide classes and functions 
that allow to read and manipulate PDF files with perl. PDF stands for
Portable Document Format and is a format proposed by Adobe. For
more details abour PDF, refer to:

B<http://www.adobe.com/> 

For a detailed documentation, see the PDF library.

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

=item B<PageSize>

Returns the size of the page of the object file. As side effect, 
the PDF object contains part of the Catalog structure after 
the call ( more specifically, part of the Root Page ).

Note: At this development level, you cannot guess the size 
of a single page.  Only the size of the root page is available. 
Generally, the size of all the page is the same, because it's usually inherited from
the root page , but this could 
not be true if, for example, you merge two different document together.

=item B<PageRotation>

Returns the rotation of the document with the PDF conventions:

 0 ==>   0 degree (default)
 1 ==>  90 degrees
 2 ==> 180 degrees
 3 ==> 270 degrees

Note: It suffer of the same limitations of the the PageSize method.

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

