import asynchttpserver, asyncdispatch
import ../../nwt
import strutils
import tables
import os


const PUBLIC_DIR = "./public/"
var t = newNwt("templates/*.html")
t.freeze()

var server = newAsyncHttpServer()
proc cb(req: Request) {.async.} =
  let res = req.url.path.strip(leading=true, trailing=false, {'/'})
  case res
  of "":
    await req.respond(Http200, t.renderTemplate("index.html") )  
  of "logout":
    await req.respond(Http200, "TODO do something usefull")
  else:
    if t.templates.contains(res):
      await req.respond(Http200, t.renderTemplate(res))
    elif fileExists(PUBLIC_DIR / res):
      await req.respond(Http200, open(PUBLIC_DIR / res,).readAll())
    else:
      await req.respond(Http404, "404 not found")
  # echo req.url.path
  # await req.respond(Http200, "Hello World")

waitFor server.serve(Port(8080), cb)