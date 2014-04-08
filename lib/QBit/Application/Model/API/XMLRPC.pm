package Exception::API::XMLRPC;
use base qw(Exception::API);

package QBit::Application::Model::API::XMLRPC;

use qbit;

use base qw(QBit::Application::Model::API);

use Data::Rmap;

sub init {
    my ($self) = @_;

    $self->SUPER::init();

    if ($self->get_option('debug')) {
        eval "use XMLRPC::Lite +trace => 'debug';";
    } else {
        eval "use XMLRPC::Lite;";
    }

    $self->{'__RPC__'} = XMLRPC::Lite->new();
    $self->{'__RPC__'}->proxy($self->get_option('url'), timeout => $self->get_option('timeout', 300));

    return 1;
}

sub call {
    my ($self, $func, @opts) = @_;

    rmap {utf8::decode($_) if defined($_) and !utf8::is_utf8($_)} \@opts;

    my $result;
    my $error;

  TRY:
    for my $try (1 .. 3) {
        my $som;
        eval {$som = $self->{__RPC__}->call($func, @opts);};

        $error = $@;

        if (!$error) {
            if ($som->fault) {
                $self->log(
                    {
                        proxy_url => $self->{__RPC__}->proxy->endpoint,
                        method    => $func,
                        params    => \@opts,
                        content   => undef,
                        error     => $som->faultstring
                    }
                ) if $self->can('log');
                throw Exception::API::XMLRPC $som->faultstring;
            } else {
                $result = [$som->paramsall];
            }
            last TRY;
        }
        sleep(1);
    }

    $self->log(
        {
            proxy_url => $self->{__RPC__}->proxy->endpoint,
            method    => $func,
            params    => \@opts,
            content   => $result,
            error     => $error
        }
    ) if $self->can('log');

    throw Exception::API::XMLRPC $error unless $result;
    return $result;
}

TRUE;
