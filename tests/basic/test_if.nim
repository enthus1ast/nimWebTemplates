discard """
  joinable: true
"""
import ../../src/nwt2

block:
  proc test(): string = compileTemplateStr("{%if true%}simple{%endif%}")
  doAssert test() == "simple"

block:
  proc test(): string = compileTemplateStr("{%if 1 == 1%}simple{%endif%}")
  doAssert test() == "simple"

block:
  proc test(): string = compileTemplateStr("{%if false%}simple{%endif%}")
  doAssert test() == ""

block:
  proc test(): string = compileTemplateStr("{%if 1 == 1%}{%if true%}simple{%endif%}{%endif%}")
  doAssert test() == "simple"

block:
  proc test(): string = compileTemplateStr("{%if 1 == 1%}outer{%if false%}inner{%endif%}{%endif%}")
  doAssert test() == "outer"

block:
  proc test(): string = compileTemplateStr("{%if false%}outer{%if true%}inner{%endif%}{%endif%}")
  doAssert test() == ""

block:
  proc test(ii: int, ss: string): string = compileTemplateStr("{%if ii == 123 %}{{ss}}{%endif%}")
  doAssert test(123, "foo") == "foo"
  doAssert test(456, "foo") == ""

block:
  proc someProc(): bool = return true
  proc anotherProc(): int = return 123
  proc test(): string = compileTemplateStr("{%if someProc() %}{{ anotherProc() }} {{ anotherProc() * 2 }}{%endif%}")
  doAssert test() == "123 246"

block:
  proc test(): string = compileTemplateStr("{%if true %}A{%if true %}B{%endif%}C{%if false %}D{%endif%}{%endif%}")
  doAssert test() == "ABC"



# block:
#   proc test(ii: int, ss: string): string = compileTemplateStr("{%if ii == 123 %}{{ss}}{%else%}not simple{%endif%}")
#   doAssert test(123, "simple") == "simple"
#   doAssert test(456, "simple") == "not simple"

