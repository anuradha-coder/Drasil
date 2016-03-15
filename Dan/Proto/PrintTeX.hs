{-# OPTIONS -Wall #-} 
module PrintTeX where

import Prelude hiding (print)
import Data.List (intersperse)
import Text.PrettyPrint hiding (render)

import Control.Monad.Reader

import ASTTeX
import ToTeX
import qualified ASTInternal as A
import Spec (USymb(..))
import Config (srsTeXParams, lpmTeXParams, tableWidth, colAwidth, colBwidth)
import Helpers
import Unicode
import Format (Format(TeX),FormatC(..))
-- import Unit
import Symbol (Symbol(..))
import PrintC (printCode)
import qualified LayoutObjs as L

genTeX :: A.DocType -> L.Document -> Doc
genTeX typ doc = build typ $ makeDocument doc

build :: A.DocType -> Document -> Doc
build (A.SRS _) doc   = buildSRS srsTeXParams doc
build (A.LPM _) doc   = buildLPM lpmTeXParams doc
build (A.Code _) _    = error "Unimplemented (See PrintTeX)"
build (A.Website _) _ = error "Cannot use TeX to typeset Website" --Can't happen

buildSRS :: [A.DocParams] -> Document -> Doc
buildSRS ((A.DocClass sb b1) : (A.UsePackages ps) : []) (Document t a c) =
  docclass sb b1 $$ listpackages ps $$ title (pCon Plain t) $$ 
  author (p_spec a) $$ begin $$ print c $$ endL
buildSRS _ _ = error "Invalid syntax in Document Parameters"

buildLPM :: [A.DocParams] -> Document -> Doc
buildLPM  ((A.DocClass sb b1) : (A.UsePackages ps) : xs) (Document t a c) =
  docclass sb b1 $$ listpackages ps $$ moreDocParams xs $$
  title (p_spec t) $$ author (p_spec a) $$ begin $$ print c $$ endL
buildLPM _ _ = error "Invalid syntax in Document Parameters"

moreDocParams :: [A.DocParams] -> Doc
moreDocParams []                 = empty
moreDocParams ((A.ExDoc f n):xs) = exdoc f n $$ moreDocParams xs
moreDocParams _                  = error "Unexpected document parameters"

listpackages :: [String] -> Doc
listpackages []     = empty
listpackages (p:[]) = usepackage p
listpackages (p:ps) = usepackage p $$ listpackages ps

printLO :: LayoutObj -> Doc
printLO (Section d t contents)  = sec d (pCon Plain t) $$ print contents
printLO (Paragraph contents)    = text (pCon Plain contents)
printLO (EqnBlock contents)     = text $ makeEquation contents
printLO (Table rows)            = makeTable rows
printLO (CodeBlock c)           = codeHeader $$ printCode c $$ codeFooter
printLO (Definition dtype ssPs) = makeDefn dtype ssPs
printLO (List lt is)            = makeList lt is

print :: [LayoutObj] -> Doc
print l = foldr ($$) empty $ map printLO l

-----------------------------------------------------------------
------------------BEGIN SPEC PRINTING----------------------------
-----------------------------------------------------------------

p_spec :: Spec -> String
p_spec (E ex)      = p_expr ex
p_spec (a :+: s)  = p_spec a ++ p_spec s
p_spec (a :-: s)  = p_spec a ++ "_" ++ brace (p_spec s)
p_spec (a :^: s)  = p_spec a ++ "^" ++ brace (p_spec s)
p_spec (a :/: s)  = "\\frac" ++ brace (p_spec a) ++ brace (p_spec s)
p_spec (S s)      = s
p_spec (N s)      = symbol s
p_spec (Sy s)     = runReader (uSymbPrint s) Plain
p_spec HARDNL     = "\\newline"

symbol :: Symbol -> String
symbol NA               = ""
symbol (Atomic s)       = s
symbol (Special s)      = render TeX s
symbol (Catenate s1 s2) = (symbol s1) ++ (symbol s2)
--
-- handle the special cases first, then general case
symbol (Corners [] [] [x] [] s) = (symbol s) ++"^"++ brace (symbol x)
symbol (Corners [] [] [] [x] s) = (symbol s) ++"_"++ brace (symbol x)
symbol (Corners [_] [] [] [] _) = error "rendering of ul prescript"
symbol (Corners [] [_] [] [] _) = error "rendering of ll prescript"
symbol (Corners _ _ _ _ _)      = error "rendering of Corners (general)"
symbol (FormatS f s) = sFormat f s

sFormat :: FormatC -> Symbol -> String
sFormat Hat    s = "\\hat{" ++ symbol s ++ "}"
sFormat Vector s = "\\mathbf{" ++ symbol s ++ "}"
sFormat Grave  s = "\\`{" ++ symbol s ++ "}"
sFormat Acute  s = "\\'{" ++ symbol s ++ "}"
-----------------------------------------------------------------
------------------BEGIN EXPRESSION PRINTING----------------------
-----------------------------------------------------------------
p_expr :: Expr -> String
p_expr (Var v)    = v
p_expr (Dbl d)    = show d
p_expr (Int i)    = show i
p_expr (Add x y)  = p_expr x ++ "+" ++ p_expr y
p_expr (Sub x y)  = p_expr x ++ "-" ++ p_expr y
p_expr (Mul x y)  = mul x y
p_expr (Frac n d) = fraction (p_expr n) (p_expr d) --Found in Helpers
p_expr (Div n d)  = p_expr n ++ "/" ++ p_expr d
p_expr (Pow x y)  = p_expr x ++ "^" ++ brace (p_expr y)
p_expr (Sym s)    = symbol s
p_expr (Eq x y)   = p_expr x ++ "=" ++ p_expr y
p_expr (Dot x y)  = p_expr x ++ "\\cdot{}" ++ p_expr y
p_expr (Neg x)    = neg x

mul :: Expr -> Expr -> String
mul x y@(Dbl _) = p_expr x ++ "*" ++ p_expr y
mul x y@(Int _) = p_expr x ++ "*" ++ p_expr y
mul x y         = p_expr x ++ p_expr y

neg :: Expr -> String
neg x@(Var _) = "-" ++ p_expr x
neg x@(Dbl _) = "-" ++ p_expr x
neg x@(Int _) = "-" ++ p_expr x
neg x@(Sym _) = "-" ++ p_expr x
neg   (Neg n) = p_expr n
neg x         = paren ("-" ++ p_expr x)

-----------------------------------------------------------------
------------------BEGIN TABLE PRINTING---------------------------
-----------------------------------------------------------------
  
makeTable :: [[Spec]] -> Doc
makeTable lls = text ("\\begin{longtable}" ++ brace (header lls)) 
  $$ makeRows lls $$ text "\\end{longtable}"
  where header l = concat (replicate ((length (head l))-1) "l ") ++ "p" ++ 
                        brace (show tableWidth ++ "cm")

makeRows :: [[Spec]] -> Doc
makeRows []     = empty
makeRows (c:cs) = text (makeColumns c) $$ dbs $$ makeRows cs

makeColumns :: [Spec] -> String
makeColumns ls = (concat $ intersperse " & " $ map (pCon Plain) ls) ++ "\\"

-----------------------------------------------------------------
------------------BEGIN READER-----------------------------------
-----------------------------------------------------------------

data Context = Equation | EqnB | Plain deriving (Show, Eq)

getCon :: Spec -> Context
getCon (a :+: _) = getCon a
getCon (S _)     = Plain
getCon (E _)     = Equation
getCon (_ :-: _) = Equation --Sub/superscripts must be in Equation ctxt.
getCon (_ :^: _) = Equation
getCon (_ :/: _) = Equation -- Fractions are always equations.
getCon (Sy _)    = Plain
getCon (N _)     = Equation
getCon HARDNL    = Plain


lPrint :: Spec -> Reader Context String
lPrint t@(s1 :+: s2) = do
  c <- ask
  let ca = getCon s1
  let cb = getCon s2
  case c of
    EqnB -> return $ makeEquation t
    _    -> return $ pCon ca s1 ++ pCon cb s2
    
lPrint t = do
  c <- ask
  let ct = getCon t
  case c of
    EqnB -> return $ makeEquation t
    _    ->
      case ct of
        Equation -> return $ dollar (p_spec t)
        Plain    -> return $ p_spec t
        EqnB     -> return $ makeEquation t 
          --This will never run right now, but maybe eventually.

bEq, eEq :: String    
bEq = "\\begin{equation} " 
eEq = "\\end{equation}"

pCon :: Context -> Spec -> String
pCon = \c t -> runReader (lPrint t) c

uSymbPrint :: USymb -> Reader Context String --To fix unit printing will need this.
uSymbPrint (Unitless) = do
  return "unitless"
uSymbPrint (UName n) = do
  c <- ask
  let cn = getSyCon n
  if c == cn then
    return $ symbol n
  else
    case cn of
      Equation -> return $ dollar $ symbol n 
      _        -> return $ symbol n
uSymbPrint (UProd l) = do
  c <- ask
  return $ foldr1 (\x -> if (x == "unitless") then (""++) else (++x)) 
    (map ((\ctxt t -> runReader t ctxt) c) (map uSymbPrint l))
uSymbPrint (UPow Unitless _) = do
  uSymbPrint Unitless
uSymbPrint (UPow n p) = do
  c <- ask
  case c of
    Plain -> return $ runReader (uSymbPrint n) c ++ dollar ("^" ++ brace (show p))
    _     -> return $ runReader (uSymbPrint n) c ++ "^" ++ brace (show p)
uSymbPrint (UDiv n Unitless) = do
  uSymbPrint n
uSymbPrint (UDiv Unitless d) = do
  c <- ask
  return $ "1/" ++ paren (runReader (uSymbPrint d) c)
uSymbPrint (UDiv n d) = do
  c <- ask
  case d of -- 4 possible cases, 2 need parentheses, 2 don't
    UProd _ -> return $ 
      runReader (uSymbPrint n) c ++ "/" ++ paren (runReader (uSymbPrint d) c)
    UDiv _ _ -> return $
      runReader (uSymbPrint n) c ++ "/" ++ paren (runReader (uSymbPrint d) c)
    _ -> return $ runReader (uSymbPrint n) c ++ "/" ++ runReader (uSymbPrint d) c
    
getSyCon :: Symbol -> Context
getSyCon NA                  = Plain
getSyCon (Atomic _)          = Plain
--getSyCon (Special Circle)  = Equation
  -- TODO: Need to figure this out, or figure out how to print catenations in a 
  --       better way.
getSyCon (Special _)         = Plain
getSyCon (Catenate s1 _)     = getSyCon s1
getSyCon (Corners _ _ _ _ s) = getSyCon s
getSyCon (FormatS _ s)       = getSyCon s

-----------------------------------------------------------------
------------------BEGIN DATA DEFINITION PRINTING-----------------
-----------------------------------------------------------------

makeDefn :: L.DType -> [(String,LayoutObj)] -> Doc
makeDefn _ []      = error "Empty definition"
makeDefn dt ps = beginDefn $$ makeDefTable dt ps $$ endDefn

beginDefn :: Doc
beginDefn = text "~" <>newline<+> text "\\noindent \\begin{minipage}{\\textwidth}"

endDefn :: Doc  
endDefn = text "\\end{minipage}" <> dbs

makeDefTable :: L.DType -> [(String,LayoutObj)] -> Doc
makeDefTable _ []            = error "Trying to make empty Data Defn"
makeDefTable dt ps@((_,d):_) = vcat [
  text $ "\\begin{tabular}{p{"++show colAwidth++"\\textwidth} p{"++show colBwidth++"\\textwidth}}",
  text "\\toprule \\textbf{Refname} & \\textbf{" <> defAc dt <> printLO d <> text "}",
  text "\\label{" <> defAc dt <> (printLO d) <> text "}",
  makeDRows ps, dbs <+> text ("\\bottomrule \\end{tabular}")
  ]
  where defAc L.Data = text "DD:"
        defAc L.Theory = text "T:"
        defAc L.General = text "GD:"

makeDRows :: [(String,LayoutObj)] -> Doc
makeDRows []         = error "No fields to create Defn table"
makeDRows ((f,d):[]) = dBoilerplate $$ text (f ++ " & ") <> printLO d
makeDRows ((f,d):ps) = dBoilerplate $$ text (f ++ " & ") <> printLO d $$ 
                        makeDRows ps
dBoilerplate :: Doc
dBoilerplate = dbs <+> text "\\midrule" <+> dbs 

-----------------------------------------------------------------
------------------BEGIN CODE BLOCK PRINTING----------------------
-----------------------------------------------------------------

codeHeader,codeFooter :: Doc
codeHeader = bslash <> text "begin" <> br "lstlisting"
codeFooter = bslash <> text "end" <> br "lstlisting"

-----------------------------------------------------------------
------------------BEGIN EQUATION PRINTING------------------------
-----------------------------------------------------------------

makeEquation :: Spec -> String
makeEquation contents = 
  ("\\begin{equation}" ++ p_spec contents ++ "\\end{equation}")
  --TODO: Add auto-generated labels -> Need to be able to ensure labeling based
  --  on chunk (i.e. "eq:h_g" for h_g = ...
  
-----------------------------------------------------------------
------------------BEGIN LIST PRINTING----------------------------
-----------------------------------------------------------------

makeList :: ListType -> [Spec] -> Doc
makeList t items = b (show t) $$ vcat (map item items) $$ e (show t)

item :: Spec -> Doc
item = \s -> text ("\\item " ++ pCon Plain s)