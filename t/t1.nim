import ../nwt
import ../nwtTokenizer
import sequtils
import tables

var baseStr = """{%block "title" %}BASE{%endblock%}"""
var baseTokenList = toSeq(nwtTokenize baseStr)
echo baseTokenList

# var base2Str = """{%block "title" %}BASE2{%endblock%}"""
# var base2TokenList = toSeq(nwtTokenize base2Str)
# echo base2TokenList

var fillerStr = """{%block "title" %}filler and some more{%endblock%}"""
var fillerTokenList = toSeq(nwtTokenize fillerStr)
echo fillerTokenList



var baseBlockTable = baseTokenList.getBlocks()
echo baseBlockTable

echo baseTokenList.fillBlocks(fillerTokenList)