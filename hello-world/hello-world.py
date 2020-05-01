import json
def application(environ, response):
    response('200 OK', [('Content-Type', 'application/json')])
    resp = bytes(json.dumps({'hello': 'world'}),'utf-8')
    return [resp]
