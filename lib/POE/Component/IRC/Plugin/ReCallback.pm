package POE::Component::IRC::Plugin::ReCallback;

use strict;
use warnings;

use POE::Component::IRC;
use POE::Component::IRC::Plugin qw( :ALL );

use LWP::UserAgent;
use JSON qw();

my $ua = LWP::UserAgent->new(
    agent => 'Salveo Mattini/666.42',
    timeout => 2,
);

sub new {
    my ($package, %args) = @_;

    my $self = bless \%args, $package;

    return $self;
}

sub PCI_register {
    my ($self, $irc) = @_;

    # event names from https://metacpan.org/pod/POE::Component::IRC#Important-Commands
    $irc->plugin_register($self, 'SERVER', 'public');
    $irc->plugin_register($self, 'SERVER', 'msg');

    return 1;
}

sub PCI_unregister {
    return 1;
}

sub _handle_callbacks {
    my ($self, $irc, $sender_ref, $recipients_ref, $message_ref, $is_identified) = @_;

    my $sender = $$sender_ref;
    (my $sender_nick = $sender) =~ s/!.*//;

    my $where_to_reply = ${$recipients_ref}->[0];

    my $text = $$message_ref;
    Encode::_utf8_on( $text );

    my $my_own_nick = $irc->{nick};
    # allow optionally addressing the bot
    $text =~ s/\A$my_own_nick[:,\s]*//;

    my $config_file = "";
    if (!defined $self->{config_file}) {
        $config_file = "./callback.pl";
    }
    else{
        $config_file = $self->{config_file};
    }

    my $callbacks = do $config_file;
    if ( ref $callbacks ne 'ARRAY' ) {
        warn __PACKAGE__.": Attempting to load $config_file didn't return an array\n";
        warn "  \$@ follows:\n$@\n" if $@;
        warn "  \$! follows:\n$!\n" if $!;
    }

    foreach my $callback ( @$callbacks ) {
        if ( $text !~ $callback->{trigger} ) {
            next;
        }

        my $payload = {
            _meta => {
                # we bump the API version when we make backwards-incompatible
                # changes to the shape of the request/reply JSON
                api_version => 1,
            },
            text => $text,
            nick => $sender_nick,
            sender => $sender,
            my_own_nick => $my_own_nick,
            channel => $where_to_reply,
        };

        my $response = $ua->post(
            $callback->{url},
            'Content-Type' => 'application/json',
            'Content' => JSON::to_json($payload),
        );

        if ( ! $response->is_success ) {
            warn "Response from <$callback->{url}> was not a success: <@{[ $response->status_line ]}>\n";
            warn $response->decoded_content . "\n";
            if ( my $client_warning = $response->header('Client-Warning') ) {
                warn "client_warning:<$client_warning>\n";
            }
            next;
        }

        my $ct = $response->header('Content-Type') // '(no Content-Type header in response)';
        if ( $ct ne 'application/json' ) {
            warn "Response Content-Type is not 'application/json' (it's <$ct>), trying to parse it anyway...\n";
        }

        my $result = JSON::from_json($response->decoded_content);
        if ( exists $result->{reply} ){
            ## This is the yield for the reply to the channel
            $irc->yield(
                notice => $where_to_reply,
                $result->{reply},
            );
        }
    }
}

sub S_msg {
    my ($self, $irc, $sender, $recipients, $message, $is_identified) = @_;

    (my $sender_nick = $$sender) =~ s/!.*//;

    # pass \[$sender_nick] as recipients ref, so response will go to the same
    # user who is talking with the bot
    $self->_handle_callbacks($irc, $sender, \[$sender_nick], $message, $is_identified);

    return PCI_EAT_NONE;
}

sub S_public {
    my ($self, $irc, $sender, $recipients, $message, $is_identified) = @_;

    $self->_handle_callbacks($irc, $sender, $recipients, $message, $is_identified);

    return PCI_EAT_NONE;
}

1;

__END__

# vim: tabstop=4 shiftwidth=4 expandtab cindent:
