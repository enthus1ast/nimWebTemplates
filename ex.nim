import jester
import nwt
import times
import asyncdispatch
import json

var t = newNwt("templates/*")

echo "FREEZING TEMPLATES (JUST FOR FUN)"
t.freeze()

routes:
  get "/":
    resp t.renderTemplate("index.html", %*{"content": $epochTime()})
  get "/@name":#& ".html"
    resp t.renderTemplate(@"name" , %*{"content": $epochTime(), "items": @["one", "two", "three", "four"]})    
runForever()
