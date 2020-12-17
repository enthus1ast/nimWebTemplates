import macros

# nnkStmtList.newTree(
#   nnkForStmt.newTree(
#     newIdentNode("idx"),
#     newIdentNode("elem"),
#     nnkCall.newTree(
#       nnkDotExpr.newTree(
#         newLit("abcd"),
#         newIdentNode("pairs")
#       )
#     ),
#     nnkStmtList.newTree(
#       nnkCommand.newTree(
#         newIdentNode("echo"),
#         newIdentNode("idx"),
#         newLit(" "),
#         newIdentNode("elem")
#       )
#     )
#   )
# )
# dumpAstGen:
#   for idx, elem in "abcd".pairs():
#     echo idx, " ", elem


# nnkStmtList.newTree(
#   nnkForStmt.newTree(
#     newIdentNode("elem"),
#     newLit("abcd"),
#     nnkStmtList.newTree(
#       nnkCommand.newTree(
#         newIdentNode("echo"),
#         newIdentNode("elem")
#       )
#     )
#   )
# )
# dumpAstGen:
#   for elem in "abcd":
#     echo elem


# for idx, elem in "abcd".pairs():
#   echo idx, " ", elem

# dumpTree:
#   when not declared(foo):
#     var foo: string = "123"
#   else:
#     foo = "123"

# when not declared(foo):
#   var foo: string = "123"
# else:
#   foo = "123"

# macro sset() =
#   result = newStmtList()
#   var whenstmt = newNimNode(nnkWhenStmt)
#   newNimNode(nnkEl)

# for `in` in "123":
#   echo `in`

# import strutils
# echo """for idx, cnt in ["foo", "baa", "baz"].pairs():""".split("for", 1)[1].split("in")

for (idx,cnt) in "abcdef".pairs():
  echo idx
  echo cnt

# macro sset() =
# #   result = parseStmt("""
# # for idx, cnt in ["foo", "baa", "baz"].pairs():
# #   echo $cnt
# #   """)
# #   echo repr result
# #   echo repr parseExpr("""
# # idx, cnt in ["foo", "baa", "baz"].pairs()
# #   """)
#   # echo repr result


# sset()
# echo aa
# macro mm() =
#   # echo repr parseStmt("for idx in 0..myvar")
#   var ff = newNimNode nnkForStmt #(ident1, ident2, expr1, stmt1)
#   ff.add ident("idx")
#   ff.add parseExpr("0 .. 10")
#   ff.add parseExpr("echo idx")
#   echo repr ff
#   return ff

# mm()