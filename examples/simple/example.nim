import asynchttpserver, asyncdispatch
import json
import nwt

var templates = newNwt("templates/*.html") # we have all the templates in a folder called "templates"

var server = newAsyncHttpServer()
proc cb(req: Request) {.async.} =
  let res = req.url.path

  case res 
  of "/", "/index.html":
    await req.respond(Http200, templates.renderTemplate("index.html"))  
  of "/about.html":
    await req.respond(Http200, templates.renderTemplate("about.html"))
  of "/stats.html":
    await req.respond(Http200, templates.renderTemplate("stats.html", %* {"title": "some variables from nim", "foo": "Foo!", "baa": "Baa!"}))  
  else:
    await req.respond(Http404, "not found")

waitFor server.serve(Port(8080), cb) 