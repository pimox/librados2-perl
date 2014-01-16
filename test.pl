#!/usr/bin/perl 

use lib '.';
use strict;
use warnings;
use JSON;

use Data::Dumper;

use PVE::RADOS;

print "TEST1\n";
my $rados = PVE::RADOS::new();
print "TEST2\n";

my $res = $rados->mon_command({ prefix => 'mon dump', format => 'json' });
print Dumper($res);
$res = $rados->mon_command({ prefix => 'mon dump', format => 'json' });
print Dumper($res);

my $stat = $rados->cluster_stat;
print Dumper($stat);
