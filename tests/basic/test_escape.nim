discard """
  joinable: false
"""
import ../../src/nwt2
block:
  proc test(): string = compileTemplateStr("""{{ "{{" }}""")
  doAssert test() == "{{"

## THIS FAILS seems like a lexer issue maybe even #1
# block:
#   proc test(): string = compileTemplateStr("""{{ "}}" }} """)
#   doAssert test() == "}}"

## THIS FAILS seems like a lexer issue maybe even #1
# block:
#   proc test(): string = compileTemplateStr("""{{ "{{}}" }}""")
#   doAssert test() == "{{}}"

