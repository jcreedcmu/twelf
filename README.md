Twelf-in-Javascript
===================

This is an experiment to see if I can use [MLKit](https://github.com/melsman/mlkit)'s [SMLToJs](https://github.com/melsman/mlkit/blob/master/README_SMLTOJS.md) to compile
[twelf](http://twelf.org/wiki/Main_Page) to javascript and get it running in a web browser.

Status
------

- After inserting a bunch of stubs, and commenting out some of the twelf code that does tabled queries
  that seem to trigger a compiler bug in SMLToJs (which I should document further) I can at least
  get substantially all of the twelf server to compile.

- I'm able to get javascript-land calling trivial sml functions that
  successfully do `document.write` or `console.log` or the like.

- Also from javascript I can *call* `Twelf.loadString` but it
  immediately raises an exception [TextIO.openString](https://github.com/jcreedcmu/mlkit/blob/jcreed/twelf-in-js/js/basis/TextIO.sml#L64) is unimplemented.
  Implementing that function and the associated read calls is the next step.

Building
--------

Clone these two branches in sibling directories `mlkit/` and `twelf/`:
https://github.com/jcreedcmu/mlkit/tree/jcreed/twelf-in-js
https://github.com/jcreedcmu/twelf/tree/jcreed/twelf-in-js

In the `mlkit` directory, build `smltojs` in the standard way:

```shell
$ cd smltojs
$ ./autobuild
$ ./configure
$ make smltojs
$ make smltojs_basislibs
```

Then in the `twelf` directory, do
```
SML_LIB=`pwd`/../mlkit/js ../mlkit/bin/smltojs build/twelf-core-mlkit.mlb
```

This should create a file `run.html` which can be loaded into a web browser.

Original Twelf README follows.

Twelf
=====

Copyright (C) 1997-2011, Frank Pfenning and Carsten Schuermann

Authors: Frank Pfenning
         Carsten Schuermann
With contributions by:
         Brigitte Pientka
         Roberto Virga
         Kevin Watkins
         Jason Reed

Twelf is an implementation of

 - the LF logical framework, including type reconstruction
 - the Elf constraint logic programming language
 - a meta-theorem prover for LF (very preliminary)
 - a set of expansion modules to deal natively with numbers and strings
 - an Emacs interface

Installing
==========

For complete installation instructions, see http://twelf.org/

Twelf can be compiled and installed under Unix, either as a separate
"Twelf Server" intended primarily as an inferior process to Emacs, or as
a structure Twelf embedded in Standard ML.

To build with SML of New Jersey type "make smlnj." To build with MLton type
"make mlton." If you are building Twelf through SML of New Jersey, you may need
to run "make buildid" first.

Files
=====

```
 README            --- this file
 Makefile          --- enables make
 server.cm         --- used to build Twelf Server
 sources.cm        --- used to build Twelf SML
 bin/              --- utility scripts, heaps, binaries
 build/            --- build files (type "make" to see options)
 doc/              --- (Outdated) Twelf user's guide
 emacs/            --- Emacs interface for Twelf
 examples/         --- various case studies
 examples-clp/     --- examples of use of the numbers and strings extensions
 src/              --- the SML sources for Twelf
 tex/              --- TeX macros and style files
 vim/              --- Vim interface for Twelf
```