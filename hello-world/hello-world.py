def application(environ, response):
    response('200 OK', [('Content-Type', 'text/html')])
    return [b"{ \"hello\": \"world\" }"]
