import asynchttpserver, asyncdispatch
import ../../nwt
import strutils
import tables
import os
import asyncfile

const PUBLIC_DIR = "./public/"
var t = newNwt("templates/*.html")

when not defined release:
  t.freeze(staticPath = PUBLIC_DIR, outputPath = "./freezed/")  ## Example for "freezing" your templates into a static site.

var server = newAsyncHttpServer()
proc cb(req: Request) {.async.} =
  let res = req.url.path.strip(leading=true, trailing=false, {'/'})

  case res 
  # some routes!
  # be aware that freeze() only freezes the template, wich are loaded by the constructor, and copies the public folder.
  # we do not visit your custom routes for now!
  of "":
    await req.respond(Http200, t.renderTemplate("index.html") )  
  of "logout":
    await req.respond(Http200, "TODO do something usefull")

  
  else:
    if t.templates.contains(res): # when we have a template with this name, serve it
      await req.respond(Http200, t.renderTemplate(res))
    elif fileExists(PUBLIC_DIR / res): # when there is a static file with this name, serve it
      let file = openAsync(PUBLIC_DIR / res , fmRead)
      # let data 
      await req.respond(Http200, await file.readAll())
      file.close()
    else: # unkown to us
      await req.respond(Http404, "404 not found")

waitFor server.serve(Port(8080), cb)