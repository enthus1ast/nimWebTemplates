import jester
import nwt
# import nwt
import times
import asyncdispatch
# import """D:\flatdb\flatdb.nim"""
# import json
import tables

var t = newNwt("templates/*.html")
# var db = newFlatDb("tst.db", false)
# if db.nodes.len == 0:
  # discard db.append(%* {"site": "index.html", "content": "ich bin ein bisschen content"})
routes:
  get "/":
    resp t.renderTemplate("index.html", newStringTable({"content": $epochTime()}))
  get "/@name":
    resp t.renderTemplate(@"name" & ".html", newStringTable({"content": $epochTime()}))    
    # resp t.renderTemplate("index.html",  newStringTable(db.queryOne equal("site","index.html")) ))
  # get "/ass":
  #   resp t.renderTemplate("ass.html", newStringTable({"content": $epochTime()}))
runForever()
