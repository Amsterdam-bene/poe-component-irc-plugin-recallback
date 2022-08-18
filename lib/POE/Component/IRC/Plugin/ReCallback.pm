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

sub _sanitize ($) {
    my ($text) = @_;

    $text =~ s/\s+/ /g;

    return $text;
}

sub _handle_callbacks {
    my ($self, $irc, $sender_ref, $recipients_ref, $message_ref, $is_identified) = @_;

    my $sender = $$sender_ref;
    (my $sender_nick = $sender) =~ s/!.*//;

    my $where_to_reply = ${$recipients_ref}->[0];

    my $text = $$message_ref;
    Encode::_utf8_on( $text );

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

    my $my_own_nick = $irc->{nick};
    foreach my $callback ( @$callbacks ) {
        # allow optionally addressing the bot
        if ( $text !~ qr{ (?:\A$my_own_nick[:,\s]*)? $callback->{trigger} }x ) {
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
            'Content-Type' => 'application/json; charset=UTF-8',
            'Content' => JSON::to_json($payload, { utf8 => 1 }),
        );

        if ( ! $response->is_success ) {
            warn "Response from <$callback->{url}> was not a success: <@{[ $response->status_line ]}>\n";
            warn $response->decoded_content . "\n";
            if ( my $client_warning = $response->header('Client-Warning') ) {
                warn "client_warning:<$client_warning>\n";
            }
            next;
        }

        my $json_decode_params = {};
        my $response_content_type = $response->header('Content-Type') // 'application/json; charset=utf-8; _source=defaults';
        my $ct_directives_map = {};
        my ($ct, @ct_directives) = split /;\s*/, $response_content_type;
        if ( $ct ne 'application/json' && $ct ne 'text/json' ) {
            warn "Response Content-Type is not 'application/json' or 'text/json' (it's <$ct>), trying to parse it anyway...\n";
        }
        foreach my $directive ( @ct_directives ) {
            my ($k, $v) = split /=/, $directive, 2;
            $ct_directives_map->{$k} = $v;
        }
        $ct_directives_map->{charset} //= 'utf-8';
        if ( $ct_directives_map->{charset} eq 'utf-8' ) {
            $json_decode_params->{utf8} = 1;
        }

        my $result = {};
        eval {
            $result = JSON::from_json($response->decoded_content, $json_decode_params);
            1;
        } or do {
            my ($exception) = $@;
            warn "Error while unserializing JSON response; Full error follows:\n";
            warn "$exception\n";
            warn "\n";
            warn "Full response follows:\n";
            warn $response->as_string . "\n";

            $result->{debug} = JSON::to_json({
                diag => "Error while unserializing JSON response",
                exception => $exception,
            });
        };

        if ( exists $result->{debug} ) {
            my $sanitized_debug = _sanitize $result->{debug};

            $irc->yield(
                notice => $sender_nick,
                $sanitized_debug,
            );
        }
        if ( exists $result->{reply} ) {
            my $sanitized_reply = _sanitize $result->{reply};

            ## This is the yield for the reply to the channel
            $irc->yield(
                notice => $where_to_reply,
                $sanitized_reply,
            );
        }
        if ( exists $result->{replies} && ref $result->{replies} eq 'ARRAY' ) {
            foreach my $one_reply ( @{ $result->{replies} } ) {
                my $sanitized_reply = _sanitize $one_reply;

                ## This is the yield for the reply to the channel
                $irc->yield(
                    notice => $where_to_reply,
                    $sanitized_reply,
                );
            }
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
