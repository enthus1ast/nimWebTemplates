nwt is a little template engine inspired by jinja2.

it do not enforce any web framework so use whatever you like!

rudimentary freeze support with `freeze()`

have a look at the other demos!

if you feeling fancy today have a special look at the `dbdriven` database example and my little flatfile database flatdb for nim-lang


usage
=====


Directory structure
-----------------------

To follow this example create this folder structure

```
./example.nim
./templates/base.html
./templates/index.html
./templates/about.html
```



menu.html
----------

```
<a href="index.html">index</a> || <a href="about.html">about</a>
```

base.html
```jinja2
{%import menu.html%}
<html>
	<head>
		<title>{{title}}</title>
	</head>

	<body>
		<div>
			{{self.menu}} 
		</div>

		<div>
			{%block "content"%}
				{# i will be replaced by my children #}
			{%endblock%}
		</div>

		<div>
			Some footer infos we always wanna see!
			{{self.footer}}
		</div>
	</body>
</html>
```


index.html
-----------

```jinja2
{%extends "base.html"%}

{%set title "Some index and more"%}

{%block content%}
	Lorem ipsum dolor sit amet, consectetur adipisicing elit. 
	Ab, sint repellendus iure similique ipsa unde eos est nam numquam, laborum, sit ipsum voluptates modi impedit doloremque. 
	Fugiat, obcaecati delectus accusantium.
{%endblock%}

{%block footer%}
	Some footer infos we only want to see on the index
{%endblock%}

```



about.html
-----------

```jinja2
{%extends "base.html"%}
{%set title "Some about me and stuff"%}

{%block content%}
	Lorem ipsum dolor sit amet, consectetur adipisicing elit. 
	Ab, sint repellendus iure similique ipsa unde eos est nam numquam, laborum, sit ipsum voluptates modi impedit doloremque. 
	Fugiat, obcaecati delectus accusantium.
{%endblock%}

{# we not set any additional footer here, so we omit the block #}

```


example.nim
------------

```nim
import asynchttpserver, asyncdispatch
import json
import nwt

var templates = newNwt("templates/*.html") # we have all the templates in a folder called "templates"

var server = newAsyncHttpServer()
proc cb(req: Request) {.async.} =
  let res = req.url.path #.strip(leading=true, trailing=false, {'/'})

  case res 
  of "index.html":
    await req.respond(Http200, templates.renderTemplate("index.html") )  
  of "about.html":
    await req.respond(Http200, templates.renderTemplate("about.html"))
  else:
    await req.respond(Http404, "not found")

waitFor server.serve(Port(8080), cb)    
```