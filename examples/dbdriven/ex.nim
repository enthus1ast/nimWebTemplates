import jester
# import nwt
import ../../nwt
import times
import asyncdispatch
import """D:\flatdb\flatdb.nim"""
import json
# import tables

var t = newNwt("templates/*")
var db = newFlatDb("tst.db", false)
discard db.load()

## Testdata
if db.nodes.len == 0:
  ## If the db is empty we fill some default values
  discard db.append(%* {"title": "HALLO!!", "link": "hallo", "content": "ich bin ein bisschen content", "author": "enthus1ast"})
  discard db.append(%* {"title": "foo :)", "link": "foo", "content": "i am some conten about foo", "author": "klauspeter"})


routes:
  get "/":
    resp t.renderTemplate("list.html",  %* {"entries": $db.nodes} )
    
  get "/@link":
    resp t.renderTemplate("detail.html", db.queryOne equal("link", @"link") )
runForever()
