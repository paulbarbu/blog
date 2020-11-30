---
title: "Linux TCP Socket States, the Listen Backlog and SYN cookies"
description: "TCP socket debugging on GNU/Linux using a handful of basic tools: lsof, awk and tail."
date: 2019-10-24T21:23:00+03:00
categories:
  - "Software"
tags:
 - lsof
 - awk
 - tail
 - tcp
 - linux
---

TCP socket debugging on GNU/Linux using a handful of basic tools: lsof, awk and tail.

<!--more-->

### Counting socket states

For a TLDR about the Listen Backlog and SYN cookies: [Jump to the Listen Backlog and SYN cookies explanation](#explanation)

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
Then the following blocks are responsible for actually incrementing the counter we have initialized at the beginning:

* `/ESTABLISHED/`: counts the number of established sockets;
* `/LISTEN/`: counts the number of listening sockets;
* `!/ESTABLISHED|LISTEN/`: counts the number of sockets in a state OTHER than the two above. It also has the side effect of printing the current line we're processing, since I want to see its state.

Note that the regular expressions are very basic and are written based on the assumption that the `NAME` column of the `lsof` command contains exactly the socket state and one line of its output only contains it once, only on that column.

Finally the `END` block prints the counts of the socket states computed earlier, this is similar to C's`printf`.


### Improvements

* for the PID of a process you can use `pidof process-name-here`, but this won't work if you have multiple instances of the same application running and you'll have to manually select the one you need;
* `lsof -F` for parsing the output by other programs;
* the `awk` script could be improved to count all the possible sockets states without much dependence on the socket state exactly appearing only on the last column of the `lsof` output

<a name="explanation"></a>
### Interpreting the output and investigating the half-opened/closed situation


If you run this command for both the server and the client, then you could go reasoning about half-opened or closed connections.
For example if you see that you have 5000 established connections on the client and 1000 established connections on the server, that means that some of the connections are half-opened.

As to why a connection may end up half-opened/closed, that's a more involved discussion and I don't claim to have become an expert, but I have gained some insight into how tricky TCP is.

Two related potential causes (leaving out crashed, reboots and cable disconnects):

* You only `accept` connections when the application can handle them. Try instead `accept`ing connections all the time in a separate thread and save the client's socket in a queue for later processing if the application is at full processing capacity.
 By always `accept`ing connections your backlog queue will not fill up.
* Somewhat related to the first point is the fact that your *backlog* argument to `listen` is too small, hence the queue fills up.

The *backlog* queue filling up is bad since then you may, somehow artificially, get to a SYN flood where the opening handshake
cannot be finalized. The server sends a `SYN/ACK` segment (in response to the client's `SYN`) with a cookie value for the *sequence number* [^1], but it may never receive the last `ACK` back from the client.
That happens when the client thinks the connection is already established since it sent an ACK, but with the wrong sequence number. Because TCP is not actively checking the status of a connection (it is an "idle" protocol[^2]) and in my scenario we were expecting data to first come from the server to the client, the client was naively waiting for the initialization data from the server, not knowing the server is also expecting to receive from
the client an `ACK` segment with a proper sequence number set to the cookie's value.
So this can cause a network level "deadlock".
The only way out of it is by checking the connection's state at the application level (via a heartbeat protocol) or by having the client initiate the data transmission (in which case it would know that the connection is incomplete) [^3].

There are a lot of factors that need to line up for you to get into this kind of situation, but they sometimes do [^4]
and at that point you'd better try not to fiddle with the backlog parameter for `listen`, it's best to set it at `SOMAXCONN`.
And you'd better leave SYN cookies enabled since that can cause you downtime further down the line with very little cost on the part of a potential attacker.

Ideally, you'd have to fix your application, either by quickly `accept`ing connections and placing them into a queue for future processing or by having the client send the first data through the socket, instead of the server, or if that's not possible by implementing a heartbeat protocol into your application protocol (which provides a host of problems of its own, starting with the fact the the client may have to first send data, something which led us to this solution).

[^1]: https://cr.yp.to/syncookies.html
[^2]: https://blog.stephencleary.com/2009/05/detection-of-half-open-dropped.html
[^3]: http://veithen.io/2014/01/01/how-tcp-backlog-works-in-linux.html
[^4]: https://www.evanjones.ca/tcp-stuck-connection-mystery.html

### Further information

As always, you can find out more information about the above commands by running `man lsof`, `man tail`, `man awk`.

There are alternatives to `lsof` like `netstat` and `ss` which can be used in a similar way.

Apart from the main articles I've read:

* D. J. Bernstein, the inventor of SYN cookies about them: https://cr.yp.to/syncookies.html
* About the *backlog* parameter for `listen`, complete with explanations and with kernel code: http://veithen.io/2014/01/01/how-tcp-backlog-works-in-linux.html
* High level view of the half-opened connection problem: https://blog.stephencleary.com/2009/05/detection-of-half-open-dropped.html
* MySQL debugging "war" story that prompted me to write the `lsof | tail | awk` command in the first place: https://www.evanjones.ca/tcp-stuck-connection-mystery.html

These links may also be of help:

 * https://www.giac.org/paper/gsec/2013/syn-cookies-exploration/103486
 * https://stackoverflow.com/questions/15285008/regarding-tcp-syn-flood-why-is-half-open-connections-worse-than-established-con
 * https://stackoverflow.com/questions/39210043/tcp-half-open-connections-winsock-listen-accept-behavior
 * https://stackoverflow.com/questions/53580682/tcp-server-not-accepting-right-number-of-connections-issued-by-client-with-small
 * https://github.com/tokio-rs/tokio/issues/383

