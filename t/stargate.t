# -*-perl-*-
use strict;
use Test;
BEGIN { plan test => 1 }

use ObjStore;
use ObjStore::Lib::PDL;

do {
    my $gate = ObjStore::HV->new('transient');
    my $pdl = PDL->sequence(3, 3);

    $gate->{pdl} = $pdl;
    ok (($gate->{pdl} == $pdl)->min);
};
