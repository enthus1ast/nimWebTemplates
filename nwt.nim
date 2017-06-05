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
import commandParser
import nwtTokenizer
import json

type
  Nwt = ref object of RootObj
    # templates*: StringTableRef ## we load all the templates we want to render to this strtab
    templates*: Table[string,seq[Token]] ## we parse templates on start
    templatesDir*: string

  Block = tuple[name: string, posStart: int, posEnd: int]

proc add*(tokens: var Table[string,seq[Token]], templateName, templateStr: string) =
  ## parses and adds/updates a template
  tokens[templateName] = toSeq(nwtTokenize templateStr)

proc addTemplate*(nwt: Nwt, templateName , templateStr: string) = 
  ## parses and adds/updates a template, given by a string
  nwt.templates[templateName] = toSeq(nwtTokenize templateStr)

proc loadTemplates(nwt: Nwt, templatesDir: string) =
  ## loads and parses the templates from the filesystem.
  ## basic wildcards supported:
  ##    /foo/baa/*.html
  ## call this for refreshing the templates 
  if not templatesDir.isNil:
    for filename in walkFiles(templatesDir):
      var templateName = extractFilename(filename)
      # echo "Load: $1 as $2", % [filename, templateName]
      nwt.templates[templateName] = toSeq(nwtTokenize readFile(filename))

proc newNwt*(templatesDir: string = "./templates/*.html"): Nwt =
  ## this loads all templates from the template into memory
  ## if templatesDir == nil we do not load any templates
  ##  we can add them later by `addTemplate("{%foo%}{%baa%}")`
  result = Nwt()
  # result.templates = newStringTable()
  result.templates = initTable[string,seq[Token]]()
  result.templatesDir = templatesDir
  result.loadTemplates(templatesDir)

proc getBlocks*(tokens: seq[Token]): Table[string, Block] = # TODO private
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

proc fillBlocks*(baseTemplateTokens, tokens: seq[Token]): seq[Token] =  # TODO private
  ## This fills all the base template blocks with
  ## blocks from extending template
  # @[(name: content2, posStart: 2, posEnd: 4), (name: peter, posStart: 6, posEnd: 8)]
  # @[(name: content2, posStart: 3, posEnd: 4), (name: peter, posStart: 6, posEnd: 8)]
  result = baseTemplateTokens
  var templateBlocks = getBlocks(tokens)
  var baseTemplateBlocks = getBlocks(baseTemplateTokens)  

  for baseBlock in baseTemplateBlocks.values:
    if templateBlocks.contains(baseBlock.name): 
      # we only do anything if we have that block in the extending template
      result.delete(baseTemplateBlocks[baseBlock.name].posStart, baseTemplateBlocks[baseBlock.name].posEnd)
      var startp = templateBlocks[baseBlock.name].posStart
      var endp = templateBlocks[baseBlock.name].posEnd
      var inspos = baseTemplateBlocks[baseBlock.name].posStart
      result.insert(tokens[startp .. endp] , inspos)


proc evalTemplate(nwt: Nwt, templateName: string, params: StringTableRef = newStringTable()): seq[Token] = 
  # discard
  result = @[]
  var tokens = newSeq[Token]()
  for each in nwt.templates[templateName]:
    if each.tokenType == NwtEval and each.value.startswith("extends"):
      # echo "template has an extends"
      # baseTemplateTokens = nwt.templates[extractTemplateName(each.value)]

      ## ONLY ONE BASE TEMPLATE IS SUPPORTED!! so only ONE {%extends%} __PER FILE__!
      result = evalTemplate(nwt, extractTemplateName(each.value), params)
      # result.add evalTemplate(nwt, extractTemplateName(each.value), params)

    elif each.tokenType == NwtEval and each.value.startswith("set"):
      let setCmd = newChatCommand(each.value)
      params[setCmd.params[0]] = setCmd.params[1] 
      echo "params[$1] = $2" % [setCmd.params[0], setCmd.params[1]]
    # elif each.tokenType == NwtEval and each.value.startswith("if"):
    #   let checkVar = extractTemplateName(each.value)      
    tokens.add each

  # for each in tokens:
  #   result.fillBlocks()


proc toStr*(token: Token, params: JsonNode = newJObject()): string = 
  ## transforms the token to its string representation 
  # TODO should this be `$`?
  case token.tokenType
  of NwtString:
    return token.value
  of NwtComment:
    return ""
  of NwtVariable:
    echo "token: ", token
    var bufval = params.getOrDefault(token.value).getStr()
    if bufval == "":
      return "{{" & token.value & "}}" ## return the token when it could not be replaced
    else:
      return bufval
  else:
    return ""

# proc renderTemplate*(nwt: Nwt, templateName: string, params: StringTableRef = newStringTable()): string =
proc renderTemplate*(nwt: Nwt, templateName: string, params: JsonNode = newJObject()): string =  
  ## this returns the fully rendered template.
  ## all replacements are done.
  ## if the loaded template extends a base template, we parse this as well and fill all the blocks.
  ## ATM this is not recursively checking for extends on child templates! 
  ## So only one 'extends' level is supported.
  ## 
  
  when not defined release:
    echo "WARNING THIS IS AN DEBUG BUILD. NWT PARSES THE HTML ON EVERY GET; THIS IS SLOW"
    nwt.loadTemplates(nwt.templatesDir)

  result = ""
  var tokens: seq[Token] = @[]
  var baseTemplateTokens: seq[Token] = @[]

  if not nwt.templates.hasKey(templateName):
    raise newException(ValueError, "Template '$1' not found." % [templateName]) # UnknownTemplate


  # tokens = evalTemplate(nwt, templateName, params)
  for each in nwt.templates[templateName]:
    if each.tokenType == NwtEval and each.value.startswith("extends"):
      # echo "template has an extends"
      baseTemplateTokens = nwt.templates[extractTemplateName(each.value)]
    elif each.tokenType == NwtEval and each.value.startswith("set"):
      let setCmd = newChatCommand(each.value)
      params[setCmd.params[0]] = % setCmd.params[1] 
      echo "params[$1] = $2" % [setCmd.params[0], setCmd.params[1]]
    # elif each.tokenType == NwtEval and each.value.startswith("if"):
    #   let checkVar = extractTemplateName(each.value)      
    tokens.add each

  if baseTemplateTokens.len > 0:
    for token in baseTemplateTokens.fillBlocks(tokens):
      result.add token.toStr(params)
  else:
    for token in tokens:
      result.add token.toStr(params)

  # for token in tokens.fillBlocks(tokens):
  #   result.add token.toStr(params)

when isMainModule:
  # var nwt = newNwt()
  # echo "Loaded $1 templates." % [$nwt.templates.len]



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


    # addTemplate tests
    block:
      var t = newNwt(nil)
      assert t.templates == initTable[system.string, seq[Token]]()

      t.addTemplate("foo.html","i am the {{faa}} template")
      echo t.renderTemplate("foo.html",%*{"faa": "super"})
      assert t.renderTemplate("foo.html", %*{"faa": "super"}) == "i am the super template"

      t.templates.add("base.html","{%block 'bar'%}{%endblock%}")
      t.templates.add("extends.html","{%extends base.html%}{%block 'bar'%}Nim likes you{%endblock%}")
      assert t.renderTemplate("extends.html") == "Nim likes you"


    # test block in block
    block:
      discard # TODO
      # t.templates.add("base.html","{%block 'bar'%}{%endblock%}")
      # t.templates.add("extends.html","{%extends base.html%}{%block 'bar'%}Nim likes you{%endblock%}")
      # assert t.renderTemplate("extends.html") == "Nim likes you"      
      # addTemplate


    block:
      var t = newNwt("./templates/ji.html")
      for each in t.templates["ji.html"]:
        echo each
      # for each in nwtTokenize(t.templates["ji.html"]):
