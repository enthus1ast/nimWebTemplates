discard """
  joinable: false
"""
import ../../src/nwt2

# block:
#   proc test(): string =
#     compileTemplateStr("{% for cnt in \"12345\" %}{{cnt}}{%endfor%}")
#   doAssert test() == "12345"

block:
  proc test(): string =
    compileTemplateStr("{% for cnt in [\"foo\", \"baa\", \"baz\"] %}{{cnt}}{%endfor%}")
  doAssert test() == "foobaabaz"

# ## This test does not work yet :/

block:
  proc test(): string =
    compileTemplateStr("{% for idx, cnt in \"abcdef\".pairs() %}{{idx}}{{cnt}}{%endfor%}")
  doAssert test() == "0a1b2c3d4e5f"

block:
  proc test(): string =
    compileTemplateStr("{% for idx,cnt in \"abcdef\".pairs() %}{{idx}}{{cnt}}{%endfor%}")
  doAssert test() == "0a1b2c3d4e5f"

block:
  proc test(): string =
    compileTemplateStr("{% for (idx,cnt) in \"abcdef\".pairs() %}{{idx}}{{cnt}}{%endfor%}")
  doAssert test() == "0a1b2c3d4e5f"
  # echo test()




# block:
#   proc test(): string =
#     compileTemplateStr("{% var cnt = 0 %}{% while cnt != 5 %}{% cnt.inc() %}-{{cnt}}{%endwhile%}")
#   doAssert test() == "-1-2-3-4-5"

# block:
#   proc test(): string = compileTemplateStr("{% var cnt = 0 %}{% while true%}1{%break%}{%endwhile%}")
#   doAssert test() == "1"

# block:
#   proc test(): string = compileTemplateStr("{% var cnt = 0 %}{% while true%}{% cnt.inc() %}{{cnt}}{%if cnt == 5%}{%break%}{%endif%}{%endwhile%}")
#   doAssert test() == "12345"

# block:
#   proc test(): string = compileTemplateStr("{%if 1 == 1%}simple{%endif%}")
#   doAssert test() == "simple"

# block:
#   proc test(): string = compileTemplateStr("{%if false%}simple{%endif%}")
#   doAssert test() == ""

# block:
#   proc test(): string = compileTemplateStr("{%if 1 == 1%}{%if true%}simple{%endif%}{%endif%}")
#   doAssert test() == "simple"

# block:
#   proc test(): string = compileTemplateStr("{%if 1 == 1%}outer{%if false%}inner{%endif%}{%endif%}")
#   doAssert test() == "outer"

# block:
#   proc test(): string = compileTemplateStr("{%if false%}outer{%if true%}inner{%endif%}{%endif%}")
#   doAssert test() == ""

# block:
#   proc test(ii: int, ss: string): string = compileTemplateStr("{%if ii == 123 %}{{ss}}{%endif%}")
#   doAssert test(123, "foo") == "foo"
#   doAssert test(456, "foo") == ""

# block:
#   proc someProc(): bool = return true
#   proc anotherProc(): int = return 123
#   proc test(): string = compileTemplateStr("{%if someProc() %}{{ anotherProc() }} {{ anotherProc() * 2 }}{%endif%}")
#   doAssert test() == "123 246"

# # block:
# #   proc test(ii: int, ss: string): string = compileTemplateStr("{%if ii == 123 %}{{ss}}{%else%}not simple{%endif%}")
# #   doAssert test(123, "simple") == "simple"
# #   doAssert test(456, "simple") == "not simple"

