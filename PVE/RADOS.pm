package PVE::RADOS;

use 5.014002;
use strict;
use warnings;
use Carp;
use JSON;

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

sub new {
    my $conn = pve_rados_create() ||
	die "unable to create RADOS object\n";

    pve_rados_connect($conn);

    my $self = bless { conn =>  $conn };

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    pve_rados_shutdown($self->{conn});
}

sub cluster_stat {
    my ($self) = @_;

    return  pve_rados_cluster_stat($self->{conn});
}

# example: { prefix => 'mon dump', format => 'json' }
sub mon_command {
    my ($self, $cmd) = @_;

    my $json = encode_json($cmd);
    my $raw = pve_rados_mon_command($self->{conn}, [ $json ]);
    if ($cmd->{format} && $cmd->{format} eq 'json') {
	return decode_json($raw);
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
