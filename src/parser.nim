import strformat, strutils
import macros
import nwtTokenizer, sequtils, parseutils

type
  NwtNodeKind = enum
    NStr, NComment, NIf, NElif, NElse, NWhile, NVariable, NEval
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
    of NVariable:
      variableBody: string
    of NEval:
      evalBody: string
    # of NElse:
    #   elseBody: seq[NwtNode]
    else: discard

type IfState {.pure.} = enum
  InThen, InElif, InElse

## First step nodes
type
  FsNodeKind = enum
    FsIf, FsStr, FsEval, FsElse, FsElif, FsEndif, FsFor, FsEndfor, FsVariable, FsWhile, FsEndWhile
  FSNode = object
    kind: FsNodeKind
    value: string

const SPACE = "  "


# proc nn(kind: NwtNodeKind, body: seq[NwtNode]): NwtNode =
#   return NwtNode(kind: kind, body: body)

const vif = NwtNode(kind: NIf,
  ifStmt: "a == 1",
  nnThen: @[
    NwtNode(kind: NStr, strBody: "a is one"),
    NwtNode(kind: NComment, commentBody: "some info"),
    NwtNode(kind: NStr, strBody: "and more stuff"),
    NwtNode(kind: NVariable, variableBody: "SPACE"),
    NwtNode(kind: NEval, evalBody: "idx.inc(foo + baa)")
  ],
  nnElif: @[
    NwtNode(kind: NElif, elifStmt: "a == 2", elifBody: @[
      NwtNode(kind: NStr, strBody: "a\nis\ntwo")
    ]),
    NwtNode(kind: NElif, elifStmt: "a == 3", elifBody: @[
      NwtNode(kind: NStr, strBody: "a is three")
    ]),
  ],
  nnElse: @[NwtNode(kind: NStr, strBody: "a is something else")]
)

proc render(node: NwtNode, ident: int): string
proc render(nodes: seq[NwtNode], ident: int): string
proc parseSecondStep(fsTokens: seq[FSNode], pos: var int): seq[NwtNode]

func renderComment(node: NwtNode, ident: int): string =
  SPACE.repeat(ident) & "#" & node.commentBody & "\n"

func renderStr(node: NwtNode, ident: int): string =
  SPACE.repeat(ident) & "result &= \"\"\"" & node.strBody & "\"\"\"" & "\n"

func renderVariable(node: NwtNode, ident: int): string =
  SPACE.repeat(ident) & "result &= $(" & node.variableBody & ")" & "\n"

func renderEval(node: NwtNode, ident: int): string =
  SPACE.repeat(ident) & node.evalBody & "\n"

proc renderIf(node: NwtNode, ident: int): string =
  result &= SPACE.repeat(ident) & fmt"if {node.ifStmt}:" & "\n"
  result &= SPACE.repeat(ident) & render(node.nnThen, ident + 1)

  for nodeElif in node.nnElif:
    result &= fmt"elif {nodeElif.elifStmt}:" & "\n"
    result &= render(nodeElif.elifBody, ident + 1)

  result &= SPACE.repeat(ident) & fmt"else:" & "\n"
  for nodeElse in node.nnElse:
    result &= SPACE.repeat(ident) & render(nodeElse, ident + 1)

proc renderWhile(node: NwtNode, ident: int): string =
  result &= SPACE.repeat(ident) & fmt"while ({node.whileStmt}):" & "\n"
  result &= SPACE.repeat(ident) & render(node.whileBody, ident + 1)

proc render(nodes: seq[NwtNode], ident: int): string =
  for node in nodes:
    result &= render(node, ident)

proc render(node: NwtNode, ident: int): string =
  result = ""
  case node.kind
  of NComment:
    result &= renderComment(node, ident)
  of NStr:
    result &= renderStr(node, ident)
  of NIf:
    result &= renderIf(node, ident)
  of NWhile:
    result &= renderWhile(node, ident)
  of NVariable:
    result &= renderVariable(node, ident)
  of NEval:
    # Eval could also be NVariable?
    result &= renderEval(node, ident)
  else:
    discard

# echo render(vif, 0)

# var tokens = toSeq(nwtTokenize("""{% if a == 1 %}{# a comment #}a{% if sex == "male"%}HE{%else%}SHE{%endif%}is one{{ONE}}{% elif a == 2 %}a is two{{TWO}}{% elif a == 3 %}a is three{{THREE}}{% else %}a is something else{{ELSE}}{%endif%}"""))
# echo tokens

func splitStmt(str: string): tuple[pref: string, suf: string] =
  var pos = parseIdent(str, result.pref, 0)
  pos += str.skipWhitespace(pos)
  result.suf = str[pos..^1]


proc parseFirstStep(tokens: seq[Token]): seq[FSNode] =
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

# var fsNode = parseFirstStep(tokens)
# echo "\n\n"
# echo fsNode


template addCorrectNode(container: seq[NwtNode], elem: FsNode) =
  case elem.kind
  of FsStr:
    container.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
  of FsVariable:
    container.add NwtNode(kind: NVariable, variableBody: elem.value) # TODO choose right NwtNodeKind
  else:
    echo fmt"{elem.kind} not supported yet"

# proc parseSsElif(fsTokens: seq[FsNode], pos: var int): NwtNode =


proc parseSsIf(fsTokens: seq[FsNode], pos: var int): NwtNode =
  # echo "parseSSif"
  var elem: FsNode = fsTokens[pos] # first is the if that we got called about
  # assert elem.kind == FsIf
  result = NwtNode(kind: NwtNodeKind.NIf)
  result.ifStmt = elem.value
  pos.inc # skip the if
  var ifstate = IfState.InThen
  while pos < fsTokens.len:
    elem = fsTokens[pos]
    # echo fmt"parseSsIf: {pos} {elem}"

    if elem.kind == FsIf:
      # echo "open new if"
      # TODO open a new if; where to put the parsed node from the recursive if parser??
      #### TODO pack this into func/template
      if ifState == IfState.InThen:
        # result.nnThen.add parseSecondStep(fsTokens, pos) ## TODO should be parseSecondStep
        result.nnThen.add parseSsIf(fsTokens, pos) ## TODO should be parseSecondStep
      if ifState == IfState.InElse:
        # result.nnElse.add parseSecondStep(fsTokens, pos) ## TODO should be parseSecondStep
        result.nnElse.add parseSsIf(fsTokens, pos) ## TODO should be parseSecondStep
      if ifState == IfState.InElif:
        # result.nnElif[^1].elifBody.add parseSecondStep(fsTokens, pos) ## TODO should be parseSecondStep
        result.nnElif[^1].elifBody.add parseSsIf(fsTokens, pos) ## TODO should be parseSecondStep
      ####

    elif elem.kind == FsElif:
      # echo "put to elif"
      ifstate = IfState.InElif
      result.nnElif.add NwtNode(kind: NElif, elifStmt: elem.value)
    elif elem.kind == FsElse:
      # echo "put to else"
      ifstate = IfState.InElse
    elif elem.kind == FsEndif:
      # pos.inc
      break
    else:
      if ifState == IfState.InThen:
        result.nnThen.addCorrectNode(elem)
      if ifState == IfState.InElse:
        result.nnElse.addCorrectNode(elem)
      if ifState == IfState.InElif:
        result.nnElif[^1].elifBody.addCorrectNode(elem)
        # var elifnode = NwtNode(kind: NElif)
        # result.nnElif.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
    pos.inc


proc parseSecondStepOne(fsTokens: seq[FSNode], pos: var int): NwtNode


proc parseSsWhile(fsTokens: seq[FsNode], pos: var int): NwtNode =
  # echo "parseSSif"
  var elem: FsNode = fsTokens[pos] # first is the while that we got called about
  result = NwtNode(kind: NwtNodeKind.NWhile)
  result.whileStmt = elem.value
  while pos < fsTokens.len:
    echo "jjjjjjjjjjjjjjjjjjj ", pos
    pos.inc # skip the while
    echo fsTokens[pos .. ^1]
    elem = fsTokens[pos]
    echo elem
    if elem.kind == FsWhile:
      echo "OPEN ANOTHER WHILE #############################################################"
      # result.whileBody &= parseSsWhile(fsTokens, pos) # new while (could be parseSecondStep as well)
    elif elem.kind == FsEndWhile:
      # pos.inc
      echo "BR: ", fsTokens[pos .. ^1]
      break
    else:
      # pos.inc
      discard
      result.whileBody &= parseSecondStepOne(fsTokens, pos)
    # pos.inc


proc parseSecondStepOne(fsTokens: seq[FSNode], pos: var int): NwtNode =
    let fsToken = fsTokens[pos]
    if fsToken.kind == FSif:  #or fsToken.kind == FSElif:
      return parseSsIf(fsTokens, pos)
    elif fsToken.kind == FsWhile:
      return parseSsWhile(fsTokens, pos)
    elif fsToken.kind == FsStr:
      return NwtNode(kind: NStr, strBody: fsToken.value)
    elif fsToken.kind == FsVariable:
      return NwtNode(kind: NVariable, variableBody: fsToken.value) # TODO choose right NwtNodeKind
    elif fsToken.kind == FsEval:
      return NwtNode(kind: NEval, evalBody: fsToken.value) # TODO choose right NwtNodeKind
    else:
      echo "NOT IMPL: ", fsToken

proc parseSecondStep(fsTokens: seq[FSNode], pos: var int): seq[NwtNode] =
  # var pos = 0
  while pos < fsTokens.len:
    # var fsToken = fsTokens[pos]
    result &= parseSecondStepOne(fsTokens, pos)
      # var node = NwtNode(kind: NIf, ifStmt: fsToken.value)
      # result.add node
    # elif fsToken.kind == FsStr:
      # Append if last was 'if'
    pos.inc # skip the current elem (test if the inner procs should forward)


macro compileTemplateStr3*(str: untyped): untyped =
  var body = newStmtList()

  var lexerTokens = toSeq(nwtTokenize(str.strVal))
  echo "Lexer tokens:"
  echo lexerTokens

  var firstStepTokens = parseFirstStep(lexerTokens)
  echo "firstStepTokens:"
  echo firstStepTokens

  var pos = 0
  var secondsStepTokens = parseSecondStep(firstStepTokens, pos)
  echo "secondsStepTokens:"
  echo secondsStepTokens

  var renderedText = render(secondsStepTokens, 0)
  echo "renderedText:"
  echo renderedText

  body.add parseStmt(renderedText)
  return body

proc onlyFirstAndSecond(str: string): string =
  var lexerTokens = toSeq(nwtTokenize(str))
  echo "Lexer tokens:"
  echo lexerTokens

  var firstStepTokens = parseFirstStep(lexerTokens)
  echo "firstStepTokens:"
  echo firstStepTokens

  var pos = 0
  var secondsStepTokens = parseSecondStep(firstStepTokens, pos)
  echo "secondsStepTokens:"
  echo secondsStepTokens

  var renderedText = render(secondsStepTokens, 0)
  echo "renderedText:"
  echo renderedText

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
    echo onlyFirstAndSecond("""{{foo}}{% while idx < 10 %}idx is: {{idx}}{%idx.inc%}{% endwhile %}baa{{zaa}}""")

    # proc testMe(): string =
    #   compileTemplateStr3 """{% while idx < 10 %}idx is: {{idx}}{%idx.inc%}{%endwhile%}"""
    # echo testMe()




  # var ssNode = parseSecondStep(fsNode)
  # echo "\n\n"
  # echo ssNode
  # echo "\n\n"
  # echo "\n\n"
  # echo ssNode.render(0)

  # echo toSeq(nwtTokenize("""{%block "content" %}{%endblock%}FOO"""))

  # macro baa() =
  #   var ssNode = parseSecondStep(fsNode)
  #   return parseStmt(render(ssNode, 0))

  # baa()