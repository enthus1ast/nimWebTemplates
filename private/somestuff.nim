import ../src/nwt2
import prologue, strutils
import times # for use in template

type
  Entry = object
    ii: int
    ff: float
    ss: string
  SomeObj = object
    name: string
    entries: seq[Entry]

var someObj = SomeObj()
someObj.name = "the object"
someObj.entries.add Entry(ii: 1, ff: 1.0, ss: "one")
someObj.entries.add Entry(ii: 2, ff: 2.0, ss: "two")
someObj.entries.add Entry(ii: 3, ff: 3.0, ss: "three")
# for idx in 4..10_000:
#   someObj.entries.add Entry(ii: idx, ff: idx.float, ss: "SOME :" & $idx)

proc render(ctx: Context, obj: SomeObj): string {.gcsafe.} = compileTemplateFile("someObj.ninja")
proc render(ctx: Context, entry: Entry): string {.gcsafe.} = compileTemplateFile("entry.ninja")
# writeFile("index.html", render(someObj))

proc index*(ctx: Context) {.async, gcsafe.} =
  resp render(ctx, someObj)

proc entry*(ctx: Context) {.async, gcsafe.} =
  var id: int
  try:
    id = ctx.getPathParams("id").parseInt()
    resp render(ctx, someObj.entries[id])
  except:
    resp "Id not found"

proc add*(ctx: Context) {.async, gcsafe.} =
  let newIdx = someObj.entries.len + 1
  someObj.entries.add(
    Entry(
      ii: newIdx,
      ff: (newIdx).float,
      ss: $newIdx )
  )
  resp redirect("/", Http302)

let app = newApp(settings = newSettings())
app.addRoute("/entry/{id}", entry, @[HttpGet], name = "entry")
app.addRoute("/add", add, @[HttpGet], name = "add")
app.addRoute("/", index, @[HttpGet])
app.run()

# import timeit
# template pp() =
#   discard render(someObj)

# echo timeGo(pp)
