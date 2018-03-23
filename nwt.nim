#
#
#                  nimWebTemplates
#        (c) Copyright 2017 David Krause
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## :Author: David Krause (enthus1ast)
## 
## 
## a jinja like template syntax parser
## 
## 
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

import strtabs
import strutils
import parseutils
import sequtils
import os
import tables
import commandParser
import nwtTokenizer
import json
import queues
import cgi

########################################################
## For building a stack easily.....
## Check if they exists in stdlib
## 
proc popr[T](s: var seq[T]): T =
  ## removes and returns the rightest/last item
  result = s[^1]
  s.delete(s.len)

proc popl[T](s: var seq[T]): T =
  ## removes and return the leftest/first item
  result = s[0]
  s.delete(0)

proc pushr[T](s: var seq[T], itm: T) =
  ## adds a value to the back/right
  s.add(itm)

proc pushl[T](s: var seq[T], itm: T)=
  ## adds a value to the front/left
  s.insert(itm,0)
########################################################


type
  Nwt* = ref object of RootObj
    # templates*: StringTableRef ## we load all the templates we want to render to this strtab
    templates*: Table[string,seq[Token]] ## we parse templates on start
    templatesDir*: string
    echoEmptyVars*: bool ## set this to true to let nwt print an empty variable like this '{{variable}}' or '{{self.variable}}'

  Block = tuple[name: string, cmd: ChatCommand, posStart: int, posEnd: int]

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
  result.templates = initTable[string,seq[Token]]()
  result.templatesDir = templatesDir
  result.loadTemplates(templatesDir)
  result.echoEmptyVars = false 

proc getBlocks*(tokens: seq[Token], starting="block", ending="endblock" ): Table[string, Block] = # TODO private
  # returns all {%block 'foo'%} statements as a Table of Block
  result = initTable[string, Block]()
  var stack = newSeq[(ChatCommand, int)]()

  var actual: Block = ("",ChatCommand(),0,0)
  for i, each in tokens:
    if each.tokenType == NwtEval and each.value.strip().startswith(starting): # block
      var cmd = newChatCommand(each.value)
      stack.pushl( (cmd, i ))
    elif each.tokenType == NwtEval and each.value.strip().startswith(ending):
      if stack.len == 0:
        raise newException(ValueError, "UNBALANCED BLOCKS too many closeing tags for: " & $each & " " & $tokens )
      var cmd: ChatCommand
      (cmd, actual.posStart) = stack.popl()
      actual.name = cmd.params[0]
      actual.cmd = cmd
      actual.posEnd = i
      result.add(actual.name, actual)
      actual = ("", ChatCommand() ,0,0)
  if stack.len > 0:
    raise newException(ValueError, "UNBALANCED BLOCKS to many opening tags for: " & starting & "\nstack:\n" & $stack )

var blockTable: Table[string, seq[Token]] = initTable[string, seq[Token]]()

proc fillBlocks*(baseTemplateTokens, tokens: seq[Token], params: JsonNode): seq[Token] =  # TODO private
  ## This fills all the base template blocks with
  ## blocks from extending template
  # @[(name: content2, posStart: 2, posEnd: 4), (name: peter, posStart: 6, posEnd: 8)]
  # @[(name: content2, posStart: 3, posEnd: 4), (name: peter, posStart: 6, posEnd: 8)]
  result = baseTemplateTokens
  var templateBlocks = getBlocks(tokens)
  var baseTemplateBlocks = getBlocks(baseTemplateTokens)  

  ## To make {self.templateName} work
  for k,v in templateBlocks:
    blockTable[k] = tokens[v.posStart .. v.posEnd]

  for baseBlock in baseTemplateBlocks.values:

    if templateBlocks.contains(baseBlock.name): 
      var startp = templateBlocks[baseBlock.name].posStart
      var endp = templateBlocks[baseBlock.name].posEnd
      var blockTokens = tokens[startp .. endp]

      blockTable[baseBlock.name] = blockTokens

      ## The main block replacement
      # we only do anything if we have that block in the extending template
      var inspos = baseTemplateBlocks[baseBlock.name].posStart
      result.delete(baseTemplateBlocks[baseBlock.name].posStart, baseTemplateBlocks[baseBlock.name].posEnd)
      result.insert(blockTokens , inspos)

proc evalTemplate(nwt: Nwt, templateName: string, params: JsonNode): seq[Token] =   
  result = @[]
  var baseTemplateTokens = newSeq[Token]()
  var importTemplateTokens = newSeq[Token]()
  var tokens = newSeq[Token]()
  var alreadyExtendet = false

  for idx, each in nwt.templates[templateName]:
    if each.tokenType == NwtEval and each.value.startswith("extends"):
      if alreadyExtendet: 
        continue
      alreadyExtendet = true

      ## ONLY ONE BASE TEMPLATE IS SUPPORTED!! so only ONE {%extends%} __PER FILE__!
      baseTemplateTokens = evalTemplate(nwt, extractTemplateName(each.value), params)
      continue
  
    elif each.tokenType == NwtEval and each.value.startswith("set"):
      let setCmd = newChatCommand(each.value)
      params[setCmd.params[0]] = %* setCmd.params[1] 
      # echo "params[$1] = $2" % [setCmd.params[0], setCmd.params[1]]
    
    elif each.tokenType == NwtEval and each.value.startswith("if"):
      discard

    elif each.tokenType == NwtEval and each.value.startswith("import"):
      let cmd = newChatCommand(each.value)
      let importTemplateName = cmd.params[0]
      if importTemplateName == templateName:
        raise newException(ValueError, "template $1 could not import itself" % templateName)
      # echo "@@@@---> importing template: ", importTemplateName
      for t in nwt.evalTemplate(importTemplateName, params):
        importTemplateTokens.add t
      continue
    else: # starwith checks passed
      tokens.add each

  if importTemplateTokens.len > 0:
    # echo "resolving import tokens:"
    # echo tokens
    # echo "####################################################"
    # echo importTemplateTokens
    tokens = tokens.fillBlocks(importTemplateTokens, params)
    # echo "====================================================="
    # echo tokens
    # quit()

  if baseTemplateTokens.len == 0:
    return tokens
  else:
    return baseTemplateTokens.fillBlocks(tokens, params)


template decorateVariable(a: untyped): untyped =
  "{{" & a & "}}"

proc toStr*(nwt: Nwt, token: Token, params: JsonNode): string = 
  # echo token , " " ,params
  ## transforms the token to its string representation 
  # TODO should this be `$`?

  # template emptyValue():
  var bufval = ""

  case token.tokenType
  of NwtString:
    return token.value
  of NwtComment:
    return ""
  of NwtVariable:
    # echo "token: ", token
        # TODO dirty hack ? 
    if token.value == "debug":
      let dbg = """
      <pre>
          PARAMS:
          $1

          BLOCKTABLE:
          $2
      </pre>
      """ % @[ 
          params.pretty(), 
          ($blockTable)
          ]
      echo dbg
      return "<pre>" & dbg.xmlEncode & "</pre>"

    if token.value.startswith("self."):
      # echo "NODE STARTS WITH self. :: ", token.value
      var cmd = newChatCommand(token.value,false, @['.'])
      let templateName = cmd.params[1]
      bufval.setLen(0)
      if blockTable.hasKey(templateName): 
        for token in blockTable[templateName]:
          bufval.add nwt.toStr(token, params)
      elif nwt.echoEmptyVars:
        bufval = decorateVariable(token.value)
      else:
        bufval = ""
      return bufval

    var node = params.getOrDefault(token.value)

    if not node.isNil:
      case node.kind
      of JString:
        bufval = node.getStr()
      of JInt:  
        bufval = $(node.getNum())
      of JFloat:
        bufval = $(node.getFNum())
      else:
        bufval = ""

    if (bufval == "") and (nwt.echoEmptyVars == true):
      return token.value.decorateVariable ## return the token when it could not be replaced
    else:
      return bufval
  else:
    return ""


proc evalScripts(nwt: Nwt, tokens: seq[Token] , params: JsonNode = newJObject()): seq[Token] =  
  ## This evaluates the template logic.
  ## After this the template is fully epanded an is ready to convert it to strings
  ## TODO we should avoid looping multiple times....
  var forBlocks = getBlocks(tokens, starting = "for", ending = "endfor")
  ### [foo, in, baa]
  # echo "@@@______----: "
  # for
  # for token in tokens:

  # for forBlock in forBlocks.values: 
  #   echo forBlock ## (name: item, cmd: for --> @[item, in, items], posStart: 0, posEnd: 4)
    
    
    # tokens.insert()

  #     for idx, each in params[forBlock.cmd.params[2]]:
  #       echo forBlock.cmd.params[0], "->", each # , "-> ", each , "[" , idx , "]"

  return tokens

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
  blockTable.clear() ## ever new render ach scheiesse...
  if not nwt.templates.hasKey(templateName):
    raise newException(ValueError, "Template '$1' not found." % [templateName]) # UnknownTemplate
  tokens = nwt.evalTemplate(templateName, params)
  tokens = nwt.evalScripts(tokens, params) # expands `for` `if` etc
  for token in tokens:
    result.add nwt.toStr(token, params)

proc freeze*(nwt: Nwt, params: JsonNode = newJObject(), outputPath: string = "./freezed/", staticPath = "./public/") =
  ## generates the html for each template.
  ## writes to the output path
  if not dirExists(outputPath): createDir(outputPath)
  if staticPath.len != 0 and dirExists(staticPath):
    copyDir( staticPath.strip(false, true,  {'/'}) , outputPath)
  for name, tmpl in nwt.templates:
    let freezedFilePath = outputPath / name 
    echo "Freezing: ", name, " to: ", freezedFilePath
    var fh = open( freezedFilePath, fmWrite )
    fh.write(nwt.renderTemplate(name, params))
    fh.close()

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

    block:
      var t = newNwt(nil)
      assert t.templates == initTable[system.string, seq[Token]]()

      t.addTemplate("foo.html","i am the {{faa}} template")
      # echo t.renderTemplate("foo.html",%*{"faa": "super"})
      assert t.renderTemplate("foo.html", %*{"faa": "super"}) == "i am the super template"

      t.templates.add("base.html","{%block 'bar'%}{%endblock%}")
      t.templates.add("extends.html","{%extends base.html%}{%block 'bar'%}Nim likes you{%endblock%}")
      assert t.renderTemplate("extends.html") == "Nim likes you"
