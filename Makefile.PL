# $Id: Makefile.PL,v 1.1 1998/01/15 10:52:17 ag71333 Exp ag71333 $
#
# Copyright (c) 1998 Antonio Rosella Italy
#
# Free usage under the same Perl Licence condition.
#

BEGIN { require 5.004 }

use ExtUtils::MakeMaker 5.16, qw(WriteMakefile $Verbose);
use Config;

# my $os = $^O;
# my $osvers = $Config{osvers};
# $osvers =~ s/^\s*(\d+\.\d+).*/$1/;  # drop sub-sub-version: 2.5.1 -> 2.5

if ($] < 5.004) {
	print "\n*** You are using an old version of Perl. ***\n\a";
	print "Perl 5.004 fixes many bugs in older versions and is highly recommended.\n";
	sleep 5;
}

%opts = (
	NAME=> 'PDF',
	VERSION_FROM=> 'PDF.pm',
	clean => { FILES=> '$(DISTVNAME)/' },
	dist  => {
		DIST_DEFAULT=> 'clean distcheck disttest ci tardist',
		PREOP => '$(MAKE) -f Makefile.old distdir',
		COMPRESS => 'gzip -v9', SUFFIX => 'gz',
	},
);

$Verbose = 1;
WriteMakefile( %opts );

# end.
