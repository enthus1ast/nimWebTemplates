discard """
  joinable: false
"""
import ../../src/nwt2
import unittest

### Now complex examples follow
suite "test_if_complex":
  test "if/else":
    block:
      proc test(): string = compileTemplateStr("{%if false %}A{%else%}B{%endif%}")
      doAssert test() == "B"

## TODO
# block:
#   proc test(ii: int): string = compileTemplateStr("{%if ii == 1 %}A{%elif ii == 2%}B{%elif ii == 3%}C{%else%}D{%endif%}")
#   doAssert test(1) == "A"
#   doAssert test(2) == "B"
#   doAssert test(3) == "C"
#   doAssert test(4) == "D"