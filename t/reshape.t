# -*-perl-*- math
use strict;
use Test; plan test => 3, todo => [3];

use ObjStore;
use PDL::Lite;
use ObjStore::Lib::PDL;

# ObjStore::debug('bridge','txn');

# PDL::Core::set_debugging(100);

use ObjStore::Config;

my $db = ObjStore::open($ObjStore::Config::TMP_DBDIR . "/perltest", 'update');

begin 'update', sub {
    my $p = ObjStore::Lib::PDL->new($db, { Dims => [3,3] });
    #$p->_debug(1);
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
