import ./nwtTokenizer
import macros
import strutils, sequtils
import sets
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



proc parseTo(tokens: seq[Token], tokenType: NwtToken, value: HashSet[string]): seq[Token] =
  result = @[]
  for token in tokens:
    if token.tokenType == tokenType and (value.contains token.value):
      break
    result.add token

proc parse(tokens: seq[Token]): NimNode {.gcsafe.} =
  echo "parse: " , tokens
  result = newStmtList()
  var pos = 0
  while true:
    if pos >= tokens.len: break
    var token = tokens[pos]
    var value = token.value
    case token.tokenType
    of NwtString:
      result.add quote do: result.add `value`
    of NwtVariable:
      var idn = parseStmt(value)
      result.add quote do:
        result.add $`idn`
    of NwtEval:
      var parts = token.value.strip().split(" ")
      case parts[0]
      of "if":
        var consumed = tokens[pos..^1].parseTo(NwtEval, ["endif", "elif", "else"].toHashSet )
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
        var consumed = tokens[pos..^1].parseTo(NwtEval, ["endwhile"].toHashSet)
        pos.inc(consumed.len)
        var whileStmt = newNimNode(nnkWhileStmt)
        whileStmt.add parseStmt(parts[1..^1].join(" "))
        whileStmt.add parse(consumed[1..^1]) ## TODO 2 because last token is in there as stmt (bug i guess)
        result.add whileStmt
      of "for":
        # {% for idx in 0 .. ii %}
        #   {{idx}}
        # {% endfor %}
        #####
        # var ff = newNimNode nnkForStmt #(ident1, ident2, expr1, stmt1)
        # ff.add ident("idx")
        # ff.add parseExpr("0 .. 10")
        # ff.add parseExpr("echo idx")
        var consumed = tokens[pos..^1].parseTo(NwtEval, ["endfor"].toHashSet)
        pos.inc(consumed.len)
        var forStmt = newNimNode(nnkForStmt)
        # forStmt.add newIdentNode(parts[1])

        ## TODO this seems to work, make it nice later
        for part in token.value.strip().split("for", 1)[1].split("in")[0].split(","):
          echo "P: ", part
          forStmt.add newIdentNode(part.strip(chars = Whitespace + {'(', ')'}))

        forStmt.add parseExpr(token.value.strip().split("for", 1)[1].split("in")[1])
        # echo parts
        # forStmt.add parseExpr(token.value.strip().split("for", 1)[1]) #.split("in")
        # echo "PART#########"
        # echo parts[1..^1].join(" ")
        # echo "PART^#########"

        # forStmt.add parseExpr(parts[1..^1].join(" "))
        # forStmt.add parseExpr(parts[3..^1].join(" "))

        echo "FOR STMT"
        echo repr forStmt
        echo "##########"
        # forStmt.add newNimNode(nnkNone) #newIdentNode("") # the second
        # forStmt.add parseStmt()
        forStmt.add parse(consumed[1..^1]) ## TODO 2 because last token is in there as stmt (bug i guess)
        result.add forStmt
      of "include":
        # result.add
        result.add parse( toSeq(nwtTokenize(readFile(token.value.extractTemplateName()))))
      of "insert":
        ## Literaly insert another file into the template
        ## useful for documentation?
        let rawContent = readFile(token.value.extractTemplateName())
        result.add quote do: result.add `rawContent`
      # of "set":
      #   let varident = newIdentNode(parts[1])
      #   result.add quote do:
      #     when declared(`varident`):
      #       # echo "var is declare:", parts[1]
      #       `result.add` parseStmt(parts[1..^1].join(" "))
      #     else:
      #       echo "var is NOT declared", parts[1]
      #       parseStmt("var " & parts[1..^1])
      #   # Make this compatible with old nwt
      #   # var modParts = parts[1..^1]
      #   # when defined(parts[1]):
      #   #   # do not declare var again
      #   #   result.add parseStmt(modParts)
      #   # else:

      of "endif", "endwhile", "endfor":
        discard ## TODO catching end statements should not be needed
      else:
        result.add token.value.parseStmt()
    else:
      discard
    pos.inc

macro compileTemplateStr*(str: untyped): untyped =
  var body = newStmtList()
  var tokens = toSeq(nwtTokenize(str.strVal))
  echo tokens
  body = parse(tokens)
  echo repr body
  return body

macro compileTemplateFile*(path: static string): void =
  var str = readFile(path)
  var body = newStmtList()
  var tokens = toSeq(nwtTokenize(str))
  echo tokens
  body = parse(tokens)
  return body

when isMainModule and true:
  import httpclient
  proc get(url: string): string =
    var client = newHttpClient()
    return client.getContent(url)

  var idx = 0
  proc foo(): string = compileTemplateFile("tests/templates/one.html")
  echo foo()
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

