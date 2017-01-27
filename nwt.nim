## Experiment to build a basic
## jinja like template parser
## Works:
##  - comments {# comment #}
##  - variable {{variable}}
##  - extends [NON recursive ATM]
## NOT:
##  - evaluation (for, while, etc)
##  - everything else ;)

## Example usage with jester:
## routes:
##   get "/":
##     resp t.renderTemplate("index.html", newStringTable({"content": $epochTime()}))
##   get "/ass":
##     resp t.renderTemplate("ass.html", newStringTable({"content": $epochTime()}))
## runForever()


# {% set activeHome = 'active' %} Setzt variable

import strtabs
import strutils
import parseutils
import sequtils
import os
import tables

type 
  TemplateSyntaxError = Exception
  UnknownTemplate = Exception

  Nwt = object of RootObj
    templates*: StringTableRef ## we load all the templates we want to render to this strtab

  NwtToken = enum
    NwtString, # a string block
    NwtComment,
    NwtEval,
    NwtVariable

  Token = object of RootObj 
    tokenType: NwtToken # the type of the token
    value: string # the value 

  Block = tuple[name: string, posStart: int, posEnd: int]


proc newToken(tokenType:NwtToken, value: string): Token = 
  result = Token()
  result.tokenType = tokenType
  result.value = value

proc debugPrint(buffer: string, pos: int) = 
  var pointPos = if pos - 1 < 0: 0 else: pos - 1
  echo buffer
  echo '-'.repeat(pointPos) & "^"
  # echo pointPos

iterator nwtTokenize(s: string): Token =
  ## transforms nwt templates into tokens
  var 
    buffer: string = s 
    pos = 0
    toyieldlater = ""

  while true:
    var stringToken = ""
    pos = buffer.parseUntil(stringToken,'{',pos) + pos
    # buffer.debugPrint(pos)

    if buffer == "{":
      # echo "buffer ist just '{'"
      yield newToken(NwtString, "{")
      break

    if stringToken.len == buffer.len:
      # echo "we have read the string at once! no '{' found"
      yield newToken(NwtString, stringToken)
      break

    if stringToken != "" :
      # yield newToken(NwtString, stringToken)
      toyieldlater.add stringToken
    pos.inc # skip "{"
    if buffer.continuesWith("{",pos): 
      if toyieldlater != "": yield newToken(NwtString, toyieldlater); toyieldlater = ""
      pos.inc # skip {
      pos = buffer.parseUntil(stringToken,'}',pos) + pos
      yield newToken(NwtVariable, stringToken.strip())
      pos.inc # skip }
      pos.inc # skip }
    elif buffer.continuesWith("#",pos): 
      if toyieldlater != "": yield newToken(NwtString, toyieldlater); toyieldlater = ""
      pos.inc # skip #
      pos = buffer.parseUntil(stringToken,'#',pos) + pos
      pos.inc # skip end # 
      if buffer.continuesWith("}", pos): 
        pos.inc # skip }
        yield newToken(NwtComment, stringToken[0..^1].strip()) # really need to strip?
    elif buffer.continuesWith("%",pos): 
      if toyieldlater != "": yield newToken(NwtString, toyieldlater); toyieldlater = ""
      pos.inc # skip #
      pos = buffer.parseUntil(stringToken,'%',pos) + pos
      pos.inc # skip end # 
      if buffer.continuesWith("}", pos): 
        pos.inc # skip }
        yield newToken(NwtEval, stringToken[0..^1].strip()) # really need to strip? 
    else:
      if pos >= buffer.len:
        # echo "we have reached the end of buffer"
        # yield newToken(NwtString, stringToken)
        yield newToken(NwtString, toyieldlater)
      else:
        # echo "we found a { somewhere so we have to prepend it"
        toyieldlater = toyieldlater & "{" 
      discard

    if pos >= buffer.len: # TODO check if this has to be '>'
      ## Nothing to do for us here
      break

proc toStr(token: Token, params: StringTableRef = newStringTable()): string = 
  ## transforms the token to its string representation 
  # TODO should this be `$`?
  case token.tokenType
  of NwtString:
    return token.value
  of NwtComment:
    return ""
  of NwtVariable:
    var bufval = params.getOrDefault(token.value)
    if bufval == "":
      return "{{" & token.value & "}}" ## return the token when it could not replaced
    else:
      return bufval
  else:
    return ""

proc newNwt*(templatesDir: string = "./templates/*.html"): Nwt =
  ## this loads all templates from the template into memory
  result = Nwt()
  result.templates = newStringTable()
  for filename in walkFiles(templatesDir):
    var templateName = extractFilename(filename)
    # echo "Load: $1 as $2", % [filename, templateName]
    result.templates[templateName] = readFile(filename)

proc extractTemplateName(raw: string): string = 
  ## returns the template name from
  ##  extends "base.html"
  ## returns "base.html"
  var parts = raw.strip().split(" ")
  if parts.len != 2:
    raise newException(TemplateSyntaxError, "Could not extract template name from '$1'" % [raw])
  result = parts[1].captureBetween('"', '"')
  if result != "": return

  result = parts[1].captureBetween('\'', '\'')
  if result != "": return

  result = parts[1] # TODO is this working??
  

proc getBlocks(tokens: seq[Token]): Table[string, Block] =
  # returns all {%block 'foo'%} statements as a Table of Block
  result = initTable[string, Block]()
  var actual: Block = ("",0,0)
  for i, each in tokens:
    if each.tokenType == NwtEval and each.value.strip().startswith("block"): # block
      actual.name = each.value.extractTemplateName()
      actual.posStart = i
    if each.tokenType == NwtEval and each.value.strip().startswith("endblock"):
      actual.posEnd = i
      result[actual.name] = actual
      actual = ("",0,0)

proc fillBlocks(baseTemplateTokens, tokens: seq[Token]): seq[Token] = 
  ## This fills all the base template blocks with
  ## blocks from extending template
  # @[(name: content2, posStart: 2, posEnd: 4), (name: peter, posStart: 6, posEnd: 8)]
  # @[(name: content2, posStart: 3, posEnd: 4), (name: peter, posStart: 6, posEnd: 8)]
  result = baseTemplateTokens
  var templateBlocks = getBlocks(tokens)
  var baseTemplateBlocks = getBlocks(baseTemplateTokens)  

  for baseBlock in baseTemplateBlocks.values:
    if templateBlocks.contains(baseBlock.name):
      if templateBlocks.contains(baseBlock.name): 
        # we only do anything if we have that block in the extending template
        result.delete(baseTemplateBlocks[baseBlock.name].posStart, baseTemplateBlocks[baseBlock.name].posEnd)
        var startp = templateBlocks[baseBlock.name].posStart
        var endp = templateBlocks[baseBlock.name].posEnd
        # var endp   = tokens[templateBlocks[baseBlock.name]].posStart
        var inspos = baseTemplateBlocks[baseBlock.name].posStart
        result.insert(tokens[startp .. endp] , inspos)

proc renderTemplate*(nwt: Nwt, templateName: string, params: StringTableRef = newStringTable()): string =
  ## this returns the fully rendered template.
  ## all replacements are done.
  ## if the loaded template extends a base template, we parse this as well and fill all the blocks.
  ## ATM this is not recursively checking for extends on child templates! 
  ## So only one 'extends' level is supported.
  result = ""
  var tokens: seq[Token] = @[]
  var baseTemplateTokens: seq[Token] = @[]

  if not nwt.templates.hasKey(templateName):
    raise newException(UnknownTemplate, "Template '$1' not found." % [templateName])
  for each in nwtTokenize(nwt.templates[templateName]):
    if each.tokenType == NwtEval and  each.value.startswith("extends"):
      # echo "template has an extends"
      baseTemplateTokens = toSeq( nwtTokenize(  nwt.templates[extractTemplateName(each.value)] ))
    tokens.add each

  if baseTemplateTokens.len > 0:
    for token in baseTemplateTokens.fillBlocks(tokens):
      result.add token.toStr(params)
  else:
    for token in tokens:
      result.add token.toStr(params)


when isMainModule:
  # var nwt = newNwt()
  # echo "Loaded $1 templates." % [$nwt.templates.len]


  ## Tokenize tests
  assert toSeq(nwtTokenize("hello")) == @[newToken(NwtString, "hello")]
  assert toSeq(nwtTokenize("{{var}}")) == @[newToken(NwtVariable, "var")]
  assert toSeq(nwtTokenize("{{ var }}")) == @[newToken(NwtVariable, "var")]
  assert toSeq(nwtTokenize("{{var}}{{var}}")) == @[newToken(NwtVariable, "var"),newToken(NwtVariable, "var")]
  assert toSeq(nwtTokenize("{#i am a comment#}")) == @[newToken(NwtComment, "i am a comment")]
  assert toSeq(nwtTokenize("{# i am a comment #}")) == @[newToken(NwtComment, "i am a comment")]
  assert toSeq(nwtTokenize("{%raw%}")) == @[newToken(NwtEval, "raw")]
  assert toSeq(nwtTokenize("{% raw %}")) == @[newToken(NwtEval, "raw")]
  assert toSeq(nwtTokenize("{% for each in foo %}")) == @[newToken(NwtEval, "for each in foo")]

  assert toSeq(nwtTokenize("body { background-color: blue; }")) == 
    @[newToken(NwtString, "body { background-color: blue; }")]

  assert toSeq(nwtTokenize("{ nope }")) == @[newToken(NwtString, "{ nope }")]
  assert toSeq(nwtTokenize("{nope}")) == @[newToken(NwtString, "{nope}")]
  assert toSeq(nwtTokenize("{nope")) == @[newToken(NwtString, "{nope")]
  assert toSeq(nwtTokenize("nope}")) == @[newToken(NwtString, "nope}")]

  assert toSeq(nwtTokenize("{")) == @[newToken(NwtString, "{")]
  assert toSeq(nwtTokenize("}")) == @[newToken(NwtString, "}")]

  assert toSeq(nwtTokenize("""{%block 'first'%}{%blockend%}""")) == @[newToken(NwtEval, "block 'first'"), newToken(NwtEval, "blockend")]
  assert toSeq(nwtTokenize("foo {baa}")) == @[newToken(NwtString, "foo {baa}")]

  assert toSeq(nwtTokenize("foo {{baa}} {baa}")) == @[newToken(NwtString, "foo "), 
                                                      newToken(NwtVariable, "baa"),
                                                      newToken(NwtString, " {baa}")]
 
  ## extractTemplateName tests
  assert extractTemplateName("""extends "foobaa.html" """) == "foobaa.html"
  assert extractTemplateName("""extends "foobaa.html"""") == "foobaa.html"
  assert extractTemplateName("""extends 'foobaa.html'""") == "foobaa.html"
  assert extractTemplateName("""extends foobaa.html""") == "foobaa.html"
  assert extractTemplateName("""extends foobaa.html""") == "foobaa.html" 
  assert extractTemplateName(toSeq(nwtTokenize("""{% extends "foobaa.html" %}"""))[0].value) == "foobaa.html" 
  block: 
    var tokens = toSeq(nwtTokenize("""{% extends "foobaa.html" %}{% extends "goo.html" %} """)) 
    assert extractTemplateName(tokens[0].value) == "foobaa.html"
    assert extractTemplateName(tokens[1].value) == "goo.html"
  block: 
    var tokens = toSeq(nwtTokenize("""{% extends "foobaa.html" %}{% extends "goo.html" %}""")) 
    assert extractTemplateName(tokens[0].value) == "foobaa.html"
    assert extractTemplateName(tokens[1].value) == "goo.html"
  block: 
    var tokens = toSeq(nwtTokenize("""{%extends "foobaa.html" %}{% extends 'goo.html' %}""")) 
    assert extractTemplateName(tokens[0].value) == "foobaa.html"
    assert extractTemplateName(tokens[1].value) == "goo.html"


  block:
    let tst = """<html>
        <head>
          <title>engine</title>
        </head>
        <body>
        <style>
          {%block 'foo'%}{}{%endblock%}
          {ugga}}
        </style>
          <h1>Welcome from baseasdfasdf</h1>
          <div id="content">
          </div>
        </body>
      </html>""" 
    # for each in nwtTokenize(tst):
    #   echo each


  block:

    var tst = """{%extends "base.html"%}
    {%block "klausi"%}
    ass : ) 
    {%endblock%}
    {%block "content2"%}
    ass : ) 
    {%endblock%}
    {%block "peter"%}
    ass petr
    {%endblock%}"""


    # for i, each in toSeq(nwtTokenize(tst)):
    #   echo i, ":\t", each.tokenType, "-> " ,each.value.strip()

    # for each in getBlocks(toSeq(nwtTokenize(tst))).values:
    #   echo each


    block:
      var baseTmpl  = toSeq(nwtTokenize("""{%block 'first'%}{%endblock%}"""))
      var childTmpl = toSeq(nwtTokenize("""{%block 'first'%}I AM THE CHILD{%endblock%}"""))
      echo baseTmpl
      for each in getBlocks(baseTmpl).values:
        echo each


      echo childTmpl
      for each in getBlocks(childTmpl).values:
        echo each


      echo baseTmpl.fillBlocks(childTmpl)

  ## fillBlock tests

  # echo extractTemplateName("""extends "foobaa.html" """)
