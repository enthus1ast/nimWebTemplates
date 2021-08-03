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
# echo vif[]

proc render(node: NwtNode, ident: int): string
proc render(nodes: seq[NwtNode], ident: int): string

const SPACE = "  "

import strformat, strutils

func renderWhile(node: NwtNode, ident: int): string =
  ""

func renderComment(node: NwtNode, ident: int): string =
  SPACE.repeat(ident) & "#" & node.commentBody

func renderStr(node: NwtNode, ident: int): string =
  SPACE.repeat(ident) & "result &= \"\"\"" & node.strBody & "\"\"\""

proc renderIf(node: NwtNode, ident: int): string =
  result &= fmt"if {node.ifStmt}:" & "\n"
  result &= SPACE.repeat(ident) & render(node.nnThen, ident + 1)

  for nodeElif in node.nnElif:
    result &= fmt"elif {nodeElif.elifStmt}:" & "\n"
    # result &= "\t" & ("elif") & "\n"
    result &= render(nodeElif.elifBody, ident + 1)

  result &= fmt"else:" & "\n"
  for nodeElse in node.nnElse:
    result &= SPACE.repeat(ident) & render(nodeElse, ident + 1)

proc render(nodes: seq[NwtNode], ident: int): string =
  for node in nodes:
    result &= render(node, ident) & "\n"

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
    result &= SPACE.repeat(ident) & "result &= $(" & node.variableBody & ")"
  of NEval:
    # Eval could also be NVariable?
    result &= SPACE.repeat(ident)  & node.evalBody
  else:
    discard

echo render(vif, 0)

import macros

macro foo() =
  return parseStmt(render(vif, 0))

import nwtTokenizer, sequtils, parseutils

var tokens = toSeq(nwtTokenize("""{% if a == 1 %}a is one{{ONE}}{% elif a == 2 %}a is two{{TWO}}{% elif a == 3 %}a is three{{THREE}}{% else %}a is something else{{ELSE}}{%endif%}"""))
echo tokens

func splitStmt(str: string): tuple[pref: string, suf: string] =
  var pos = parseIdent(str, result.pref, 0)
  pos += str.skipWhitespace(pos)
  result.suf = str[pos..^1]


type
  FsNodeKind = enum
    FsIf, FsStr, FsEval, FsElse, FsElif, FsEndif, FsFor, FsEndfor, FsVariable
  FSNode = object
    kind: FsNodeKind
    value: string


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
      # while
      else:
        result.add FSNode(kind: FsEval, value: token.value)
    elif token.tokenType == NwtString:
      result.add FSNode(kind: FsStr, value: token.value)
    elif token.tokenType == NwtVariable:
      result.add FSNode(kind: FsVariable, value: token.value)
    # elif token.tokenType == NwtComment:
    #   result.add FSNode(kind: FsComment, value: token.value)

var fsNode = parseFirstStep(tokens)
echo "\n\n"
echo fsNode


template addCorrectNode(container: seq[NwtNode], elem: FsNode) =
  case elem.kind
  of FsStr:
    container.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
  of FsVariable:
    container.add NwtNode(kind: NVariable, variableBody: elem.value) # TODO choose right NwtNodeKind
  else:
    echo fmt"{elem.kind} not supported yet"

type IfState {.pure.} = enum
  InThen, InElif, InElse

proc parseSsIf(fsTokens: seq[FsNode], pos: var int): NwtNode =
  echo "parseSSif"
  var elem: FsNode = fsTokens[pos] # first is the if that we got called about
  result = NwtNode(kind: NwtNodeKind.NIf)
  result.ifStmt = elem.value
  pos.inc # skip the if
  var ifstate = IfState.InThen
  while pos < fsTokens.len:
    elem = fsTokens[pos]
    echo fmt"parseSsIf: {pos} {elem}"

    if elem.kind == FsIf:
      echo "open new if"
      # TODO open a new if; where to put the parsed node from the recursive if parser??

    elif elem.kind == FsElif:
      echo "put to elif"
      ifstate = IfState.InElif
      result.nnElif.add NwtNode(kind: NElif, elifStmt: elem.value)
    elif elem.kind == FsElse:
      echo "put to else"
      ifstate = IfState.InElse
    elif elem.kind == FsEndif:
      break
    else:
      if ifState == IfState.InThen:
        result.nnThen.addCorrectNode(elem)
      if ifState == IfState.InElse:
        result.nnElse.addCorrectNode(elem)
        # result.nnElse.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
      if ifState == IfState.InElif:
        # result.nnElif[^1].elifBody.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
        result.nnElif[^1].elifBody.addCorrectNode(elem)
        # var elifnode = NwtNode(kind: NElif)
        # result.nnElif.add NwtNode(kind: NStr, strBody: elem.value) # TODO choose right NwtNodeKind
    pos.inc


proc parseSecondStep(fsTokens: seq[FSNode]): seq[NwtNode] =
  var pos = 0
  while pos < fsTokens.len:
    var fsToken = fsTokens[pos]
    if fsToken.kind == FSif:
      result &= parseSsIf(fsTokens, pos)
      # var node = NwtNode(kind: NIf, ifStmt: fsToken.value)
      # result.add node
    # elif fsToken.kind == FsStr:
      # Append if last was 'if'
    pos.inc # skip the current elem (test if the inner procs should forward)


var ssNode = parseSecondStep(fsNode)
echo "\n\n"
echo ssNode