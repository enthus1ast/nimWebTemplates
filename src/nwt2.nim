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

import sequtils

proc parseTo(tokens: seq[Token], tokenType: NwtToken, value: string): seq[Token] =
  result = @[]
  for token in tokens:
    result.add token
    if token.tokenType == tokenType and token.value == value:
      break

proc parse(body: NimNode, tokens: seq[Token]): NimNode =
  echo "parse: " , tokens
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
      body.add quote do: result.add `value`

    of NwtVariable:
      var idn = parseStmt(value)
      body.add quote do:
        result.add $`idn`
    of NwtEval:
      var parts = token.value.strip().split(" ")
      if parts[0] == "if":
        var consumed = tokens[pos..^1].parseTo(NwtEval, "endif")
        pos.inc(consumed.len)
        # var iff = newNimNode(nnkIfExpr)
        # var condA = parseStmt(parts[1..^1].join(" "))
        var iff = newIfStmt(
          (
            parseStmt(parts[1..^1].join(" ")),
            parse(consumed[1..^1])
          )
        )
        # parse(condA, consumed[1..^1])
        # iff.body = condA
        # body.add iff
        # iff.add(parseStmt(parts[1..^1].join(" ")))
        # body.add iff

      # var idn = parseStmt(value)
      # body.add quote do:
      #   `idn`
      # if parts[0] == "endif":
      #   discard
    else:
      discard
    pos.inc

macro compileTemplateStr(str: static string): untyped =
  # result = newProc()
  # result = newStmtList()
  # var pr = newProc(newIdentNode("tst"), @[newIdentNode("string")])
  var body = newStmtList()
  var tokens = toSeq(nwtTokenize(str))
  echo tokens
  parse(body, tokens)
  # pr.body = body
  # echo repr pr
  echo repr body
  return body


# dumpAstGen:
#   proc tst(): string = discard

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


when isMainModule and false:
  proc simple(): string = compileTemplateStr("simple")
  proc simpleVar(ii: int): string = compileTemplateStr("simple{{ii}}simple")
  assert simple() == "simple"
  assert simpleVar(123) == "simple123simple"


# assert