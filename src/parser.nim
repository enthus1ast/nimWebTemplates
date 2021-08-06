import strformat, strutils
import macros
import nwtTokenizer, sequtils, parseutils

type
  NwtNodeKind = enum
    NStr, NComment, NIf, NElif, NElse, NWhile, NFor, NVariable, NEval, NImport
  NwtNode = object
    case kind: NwtNodeKind
    of NStr:
      strBody: string
    of NComment:
      commentBody: string
    of NIf:
      ifStmt: string
      nnThen: seq[NwtNode] # <---- Alle Nodes
      nnElif: seq[NwtNode] # <---  Elif nodes
      nnElse: seq[NwtNode] # <---- Alle Nodes
    of NElif:
      elifStmt: string
      elifBody: seq[NwtNode]
    of NWhile:
      whileStmt: string
      whileBody: seq[NwtNode]
    of NFor:
      forStmt: string
      forBody: seq[NwtNode]
    of NVariable:
      variableBody: string
    of NEval:
      evalBody: string
    of NImport:
      importBody: string
    # of NElse:
    #   elseBody: seq[NwtNode]
    else: discard

type IfState {.pure.} = enum
  InThen, InElif, InElse

# First step nodes
type
  FsNodeKind = enum
    FsIf, FsStr, FsEval, FsElse, FsElif, FsEndif, FsFor, FsEndfor, FsVariable, FsWhile, FsEndWhile, FsImport
  FSNode = object
    kind: FsNodeKind
    value: string

# Forward decleration
proc parseSecondStep*(fsTokens: seq[FSNode], pos: var int): seq[NwtNode]
proc parseSecondStepOne(fsTokens: seq[FSNode], pos: var int): NwtNode
proc astAstOne(token: NwtNode): NimNode
proc astAst(tokens: seq[NwtNode]): seq[NimNode]

func splitStmt(str: string): tuple[pref: string, suf: string] {.inline.} =
  ## the prefix is normalized (transformed to lowercase)
  var pref = ""
  var pos = parseIdent(str, pref, 0)
  pos += str.skipWhitespace(pos)
  result.pref = toLowerAscii(pref)
  result.suf = str[pos..^1]

proc parseFirstStep*(tokens: seq[Token]): seq[FSNode] =
  result = @[]
  for token in tokens:
    if token.tokenType == NwtEval:
      let (pref, suf) = splitStmt(token.value)
      case pref
      of "if":
        result.add FSNode(kind: FsIf, value: suf)
      of "elif":
        result.add FSNode(kind: FsElif, value: suf)
      of "else":
        result.add FSNode(kind: FsElse, value: suf)
      of "endif":
        result.add FSNode(kind: FsEndif, value: suf)
      of "for":
        result.add FSNode(kind: FsFor, value: suf)
      of "endfor":
        result.add FSNode(kind: FsEndfor, value: suf)
      of "while":
        result.add FSNode(kind: FsWhile, value: suf)
      of "endwhile":
        result.add FSNode(kind: FsEndWhile, value: suf)
      of "importnwt":
        result.add FSNode(kind: FsImport, value: suf)
      else:
        result.add FSNode(kind: FsEval, value: token.value)
    elif token.tokenType == NwtString:
      result.add FSNode(kind: FsStr, value: token.value)
    elif token.tokenType == NwtVariable:
      result.add FSNode(kind: FsVariable, value: token.value)
    else:
      echo "Not catched:", token
    # elif token.tokenType == NwtComment:
    #   result.add FSNode(kind: FsComment, value: token.value)

# template addCorrectNode(container: seq[NwtNode], elem: FsNode) =
#   case elem.kind
#   of FsStr:
#     container.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
#   of FsVariable:
#     container.add NwtNode(kind: NVariable, variableBody: elem.value) # TODO choose right NwtNodeKind
#   else:
#     echo fmt"{elem.kind} not supported yet"

# proc parseSsElif(fsTokens: seq[FsNode], pos: var int): NwtNode =


proc parseSsIf(fsTokens: seq[FsNode], pos: var int): NwtNode =
  var elem: FsNode = fsTokens[pos] # first is the if that we got called about
  result = NwtNode(kind: NwtNodeKind.NIf)
  result.ifStmt = elem.value
  pos.inc # skip the if
  var ifstate = IfState.InThen
  while pos < fsTokens.len:
    elem = fsTokens[pos]
    if elem.kind == FsIf:
      # echo "open new if"
      # TODO open a new if; where to put the parsed node from the recursive if parser??
      #### TODO pack this into func/template
      if ifState == IfState.InThen:
        result.nnThen.add parseSecondStep(fsTokens, pos) ## TODO should be parseSecondStep
      if ifState == IfState.InElse:
        result.nnElse.add parseSecondStep(fsTokens, pos) ## TODO should be parseSecondStep
      if ifState == IfState.InElif:
        result.nnElif[^1].elifBody.add parseSecondStep(fsTokens, pos) ## TODO should be parseSecondStep
    elif elem.kind == FsElif:
      ifstate = IfState.InElif
      result.nnElif.add NwtNode(kind: NElif, elifStmt: elem.value)
    elif elem.kind == FsElse:
      ifstate = IfState.InElse
    elif elem.kind == FsEndif:
      break
    else:
      if ifState == IfState.InThen:
        result.nnThen &= parseSecondStepOne(fsTokens, pos) #addCorrectNode(elem)
      if ifState == IfState.InElse:
        result.nnElse &= parseSecondStepOne(fsTokens, pos)
      if ifState == IfState.InElif:
        result.nnElif[^1].elifBody &= parseSecondStepOne(fsTokens, pos)
    pos.inc


proc parseSsWhile(fsTokens: seq[FsNode], pos: var int): NwtNode =
  var elem: FsNode = fsTokens[pos] # first is the while that we got called about
  result = NwtNode(kind: NwtNodeKind.NWhile)
  result.whileStmt = elem.value
  while pos < fsTokens.len:
    pos.inc # skip the while
    echo fsTokens[pos .. ^1]
    elem = fsTokens[pos]
    if elem.kind == FsEndWhile:
      break
    else:
      result.whileBody &= parseSecondStepOne(fsTokens, pos)

proc parseSsFor(fsTokens: seq[FsNode], pos: var int): NwtNode =
  var elem: FsNode = fsTokens[pos] # first is the while that we got called about
  result = NwtNode(kind: NwtNodeKind.NFor)
  result.forStmt = elem.value
  while pos < fsTokens.len:
    pos.inc # skip the while
    echo fsTokens[pos .. ^1]
    elem = fsTokens[pos]
    if elem.kind == FsEndFor:
      break
    else:
      result.forBody &= parseSecondStepOne(fsTokens, pos)

proc parseSecondStepOne(fsTokens: seq[FSNode], pos: var int): NwtNode =
    let fsToken = fsTokens[pos]

    # Complex Types
    if fsToken.kind == FSif:
      return parseSsIf(fsTokens, pos)
    elif fsToken.kind == FsWhile:
      return parseSsWhile(fsTokens, pos)
    elif fsToken.kind == FsFor:
      return parseSsFor(fsTokens, pos)
    # Simple Types
    elif fsToken.kind == FsStr:
      return NwtNode(kind: NStr, strBody: fsToken.value)
    elif fsToken.kind == FsVariable:
      return NwtNode(kind: NVariable, variableBody: fsToken.value) # TODO choose right NwtNodeKind
    elif fsToken.kind == FsEval:
      return NwtNode(kind: NEval, evalBody: fsToken.value) # TODO choose right NwtNodeKind
    else:
      echo "NOT IMPL: ", fsToken


proc includeNwt(nodes: var seq[NwtNode], path: string) {.compileTime.} =
    var str = staticRead(path.strip(true, true, {'"'}) )
    var lexerTokens = toSeq(nwtTokenize(str))
    var firstStepTokens = parseFirstStep(lexerTokens)
    var pos = 0
    var secondsStepTokens = parseSecondStep(firstStepTokens, pos)
    for secondStepToken in secondsStepTokens:
      nodes.add secondStepToken

proc parseSecondStep*(fsTokens: seq[FSNode], pos: var int): seq[NwtNode] =
  while pos < fsTokens.len:
    ## TODO TEST IF THIS IS GOOD HERE
    ## this is include
    let token = fsTokens[pos]
    if token.kind == FsImport:
      result.includeNwt(token.value)
    else:
      result &= parseSecondStepOne(fsTokens, pos)
    pos.inc # skip the current elem (test if the inner procs should forward)



func astVariable(token: NwtNode): NimNode =
  return nnkStmtList.newTree(
    nnkInfix.newTree(
      newIdentNode("&="),
      newIdentNode("result"),
      newCall(
        "$",
        parseStmt(token.variableBody)
      )
    )
  )

func astStr(token: NwtNode): NimNode =
  return nnkStmtList.newTree(
    nnkInfix.newTree(
      newIdentNode("&="),
      newIdentNode("result"),
      newStrLitNode(token.strBody)
    )
  )

func astEval(token: NwtNode): NimNode =
  return parseStmt(token.evalBody)

func astComment(token: NwtNode): NimNode =
  return newCommentStmtNode(token.commentBody)

proc astFor(token: NwtNode): NimNode =
  let easyFor = "for " & token.forStmt & ": discard" # `discard` to make a parsable construct
  result = parseStmt(easyFor)
  result[0][2] = newStmtList(astAst(token.forBody)) # overwrite discard with real for body

proc astWhile(token: NwtNode): NimNode =
  nnkStmtList.newTree(
    nnkWhileStmt.newTree(
      parseStmt(token.whileStmt),
      nnkStmtList.newTree(
        astAst(token.whileBody)
      )
    )
  )


proc astIf(token: NwtNode): NimNode =
  result = nnkIfStmt.newTree()

  # Add the then node
  result.add:
    nnkElifBranch.newTree(
      parseStmt(token.ifStmt),
      nnkStmtList.newTree(
        astAst(token.nnThen)
      )
    )

  ## Add the elif nodes
  for elifToken in token.nnElif:
    result.add:
      nnkElifBranch.newTree(
        parseStmt(elifToken.elifStmt),
        nnkStmtList.newTree(
          astAst(elifToken.elifBody)
        )
      )

  # Add the else node
  if token.nnElse.len > 0:
    result.add:
      nnkElse.newTree(
        nnkStmtList.newTree(
          astAst(token.nnElse)
        )
      )


proc astAstOne(token: NwtNode): NimNode =
  if token.kind == NVariable:
    return astVariable(token)
  elif token.kind == NStr:
    return astStr(token)
  elif token.kind == NEval:
    return astEval(token)
  elif token.kind == NComment:
    return astComment(token)
  elif token.kind == NIf:
    return astIf(token)
  elif token.kind == NFor:
    return astFor(token)
  elif token.kind == NWhile:
    return astWhile(token)
  # elif token.kind == NImport:
  #   return

proc astAst(tokens: seq[NwtNode]): seq[NimNode] =
  for token in tokens:
    result.add astAstOne(token)

macro compileTemplateStr*(str: typed): untyped =
  var lexerTokens = toSeq(nwtTokenize(str.strVal))
  var firstStepTokens = parseFirstStep(lexerTokens)
  var pos = 0
  var secondsStepTokens = parseSecondStep(firstStepTokens, pos)
  result = newStmtList()
  for token in secondsStepTokens:
    result.add astAstOne(token)

macro compileTemplateFile*(path: static string): untyped =
  let str = staticRead(path)
  # let pathn = newNimNode(nnkStrLit)
  # pathn.strVal = str
  # compileTemplateStr(str)
  ## TODO Why can't i call the other template?
  var lexerTokens = toSeq(nwtTokenize(str))
  var firstStepTokens = parseFirstStep(lexerTokens)
  var pos = 0
  var secondsStepTokens = parseSecondStep(firstStepTokens, pos)
  result = newStmtList()
  for token in secondsStepTokens:
    result.add astAstOne(token)

# when isMainModule:
#   expandMacros:
#     var result = ""
#     compileTemplateStr("{{foo}}baa{% idx.inc() %}{# a comment #}{%if foo() == baa()%}baa{{BAA}}{%elif true == true%}elif branch{%elif false == false%}elif branch2{%else%}ELSEBRANCH{%endif%}    {%for idx in 0..10%}{%if true%}{{TRAA}}{%endif%}{%endfor%}   {% var loop = 0%}{%while loop < 10%} {% loop.inc %} {%endwhile%} ")




when isMainModule:
  discard

  # block:
  #   proc testMe(a = 1, ONE = "ONE", TWO = "TWO", THREE = "THREE", ELSE = "ELSE", sex = "male"): string =
  #     compileTemplateStr3 """{% if a == 1 %}a{% if sex == "male"%}HE{%else%}SHE{%endif%}is one{{ONE}}{% elif a == 2 %}a is two{{TWO}}{% elif a == 3 %}a is three{{THREE}}{% else %}a is something else{{ELSE}}{%endif%}"""
  #   assert "aHEis one-->ONE<--" == testMe(a = 1, sex = "male", ONE = "-->ONE<--")
  #   assert "aSHEis one-->ONE<--" == testMe(a = 1, sex = "female", ONE = "-->ONE<--")
  #   assert "a is twoTWO" == testMe(a = 2)
  #   assert "a is threeTHREE" == testMe(a = 3)

  block:
    discard
    # echo onlyFirstAndSecond("""{{foo}}{% while idx < 10 %}idx is: {{idx}}{%idx.inc%}{% endwhile %}baa{{zaa}}""")
    # echo onlyFirstAndSecond("""{{foo}}{% while idx < 10 %}idx is: {{idx}}{%idx.inc%}{% endwhile %}baa{{zaa}}""")
    # echo onlyFirstAndSecond("""{% while isAA() %}AA{%while isBB()%}BB{%while isCC()%}CC{%endwhile%}{%endwhile%}{% endwhile %}baa{{zaa}}""")
    # echo onlyFirstAndSecond("""{%if elems.len > 0%}{% while isFoo() %}FOO{% endwhile %}{%endif%}""")

    # echo onlyFirstAndSecond("""{% for idx in 0..10 %}{{idx}}<br>{%endfor%}""")

    # ## Wrong render but ast looks good...
    # echo onlyFirstAndSecond("""{%if elems.len > 0%}{% while isFoo() %}FOO{%if true%}true{%endif%}{% endwhile %}{%endif%}baa""")
    # echo onlyFirstAndSecond("""
    #   {%if elems.len > 0%}
    #     {% while isFoo() %}
    #       FOO
    #       {%if true%}
    #         true
    #       {%endif%}
    #     {% endwhile %}
    #   {%endif%}
    #   baa""")



    # proc testMe(): string =
    #   compileTemplateStr3 """{% while idx < 10 %}idx is: {{idx}}{%idx.inc%}{%endwhile%}"""
    # echo testMe()

    # # Rendered wrong, ast seems ok
    # proc testMe(): string =
    #   compileTemplateStr3 """{%while true%}{% for idx in 0..10 %}{{idx}}<br>{%endfor%}{%endwhile%}"""
    # echo testMe()

    # echo prettyNwt("""{% var foo: string = ":D" %}{% for idx in 0..10 %}{% foo &= $idx %}foo={{foo}}<br>{%endfor%}""")


    # type TestObj = object
    #   foo: string
    #   baa: int
    # proc testObj(tobj: TestObj): string =
    #   compileTemplateStr3 """{% for idx in 0 .. tobj.baa  %}{{idx}}{{tobj.foo}}{%endfor%}"""
    # echo testObj(TestObj(foo:"_FOO", baa: 20))

    # proc testMe2(): string =
    #   compileTemplateStr3 """{% var foo: string = ":D" %}{% for idx in 0..10 %}{% foo &= $idx %}foo={{foo}}<br>{%endfor%}"""
    # echo testMe2()
