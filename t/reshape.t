# -*-perl-*- math
use strict;
use Test; plan test => 3, todo => [3];

use ObjStore;
use PDL::Lite;
use ObjStore::Lib::PDL;

begin 'update', sub {
    my $p = ObjStore::Lib::PDL->new('transient', { Dims => [3,3] });
    $p->setdims([4,4]);
    ok join('',$p->dims), '44';

    # try switching types
    my $x = $p->slice(':,1')->clump(2);
    $x .= PDL->sequence(4) + 254;

    my $byte = PDL::byte()->[0];
    $p->set_datatype($byte);

    ok $p->get_datatype, $byte;
    ok $p->at(0,1), 254;
};
die if $@;
