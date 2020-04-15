{-# LANGUAGE TypeFamilies #-}

-- | The logic to render Python code is contained in this module
module GOOL.Drasil.LanguageRenderer.PythonRenderer (
  -- * Python Code Configuration -- defines syntax of all Python code
  PythonCode(..)
) where

import Utils.Drasil (blank, indent)

import GOOL.Drasil.CodeType (CodeType(..))
import GOOL.Drasil.ClassInterface (Label, MSBody, VSType, SVariable, SValue, 
  MSStatement, MSParameter, SMethod, ProgramSym(..), FileSym(..), 
  PermanenceSym(..), BodySym(..), bodyStatements, oneLiner, BlockSym(..), 
  TypeSym(..), ControlBlock(..), VariableSym(..), 
  listOf, ValueSym(..), Literal(..), MathConstant(..), VariableValue(..), CommandLineArgs(..), NumericExpression(..), BooleanExpression(..), Comparison(..),
  ValueExpression(..), funcApp, selfFuncApp, extFuncApp, extNewObj, 
  InternalValueExp(..), objMethodCall,
  objMethodCallNoParams, FunctionSym(..), ($.), GetSet(..), List(..), InternalList(..), at, Iterator(..),
  StatementSym(..), AssignStatement(..), (&=), DeclStatement(..), 
  IOStatement(..), StringStatement(..), FuncAppStatement(..), CommentStatement(..), observerListName, 
  ControlStatement(..), switchAsIf, StatePattern(..), ObserverPattern(..), StrategyPattern(..), ScopeSym(..), ParameterSym(..), 
  MethodSym(..), StateVarSym(..), ClassSym(..), ModuleSym(..), ODEInfo(..), 
  ODEOptions(..), ODEMethod(..))
import GOOL.Drasil.RendererClasses (VSUnOp, RenderSym, InternalFile(..),
  ImportSym(..), ImportElim(..), PermElim(..), InternalBody(..), InternalBlock(..), 
  InternalType(..), UnaryOpSym(..), BinaryOpSym(..), InternalOp(..), 
  InternalVariable(..), InternalValue(..), InternalGetSet(..), InternalListFunc(..), InternalIterator(..), InternalFunction(..), InternalAssignStmt(..), InternalIOStmt(..), InternalControlStmt(..),
  InternalStatement(..), InternalScope(..), MethodTypeSym(..), 
  InternalParam(..), InternalMethod(..), InternalStateVar(..), 
  InternalClass(..), InternalMod(..), BlockCommentSym(..))
import GOOL.Drasil.LanguageRenderer (multiStateDocD, bodyDocD, outDoc, 
  destructorError, multiAssignDoc, returnDocD, mkStNoEnd, breakDocD, 
  continueDocD, mkStateVal, mkVal, mkStateVar, classVarDocD, listSetFuncDocD, 
  castObjDocD, dynamicDocD, bindingError, classDec, dot, forLabel, inLabel, 
  commentedItem, addCommentsDocD, commentedModD, docFuncRepr, valueList, 
  variableList, parameterList, surroundBody)
import qualified GOOL.Drasil.LanguageRenderer.LanguagePolymorphic as G (
  multiBody, block, multiBlock, int, listInnerType, obj, funcType, runStrategy, 
  notOp', negateOp, sqrtOp', absOp', expOp', sinOp', cosOp', tanOp', asinOp', 
  acosOp', atanOp', csc, sec, cot, equalOp, notEqualOp, greaterOp, 
  greaterEqualOp, lessOp, lessEqualOp, plusOp, minusOp, multOp, divideOp, 
  moduloOp, var, staticVar, extVar, classVar, objVar, objVarSelf, listVar, 
  arrayElem, iterVar, litChar, litDouble, litInt, litString, valueOf, arg, 
  argsList, objAccess, objMethodCall, objMethodCallNoParams, indexOf, call, 
  funcAppMixedArgs, selfFuncAppMixedArgs, extFuncAppMixedArgs, newObjMixedArgs, 
  extNewObjMixedArgs, lambda, func, get, set, listAdd, listAppend, iterBegin, 
  iterEnd, listAccess, listSet, getFunc, setFunc, listAddFunc, listAppendFunc, 
  iterBeginError, iterEndError, listAccessFunc, listSetFunc, state, loopState, 
  emptyState, assign, decrement, increment', increment1', decrement1, 
  listDecDef', objDecNew, objDecNewNoParams, closeFile, discardFileLine, 
  stringListVals, stringListLists, returnState, valState, comment, throw, 
  ifCond, ifExists, tryCatch, checkState, construct, param, method, getMethod, 
  setMethod, constructor, function, docFunc, stateVarDef, constVar, buildClass, 
  implementingClass, docClass, commentedClass, intClass, buildModule, 
  modFromData, fileDoc, docMod, fileFromData)
import GOOL.Drasil.LanguageRenderer.LanguagePolymorphic (unOpPrec, unExpr, 
  unExpr', typeUnExpr, powerPrec, multPrec, andPrec, orPrec, binExpr, 
  typeBinExpr, addmathImport)
import GOOL.Drasil.AST (Terminator(..), ScopeTag(..), FileType(..), 
  FileData(..), fileD, FuncData(..), fd, ModData(..), md, updateMod, 
  MethodData(..), mthd, updateMthd, OpData(..), od, ParamData(..), pd, 
  ProgData(..), progD, TypeData(..), td, ValData(..), vd, VarData(..), vard)
import GOOL.Drasil.Helpers (vibcat, emptyIfEmpty, toCode, toState, onCodeValue,
  onStateValue, on2CodeValues, on2StateValues, on3CodeValues, on3StateValues,
  onCodeList, onStateList, on2StateLists, on1StateValue1List)
import GOOL.Drasil.State (VS, lensGStoFS, lensMStoVS, lensVStoMS, revFiles,
  addLangImportVS, getLangImports, addLibImport, addLibImportVS, getLibImports, 
  addModuleImport, addModuleImportVS, getModuleImports, setFileType, 
  getClassName, setCurrMain, getClassMap, setMainDoc, getMainDoc)

import Prelude hiding (break,print,sin,cos,tan,floor,(<>))
import Data.Maybe (fromMaybe)
import Control.Lens.Zoom (zoom)
import Control.Applicative (Applicative)
import Control.Monad (join)
import Control.Monad.State (modify)
import Data.List (intercalate, sort)
import qualified Data.Map as Map (lookup)
import Text.PrettyPrint.HughesPJ (Doc, text, (<>), (<+>), parens, empty, equals,
  vcat, colon, brackets, isEmpty)

pyExt :: String
pyExt = "py"

newtype PythonCode a = PC {unPC :: a}

instance Functor PythonCode where
  fmap f (PC x) = PC (f x)

instance Applicative PythonCode where
  pure = PC
  (PC f) <*> (PC x) = PC (f x)

instance Monad PythonCode where
  return = PC
  PC x >>= f = f x

instance ProgramSym PythonCode where
  type Program PythonCode = ProgData 
  prog n files = do
    fs <- mapM (zoom lensGStoFS) files
    modify revFiles
    return $ onCodeList (progD n) fs

instance RenderSym PythonCode

instance FileSym PythonCode where
  type RenderFile PythonCode = FileData
  fileDoc m = modify (setFileType Combined) >> G.fileDoc pyExt top bottom m

  docMod = G.docMod pyExt

instance InternalFile PythonCode where
  top _ = toCode empty
  bottom = toCode empty
  
  commentedMod cmt m = on2StateValues (on2CodeValues commentedModD) m cmt

  fileFromData = G.fileFromData (\m fp -> onCodeValue (fileD fp) m)

instance ImportSym PythonCode where
  type Import PythonCode = Doc
  langImport n = toCode $ text $ "import " ++ n
  modImport = langImport

instance ImportElim PythonCode where
  importDoc = unPC

instance PermanenceSym PythonCode where
  type Permanence PythonCode = Doc
  static = toCode empty
  dynamic = toCode dynamicDocD

instance PermElim PythonCode where
  permDoc = unPC
  binding = error $ bindingError pyName

instance BodySym PythonCode where
  type Body PythonCode = Doc
  body = onStateList (onCodeList bodyDocD)

  addComments s = onStateValue (onCodeValue (addCommentsDocD s pyCommentStart))

instance InternalBody PythonCode where
  bodyDoc = unPC
  docBody = onStateValue toCode
  multiBody = G.multiBody 

instance BlockSym PythonCode where
  type Block PythonCode = Doc
  block = G.block

instance InternalBlock PythonCode where
  blockDoc = unPC
  docBlock = onStateValue toCode
  multiBlock = G.multiBlock

instance TypeSym PythonCode where
  type Type PythonCode = TypeData
  bool = toState $ typeFromData Boolean "" empty
  int = G.int
  float = error "Floats unavailable in Python, use Doubles instead"
  double = toState $ typeFromData Double "float" (text "float")
  char = toState $ typeFromData Char "" empty
  string = pyStringType
  infile = toState $ typeFromData File "" empty
  outfile = toState $ typeFromData File "" empty
  listType = onStateValue (\t -> typeFromData (List (getType t)) "[]" 
    (brackets empty))
  arrayType = listType
  listInnerType = G.listInnerType
  obj = G.obj
  -- enumType = G.enumType
  funcType = G.funcType
  iterator t = t
  void = toState $ typeFromData Void "NoneType" (text "NoneType")

  getType = cType . unPC
  getTypeString = typeString . unPC

instance InternalType PythonCode where
  getTypeDoc = typeDoc . unPC
  typeFromData t s d = toCode $ td t s d

instance ControlBlock PythonCode where
  solveODE info opts = modify (addLibImport odeLib) >> multiBlock [
    block [
      r &= objMethodCall odeT (extNewObj odeLib odeT 
      [lambda [iv, dv] (ode info)]) 
        "set_integrator" (pyODEMethod (solveMethod opts) ++
          [absTol opts >>= (mkStateVal double . (text "atol=" <>) . valueDoc),
          relTol opts >>= (mkStateVal double . (text "rtol=" <>) . valueDoc)]),
      valState $ objMethodCall odeT rVal "set_initial_value" [initVal info]],
    block [
      listDecDef iv [tInit info],
      listDecDef dv [initVal info],
      while (objMethodCallNoParams bool rVal "successful" ?&& 
        r_t ?< tFinal info) (bodyStatements [
          valState $ objMethodCall odeT rVal "integrate" [r_t #+ stepSize opts],
          valState $ listAppend (valueOf iv) r_t,
          valState $ listAppend (valueOf dv) (listAccess r_y $ litInt 0)
        ])
     ]
   ]
   where odeLib = "scipy.integrate"
         iv = indepVar info
         dv = depVar info
         odeT = obj "ode"
         r = var "r" odeT
         rVal = valueOf r
         r_t = valueOf $ objVar r (var "t" $ listInnerType $ onStateValue 
           variableType iv)
         r_y = valueOf $ objVar r (var "y" $ onStateValue variableType dv)

instance UnaryOpSym PythonCode where
  type UnaryOp PythonCode = OpData
  notOp = G.notOp'
  negateOp = G.negateOp
  sqrtOp = G.sqrtOp'
  absOp = G.absOp'
  logOp = pyLogOp
  lnOp = pyLnOp
  expOp = G.expOp'
  sinOp = G.sinOp'
  cosOp = G.cosOp'
  tanOp = G.tanOp'
  asinOp = G.asinOp'
  acosOp = G.acosOp'
  atanOp = G.atanOp'
  floorOp = addmathImport $ unOpPrec "math.floor"
  ceilOp = addmathImport $ unOpPrec "math.ceil"

instance BinaryOpSym PythonCode where
  type BinaryOp PythonCode = OpData
  equalOp = G.equalOp
  notEqualOp = G.notEqualOp
  greaterOp = G.greaterOp
  greaterEqualOp = G.greaterEqualOp
  lessOp = G.lessOp
  lessEqualOp = G.lessEqualOp
  plusOp = G.plusOp
  minusOp = G.minusOp
  multOp = G.multOp
  divideOp = G.divideOp
  powerOp = powerPrec "**"
  moduloOp = G.moduloOp
  andOp = andPrec "and"
  orOp = orPrec "or"

instance InternalOp PythonCode where
  uOpDoc = opDoc . unPC
  bOpDoc = opDoc . unPC
  uOpPrec = opPrec . unPC
  bOpPrec = opPrec . unPC
  
  uOpFromData p d = toState $ toCode $ od p d
  bOpFromData p d = toState $ toCode $ od p d

instance VariableSym PythonCode where
  type Variable PythonCode = VarData
  var = G.var
  staticVar = G.staticVar
  const = var
  extVar l n t = modify (addModuleImportVS l) >> G.extVar l n t
  self = zoom lensVStoMS getClassName >>= (\l -> mkStateVar "self" (obj l) (text "self"))
  -- enumVar = G.enumVar
  classVar = G.classVar classVarDocD
  extClassVar c v = join $ on2StateValues (\t cm -> maybe id ((>>) . modify . 
    addModuleImportVS) (Map.lookup (getTypeString t) cm) $ 
    G.classVar pyClassVar (toState t) v) c getClassMap
  objVar = G.objVar
  objVarSelf = G.objVarSelf
  listVar = G.listVar
  arrayElem i = G.arrayElem (litInt i)
  iterVar = G.iterVar

  variableName = varName . unPC
  variableType = onCodeValue varType

instance InternalVariable PythonCode where
  variableBind = varBind . unPC
  variableDoc = varDoc . unPC
  varFromData b n t d = on2CodeValues (vard b n) t (toCode d)

instance ValueSym PythonCode where
  type Value PythonCode = ValData
  valueType = onCodeValue valType

instance Literal PythonCode where
  litTrue = mkStateVal bool (text "True")
  litFalse = mkStateVal bool (text "False")
  litChar = G.litChar
  litDouble = G.litDouble
  litFloat = error "Floats unavailable in Python, use Doubles instead"
  litInt = G.litInt
  litString = G.litString
  litArray t es = sequence es >>= (\elems -> mkStateVal (arrayType t) 
    (brackets $ valueList elems))
  litList = litArray

instance MathConstant PythonCode where
  pi = addmathImport $ mkStateVal double (text "math.pi")

instance VariableValue PythonCode where
  valueOf = G.valueOf

instance CommandLineArgs PythonCode where
  arg n = G.arg (litInt $ n+1) argsList
  argsList = modify (addLangImportVS "sys") >> G.argsList "sys.argv"
  argExists i = listSize argsList ?> litInt (fromIntegral $ i+1)

instance NumericExpression PythonCode where
  (#~) = unExpr' negateOp
  (#/^) = unExpr sqrtOp
  (#|) = unExpr absOp
  (#+) = binExpr plusOp
  (#-) = binExpr minusOp
  (#*) = binExpr multOp
  (#/) v1' v2' = join $ on2StateValues (\v1 v2 -> pyDivision (getType $ 
    valueType v1) (getType $ valueType v2) v1' v2') v1' v2'
    where pyDivision Integer Integer = binExpr (multPrec "//")
          pyDivision _ _ = binExpr divideOp
  (#%) = binExpr moduloOp
  (#^) = binExpr powerOp

  log = unExpr logOp
  ln = unExpr lnOp
  exp = unExpr expOp
  sin = unExpr sinOp
  cos = unExpr cosOp
  tan = unExpr tanOp
  csc = G.csc
  sec = G.sec
  cot = G.cot
  arcsin = unExpr asinOp
  arccos = unExpr acosOp
  arctan = unExpr atanOp
  floor = unExpr floorOp
  ceil = unExpr ceilOp

instance BooleanExpression PythonCode where
  (?!) = typeUnExpr notOp bool
  (?&&) = typeBinExpr andOp bool
  (?||) = typeBinExpr orOp bool

instance Comparison PythonCode where
  (?<) = typeBinExpr lessOp bool
  (?<=) = typeBinExpr lessEqualOp bool
  (?>) = typeBinExpr greaterOp bool
  (?>=) = typeBinExpr greaterEqualOp bool
  (?==) = typeBinExpr equalOp bool
  (?!=) = typeBinExpr notEqualOp bool

instance ValueExpression PythonCode where
  inlineIf = pyInlineIf

  funcAppMixedArgs = G.funcAppMixedArgs
  selfFuncAppMixedArgs = G.selfFuncAppMixedArgs dot self
  extFuncAppMixedArgs l n t ps ns = modify (addModuleImportVS l) >> 
    G.extFuncAppMixedArgs l n t ps ns
  libFuncAppMixedArgs l n t ps ns = modify (addLibImportVS l) >> 
    G.extFuncAppMixedArgs l n t ps ns
  newObjMixedArgs = G.newObjMixedArgs ""
  extNewObjMixedArgs l tp ps ns = modify (addModuleImportVS l) >> 
    G.extNewObjMixedArgs l tp ps ns
  libNewObjMixedArgs l tp ps ns = modify (addLibImportVS l) >> 
    G.extNewObjMixedArgs l tp ps ns

  lambda = G.lambda pyLambda

  notNull v = v ?!= valueOf (var "None" void)

instance InternalValue PythonCode where
  inputFunc = mkStateVal string (text "input()") -- raw_input() for < Python 3.0
  printFunc = mkStateVal void (text "print")
  printLnFunc = mkStateVal void empty
  printFileFunc _ = mkStateVal void empty
  printFileLnFunc _ = mkStateVal void empty
  
  cast = on2StateValues (\t -> mkVal t . castObjDocD (getTypeDoc t) . valueDoc)

  call = G.call equals

  valuePrec = valPrec . unPC
  valueDoc = val . unPC
  valFromData p t d = on2CodeValues (vd p) t (toCode d)

instance InternalValueExp PythonCode where
  objMethodCallMixedArgs' = G.objMethodCall
  objMethodCallNoParams' = G.objMethodCallNoParams

instance FunctionSym PythonCode where
  type Function PythonCode = FuncData
  func = G.func
  objAccess = G.objAccess

instance GetSet PythonCode where
  get = G.get
  set = G.set

instance List PythonCode where
  listSize = on2StateValues (\f v -> mkVal (functionType f) 
    (pyListSize (valueDoc v) (functionDoc f))) listSizeFunc
  listAdd = G.listAdd
  listAppend = G.listAppend
  listAccess = G.listAccess
  listSet = G.listSet
  indexOf = G.indexOf "index"

instance InternalList PythonCode where
  listSlice' b e s vnew vold = docBlock $ zoom lensMStoVS $ pyListSlice vnew 
    vold (getVal b) (getVal e) (getVal s)
    where getVal = fromMaybe (mkStateVal void empty)

instance Iterator PythonCode where
  iterBegin = G.iterBegin
  iterEnd = G.iterEnd

instance InternalGetSet PythonCode where
  getFunc = G.getFunc
  setFunc = G.setFunc

instance InternalListFunc PythonCode where
  listSizeFunc = funcFromData (text "len") int
  listAddFunc _ = G.listAddFunc "insert"
  listAppendFunc = G.listAppendFunc "append"
  listAccessFunc = G.listAccessFunc
  listSetFunc = G.listSetFunc listSetFuncDocD

instance InternalIterator PythonCode where
  iterBeginFunc _ = error $ G.iterBeginError pyName
  iterEndFunc _ = error $ G.iterEndError pyName

instance InternalFunction PythonCode where
  functionType = onCodeValue fType
  functionDoc = funcDoc . unPC

  funcFromData d = onStateValue (onCodeValue (`fd` d))

instance InternalAssignStmt PythonCode where
  multiAssign vars vals = zoom lensMStoVS $ on2StateLists (\vrs vls -> 
    mkStNoEnd (multiAssignDoc vrs vls)) vars vals

instance InternalIOStmt PythonCode where
  printSt nl f p v = zoom lensMStoVS $ on3StateValues (\f' p' v' -> mkStNoEnd $ 
    pyPrint nl p' v' f') (fromMaybe (mkStateVal void empty) f) p v
  
instance InternalControlStmt PythonCode where
  multiReturn [] = error "Attempt to write return statement with no return variables"
  multiReturn vs = zoom lensMStoVS $ onStateList (mkStNoEnd . returnDocD) vs

instance InternalStatement PythonCode where
  state = G.state
  loopState = G.loopState
  
  emptyState = G.emptyState
  statementDoc = fst . unPC
  statementTerm = snd . unPC

  stateFromData d t = toCode (d, t)

instance StatementSym PythonCode where
  -- Terminator determines how statements end
  type Statement PythonCode = (Doc, Terminator)
  valState = G.valState Empty
  multi = onStateList (onCodeList multiStateDocD)

instance AssignStatement PythonCode where
  assign = G.assign Empty
  (&-=) = G.decrement
  (&+=) = G.increment'
  (&++) = G.increment1'
  (&--) = G.decrement1

instance DeclStatement PythonCode where
  varDec _ = toState $ mkStNoEnd empty
  varDecDef = assign
  listDec _ v = zoom lensMStoVS $ onStateValue (mkStNoEnd . pyListDec) v
  listDecDef = G.listDecDef'
  arrayDec = listDec
  arrayDecDef = listDecDef
  objDecDef = varDecDef
  objDecNew = G.objDecNew
  extObjDecNew lib v vs = modify (addModuleImport lib) >> varDecDef v 
    (extNewObj lib (onStateValue variableType v) vs)
  objDecNewNoParams = G.objDecNewNoParams
  extObjDecNewNoParams lib v = modify (addModuleImport lib) >> varDecDef v 
    (extNewObj lib (onStateValue variableType v) [])
  constDecDef = varDecDef
  funcDecDef v ps r = onStateValue (mkStNoEnd . methodDoc) (zoom lensMStoVS v 
    >>= (\vr -> function (variableName vr) private dynamic 
    (toState $ variableType vr) (map param ps) (oneLiner $ returnState r)))

instance IOStatement PythonCode where
  print = pyOut False Nothing printFunc
  printLn = pyOut True Nothing printFunc
  printStr = print . litString
  printStrLn = printLn . litString

  printFile f = pyOut False (Just f) printFunc
  printFileLn f = pyOut True (Just f) printFunc
  printFileStr f = printFile f . litString
  printFileStrLn f = printFileLn f . litString

  getInput = pyInput inputFunc
  discardInput = valState inputFunc
  getFileInput f = pyInput (objMethodCall string f "readline" [])
  discardFileInput f = valState (objMethodCall string f "readline" [])

  openFileR f n = f &= funcApp "open" infile [n, litString "r"]
  openFileW f n = f &= funcApp "open" outfile [n, litString "w"]
  openFileA f n = f &= funcApp "open" outfile [n, litString "a"]
  closeFile = G.closeFile "close"

  getFileInputLine = getFileInput
  discardFileLine = G.discardFileLine "readline"
  getFileInputAll f v = v &= objMethodCall (listType string) f
    "readlines" []
  
instance StringStatement PythonCode where
  stringSplit d vnew s = assign vnew (objAccess s (func "split" 
    (listType string) [litString [d]]))  

  stringListVals = G.stringListVals
  stringListLists = G.stringListLists

instance FuncAppStatement PythonCode where
  inOutCall = pyInOutCall funcApp
  selfInOutCall = pyInOutCall selfFuncApp
  extInOutCall m = pyInOutCall (extFuncApp m)

instance CommentStatement PythonCode where
  comment = G.comment pyCommentStart

instance ControlStatement PythonCode where
  break = toState $ mkStNoEnd breakDocD
  continue = toState $ mkStNoEnd continueDocD

  returnState = G.returnState Empty

  throw = G.throw pyThrow Empty

  ifCond = G.ifCond pyBodyStart (text "elif") pyBodyEnd
  switch = switchAsIf

  ifExists = G.ifExists

  for _ _ _ _ = error $ "Classic for loops not available in Python, please " ++
    "use forRange, forEach, or while instead"
  forRange i initv finalv stepv = forEach i
    (funcApp "range" (listType int) [initv, finalv, stepv])
  forEach i' v' = on3StateValues (\i v b -> mkStNoEnd (pyForEach i v b)) 
    (zoom lensMStoVS i') (zoom lensMStoVS v')
  while v' = on2StateValues (\v b -> mkStNoEnd (pyWhile v b)) 
    (zoom lensMStoVS v')

  tryCatch = G.tryCatch pyTryCatch

instance StatePattern PythonCode where 
  checkState = G.checkState

instance ObserverPattern PythonCode where
  notifyObservers f t = forRange index initv (listSize obsList) 
    (litInt 1) notify
    where obsList = valueOf $ observerListName `listOf` t
          index = var "observerIndex" int
          initv = litInt 0
          notify = oneLiner $ valState $ at obsList (valueOf index) $. f

instance StrategyPattern PythonCode where
  runStrategy = G.runStrategy

instance ScopeSym PythonCode where
  type Scope PythonCode = Doc
  private = toCode empty
  public = toCode empty

instance InternalScope PythonCode where
  scopeDoc = unPC
  scopeFromData _ = toCode

instance MethodTypeSym PythonCode where
  type MethodType PythonCode = TypeData
  mType = zoom lensMStoVS
  construct = G.construct

instance ParameterSym PythonCode where
  type Parameter PythonCode = ParamData
  param = G.param variableDoc
  pointerParam = param

instance InternalParam PythonCode where
  parameterName = variableName . onCodeValue paramVar
  parameterType = variableType . onCodeValue paramVar
  parameterDoc = paramDoc . unPC
  paramFromData v d = on2CodeValues pd v (toCode d)

instance MethodSym PythonCode where
  type Method PythonCode = MethodData
  method = G.method
  getMethod = G.getMethod
  setMethod = G.setMethod
  constructor = G.constructor initName

  docMain = mainFunction

  function = G.function
  mainFunction b = do
    modify setCurrMain
    bod <- b
    modify (setMainDoc $ bodyDoc bod)
    toState $ toCode $ mthd empty

  docFunc = G.docFunc

  inOutMethod n = pyInOut (method n)

  docInOutMethod n = pyDocInOut (inOutMethod n)

  inOutFunc n = pyInOut (function n)

  docInOutFunc n = pyDocInOut (inOutFunc n)

instance InternalMethod PythonCode where
  intMethod m n _ _ _ ps b = modify (if m then setCurrMain else id) >> 
    on3StateValues (\sl pms bd -> methodFromData Pub $ pyMethod n sl pms bd) 
    (zoom lensMStoVS self) (sequence ps) b 
  intFunc m n _ _ _ ps b = modify (if m then setCurrMain else id) >>
    on1StateValue1List (\bd pms -> methodFromData Pub $ pyFunction n pms bd) 
    b ps
  commentedFunc cmt m = on2StateValues (on2CodeValues updateMthd) m 
    (onStateValue (onCodeValue commentedItem) cmt)
    
  destructor _ = error $ destructorError pyName

  methodDoc = mthdDoc . unPC
  methodFromData _ = toCode . mthd

instance StateVarSym PythonCode where
  type StateVar PythonCode = Doc
  stateVar _ _ _ = toState (toCode empty)
  stateVarDef _ = G.stateVarDef
  constVar _ = G.constVar (permDoc 
    (static :: PythonCode (Permanence PythonCode)))

instance InternalStateVar PythonCode where
  stateVarDoc = unPC
  stateVarFromData = onStateValue toCode

instance ClassSym PythonCode where
  type Class PythonCode = Doc
  buildClass = G.buildClass
  -- enum n es s = modify (setClassName n) >> classFromData (toState $ pyClass n 
  --   empty (scopeDoc s) (enumElementsDocD' es) empty)
  extraClass = buildClass
  implementingClass = G.implementingClass

  docClass = G.docClass

instance InternalClass PythonCode where
  intClass = G.intClass pyClass

  inherit n = toCode $ maybe empty (parens . text) n
  implements is = toCode $ parens (text $ intercalate ", " is)

  commentedClass = G.commentedClass

  classDoc = unPC
  classFromData d = d

instance ModuleSym PythonCode where
  type Module PythonCode = ModData
  buildModule n is = G.buildModule n (on3StateValues (\lis libis mis -> vibcat [
    vcat (map (importDoc . 
      (langImport :: Label -> PythonCode (Import PythonCode))) lis),
    vcat (map (importDoc . 
      (langImport :: Label -> PythonCode (Import PythonCode))) (sort $ is ++ 
      libis)),
    vcat (map (importDoc . 
      (modImport :: Label -> PythonCode (Import PythonCode))) mis)]) 
    getLangImports getLibImports getModuleImports) getMainDoc

instance InternalMod PythonCode where
  moduleDoc = modDoc . unPC
  modFromData n = G.modFromData n (toCode . md n)
  updateModuleDoc f = onCodeValue (updateMod f)

instance BlockCommentSym PythonCode where
  type BlockComment PythonCode = Doc
  blockComment lns = toCode $ pyBlockComment lns pyCommentStart
  docComment = onStateValue (\lns -> toCode $ pyDocComment lns (text "##") 
    pyCommentStart)

  blockCommentDoc = unPC

-- convenience
initName :: Label
initName = "__init__"

pyName :: String
pyName = "Python"

pyBodyStart, pyBodyEnd, pyCommentStart :: Doc
pyBodyStart = colon
pyBodyEnd = empty
pyCommentStart = text "#"

pyODEMethod :: ODEMethod -> [SValue PythonCode]
pyODEMethod RK45 = [litString "dopri5"]
pyODEMethod BDF = [litString "vode", 
  (litString "bdf" :: SValue PythonCode) >>= 
  (mkStateVal string . (text "method=" <>) . valueDoc)]
pyODEMethod Adams = [litString "vode", 
  (litString "adams" :: SValue PythonCode) >>= 
  (mkStateVal string . (text "method=" <>) . valueDoc)]

pyLogOp :: (RenderSym r) => VSUnOp r
pyLogOp = addmathImport $ unOpPrec "math.log10"

pyLnOp :: (RenderSym r) => VSUnOp r
pyLnOp = addmathImport $ unOpPrec "math.log"

pyClassVar :: Doc -> Doc -> Doc
pyClassVar c v = c <> dot <> c <> dot <> v

pyInlineIf :: (RenderSym r) => SValue r -> SValue r -> SValue r -> 
  SValue r
pyInlineIf = on3StateValues (\c v1 v2 -> valFromData (valuePrec c) 
  (valueType v1) (valueDoc v1 <+> text "if" <+> valueDoc c <+> text "else" <+> 
  valueDoc v2))

pyLambda :: (RenderSym r) => [r (Variable r)] -> r (Value r) -> 
  Doc
pyLambda ps ex = text "lambda" <+> variableList ps <> colon <+> valueDoc ex

pyListSize :: Doc -> Doc -> Doc
pyListSize v f = f <> parens v

pyStringType :: (RenderSym r) => VSType r
pyStringType = toState $ typeFromData String "str" (text "str")

pyListDec :: (RenderSym r) => r (Variable r) -> Doc
pyListDec v = variableDoc v <+> equals <+> getTypeDoc (variableType v)

pyPrint :: (RenderSym r) => Bool -> r (Value r) -> r (Value r) 
  -> r (Value r) -> Doc
pyPrint newLn prf v f = valueDoc prf <> parens (valueDoc v <> nl <> fl)
  where nl = if newLn then empty else text ", end=''"
        fl = emptyIfEmpty (valueDoc f) $ text ", file=" <> valueDoc f

pyOut :: (RenderSym r) => Bool -> Maybe (SValue r) -> SValue r -> 
  SValue r -> MSStatement r
pyOut newLn f printFn v = zoom lensMStoVS v >>= pyOut' . getType . valueType
  where pyOut' (List _) = printSt newLn f printFn v
        pyOut' _ = outDoc newLn f printFn v

pyInput :: SValue PythonCode -> SVariable PythonCode -> MSStatement PythonCode
pyInput inSrc v = v &= (v >>= pyInput' . getType . variableType)
  where pyInput' Integer = funcApp "int" int [inSrc]
        pyInput' Float = funcApp "float" double [inSrc]
        pyInput' Double = funcApp "float" double [inSrc]
        pyInput' Boolean = inSrc ?!= litString "0"
        pyInput' String = objMethodCall string inSrc "rstrip" []
        pyInput' Char = inSrc
        pyInput' _ = error "Attempt to read a value of unreadable type"

pyThrow :: (RenderSym r) => r (Value r) -> Doc
pyThrow errMsg = text "raise" <+> text "Exception" <> parens (valueDoc errMsg)

pyForEach :: (RenderSym r) => r (Variable r) -> r (Value r) -> 
  r (Body r) -> Doc
pyForEach i lstVar b = vcat [
  forLabel <+> variableDoc i <+> inLabel <+> valueDoc lstVar <> colon,
  indent $ bodyDoc b]

pyWhile :: (RenderSym r) => r (Value r) -> r (Body r) -> Doc
pyWhile v b = vcat [
  text "while" <+> valueDoc v <> colon,
  indent $ bodyDoc b]

pyTryCatch :: (RenderSym r) => r (Body r) -> r (Body r) -> Doc
pyTryCatch tryB catchB = vcat [
  text "try" <+> colon,
  indent $ bodyDoc tryB,
  text "except" <+> text "Exception" <+> colon,
  indent $ bodyDoc catchB]

pyListSlice :: (RenderSym r) => SVariable r -> SValue r -> SValue r 
  -> SValue r -> SValue r -> VS Doc
pyListSlice vn vo beg end step = (\vnew vold b e s -> variableDoc vnew <+> 
  equals <+> valueDoc vold <> brackets (valueDoc b <> colon <> valueDoc e <> 
  colon <> valueDoc s)) <$> vn <*> vo <*> beg <*> end <*> step

pyMethod :: (RenderSym r) => Label -> r (Variable r) -> 
  [r (Parameter r)] -> r (Body r) -> Doc
pyMethod n slf ps b = vcat [
  text "def" <+> text n <> parens (variableDoc slf <> oneParam <> pms) <> colon,
  indent bodyD]
      where pms = parameterList ps
            oneParam = emptyIfEmpty pms $ text ", "
            bodyD | isEmpty (bodyDoc b) = text "None"
                  | otherwise = bodyDoc b

pyFunction :: (RenderSym r) => Label -> [r (Parameter r)] -> 
  r (Body r) -> Doc
pyFunction n ps b = vcat [
  text "def" <+> text n <> parens (parameterList ps) <> colon,
  indent bodyD]
  where bodyD | isEmpty (bodyDoc b) = text "None"
              | otherwise = bodyDoc b

pyClass :: Label -> Doc -> Doc -> Doc -> Doc -> Doc
pyClass n pn s vs fs = vcat [
  s <+> classDec <+> text n <> pn <> colon,
  indent funcSec]
  where funcSec | isEmpty (vs <> fs) = text "None"
                | isEmpty vs = fs
                | isEmpty fs = vs
                | otherwise = vcat [vs, blank, fs]

pyInOutCall :: (Label -> VSType PythonCode -> [SValue PythonCode] -> 
  SValue PythonCode) -> Label -> [SValue PythonCode] -> [SVariable PythonCode] 
  -> [SVariable PythonCode] -> MSStatement PythonCode
pyInOutCall f n ins [] [] = valState $ f n void ins
pyInOutCall f n ins outs both = multiAssign rets [f n void (map valueOf both ++ 
  ins)]
  where rets = both ++ outs

pyBlockComment :: [String] -> Doc -> Doc
pyBlockComment lns cmt = vcat $ map ((<+>) cmt . text) lns

pyDocComment :: [String] -> Doc -> Doc -> Doc
pyDocComment [] _ _ = empty
pyDocComment (l:lns) start mid = vcat $ start <+> text l : map ((<+>) mid . 
  text) lns

pyInOut :: (PythonCode (Scope PythonCode) -> PythonCode (Permanence PythonCode) 
    -> VSType PythonCode -> [MSParameter PythonCode] -> MSBody PythonCode -> 
    SMethod PythonCode)
  -> PythonCode (Scope PythonCode) -> PythonCode (Permanence PythonCode) -> 
  [SVariable PythonCode] -> [SVariable PythonCode] -> [SVariable PythonCode] -> 
  MSBody PythonCode -> SMethod PythonCode
pyInOut f s p ins [] [] b = f s p void (map param ins) b
pyInOut f s p ins outs both b = f s p void (map param $ both ++ ins) 
  (on3StateValues (on3CodeValues surroundBody) (multi $ map varDec outs) b 
  (multiReturn $ map valueOf rets))
  where rets = both ++ outs

pyDocInOut :: (RenderSym r) => (r (Scope r) -> r (Permanence r) 
    -> [SVariable r] -> [SVariable r] -> [SVariable r] -> MSBody r 
    -> SMethod r)
  -> r (Scope r) -> r (Permanence r) -> String -> 
  [(String, SVariable r)] -> [(String, SVariable r)]
  -> [(String, SVariable r)] -> MSBody r -> SMethod r
pyDocInOut f s p desc is os bs b = docFuncRepr desc (map fst $ bs ++ is)
  (map fst $ bs ++ os) (f s p (map snd is) (map snd os) (map snd bs) b)
