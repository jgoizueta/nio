% tools.w -- common Ruby utilities for Nio
%
% Copyright (C) 2003-2005, Javier Goizueta <javier@@goizueta.info>
%
% This program is free software; you can redistribute it and/or
% modify it under the terms of the GNU General Public License
% as published by the Free Software Foundation; either version 2
% of the License, or (at your option) any later version.

% ===========================================================================
\documentclass[a4paper,oneside,english]{article}
\usepackage[english,read]{nwprog}
% ===========================================================================


% ===========================================================================
%\input{nwprogen.tex}
% ===========================================================================

\isodate

\newcommand{\ProgTitle}{Ruby Tools}
\newcommand{\ProgAuth}{Javier Goizueta}
\newcommand{\ProgDate}{\today}
\newcommand{\ProgVer}{1.0}
\newcommand{\ProgSource}{\ttfamily\bfseries tools.w}

\title{\ProgTitle}
\author{\ProgAuth}
\date{\ProgDate}

% ===========================================================================

\lng{ruby}

%@r~%  The ASCII tilde is used as the nuweb escape character

\begin{document}

\section{Ruby Tools}

~o lib/nio/tools.rb
~{# Common Utilities
~<License~>
~<Required Modules~>
~<definitions~>
~<classes~>
module Nio
  ~<Nio classes~>
  module_function
  ~<Nio functions~>
end
~}


~d License
~{~%
# Copyright (C) 2003-2005, Javier Goizueta <javier@goizueta.info>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
~}

~d Required Modules
~{~%
require 'rubygems'
~}


\section{Tests}

~o test/test_tools.rb
~{
#require File.dirname(__FILE__) + '/test_helper.rb'
require 'test/unit'

require 'nio/repdec'
include Nio
require 'yaml'

~<Tests definitions~>

class TestTools < Test::Unit::TestCase

  def setup
    ~<Tests setup~>
  end

  ~<Tests~>
end
 ~}


\section{State-Equivalent Classes}

This mix-in module by Robert Klemme makes a class's equality-behaviour
be based on object state (instance variables).

~d Nio classes
~{~%
module StateEquivalent
  def ==(obj); test_equal(obj); end
  def eql?(obj); test_equal(obj); end
  def ===(obj); test_equal(obj); end
  def hash
    h = 0
    self.instance_variables.each do |var|
      v = self.instance_eval var.to_s
      h ^= v.hash unless v.nil?
    end
    h
  end

  private
  def test_equal(obj)
    return false unless self.class == obj.class
    (self.instance_variables + obj.instance_variables).uniq.each do |var|
      v1 = self.instance_eval var.to_s
      v2 = obj.instance_eval var.to_s
      return false unless v1 == v2
    end
    true
  end
end
~}

\subsection{Tests}

~d Tests definitions
~{~%
class SEclass
  include StateEquivalent
  def initialize(a,b)
    @a = a
    @b = b
  end
end
~}

~d Tests
~{~%
def test_StateEquivalent
  x = SEclass.new(11,22)
  y = SEclass.new(11,22)
  z = SEclass.new(11,23)
  xx = x
  assert_equal(true,x==xx)
  assert_equal(true,x==y)
  assert_equal(false,x==z)
  assert_equal(x.hash,xx.hash)
  assert_equal(x.hash,y.hash)
  assert_equal(false,x.hash==z.hash)
end
~}



% -------------------------------------------------------------------------------------
\section{Índices}


\subsection{Archivos}
~f

\subsection{Fragmentos}
~m

\subsection{Identificadores}
~u



\end{document}