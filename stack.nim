########################################################
## For building a stack easily.....
## Check if they exists in stdlib
## 
proc popr*[T](s: var seq[T]): T =
  ## removes and returns the rightest/last item
  result = s[^1]
  s.delete(s.len)

proc popl*[T](s: var seq[T]): T =
  ## removes and return the leftest/first item
  result = s[0]
  s.delete(0)

proc pushr*[T](s: var seq[T], itm: T) =
  ## adds a value to the back/right
  s.add(itm)

proc pushl*[T](s: var seq[T], itm: T)=
  ## adds a value to the front/left
  s.insert(itm,0)
########################################################