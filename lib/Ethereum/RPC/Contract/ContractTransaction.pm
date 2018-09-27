package Ethereum::RPC::Contract::ContractTransaction;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

   Ethereum::RPC::Contract::ContractTransaction - Centralize contract transactions

=cut


use Moo;
use Future;

use Ethereum::RPC::Contract::ContractResponse;
use Ethereum::RPC::Contract::Helper::UnitConversion;

has contract_address => ( is => 'ro' );
has rpc_client       => ( is => 'ro', lazy => 1 );

sub _build_rpc_client {
    return Ethereum::RPC::Client->new;
}

has data             => ( is => 'ro', required => 1 );
has from             => ( is => 'ro');
has gas              => ( is => 'ro');
has gas_price        => ( is => 'ro');

=head2 call_transaction

Call a public functions and variables from a ethereum contract

Return:
    Ethereum::RPC::Contract::ContractResponse, error message

=cut

sub call_transaction {
    my $self = shift;

    my $res = $self->rpc_client->eth_call([{
        to    => $self->contract_address,
        data  => $self->data,
    }, "latest"])
    ->then(sub{
        my ($call_response) = @_;
        Future->done(Ethereum::RPC::Contract::ContractResponse->new({response => $call_response}));
    })
    ->on_fail(sub{
        Future->fail("Can't call transaction");
    });

    return $res;
}

=head2 send_transaction

Send a transaction to a payable functions from a ethereum contract

Return:
    Ethereum::RPC::Contract::ContractResponse, error message

=cut

sub send_transaction {
    my $self = shift;

    my $params = {
        to          => $self->contract_address,
        from        => $self->from,
        gasPrice    => $self->gas_price,
        data        => $self->data,
    };

    $params->{gas} = Ethereum::RPC::Contract::Helper::UnitConversion::to_wei($self->gas) if $self->gas;

    my $res = $self->rpc_client->eth_sendTransaction([$params])
    ->then(sub{
        my ($send_response) = @_;
        Future->done(Ethereum::RPC::Contract::ContractResponse->new({response => $send_response}));
    })
    ->on_fail(sub{
        Future->fail("Can't call transaction");
    });
    
    return $res;
}

1;
