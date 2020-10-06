import macros


# dumpAstGen:
#   for idx in 0..myvar:
#     echo idx

macro mm() =
  # echo repr parseStmt("for idx in 0..myvar")
  var ff = newNimNode nnkForStmt #(ident1, ident2, expr1, stmt1)
  ff.add ident("idx")
  ff.add parseExpr("0 .. 10")
  ff.add parseExpr("echo idx")
  echo repr ff
  return ff

mm()