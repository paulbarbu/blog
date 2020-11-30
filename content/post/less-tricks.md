---
title: "Less Tricks For The Command Line"
description: "Less tricks for more productivity on the command line. Pun intended."
date: 2020-10-13T21:35:16+03:00
categories:
  - "Software"
tags:
 - less
 - linux
thumbnail: "/lesstricks/thumbnail.webp"
---

Less tricks for more productivity on the command line. Pun intended.

<!--more-->

## Introduction

`less` is a command line program that lets you display the contents of files in the Linux terminal.

I have been a user of `cat` and `grep` combination (`cat file.txt | grep foo`) for a long time, but we can do better.

`less` doesn't have to load the whole file in memory and can search and do other small things that might help you.

`less` is also used when you read man pages, i.e.: `man less` will open a `less` process :-).

What follows are just basic features of `less` that I use on a daily basis, for more advanced usage see its man page.

## Searching

After having opened a file in less `less file.txt` you can start searching for keywords by pressing `/` and typing the search term.
Like so: `/foobar`

There can be no results or several, to navigate backwards and forwards press `N` (`Shift` + `n`) and `n`.

## Filtering

Apart from searching we can also only display data that we're interested in or we can hide data that we're not interested in.

This is done similarly to searching:

`&foobar`

This will only display lines from your file that contain the term, all other will be hidden.

In order to exclude lines containing a term, just negate it using `!`, like this:

`&!foobar`

Will hide all lines that do contain the "foobar" term.

**Note:** Both the filtering and the searching features have a history of terms, after typing either `/` or `&` use the up arrow to see term previously used.

## Line numbers

You can also display line numbers and they will also be filtered in/out so you can see which lines match your criteria.

For this you'll have to type `-N` and press `Enter`.

In order to turn off the line numbers, repeat the sequence.

## Follow

If you ever used `tail -f file.txt` to see the contents of a log file while they are changing, well... `less` provides a similar functionality, you either have to start it with the `-F` flag:

`less +F file.txt`

Or you can use this functionality by pressing `F` (`Shift` + `f`) in order to make it watch for content changes.

In order to stop watching for changes, press `Ctrl` + `c`.

Very handy feature when you want to follow a log file.

## Colored output

If you have `colordiff` installed, a little thing I like to do and use almost daily is:

`svn diff | colordiff | less -R`

This will simulate for SVN what `git diff` does out of the box.

This demonstrates that `less` can output colors as well and the pagination comes in handy so your terminal stays clean after viewing the diff.

<small>Thumbnail image from https://pixabay.com/ </small>