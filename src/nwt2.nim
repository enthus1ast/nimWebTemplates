import ./nwtTokenizer
import macros
import strutils
# static:
#   for token in nwtTokenize("foo{{baa}}{#com#}{%if true%}asdf{%endif%}"):
#     echo token


# for token in nwtTokenize("""{% block content"%}{%endblock%} SOME MORE STUFF"""):
#   echo token

# static:
#   for token in nwtTokenize("{%if true%}asdf{%endif%}"):
#     echo token

# type
#   NinjaNodeKind = enum
#     NjIf
#     NjElif
#     NjElse
#     NjFor
#     NjWhile
#   NinjaNode = object
#     kind: NinjaNodeKind


import sequtils

proc parseTo(tokens: seq[Token], tokenType: NwtToken, value: string): seq[Token] =
  result = @[]
  for token in tokens:
    if token.tokenType == tokenType and token.value == value:
      break
    result.add token

proc parse(tokens: seq[Token]): NimNode =
  echo "parse: " , tokens
  result = newStmtList()
  var pos = 0
  while true:
    if pos >= tokens.len: break
    var token = tokens[pos]
    # for token in tokens:
    var value = token.value
    # echo "FROM MACRO: ", token
    case token.tokenType
    of NwtString:
      # echo "STRING"
      # body.add quote do: echo token.value
      # if body[^1].kind == nnkIfExpr:
      #   body[^1].add quote do: result.add `value`
      # else:
      result.add quote do: result.add `value`

    of NwtVariable:
      var idn = parseStmt(value)
      result.add quote do:
        result.add $`idn`
    of NwtEval:
      var parts = token.value.strip().split(" ")
      case parts[0]
      of "if":
        var consumed = tokens[pos..^1].parseTo(NwtEval, "endif")
        pos.inc(consumed.len)
        ## TODO 2 because last token is in there as stmt (bug i guess)
        var iff = newIfStmt(
          (
            parseStmt(parts[1..^1].join(" ")),
            parse(consumed[1..^1])
          )
        )
        result.add iff
      of "while":
        var consumed = tokens[pos..^1].parseTo(NwtEval, "endwhile")
        pos.inc(consumed.len)
        var whileStmt = newNimNode(nnkWhileStmt)
        whileStmt.add parseStmt(parts[1..^1].join(" "))
        whileStmt.add parse(consumed[1..^1]) ## TODO 2 because last token is in there as stmt (bug i guess)
        result.add whileStmt
      of "for":
        var consumed = tokens[pos..^1].parseTo(NwtEval, "endfor")
        pos.inc(consumed.len)
        var forStmt = newNimNode(nnkForStmt)
        forStmt.add newIdentNode(parts[1])
        # forStmt.add newNimNode(nnkNone) #newIdentNode("") # the second
        # forStmt.add parseStmt()
        forStmt.add parse(consumed[2..^1]) ## TODO 2 because last token is in there as stmt (bug i guess)
        result.add forStmt
      of "include":
        # result.add
        result.add parse( toSeq(nwtTokenize(readFile(token.value.extractTemplateName()))))
      of "endif", "endwhile", "endfor":
        discard ## TODO catching end statements should not be needed
      else:
        result.add token.value.parseStmt()
    else:
      discard
    pos.inc

macro compileTemplateStr*(str: untyped): untyped =
  # result = newProc()
  # result = newStmtList()
  # var pr = newProc(newIdentNode("tst"), @[newIdentNode("string")])
  var body = newStmtList()
  var tokens = toSeq(nwtTokenize(str.strVal))
  echo tokens
  body = parse(tokens)
  # pr.body = body
  # echo repr pr
  echo repr body
  return body

macro compileTemplateFile*(path: static string): void =
  var str = readFile(path)
  var body = newStmtList()
  var tokens = toSeq(nwtTokenize(str))
  echo tokens
  body = parse(tokens)
  return body

proc foo(): string = compileTemplateFile("tests/templates/one.html")
echo foo()

# dumpAstGen:
#   proc tst(): string = discard


when isMainModule:
  type
    MyObj = object
      aa: float
      ss: string

  proc faa(foo: int, obj: MyObj): string =
    # echo "FAA"
    # const ttt = "asdf asdf {{foo * 2}} more {{(obj.aa)}} {{obj.ss.len}} {# Some comment #} {{obj}}"
    # const ttt = "{%if (foo == 123)%}echo 123{%endif%}  {%if (foo == 567)%}echo 567{%endif%}"
    # const ttt = "{%while true%}"
    const ttt = "{%if (foo == 123)%}{%if (obj.aa == 13.37)%}leet{%endif%}{%endif%}"
    compileTemplateStr(ttt)
  # echo tst()

  echo faa(123, MyObj(aa: 13.37, ss: "some string"))

