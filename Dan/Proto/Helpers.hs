{-# OPTIONS -Wall #-} 
module Helpers where

import Text.PrettyPrint
import Data.Char
import Config (tableWidth)
-- May subdivide this file into multiple helper files as it grows. Specifically,
--  we may prefer having TeX specific commands in their own module.

--Table making help
lAndDim :: [[a]] -> String
lAndDim []  = error "No fields provided"
lAndDim [f] = concat (replicate ((length f)-1) "l ") ++ "p" ++ 
  brace (show tableWidth ++ "cm")
lAndDim _   = error "Unimplemented use of lAndDim in Helpers."
  
--basic docs
bslash,dbs,eq,dlr,ast,pls,hat,slash,hyph :: Doc
bslash = text "\\"
dbs    = bslash <> bslash
eq     = text "="
dlr    = text "$"
ast    = text "*"
pls    = text "+"
hat    = text "^"
slash  = text "/"
hyph   = text "-"

sq,br :: String -> Doc
sq t = text $ "[" ++ t ++ "]"
br t = text $ "{" ++ t ++ "}"

--basic plaintext manipulation
paren,brace,dollar,quotes :: String -> String
paren  = \x -> "(" ++ x ++ ")"
brace  = \x -> "{" ++ x ++ "}"
dollar = \x -> "$" ++ x ++ "$"
quotes = \x -> "\"" ++ x ++ "\""

--capitalize
capitalize :: String -> String
capitalize [] = []
capitalize (c:cs) = toUpper c:map toLower cs



--format strings and convert -> Doc
upcase, lowcase :: [Char] -> Doc
upcase []      = text []
upcase (c:cs)  = text $ toUpper c:cs --capitalize first letter of string
lowcase []     = text []
lowcase (c:cs) = text $ toLower c:cs --make first letter lowercase

--TeX Specifics
docclass :: String -> String -> Doc
docclass [] brac      = bslash <> text "documentclass" <> br brac
docclass sqbrack brac = bslash <> text "documentclass" <> sq sqbrack <> br brac

usepackage :: String -> Doc
usepackage pkg = bslash <> text "usepackage" <> br pkg

exdoc :: String -> String -> Doc
exdoc [] d      = bslash <> text "externaldocument" <> br d
exdoc sqbrack d = bslash <> text "externaldocument" <> sq sqbrack <> br d

title :: String -> Doc
title t = bslash <> text "title" <> br t

author :: String -> Doc
author a = bslash <> text "author" <> br a

begin, endL, command :: Doc
begin   = bslash <> text "begin" <> br "document" $$ bslash <> text "maketitle"
endL    = bslash <> text "end" <> br "document"
command = bslash <> text "newcommand"

comm :: String -> String -> String -> Doc
comm b1 [] [] = (command) <> br ("\\" ++ b1)
comm b1 b2 [] = (command) <> br ("\\" ++ b1) <> br b2
comm b1 b2 s1 = (command) <> br ("\\" ++ b1) <> sq s1 <> br b2

count :: String -> Doc
count b1 = bslash <> text "newcounter" <> br b1

renewcomm :: String -> String -> Doc
renewcomm b1 b2 = bslash <> text "renewcommand" <> br ("\\" ++ b1) <> br b2

sec :: String -> Doc
sec b1 = bslash <> text "section*" <> br b1

subsec :: String -> Doc
subsec b1 = bslash <> text "subsection*" <> br b1

newline :: Doc
newline = bslash <> text "newline"

-- Macro / Command def'n --
--TeX--
srsComms, lpmComms, bullet, counter, ddefnum, ddref, colAw, colBw, arrayS :: Doc
srsComms = bullet $$ counter $$ ddefnum $$ ddref $$ colAw $$ colBw $$ arrayS
lpmComms = text ""

bullet  = comm "blt" "- " []
counter = count "datadefnum"
ddefnum = comm "ddthedatadefnum" "DD\\thedatadefnum" []
ddref   = comm "ddref" "DD\\ref{#1}" "1"
colAw   = comm "colAwidth" "0.2\\textwidth" []
colBw   = comm "colBwidth" "0.73\\textwidth" []
arrayS  = renewcomm "arraystretch" "1.2"

fraction :: String -> String -> String
fraction n d = "\\frac{" ++ n ++ "}{" ++ d ++ "}"

b,e :: String -> Doc
b s = bslash <> text ("begin" ++ brace s)
e s = bslash <> text ("end" ++ brace s)