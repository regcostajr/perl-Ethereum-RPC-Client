package Ethereum::RPC::Client;

use strict;
use warnings;

use Moo;
use Mojo::UserAgent;
use Ethereum::RPC::Contract;

use Future;
use IO::Async;
use Net::Async::HTTP;
use JSON::MaybeXS;
use Encode qw(encode_utf8);

our $VERSION = '0.02';

has host => (
    is      => 'ro',
    default => sub { '127.0.0.1' });

has port => (
    is => "ro",
    default => 8545,
);

has _http_client => (
    is => 'lazy',
);

sub _build__http_client {
    return Net::Async::HTTP->new(
        decode_content => 1,
    );
}

has _loop => (
    is => 'lazy',
);

sub _build__loop {
    return IO::Async::Loop->new();
}

has _json => (
    is => 'lazy',
);

sub _build__json {
    return JSON::MaybeXS->new(pretty => 1);
}

## no critic (RequireArgUnpacking)
sub AUTOLOAD {
    my $self = shift;

    my $method = $Ethereum::RPC::Client::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $url = "";
    $url .= 'http://' unless $url =~ /^http/;
    $url .= $self->host;
    $url .= ':' . $self->port if $self->port;

    $self->{id} = 1;
    my $obj = {
        id     => $self->{id}++,
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    $self->_loop->add($self->_http_client) unless defined $self->_http_client->loop;
    return $self->get_json_response(
        "POST" => $url,
        encode_utf8($self->_json->encode($obj)),
        content_type => 'application/json',
    );
}

sub get_json_response {
    my ($self, $meth, @params) = @_;
    $self->_http_client->$meth(@params)->transform(
        done => sub {
            my ($resp) = @_;
            $self->_json->decode($resp->decoded_content)->{result};
        }
        )->else(
        sub {
            Future->fail(@_);
        });
}

=head2 contract

Creates a new contract instance

Parameters:
    contract_address    ( Optional - only if the contract already exists ),
    contract_abi        ( Required - https://solidity.readthedocs.io/en/develop/abi-spec.html ),
    from                ( Optional - Address )
    gas                 ( Optional - Integer gas )
    gas_price           ( Optional - Integer gasPrice )

Return:
    New contract instance

=cut

sub contract {
    my $self   = shift;
    my $params = shift;
    return Ethereum::RPC::Contract->new((%{$params}, rpc_client => $self));
}

1;

=pod

=head1 NAME

Ethereum::RPC::Client - Ethereum JSON-RPC Client

=head1 SYNOPSIS

   use Ethereum::RPC::Client;

   # Create Ethereum::RPC::Client object
   my $eth = Ethereum::RPC::Client->new(
      host     => "127.0.0.1",
   );

   my $web3_clientVersion = $eth->web3_clientVersion;

   # https://github.com/ethereum/wiki/wiki/JSON-RPC

=head1 DESCRIPTION

This module implements in PERL the JSON-RPC of Ethereum L<https://github.com/ethereum/wiki/wiki/JSON-RPC>

=head1 SEE ALSO

L<Bitcoin::RPC::Client>

=head1 AUTHOR

Binary.com E<lt>fayland@binary.comE<gt>

=head1 COPYRIGHT

Copyright 2017- Binary.com

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
