# -*-perl-*- math
use strict;
use Test;
BEGIN { plan test => 14 }

use ObjStore;
use PDL::Lite;
use ObjStore::Lib::PDL;

ok 1;

begin 'update', sub {
    my $p = ObjStore::Lib::PDL->new('transient', { Dims => [3,3] });
    ok $p->getndims, 2;
    ok $p->nelem, 9;
    ok join('',$p->dims), '33';

#    $p = PDL->zeroes(3,3);
    my $bit = $p->slice('1,1')->clump(2);
    $bit .= 3.5;
    ok $bit->at(0), 3.5;
    for (my $x=0; $x < 3; $x++) {
	for (my $y=0; $y < 3; $y++) {
	    ok $p->at($x,$y), $x==1 && $y==1? 3.5 : 0;
	}
    }
};
die if $@;
