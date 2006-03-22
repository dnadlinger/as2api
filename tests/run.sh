#!/bin/sh

if [ "$1" == "cover" ]; then
  rb="/home/dave/opt/bin/rcov --exclude-only=/usr/lib"
else
  rb="ruby -w"
fi

$rb -I .. ./ts.rb
