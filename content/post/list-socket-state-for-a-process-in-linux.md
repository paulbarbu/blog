---
title: "List Socket State for a Process in Linux"
date: 2019-10-13T21:23:00+03:00
draft: true
---

Whether you want to investigate a half-opened/half-closed connection issue in Linux or you want to know if your application
leaks sockets, then this command might be helpful:

{{< highlight bash >}}
$ lsof -a -i TCP:5000 -p 3921 | tail -n +2 | awk 'BEGIN{listen=0;estab=0;other=0} /ESTABLISHED/{estab+=1} /LISTEN/{listen+=1} !/ESTABLISHED|LISTEN/{other+=1; print} END{printf("established=%s listen=%s other=%s\n", estab, listen, other)}'
{{< / highlight >}}

That command is pretty long, so from left to right we're piping the output of **lsof** into **tail**, then **awk**.

Now generally you don't want to copy and paste commands from the web into your terminal, that's just bad practice.
Let's try to understand what's going on with that command.