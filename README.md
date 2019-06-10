# POE::Component::IRC::Plugin::ReCallback

This pocoirc plugin forwards text which matches certain regular expressions as JSON to an external service, and optionally writes replies back to the channel where they came from.

See the `examples/` directory for an example microservice which replies `yolo in bolo, Dude` when triggered by Dude's message.

### example usage

    $ cat pocoirc-config.yaml
    [...]
    local_plugins:
        - [ReCallback, {config_file: /usr/src/bot/etc/recallback.pl}]
    [...]

    $ cat callbacks.pl
    [
        {
            trigger => qr/^hello\b/i,
            url => 'https://some-microservice.net/greeting',
        },
        {
            trigger => qr/whatever/,
            url => 'https://whatever-handler.io/',
        },
    ];

    $ pocoirc --verbose --config pocoirc-config.yaml
    [...]

This example will POST a JSON to the url when someone says something that begins with "hello".  The request will look more or less like this:

    POST /greeting HTTP/1.1
    Host: some-microservice.net
    Content-Type: application/json
    Accept: application/json

    {
        "_meta": { "api_version": 1 },
        "text" => "hello bot, say something",
        "nick" => "Rocco",
        "sender" => "Rocco!~rtanica@unaffiliated/rocco",
        "my_own_nick" => "DeBot",
        "channel" => "##horsing-around"
    }

The microservice should reply with a JSON, and if the response document has a `reply` field, that's what will be replied on the channel, e.g.:

    HTTP/1.1 200 OK
    Content-Type: application/json

    {"reply":"Hi there, Rocco"}

If it wants to send more than one message, it can do so with a `replies` field:

    HTTP/1.1 200 OK
    Content-Type: application/json

    {"replies":["one message","another message","and so on"]}

The separate messages will be sent one at a time, in order.

If you have some verbose debugging which should be sent back in a private query to the person triggering the call (e.g. during development of a callback, you'd like to see some additional information), you can add a `debug` field, which will be sent as a private message.

    HTTP/1.1 200 OK
    Content-Type: application/json

    {"reply":"OK, cool","debug":"this is what happened behind the scenes"}

The `OK, cool` string will be replied, and the other phrase will be sent as a private message.

[modeline]: # ( vim: set wrap tabstop=4 shiftwidth=4 expandtab fileencoding=utf-8 spell spelllang=en: )
