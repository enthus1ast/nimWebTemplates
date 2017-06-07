{%extends base.nim%}
{%set publicDir "./public/"%}
{%set templateDir "templates/*.html"%}



{%block "routes"%}
  of "":
    await req.respond(Http200, t.renderTemplate("index.html") )  
  of "logout":
    await req.respond(Http200, "TODO do something usefull")
{%endblock%}