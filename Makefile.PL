#!./perl -w

use strict;
use ExtUtils::MakeMaker;
use ObjStore::MakeMaker qw(add_os_args os_schema_rule);
use PDL::Version 1.99987;
use PDL::Core::Dev;

my @PREFIX = (PREFIX => $ENV{PERL5PREFIX})
    if exists $ENV{PERL5PREFIX};

my $v = '01';
my %args = (
	    @PREFIX,
	    PREREQ_PM	 => { ObjStore => '1.46' },
	    NAME         => 'ObjStore::Lib::PDL',
	    VERSION_FROM => './PDL.pm',
	    OBJECT       => join(' ', 'PDL.o', "Lib-PDL-$v.o"),
	    INC		 => &PDL_INCLUDE(),
);

WriteMakefile(add_os_args(%args));

sub MY::postamble { os_schema_rule("Lib-PDL-$v.sch") }
