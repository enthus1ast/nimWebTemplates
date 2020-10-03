import asynchttpserver, asyncdispatch
import ../../../nwt
import strutils
import tables
import os


const PUBLIC_DIR = "{{publicDir}}"
var t = newNwt("{{templateDir}}")

when not defined release:
  t.freeze(staticPath = PUBLIC_DIR, outputPath = "./freezed/")  ## Example for "freezing" your templates into a static site.

var server = newAsyncHttpServer()
proc cb(req: Request) {.async.} =
  let res = req.url.path.strip(leading=true, trailing=false, {'/'})

  case res 
  # some routes!
  # be aware that freeze() only freezes the template and copies the public folder.
  # we do not visit your custom rules for now!


{%block "routes"%}{%endblock%}  

  else:
    if t.templates.contains(res): # when we have a template with this name, serve it
      await req.respond(Http200, t.renderTemplate(res))
    elif fileExists(PUBLIC_DIR / res): # when there is a static file with this name, serve it
      await req.respond(Http200, open(PUBLIC_DIR / res,).readAll())
    else: # unkown to us
      await req.respond(Http404, "404 not found")

waitFor server.serve(Port(8080), cb)