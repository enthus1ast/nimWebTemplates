import os, random, strutils
import prologue
import ../src/parser
import ropes

type
  User = object
    name: string
    lastname: string
    age: int

let users: seq[User] = @[
  User(name: "Katja", lastname: "Kopylevych", age: 32),
  User(name: "David", lastname: "Krause", age: 32),
]

proc renderIndex(title: string, users: seq[User]): Rope {.gcsafe.} =
  compileTemplateFile(getCurrentDir() / "index.nwt")

proc renderUser(title: string, idx: int, users: seq[User]): Rope {.gcsafe.} =
  let user = users[idx]
  compileTemplateFile(getCurrentDir() / "user.nwt")


proc hello*(ctx: Context) {.async, gcsafe.} =
  resp $renderIndex("someTitle", users)

proc user*(ctx: Context) {.async, gcsafe.} =
  var idx = 0
  try:
    idx = parseInt(ctx.getPathParams("idx", "0"))
    resp $renderUser("someTitle", idx, users)
  except:
    discard # return error
    resp "not found", Http404

let app = newApp()
app.get("/", hello)
app.get("/users/{idx}", user)
app.run()