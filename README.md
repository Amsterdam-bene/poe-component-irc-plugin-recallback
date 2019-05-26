# POE::Component::IRC::Plugin::ReCallback

This pocoirc plugin forwards text which matches certain regular expressions as JSON to an external service, and optionally writes replies back to the channel where they came from.

See the `examples/` directory for an example microservice which replies `yolo in bolo, Dude` when triggered by Dude's message.

### example usage

    $ cat pocoirc-config.yaml
    [...]
    local_plugins:
        - [ReCallback]
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
        "text" => "hello bot, say something",
        "nick" => "Rocco",
        "my_own_nick" => "DeBot",
        "channel" => "##horsing-around"
    }

The microservice should reply with a JSON, and if the response document has a "reply" field, that's what will be replied on the channel, e.g.:

    HTTP/1.1 200 OK
    Content-Type: application/json

    {"reply":"Hi there, Rocco"}

[modeline]: # ( vim: set wrap tabstop=4 shiftwidth=4 expandtab fileencoding=utf-8 spell spelllang=en: )
