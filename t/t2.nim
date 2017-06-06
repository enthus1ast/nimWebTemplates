import ../nwt
import ../nwtTokenizer
import sequtils
import tables
import commandParser

# var baseStr = """{%block "title" %}BASE{%endblock%}"""
# var baseTokenList = toSeq(nwtTokenize baseStr)
# echo baseTokenList

# # var base2Str = """{%block "title" %}BASE2{%endblock%}"""
# # var base2TokenList = toSeq(nwtTokenize base2Str)
# # echo base2TokenList

# var fillerStr = """{%block "title" %}filler and some more{%endblock%}"""
# var fillerTokenList = toSeq(nwtTokenize fillerStr)
# echo fillerTokenList



# var baseBlockTable = baseTokenList.getBlocks()
# echo baseBlockTable

# echo baseTokenList.fillBlocks(fillerTokenList)



# var baseStr = """{%block "title" %}BASE {%block "klaus" %}ich bin der klaus{%endblock%} ich bin _NICH_ der klaus{%endblock%} hallo """
# var baseStr = """{%block "title" %}BASE {%block "klaus" %}ich bin der klaus ich bin _NICH_ der klaus{%endblock%} hallo {%endblock%}a asdfasf"""
# var baseTokenList = toSeq(nwtTokenize baseStr)
# echo baseTokenList
# for k,v in getBlocks(baseTokenList).pairs:
#   echo k, "->", v



var baseStr = """{%for foo in baa%}BASE {%for uggu in foo%}ich bin der klaus {{uggu}} ich bin _NICH_ der klaus{%endfor%} hallo {%endfor%}a asdfasf"""
var baseTokenList = toSeq(nwtTokenize baseStr)
echo baseTokenList
for k,v in getBlocks(baseTokenList, "for", "endfor").pairs:
  echo k, "->", v