#!/usr/bin/perl 

use lib '.';
use strict;
use warnings;
use JSON;
use PVE::RPCEnvironment;

use Data::Dumper;

use PVE::RADOS;

my $rpcenv = PVE::RPCEnvironment->init('cli');

my $rados = PVE::RADOS::new();

my $res = $rados->mon_command({ prefix => 'get_command_descriptions'});
print Dumper($res);

$res = $rados->mon_command({ prefix => 'mon dump', format => 'json' });
print Dumper($res);

my $stat = $rados->cluster_stat;
print Dumper($stat);
