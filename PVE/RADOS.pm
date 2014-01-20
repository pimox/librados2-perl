package PVE::RADOS;

use 5.014002;
use strict;
use warnings;
use Carp;
use JSON;
use Socket;
 
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use PVE::RADOS ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '1.0';

require XSLoader;
XSLoader::load('PVE::RADOS', $VERSION);

# fixme: timeouts??

my $writedata = sub {
    my ($fh, $cmd, $data) = @_;

    local $SIG{PIPE} = 'IGNORE';
 
    my $bin = pack "a L/a*", $cmd, $data || '';
    my $res = syswrite $fh, $bin;

    die "write data failed - $!\n" if !defined($res);
};

my $readdata = sub {
    my ($fh, $expect_result) = @_;

    my $head = '';

    local $SIG{PIPE} = 'IGNORE';

    while (length($head) < 5) {
	last if !sysread $fh, $head, 5 - length($head), length($head);
    }
    die "partial read\n" if length($head) < 5;
    
    my ($cmd, $len) = unpack "a L", $head;

    my $data = '';
    while (length($data) < $len) {
	last if !sysread $fh, $data, $len - length($data), length($data);
    }
    die "partial data read\n" if length($data) < $len;

    if ($expect_result) { 
	die $data if $cmd eq 'E' && $data;
	die "got unexpected result\n" if  $cmd ne '>';
    }

    return wantarray ? ($cmd, $data) : $data;
};

sub new {
    my ($class, %params) = @_;

    socketpair(my $child, my $parent, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
	||  die "socketpair: $!";

    my $cpid = fork();

    die "unable to fork - $!\n" if !defined($cpid);

    my $self = bless {};

    if ($cpid) { # parent
	close $parent;
 
	$self->{cpid} = $cpid;
	$self->{child} = $child;

	# wait for sync
	my ($cmd, $msg) = &$readdata($child);
	die $msg if $cmd eq 'E';
	die "internal error- got unexpected result" if $cmd ne 'S';

    } else { # child
	$0 = 'pverados';
 
	# fixme: timeout?

	close $child;

	my $timeout = delete $params{timeout} || 5;

	my $conn;
	eval {
	    $conn = pve_rados_create() ||
		die "unable to create RADOS object\n";

	    pve_rados_conf_set($conn, 'client_mount_timeout', $timeout);

	    foreach my $k (keys %params) {
		pve_rados_conf_set($conn, $k, $params{$k});
	    }

	    pve_rados_connect($conn);
	};
	if (my $err = $@) {
	    &$writedata($parent, 'E', $err);
	    die $err;
	}
	&$writedata($parent, 'S');

	$self->{conn} = $conn;

	for (;;) {
	    my ($cmd, $data) = &$readdata($parent);
	    
	    last if $cmd eq 'Q';

	    my $res;
	    eval {
		if ($cmd eq 'M') { # rados monitor commands
		    $res = pve_rados_mon_command($self->{conn}, [ $data ]);
		} elsif ($cmd eq 'C') { # class methods
		    my $aref = decode_json($data);
		    my $method = shift @$aref;
		    $res = encode_json($self->$method(@$aref));
		} else {
		    die "invalid command\n";
		}
	    };
	    if (my $err = $@) {
		&$writedata($parent, 'E', $err);
		die $err;
	    }
	    &$writedata($parent, '>', $res);
	}
 
	exit(0);
    }

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    if ($self->{cpid}) {
	#print "$$: DESTROY WAIT0\n";
	eval { &$writedata($self->{child}, 'Q'); };
	my $res = waitpid($self->{cpid}, 0);
	#print "$$: DESTROY WAIT $res\n";
    } else {
	#print "$$: DESTROY SHUTDOWN\n";
	pve_rados_shutdown($self->{conn}) if $self->{conn};
    }
}

sub cluster_stat {
    my ($self, @args) = @_;

    if ($self->{cpid}) {
	my $data = encode_json(['cluster_stat', @args]);
	&$writedata($self->{child}, 'C', $data);
	return decode_json(&$readdata($self->{child}, 1));
    } else {
	return pve_rados_cluster_stat($self->{conn});
    }
}

# example1: { prefix => 'get_command_descriptions'})
# example2: { prefix => 'mon dump', format => 'json' }
sub mon_command {
    my ($self, $cmd) = @_;

    $cmd->{format} = 'json' if !$cmd->{format};

    my $json = encode_json($cmd);

    &$writedata($self->{child}, 'M', $json);

    my $raw = &$readdata($self->{child}, 1);

    if ($cmd->{format} && $cmd->{format} eq 'json') {
	return length($raw) ? decode_json($raw) : undef;
    }
    return $raw;
}


1;
__END__

=head1 NAME

PVE::RADOS - Perl bindings for librados

=head1 SYNOPSIS

  use PVE::RADOS;

  my $rados = PVE::RADOS::new();
  my $stat = $rados->cluster_stat();
  my $res = $rados->mon_command({ prefix => 'mon dump', format => 'json' });

=head1 DESCRIPTION

Perl bindings for librados.

=head2 EXPORT

None by default.

=head1 AUTHOR

Dietmar Maurer, E<lt>dietmar@proxmox.com<gt>

=cut
