use strict;
package ObjStore::Lib::PDL;
use Carp;
use ObjStore;
use base ('ObjStore::UNIVERSAL','PDL','DynaLoader');
use vars qw($VERSION @OVERLOAD);
$VERSION = '0.01';
BEGIN {
    # ugh!
    my %fixup = (
		 '""' => \&PDL::Core::string,
		);
    my %ov = @ObjStore::UNIVERSAL::OVERLOAD;
    for (keys %ov) {
#	warn "don't know how to fix '$_'" if !exists $fixup{$_};
    }
    @OVERLOAD = %fixup;
}
use overload @OVERLOAD;

__PACKAGE__->bootstrap($VERSION);
$ObjStore::SCHEMA{'ObjStore::Lib::PDL'}->
    load($ObjStore::Config::SCHEMA_DBDIR."/Lib-PDL-01.adb");

sub new {
    my ($this, $near, $how) = @_;
    $near = $near->segment_of if ref $near;
    my $class = ref $this || $this;
    my $o = _allocate($class, $near);
    if ($how) {
	$o->set_datatype($how->{Datatype})
	    if exists $how->{Datatype};
	$o->setdims($how->{Dims})
	    if exists $how->{Dims};
    }
    $o;
}

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
such that the last dimension is the most packed.  For example, in a
PDL of dimensions [3,3,3] the following locations are sequential in
memory:

  [2,1,0]
  [2,1,1]
  [2,1,2]

Whereas the follow three elements are separated by relatively large gaps:

  [0,2,1]
  [1,2,1]
  [2,2,1]

Be aware that this memory layout convention is dependent on the
implementation of PDL.  However, it is very unlikely to change.

=cut
