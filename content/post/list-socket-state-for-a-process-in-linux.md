---
title: "List Socket State for a Process in Linux"
date: 2019-10-13T21:23:00+03:00
draft: true
---

Whether you want to investigate a half-opened/half-closed connection issue in Linux or you want to know if your application
leaks sockets, then this command might be helpful:

``` bash
$ lsof -a -i TCP:5000 -p 3921 | tail -n +2 | awk 'BEGIN{listen=0;estab=0;other=0} /ESTABLISHED/{estab+=1} /LISTEN/{listen+=1} !/ESTABLISHED|LISTEN/{other+=1; print} END{printf("established=%s listen=%s other=%s\n", estab, listen, other)}'
```

That command is pretty long, so from left to right we're piping the output of `lsof` into `tail`, then `awk`.

Now generally you don't want to copy and paste commands from the web into your terminal, that's just bad practice.
Let's try to understand what's going on with that command.

First of all, in Linux, sockets are represented as file descriptors, or *fd* for short. Hence they count towards the
open files collection of a process.
In Linux, we use the `lsof` command to list the open files in the whole system or belonging to a certain process.

### lsof
`lsof -a -i TCP:5000 -p 3921`

In this particular problem I was interested to see whether the process had any TCP connections established or not.
The `lsof` command practically needed to tell me whether my process, indicated to it by it's process ID via `-p 3921`
had any TCP open file descriptors (i.e. sockets) on port 5000
(since this is the port I was expecting the connections to happen on): `-i TCP:5000`.
But I needed to have both of the filters active at the same time, TCP sockets on port 5000 belonging to PID 3921, not just any process on the system.

If you run only this command and expect thousands of connections to your application, reading the output line-by-line will not be very useful. We need to further process it. Hence we're going to pipe to `tail` first.

### tail
`tail -n +2`

This just gives me the tail-end of the piped input starting with the second line. The first line of the `lsof` output is the
name of each column:

```
COMMAND     PID   TID TASKCMD          USER   FD      TYPE             DEVICE    SIZE/OFF       NODE NAME
```

So instead of the standard `tail` behaviour of getting the *last* n lines of output, I get the last lines of the output starting with line *+n*.

### awk
``` bash
awk 'BEGIN{
    listen=0;
    estab=0;
    other=0
}

/ESTABLISHED/{
    estab+=1
}

/LISTEN/{
    listen+=1
}

!/ESTABLISHED|LISTEN/{
    other+=1;
    print
}

END{
    printf("established=%s listen=%s other=%s\n", estab, listen, other)
}'
```

On to the actual processing, I think this is the most advanced `awk` script I have written to date.
Nothing exceptional, really, but very useful to know the basics.

So this application I was tasked with debugging was expecting a lot of connections on TCP port 5000, having done some extensive modifications to its `listen`/`accept` behaviour I quickly needed to know how many connections were established.

The `awk` script does just that, it counts the sockets in `ESTABLISHED` state, `LISTEN` and a third category that includes
all other states (e.g. `CLOSE_WAIT`).

It does this by processing each output line of the `lsof ... | tail ...` command. I start from the fact that the socket state shows up in the `lsof` command in the last column, for example:
```
COMMAND  PID USER   FD   TYPE  DEVICE SIZE/OFF    NODE NAME
nc      4752 paul    3u  IPv4 3053522      0t0     TCP *:39543 (LISTEN)
```
Note the value of the `NAME` column: `*:39543 (LISTEN)` which has the format `address:port (state)`

The `awk` script sets up three variables in the `BEGIN` block (which is executed only once when the program starts.
Then the following blocks are responsibl efor actually incrementing the counter we have initialised at the beginning:

* `/ESTABLISHED/`: counts the number of established sockets;
* `/LISTEN/`: counts the number of listening sockets;
* `!/ESTABLISHED|LISTEN/`: counts the number of sockets in a state OTHER than the two above. It also has the side effect of printing the current line we're processing, since I want to see its state.

Note that the regular expressions are very basic and are wrritten based on the assumption that the `NAME` column of the `lsof` command contains exactly the socket state and one line of its output only contains it once, only on that column.

Finally the `END` blocks prints the counts of the socket states computed earlier, this is similar to C's`printf`.


### Interpreting the output

If you run this command for both the server and the client, then you could go reasoning about half-opened or closed connections.
For example if you see that you have 1000 established conenctions on the client and 5000 established connections on the server, that means ... TODO

### Further information

As always, you can find out more information about the above commands by running `man lsof`, `man tail`, `man awk`.

TODO: links

### Improvements

* for the PID of a process you can use `pidof process-name-here`, but this won't work if you have multiple instances of the same application running and you'll have to manually select the one you need;
* `lsof -F` for parsing the output by other programs;
* the `awk` script could be improved to count all the possible sockets states without much dependence on the socket state exactly appearing only on the last column of the `lsof` output
