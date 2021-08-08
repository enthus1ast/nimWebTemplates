import asynchttpserver, asyncdispatch
# {.push experimental: "vmopsDanger".}

import ../src/parser
import os, random, ropes

# template scriptDir(): string =
#   parentDir(instantiationInfo(-1, true).filename)


type
  User = object
    name: string
    lastname: string
    age: int



proc renderIndex(title: string, users: seq[User]): Rope = compileTemplateFile(getCurrentDir() / "index.nwt")

proc main {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =

    let users: seq[User] = @[
      User(name: "Katja", lastname: "Kopylevych", age: 32),
      User(name: "David", lastname: "Krause", age: 32),
    ]

    await req.respond(Http200, $renderIndex("index", users))
    # await req.respond(Http200, renderIndex(@[1,2,3]))

  server.listen Port(8080)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

asyncCheck main()
runForever()