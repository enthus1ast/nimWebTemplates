import jester
import nwt
# import nwt
import times
import asyncdispatch
# import """D:\flatdb\flatdb.nim"""
import json
# import tables

var t = newNwt("templates/*")

echo "FREEZING TEMPLATES (JUST FOR FUN)"
# t.freeze()

# var db = newFlatDb("tst.db", false)
# if db.nodes.len == 0:
  # discard db.append(%* {"site": "index.html", "content": "ich bin ein bisschen content"})
routes:
  get "/jesterLeakTest":
    resp "ok"

  get "/":
    # resp t.renderTemplate("index.html", newStringTable({"content": $epochTime()}))
    resp t.renderTemplate("index.html", %*{"content": $epochTime()})
  get "/@name":#& ".html"
    # resp t.renderTemplate(@"name" , newStringTable({"content": $epochTime()}))    
    resp t.renderTemplate(@"name" , %*{"content": $epochTime(), "items": @["one", "two", "three", "four"]})    
    # resp t.renderTemplate("index.html",  newStringTable(db.queryOne equal("site","index.html")) ))
  # get "/ass":
  #   resp t.renderTemplate("ass.html", newStringTable({"content": $epochTime()}))
runForever()
