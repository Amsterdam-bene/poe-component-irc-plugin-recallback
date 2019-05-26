package POE::Component::IRC::Plugin::ReCallback;

use strict;
use warnings;

use POE::Component::IRC;
use POE::Component::IRC::Plugin qw( :ALL );

use Data::Dumper;
use LWP::UserAgent;
use JSON qw();

my $ua = LWP::UserAgent->new(
    agent => 'Salveo Mattini/666.42',
    timeout => 2,
);

sub new {
    my ($package, %args) = @_;

    my $self = bless {}, $package;

    return $self;
}

sub PCI_register {
    my ($self, $irc) = @_;

    $irc->plugin_register($self, 'SERVER', 'public');

    return 1;
}

sub PCI_unregister {
    return 1;
}

sub S_public {
    my ($self, $irc) = (shift, shift);

    my $nick = ${ +shift };
    $nick =~ s/!.*$//;

    my $my_own_nick = $irc->{nick};

    my $channel = ${ +shift }->[0];
    my $lc_channel = lc $channel;
    (my $pathsafe_channel = $lc_channel) =~ s{/}{_}g;
    my $channel_settings = $self->{channel_settings}{$lc_channel};

    my $message = shift;

    my $text = $$message;
    Encode::_utf8_on( $text );

    # allow optionally addressing the bot
    $text =~ s/\A$my_own_nick[:,\s]*//;

    my $callbacks = do "./callbacks.pl";
    if ( ref $callbacks ne 'ARRAY' ) {
        warn __PACKAGE__.": Attempting to load ./callbacks.pl didn't return an array\n";
        warn "  \$@ follows:\n$@\n" if $@;
        warn "  \$! follows:\n$!\n" if $!;
    }

    foreach my $callback ( @$callbacks ) {
        if ( $text !~ $callback->{trigger} ) {
            next;
        }

        my $response = $ua->post($callback->{url},
            Content => JSON::to_json ({
                text => $text,
                nick => $nick,
                my_own_nick => $my_own_nick,
                channel => $channel,
            }),
            'Content-Type' => 'application/json',
            'Yolo' => 'in bolo',
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
                notice => $channel,
                $result->{reply},
            );
        }
    }

    return PCI_EAT_NONE;
}

1;

__END__

# vim: tabstop=4 shiftwidth=4 expandtab cindent:
