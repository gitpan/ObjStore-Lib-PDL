use strict;
package ObjStore::Lib::PDL;
use Carp;
use ObjStore;
use base ('ObjStore::UNIVERSAL','PDL','DynaLoader');
use vars qw($VERSION @OVERLOAD);
$VERSION = '0.02';
BEGIN {
    my %ov = @ObjStore::UNIVERSAL::OVERLOAD;
    for (keys %ov) {
	my $pdl_meth = overload::Method('PDL', $_);
	if ($pdl_meth) {
	    push @OVERLOAD, $_, $pdl_meth;
	} else {
	    #warn "PDL does not overload '$_'\n";
	}
    }
}
use overload @OVERLOAD;

require PDL::Lite;
__PACKAGE__->bootstrap($VERSION);
$ObjStore::SCHEMA{'ObjStore::Lib::PDL'}->
    load($ObjStore::Config::SCHEMA_DBDIR."/Lib-PDL-01.adb");

sub new {
    my ($this, $near, $how) = @_;
    $near = $near->segment_of if ref $near;
    my $class = ref $this || $this;
    my $o = _allocate($class, $near);
    if ($how) {
	if (exists $how->{Datatype}) {
	    my $dt = $how->{Datatype};
	    $dt = $dt->[0] if ref $dt;
	    $o->set_datatype($dt);
	}
	$o->setdims($how->{Dims})
	    if exists $how->{Dims};
    }
    $o;
}

# ObjStore::UNIVERSAL::isa is naughty!
*isa = \&UNIVERSAL::isa;

1;

=head1 NAME

ObjStore::Lib::PDL - Persistent PDL-compatible matrices

=head1 SYNOPSIS

    use PDL::Lite;
    use ObjStore::Lib::PDL;

    begin 'update', sub {
      my $pdl = ObjStore::Lib::PDL->new($near,
			  { Datatype => PDL::float(), Dims => [3,3] });

      $pdl->slice(":,4")->clump(2) *= 2;  #or whatever
    };
    die if $@;

=head1 DESCRIPTION

The main thing of interest is that dimensions are arranged in memory
such that the first dimension is the most packed.  For example, in a
PDL of dimensions [2,3] the layout is as follows:

  [0,1]
  [2,3]
  [4,5]

Be aware that this memory layout convention is dependent on the
implementation of PDL.  However, it is very unlikely to change.

=cut
