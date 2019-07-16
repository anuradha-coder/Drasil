{-# LANGUAGE GADTs #-}
module Language.Drasil.CodeSpec where

import Language.Drasil
import Database.Drasil(ChunkDB, SystemInformation(SI), symbLookup, symbolTable,
  _constants,
  _constraints, _datadefs,
  _definitions, _inputs, _outputs,
  _quants, _sys, _sysinfodb)
import Language.Drasil.Development (dep, names', namesRI)
import Theory.Drasil (DataDefinition, qdFromDD)

import Language.Drasil.Chunk.Code (CodeChunk, CodeDefinition, CodeIdea, 
  ConstraintMap, codevar, codefunc, codeEquat, funcPrefix, codeName, 
  spaceToCodeType, toCodeName, constraintMap, qtov, qtoc, codeType)
import Language.Drasil.Code.Code (CodeType)
import Language.Drasil.Code.DataDesc (DataDesc, getInputs)

import Control.Lens ((^.))
import Data.List (nub, delete, (\\))
import qualified Data.Map as Map
import Data.Maybe (maybeToList, catMaybes, mapMaybe)

import Prelude hiding (const)

type Input = CodeChunk
type Output = CodeChunk
type Const = CodeDefinition
type Derived = CodeDefinition
type Def = CodeDefinition

data Lang = Cpp
          | CSharp
          | Java
          | Python
          deriving Eq

data CodeSystInfo where
  CSI :: {
  extInputs :: [Input],
  derivedInputs :: [Derived],
  outputs :: [Output],
  execOrder :: [Def],
  cMap :: ConstraintMap,
  constants :: [Const],
  mods :: [Mod],  -- medium hack
  sysinfodb :: ChunkDB
  } -> CodeSystInfo

data CodeSpec where
  CodeSpec :: CommonIdea a => {
  program :: a,
  inputs :: [Input],
  relations :: [Def],
  fMap :: FunctionMap,
  vMap :: VarMap,
  eMap :: ModExportMap,
  constMap :: FunctionMap,
  dMap :: ModDepMap,
  csi :: CodeSystInfo
  } -> CodeSpec

type FunctionMap = Map.Map String CodeDefinition
type VarMap      = Map.Map String CodeChunk

assocToMap :: CodeIdea a => [a] -> Map.Map String a
assocToMap = Map.fromList . map (\x -> (codeName x, x))
        
varType :: String -> VarMap -> CodeType
varType cname m = maybe (error "Variable not found") codeType (Map.lookup cname m)

codeSpec :: SystemInformation -> Choices -> [Mod] -> CodeSpec
codeSpec SI {_sys = sys
              , _quants = q
              , _definitions = defs'
              , _datadefs = ddefs
              , _inputs = ins
              , _outputs = outs
              , _constraints = cs
              , _constants = consts
              , _sysinfodb = db} chs ms = 
  let inputs' = map codevar ins
      const' = map qtov consts
      derived = map qtov $ getDerivedInputs ddefs defs' inputs' const' db
      rels = map qtoc (defs' ++ map qdFromDD ddefs) \\ derived
      mem   = modExportMap csi' chs
      outs' = map codevar outs
      allInputs = nub $ inputs' ++ map codevar derived
      exOrder = getExecOrder rels (allInputs ++ map codevar const') outs' db
      csi' = CSI {
        extInputs = inputs',
        derivedInputs = derived,
        outputs = outs',
        execOrder = exOrder,
        cMap = constraintMap cs,
        constants = const',
        mods = prefixFunctions $ packmod "Calculations" 
          "Provides functions for calculating the outputs" 
          (map FCD exOrder) : ms,
        sysinfodb = db
      }
  in  CodeSpec {
        program = sys,
        inputs = allInputs,
        relations = rels,
        fMap = assocToMap rels,
        vMap = assocToMap (map codevar q),
        eMap = mem,
        constMap = assocToMap const',
        dMap = modDepMap csi' mem chs,
        csi = csi'
      }

data Choices = Choices {
  lang :: [Lang],
  impType :: ImplementationType,
  logFile :: String,
  logging :: Logging,
  comments :: [Comments],
  onSfwrConstraint :: ConstraintBehaviour,
  onPhysConstraint :: ConstraintBehaviour,
  inputStructure :: Structure,
  inputModule :: InputModule
}

data ImplementationType = Library
                        | Program

data Logging = LogNone
             | LogFunc
             | LogVar
             | LogAll
             
data Comments = CommentFunc
              | CommentClass
              | CommentMod deriving Eq
             
data ConstraintBehaviour = Warning
                         | Exception
                         
data Structure = Unbundled
               | Bundled

data InputModule = Combined
                 | Separated
             
defaultChoices :: Choices
defaultChoices = Choices {
  lang = [Python],
  impType = Program,
  logFile = "log.txt",
  logging = LogNone,
  comments = [],
  onSfwrConstraint = Exception,
  onPhysConstraint = Warning,
  inputStructure = Bundled,
  inputModule = Combined
}

type Name = String

-- medium hacks ---
relToQD :: ExprRelat c => ChunkDB -> c -> QDefinition
relToQD sm r = convertRel sm (r ^. relat)

convertRel :: ChunkDB -> Expr -> QDefinition
convertRel sm (BinaryOp Eq (C x) r) = ec (symbLookup x $ symbolTable sm) r
convertRel _ _ = error "Conversion failed"

data Mod = Mod Name String [Func]

packmod :: Name -> String -> [Func] -> Mod
packmod n = Mod (toCodeName n)

data DMod = DMod [Name] Mod
     
data Func = FCD CodeDefinition
          | FDef FuncDef
          | FData FuncData

funcQD :: QDefinition -> Func
funcQD qd = FCD $ qtoc qd 

funcData :: Name -> String -> DataDesc -> Func
funcData n desc d = FData $ FuncData (toCodeName n) desc d

funcDef :: (Quantity c, MayHaveUnit c) => Name -> String -> [c] -> Space -> [FuncStmt] -> Func  
funcDef s desc i t fs  = FDef $ FuncDef (toCodeName s) desc (map codevar i) (spaceToCodeType t) fs 
     
data FuncData where
  FuncData :: Name -> String -> DataDesc -> FuncData
  
data FuncDef where
  FuncDef :: Name -> String -> [CodeChunk] -> CodeType -> [FuncStmt] -> FuncDef
 
data FuncStmt where
  FAsg :: CodeChunk -> Expr -> FuncStmt
  FFor :: CodeChunk -> Expr -> [FuncStmt] -> FuncStmt
  FWhile :: Expr -> [FuncStmt] -> FuncStmt
  FCond :: Expr -> [FuncStmt] -> [FuncStmt] -> FuncStmt
  FRet :: Expr -> FuncStmt
  FThrow :: String -> FuncStmt
  FTry :: [FuncStmt] -> [FuncStmt] -> FuncStmt
  FContinue :: FuncStmt
  FDec :: CodeChunk -> CodeType -> FuncStmt
  FProcCall :: Func -> [Expr] -> FuncStmt
  -- slight hack, for now
  FAppend :: Expr -> Expr -> FuncStmt
  
($:=) :: (Quantity c, MayHaveUnit c) => c -> Expr -> FuncStmt
v $:= e = FAsg (codevar v) e

ffor :: (Quantity c, MayHaveUnit c) => c -> Expr -> [FuncStmt] -> FuncStmt
ffor v = FFor (codevar  v)

fdec :: (Quantity c, MayHaveUnit c) => c -> FuncStmt
fdec v  = FDec (codevar  v) (spaceToCodeType $ v ^. typ)

asVC :: Func -> QuantityDict
asVC (FDef (FuncDef n _ _ _ _)) = implVar n (nounPhraseSP n) (Atomic n) Real
asVC (FData (FuncData n _ _)) = implVar n (nounPhraseSP n) (Atomic n) Real
asVC (FCD cd) = codeVC cd (codeSymb cd) (cd ^. typ)

asExpr :: Func -> Expr
asExpr f = sy $ asVC f

-- FIXME: hack. Use for implementation-stage functions that need to be displayed in the SRS.
asExpr' :: Func -> Expr
asExpr' f = sy $ asVC' f

-- FIXME: Part of above hack
asVC' :: Func -> QuantityDict
asVC' (FDef (FuncDef n _ _ _ _)) = vc n (nounPhraseSP n) (Atomic n) Real
asVC' (FData (FuncData n _ _)) = vc n (nounPhraseSP n) (Atomic n) Real
asVC' (FCD cd) = vc'' cd (codeSymb cd) (cd ^. typ)


-- name of variable/function maps to module name
type ModExportMap = Map.Map String String

modExportMap :: CodeSystInfo -> Choices -> ModExportMap
modExportMap cs@CSI {
  extInputs = ins,
  derivedInputs = ds
  } chs = Map.fromList $ concatMap mpair (mods cs)
  where mpair (Mod n _ fs) = map fname fs `zip` repeat n
                        ++ getExportInput chs (ins ++ map codevar ds)
                        ++ getExportDerived chs ds
                        ++ getExportConstraints chs (getConstraints (cMap cs) 
                          (ins ++ map codevar ds))
                        ++ getExportInputFormat ins
                        ++ getExportOutput (outputs cs)
                     --   ++ map codeName consts `zip` repeat "Constants"
                     -- inlining constants for now
          
type ModDepMap = Map.Map String [String]

modDepMap :: CodeSystInfo -> ModExportMap -> Choices -> ModDepMap
modDepMap cs mem chs = Map.fromList $ map (\m@(Mod n _ _) -> (n, getModDep m)) 
  (mods cs) ++ ("Control", getDepsControl cs mem)
  : catMaybes [getDepsDerived cs mem chs,
               getDepsConstraints cs mem chs,
               getDepsInFormat chs]
  where getModDep (Mod name' _ funcs) =
          delete name' $ nub $ concatMap getDep (concatMap fdep funcs)
        getDep n = maybeToList (Map.lookup n mem)
        fdep (FCD cd) = codeName cd:map codeName (codevarsandfuncs (codeEquat cd) sm mem)
        fdep (FDef (FuncDef _ _ i _ fs)) = map codeName (i ++ concatMap (fstdep sm ) fs)
        fdep (FData (FuncData _ _ d)) = map codeName $ getInputs d
        sm = sysinfodb cs

fstdep :: ChunkDB -> FuncStmt -> [CodeChunk]
fstdep _  (FDec cch _) = [cch]
fstdep sm (FAsg cch e) = cch:codevars e sm
fstdep sm (FFor cch e fs) = delete cch $ nub (codevars  e sm ++ concatMap (fstdep sm ) fs)
fstdep sm (FWhile e fs) = codevars e sm ++ concatMap (fstdep sm ) fs
fstdep sm (FCond e tfs efs)  = codevars e sm ++ concatMap (fstdep sm ) tfs ++ concatMap (fstdep sm ) efs
fstdep sm (FRet e)  = codevars  e sm
fstdep sm (FTry tfs cfs) = concatMap (fstdep sm ) tfs ++ concatMap (fstdep sm ) cfs
fstdep _  (FThrow _) = [] -- is this right?
fstdep _  FContinue = []
fstdep sm (FProcCall f l)  = codefunc (asVC f) : concatMap (`codevars` sm) l
fstdep sm (FAppend a b)  = nub (codevars  a sm ++ codevars  b sm)

fstdecl :: ChunkDB -> [FuncStmt] -> [CodeChunk]
fstdecl ctx fsts = nub (concatMap (fstvars ctx) fsts) \\ nub (concatMap (declared ctx) fsts) 
  where
    fstvars :: ChunkDB -> FuncStmt -> [CodeChunk]
    fstvars _  (FDec cch _) = [cch]
    fstvars sm (FAsg cch e) = cch:codevars' e sm
    fstvars sm (FFor cch e fs) = delete cch $ nub (codevars' e sm ++ concatMap (fstvars sm) fs)
    fstvars sm (FWhile e fs) = codevars' e sm ++ concatMap (fstvars sm) fs
    fstvars sm (FCond e tfs efs) = codevars' e sm ++ concatMap (fstvars sm) tfs ++ concatMap (fstvars sm) efs
    fstvars sm (FRet e) = codevars' e sm
    fstvars sm (FTry tfs cfs) = concatMap (fstvars sm) tfs ++ concatMap (fstvars sm ) cfs
    fstvars _  (FThrow _) = [] -- is this right?
    fstvars _  FContinue = []
    fstvars sm (FProcCall _ l) = concatMap (`codevars` sm) l
    fstvars sm (FAppend a b) = nub (codevars a sm ++ codevars b sm)

    declared :: ChunkDB -> FuncStmt -> [CodeChunk]
    declared _  (FDec cch _) = [cch]
    declared _  (FAsg _ _) = []
    declared sm (FFor _ _ fs) = concatMap (declared sm) fs
    declared sm (FWhile _ fs) = concatMap (declared sm) fs
    declared sm (FCond _ tfs efs) = concatMap (declared sm) tfs ++ concatMap (declared sm) efs
    declared _  (FRet _) = []
    declared sm (FTry tfs cfs) = concatMap (declared sm) tfs ++ concatMap (declared sm) cfs
    declared _  (FThrow _) = [] -- is this right?
    declared _  FContinue = []
    declared _  (FProcCall _ _) = []
    declared _  (FAppend _ _) = []
       
fname :: Func -> Name       
fname (FCD cd) = codeName cd
fname (FDef (FuncDef n _ _ _ _)) = n
fname (FData (FuncData n _ _)) = n 

prefixFunctions :: [Mod] -> [Mod]
prefixFunctions = map (\(Mod nm desc fs) -> Mod nm desc $ map pfunc fs)
  where pfunc f@(FCD _) = f
        pfunc (FData (FuncData n desc d)) = FData (FuncData (funcPrefix ++ n) 
          desc d)
        pfunc (FDef (FuncDef n desc a t f)) = FDef (FuncDef (funcPrefix ++ n)
          desc a t f)

getDerivedInputs :: [DataDefinition] -> [QDefinition] -> [Input] -> [Const] ->
  ChunkDB -> [QDefinition]
getDerivedInputs ddefs defs' ins consts sm  =
  let refSet = ins ++ map codevar consts
  in  if null ddefs then filter ((`subsetOf` refSet) . flip codevars sm . (^.equat)) defs'
      else filter ((`subsetOf` refSet) . flip codevars sm . (^.defnExpr)) (map qdFromDD ddefs)

type Known = CodeChunk
type Need  = CodeChunk

getExecOrder :: [Def] -> [Known] -> [Need] -> ChunkDB -> [Def]
getExecOrder d k' n' sm  = getExecOrder' [] d k' (n' \\ k')
  where getExecOrder' ord _ _ []   = ord
        getExecOrder' ord defs' k n = 
          let new  = filter ((`subsetOf` k) . flip codevars' sm . codeEquat) defs'
              cnew = map codevar new
              kNew = k ++ cnew
              nNew = n \\ cnew
          in  if null new 
              then error ("Cannot find path from inputs to outputs: " ++
                        show (map (^. uid) n)
                        ++ " given Defs as " ++ show (map (^. uid) defs')
                        ++ " and Knowns as " ++ show (map (^. uid) k) )
              else getExecOrder' (ord ++ new) (defs' \\ new) kNew nNew
  
type Export = (String, String)

getExportInput :: Choices -> [Input] -> [Export]
getExportInput _ [] = []
getExportInput chs ins = inExp $ inputStructure chs
  where inExp Unbundled = []
        inExp Bundled = map codeName ins `zip` repeat "InputParameters"

getExportDerived :: Choices -> [Derived] -> [Export]
getExportDerived _ [] = []
getExportDerived chs _ = [("derived_values", dMod $ inputStructure chs)]
  where dMod Unbundled = "InputParameters"
        dMod Bundled = "DerivedValues"

getExportConstraints :: Choices -> [Constraint] -> [Export]
getExportConstraints _ [] = []
getExportConstraints chs _ = [("input_constraints", cMod $ inputStructure chs)]
  where cMod Unbundled = "InputParameters"
        cMod Bundled = "InputConstraints"
        
getExportInputFormat :: [Input] -> [Export]
getExportInputFormat [] = []
getExportInputFormat _ = [("get_input", "InputFormat")]

getExportOutput :: [Output] -> [Export]
getExportOutput [] = []
getExportOutput _ = [("write_output", "OutputFormat")]

getDepsControl :: CodeSystInfo -> ModExportMap -> [String]
getDepsControl cs mem = 
  let ins = extInputs cs ++ map codevar (derivedInputs cs)
      ip = map (\x -> Map.lookup (codeName x) mem) ins
      inf = Map.lookup "get_input" mem
      dv = Map.lookup "derived_values" mem
      ic = Map.lookup "input_constraints" mem
      wo = Map.lookup "write_output" mem
      calcs = map (\x -> Map.lookup (codeName x) mem) (execOrder cs)
  in nub $ catMaybes (ip ++ [inf, dv, ic, wo] ++ calcs)

getDepsDerived :: CodeSystInfo -> ModExportMap -> Choices -> 
  Maybe (String, [String])
getDepsDerived cs mem chs = derivedDeps $ inputStructure chs
  where derivedDeps Unbundled = Nothing
        derivedDeps Bundled = Just ("DerivedValues", nub $ mapMaybe (
          (`Map.lookup` mem) . codeName) (concatMap (flip codevars 
          (sysinfodb cs) . codeEquat) (derivedInputs cs)))

getDepsConstraints :: CodeSystInfo -> ModExportMap -> Choices -> 
  Maybe (String, [String])
getDepsConstraints cs mem chs = constraintDeps $ inputStructure chs
  where constraintDeps Unbundled = Nothing
        constraintDeps Bundled = Just ("InputConstraints", nub $ mapMaybe (
          (`Map.lookup` mem) .codeName) reqdVals)
        ins = extInputs cs ++ map codevar (derivedInputs cs)
        cm = cMap cs
        varsList = filter (\i -> Map.member (i ^. uid) cm) ins
        reqdVals = nub $ varsList ++ concatMap (\v -> constraintvarsandfuncs v
          (sysinfodb cs) mem) (getConstraints cm varsList)

getDepsInFormat :: Choices -> Maybe (String, [String])
getDepsInFormat chs = inFormatDeps $ inputStructure chs
  where inFormatDeps Unbundled = Nothing
        inFormatDeps Bundled = Just ("InputFormat", ["InputParameters"])

subsetOf :: (Eq a) => [a] -> [a] -> Bool
xs `subsetOf` ys = all (`elem` ys) xs

-- | Get a list of Constraints for a list of CodeChunks
getConstraints :: ConstraintMap -> [CodeChunk] -> [Constraint]
getConstraints cm cs = concat $ mapMaybe (\c -> Map.lookup (c ^. uid) cm) cs

-- | Get a list of CodeChunks from an equation
codevars :: Expr -> ChunkDB -> [CodeChunk]
codevars e m = map resolve $ dep e
  where resolve x = codevar (symbLookup x $ symbolTable m)

-- | Get a list of CodeChunks from an equation (no functions)
codevars' :: Expr -> ChunkDB -> [CodeChunk]
codevars' e m = map resolve $ nub $ names' e
  where  resolve x = codevar (symbLookup x (symbolTable m))

-- | Get a list of CodeChunks from an equation, where the CodeChunks are correctly parameterized by either Var or Func
codevarsandfuncs :: Expr -> ChunkDB -> ModExportMap -> [CodeChunk]
codevarsandfuncs e m mem = map resolve $ dep e
  where resolve x 
          | Map.member (funcPrefix ++ x) mem = codefunc (symbLookup x $ symbolTable m)
          | otherwise = codevar (symbLookup x $ symbolTable m)

-- | Get a list of CodeChunks from a constraint, where the CodeChunks are correctly parameterized by either Var or Func
constraintvarsandfuncs :: Constraint -> ChunkDB -> ModExportMap ->  [CodeChunk]
constraintvarsandfuncs (Range _ ri) m mem = map resolve $ nub $ namesRI ri
  where resolve x 
          | Map.member (funcPrefix ++ x) mem = codefunc (symbLookup x $ symbolTable m)
          | otherwise = codevar (symbLookup x $ symbolTable m)
constraintvarsandfuncs _ _ _ = []