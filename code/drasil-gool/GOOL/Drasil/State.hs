{-# LANGUAGE TemplateHaskell #-}

module GOOL.Drasil.State (
  -- Types
  GS, GOOLState(..), FS, CS, MS, VS, 
  -- Lenses
  lensFStoGS, lensGStoFS, lensFStoCS, lensFStoMS, lensFStoVS, lensCStoMS, 
  lensMStoCS, lensCStoVS, lensMStoFS, lensMStoVS, lensVStoFS, lensVStoMS, 
  headers, sources, mainMod, goolState, currMain, currFileType, 
  -- Initial states
  initialState, initialFS, 
  -- State helpers
  modifyReturn, modifyReturnFunc, modifyReturnList, 
  -- State modifiers
  revFiles, addODEFilePaths, addFile, addCombinedHeaderSource, addHeader, 
  addSource, addProgNameToPaths, setMainMod, addODEFiles, getODEFiles, 
  addLangImport, addLangImportVS, addExceptionImports, getLangImports, 
  addLibImport, addLibImportVS, addLibImports, getLibImports, addModuleImport, 
  addModuleImportVS, getModuleImports, addHeaderLangImport, 
  getHeaderLangImports, addHeaderLibImport, getHeaderLibImports, 
  addHeaderModImport, getHeaderModImports, addDefine, getDefines, 
  addHeaderDefine, getHeaderDefines, addUsing, getUsing, addHeaderUsing, 
  getHeaderUsing, setFileType, setModuleName, getModuleName, setClassName, 
  getClassName, setCurrMain, getCurrMain, addClass, getClasses, updateClassMap, 
  getClassMap, updateMethodExcMap, getMethodExcMap, updateCallMap, 
  callMapTransClosure, updateMEMWithCalls, addParameter, getParameters, 
  setOutputsDeclared, isOutputsDeclared, addException, addExceptions, 
  getExceptions, addCall, setMainDoc, getMainDoc, setScope, getScope, 
  setCurrMainFunc, getCurrMainFunc, setODEDepVars, getODEDepVars, 
  setODEOthVars, getODEOthVars
) where

import GOOL.Drasil.AST (FileType(..), ScopeTag(..), QualifiedName, qualName, 
  FileData)
import GOOL.Drasil.CodeAnalysis (Exception, ExceptionType, printExc, hasLoc)
import GOOL.Drasil.CodeType (ClassName)

import Control.Lens (Lens', (^.), lens, makeLenses, over, set)
import Control.Monad.State (State, modify, gets)
import Data.List (nub)
import Data.List.Ordered (nubSort)
import Data.Maybe (isNothing)
import Data.Map (Map, fromList, insert, union, findWithDefault, mapWithKey)
import qualified Data.Map as Map (empty, map)
import Text.PrettyPrint.HughesPJ (Doc, empty)

data GOOLState = GS {
  _headers :: [FilePath], -- Used by Drasil for doxygen config gen
  _sources :: [FilePath], -- Used by Drasil for doxygen config and Makefile gen
  _mainMod :: Maybe FilePath, -- Used by Drasil generator to access main 
                              -- mod file path (needed in Makefile generation)
  _classMap :: Map String ClassName, -- Used to determine whether an import is 
                                     -- needed when using extClassVar and obj
  _odeFiles :: [FileData],

  -- Only used for Java, to generate correct "throws Exception" declarations
  _methodExceptionMap :: Map QualifiedName [ExceptionType], -- Method to exceptions thrown
  _callMap :: Map QualifiedName [QualifiedName] -- Method to other methods it calls
} 
makeLenses ''GOOLState

data FileState = FS {
  _goolState :: GOOLState,
  _currModName :: String, -- Used by fileDoc to insert the module name in the 
                          -- file path, and by CodeInfo/Java when building
                          -- method exception map and call map
  _currFileType :: FileType, -- Used when populating headers and sources in GOOLState
  _currMain :: Bool, -- Used to set mainMod in GOOLState, 
                     -- and in C++ to put documentation for the main 
                     -- module in the source file instead of header
  _currClasses :: [ClassName], -- Used to update classMap
  _langImports :: [String],
  _libImports :: [String],
  _moduleImports :: [String],
  
  -- Only used for Python
  _mainDoc :: Doc, -- To print Python's "main" last

  -- C++ only
  _headerLangImports :: [String],
  _headerLibImports :: [String],
  _headerModImports :: [String],
  _defines :: [String],
  _headerDefines :: [String],
  _using :: [String],
  _headerUsing :: [String]
}
makeLenses ''FileState

data ClassState = CS {
  _fileState :: FileState,
  _currClassName :: ClassName -- So class name is accessible when generating 
                              -- constructor or self 
}
makeLenses ''ClassState

data MethodState = MS {
  _classState :: ClassState,
  _currParameters :: [String], -- Used to get parameter names when generating 
                               -- function documentation

  -- Only used for Java
  _outputsDeclared :: Bool, -- So Java doesn't redeclare outputs variable when using inOutCall
  _exceptions :: [ExceptionType], -- Used to build methodExceptionMap
  _calls :: [QualifiedName], -- Used to build CallMap
  
  -- Only used for C++
  _currScope :: ScopeTag, -- Used to maintain correct scope when adding 
                          -- documentation to function in C++
  _currMainFunc :: Bool -- Used by C++ to put documentation for the main
                        -- function in source instead of header file
}
makeLenses ''MethodState

data ValueState = VS {
  _methodState :: MethodState,
  _currODEDepVars :: [String],
  _currODEOthVars :: [String]
}
makeLenses ''ValueState

type GS = State GOOLState
type FS = State FileState
type CS = State ClassState
type MS = State MethodState
type VS = State ValueState

-------------------------------
---- Lenses between States ----
-------------------------------

-- GS - FS --

lensGStoFS :: Lens' GOOLState FileState
lensGStoFS = lens (\gs -> set goolState gs initialFS) (const (^. goolState))

lensFStoGS :: Lens' FileState GOOLState
lensFStoGS = goolState

-- FS - CS --

lensFStoCS :: Lens' FileState ClassState
lensFStoCS = lens (\fs -> set fileState fs initialCS) (const (^. fileState))

-- FS - MS --

lensFStoMS :: Lens' FileState MethodState
lensFStoMS = lens (\fs -> set lensMStoFS fs initialMS) (const (^. lensMStoFS))

lensMStoFS :: Lens' MethodState FileState 
lensMStoFS = classState . fileState

-- CS - MS --

lensCStoMS :: Lens' ClassState MethodState
lensCStoMS = lens (\cs -> set classState cs initialMS) (const (^. classState))

lensMStoCS :: Lens' MethodState ClassState
lensMStoCS = classState

-- FS - VS --

lensFStoVS :: Lens' FileState ValueState
lensFStoVS = lens (\fs -> set lensVStoFS fs initialVS) (const (^. lensVStoFS))

lensVStoFS :: Lens' ValueState FileState
lensVStoFS = methodState . lensMStoFS

-- CS - VS --

lensCStoVS :: Lens' ClassState ValueState
lensCStoVS = lens (\cs -> set (methodState . classState) cs initialVS) 
  (const (^. (methodState . classState)))

-- MS - VS --

lensMStoVS :: Lens' MethodState ValueState
lensMStoVS = lens (\ms -> set methodState ms initialVS) (const (^. methodState))

lensVStoMS :: Lens' ValueState MethodState
lensVStoMS = methodState

-------------------------------
------- Initial States -------
-------------------------------

initialState :: GOOLState
initialState = GS {
  _headers = [],
  _sources = [],
  _mainMod = Nothing,
  _classMap = Map.empty,
  _odeFiles = [],

  _methodExceptionMap = Map.empty,
  _callMap = Map.empty
}

initialFS :: FileState
initialFS = FS {
  _goolState = initialState,
  _currModName = "",
  _currFileType = Combined,
  _currMain = False,
  _currClasses = [],
  _langImports = [],
  _libImports = [],
  _moduleImports = [],
  
  _mainDoc = empty,

  _headerLangImports = [],
  _headerLibImports = [],
  _headerModImports = [],
  _defines = [],
  _headerDefines = [],
  _using = [],
  _headerUsing = []
}

initialCS :: ClassState
initialCS = CS {
  _fileState = initialFS,
  _currClassName = ""
}

initialMS :: MethodState
initialMS = MS {
  _classState = initialCS,
  _currParameters = [],

  _outputsDeclared = False,
  _exceptions = [],
  _calls = [],

  _currScope = Priv,
  _currMainFunc = False
}

initialVS :: ValueState
initialVS = VS {
  _methodState = initialMS,
  _currODEDepVars = [],
  _currODEOthVars = []
}

-------------------------------
------- State Patterns -------
-------------------------------

modifyReturn :: (s -> s) -> a -> State s a
modifyReturn sf v = do
  modify sf
  return v

modifyReturnFunc :: (b -> s -> s) -> (b -> a) -> State s b -> State s a
modifyReturnFunc sf vf st = do
  v <- st
  modify $ sf v
  return $ vf v

modifyReturnList :: [State s b] -> (s -> s) -> 
  ([b] -> a) -> State s a
modifyReturnList l sf vf = do
  v <- sequence l
  modify sf
  return $ vf v

-------------------------------
------- State Modifiers -------
-------------------------------

revFiles :: GOOLState -> GOOLState
revFiles = over headers reverse . over sources reverse

addODEFilePaths :: GOOLState -> MethodState -> MethodState
addODEFilePaths s = over (lensMStoFS . goolState . headers) (s ^. headers ++)
  . over (lensMStoFS . goolState . sources) (s ^. sources ++)

addFile :: FileType -> FilePath -> GOOLState -> GOOLState
addFile Combined = addCombinedHeaderSource
addFile Source = addSource
addFile Header = addHeader

addHeader :: FilePath -> GOOLState -> GOOLState
addHeader fp = over headers (\h -> ifElemError fp h $
  "Multiple files with same name encountered: " ++ fp)

addSource :: FilePath -> GOOLState -> GOOLState
addSource fp = over sources (\s -> ifElemError fp s $
  "Multiple files with same name encountered: " ++ fp)

addCombinedHeaderSource :: FilePath -> GOOLState -> GOOLState
addCombinedHeaderSource fp = addSource fp . addHeader fp 

addProgNameToPaths :: String -> GOOLState -> GOOLState
addProgNameToPaths n = over mainMod (fmap f) . over sources (map f) . 
  over headers (map f)
  where f = ((n++"/")++)

setMainMod :: String -> GOOLState -> GOOLState
setMainMod n = over mainMod (\m -> if isNothing m then Just n else error 
  "Multiple modules with main methods encountered")

addODEFiles :: [FileData] -> MethodState -> MethodState
addODEFiles f = over (lensMStoFS . goolState . odeFiles) (f++)

getODEFiles :: GS [FileData]
getODEFiles = gets (^. odeFiles)

addLangImport :: String -> MethodState -> MethodState
addLangImport i = over (lensMStoFS . langImports) (\is -> nubSort $ i:is)
  
addLangImportVS :: String -> ValueState -> ValueState
addLangImportVS i = over methodState (addLangImport i)

addExceptionImports :: [Exception] -> MethodState -> MethodState
addExceptionImports es = over (lensMStoFS . langImports) 
  (\is -> nubSort $ is ++ imps)
  where imps = map printExc $ filter hasLoc es

getLangImports :: FS [String]
getLangImports = gets (^. langImports)

addLibImport :: String -> MethodState -> MethodState
addLibImport i = over (lensMStoFS . libImports) (\is -> nubSort $ i:is)

addLibImportVS :: String -> ValueState -> ValueState
addLibImportVS i = over (lensVStoFS . libImports) (\is -> nubSort $ i:is)

addLibImports :: [String] -> MethodState -> MethodState
addLibImports is s = foldl (flip addLibImport) s is

getLibImports :: FS [String]
getLibImports = gets (^. libImports)

addModuleImport :: String -> MethodState -> MethodState
addModuleImport i = over (lensMStoFS . moduleImports) (\is -> nubSort $ i:is)

addModuleImportVS :: String -> ValueState -> ValueState
addModuleImportVS i = over methodState (addModuleImport i)

getModuleImports :: FS [String]
getModuleImports = gets (^. moduleImports)

addHeaderLangImport :: String -> ValueState -> ValueState
addHeaderLangImport i = over (lensVStoFS . headerLangImports) 
  (\is -> nubSort $ i:is)

getHeaderLangImports :: FS [String]
getHeaderLangImports = gets (^. headerLangImports)

addHeaderLibImport :: String -> MethodState -> MethodState
addHeaderLibImport i = over (lensMStoFS . headerLibImports)
  (\is -> nubSort $ i:is)

getHeaderLibImports :: FS [String]
getHeaderLibImports = gets (^. headerLibImports)

addHeaderModImport :: String -> ValueState -> ValueState
addHeaderModImport i = over (lensVStoFS . headerModImports)
  (\is -> nubSort $ i:is)

getHeaderModImports :: FS [String]
getHeaderModImports = gets (^. headerModImports)

addDefine :: String -> ValueState -> ValueState
addDefine d = over (lensVStoFS . defines) (\ds -> nubSort $ d:ds)

getDefines :: FS [String]
getDefines = gets (^. defines)
  
addHeaderDefine :: String -> ValueState -> ValueState
addHeaderDefine d = over (lensVStoFS . headerDefines) (\ds -> nubSort $ d:ds)

getHeaderDefines :: FS [String]
getHeaderDefines = gets (^. headerDefines)

addUsing :: String -> ValueState -> ValueState
addUsing u = over (lensVStoFS . using) (\us -> nubSort $ u:us)

getUsing :: FS [String]
getUsing = gets (^. using)

addHeaderUsing :: String -> ValueState -> ValueState
addHeaderUsing u = over (lensVStoFS . headerUsing) (\us -> nubSort $ u:us)

getHeaderUsing :: FS [String]
getHeaderUsing = gets (^. headerUsing)

setMainDoc :: Doc -> MethodState -> MethodState
setMainDoc d = over lensMStoFS $ set mainDoc d

getMainDoc :: FS Doc
getMainDoc = gets (^. mainDoc)

setFileType :: FileType -> FileState -> FileState
setFileType = set currFileType

setModuleName :: String -> FileState -> FileState
setModuleName = set currModName

getModuleName :: FS String
getModuleName = gets (^. currModName)

setClassName :: String -> ClassState -> ClassState
setClassName = set currClassName

getClassName :: MS ClassName
getClassName = gets (^. (classState . currClassName))

setCurrMain :: MethodState -> MethodState
setCurrMain = over (lensMStoFS . currMain) (\b -> if b then 
  error "Multiple main functions defined" else not b)

getCurrMain :: FS Bool
getCurrMain = gets (^. currMain)

addClass :: String -> ClassState -> ClassState
addClass c = over (fileState . currClasses) (\cs -> ifElemError c cs 
  "Multiple classes with same name in same file")

getClasses :: FS [String]
getClasses = gets (^. currClasses)

updateClassMap :: String -> FileState -> FileState
updateClassMap n fs = over (goolState . classMap) (union (fromList $ 
  zip (repeat n) (fs ^. currClasses))) fs

getClassMap :: VS (Map String String)
getClassMap = gets (^. (lensVStoFS . goolState . classMap))

updateMethodExcMap :: String -> MethodState -> MethodState
updateMethodExcMap n ms = over (lensMStoFS . goolState . methodExceptionMap) 
  (insert (qualName mn n) (ms ^. exceptions)) ms
  where mn = ms ^. (lensMStoFS . currModName)

getMethodExcMap :: VS (Map QualifiedName [ExceptionType])
getMethodExcMap = gets (^. (lensVStoFS . goolState . methodExceptionMap))

updateCallMap :: String -> MethodState -> MethodState
updateCallMap n ms = over (lensMStoFS . goolState . callMap) 
  (insert (qualName mn n) (ms ^. calls)) ms
  where mn = ms ^. (lensMStoFS . currModName)

callMapTransClosure :: GOOLState -> GOOLState
callMapTransClosure = over callMap tClosure
  where tClosure m = Map.map (traceCalls m) m
        traceCalls :: Map QualifiedName [QualifiedName] -> [QualifiedName] -> 
          [QualifiedName]
        traceCalls _ [] = []
        traceCalls cm (c:cs) = nub $ c : traceCalls cm (nub $ cs ++ 
          findWithDefault [] c cm)

updateMEMWithCalls :: GOOLState -> GOOLState
updateMEMWithCalls s = over methodExceptionMap (\mem -> mapWithKey 
  (addCallExcs mem (s ^. callMap)) mem) s
  where addCallExcs :: Map QualifiedName [ExceptionType] -> 
          Map QualifiedName [QualifiedName] -> QualifiedName -> [ExceptionType] 
          -> [ExceptionType]
        addCallExcs mem cm f es = nub $ es ++ concatMap (\fn -> findWithDefault 
          [] fn mem) (findWithDefault [] f cm)

addParameter :: String -> MethodState -> MethodState
addParameter p = over currParameters (\ps -> ifElemError p ps $ 
  "Function has duplicate parameter: " ++ p)

getParameters :: MS [String]
getParameters = gets (reverse . (^. currParameters))

setODEDepVars :: [String] -> ValueState -> ValueState
setODEDepVars = set currODEDepVars

getODEDepVars :: VS [String]
getODEDepVars = gets (^. currODEDepVars)

setODEOthVars :: [String] -> ValueState -> ValueState
setODEOthVars = set currODEOthVars

getODEOthVars :: VS [String]
getODEOthVars = gets (^. currODEOthVars)

setOutputsDeclared :: MethodState -> MethodState
setOutputsDeclared = set outputsDeclared True

isOutputsDeclared :: MS Bool
isOutputsDeclared = gets (^. outputsDeclared)

addException :: ExceptionType -> MethodState -> MethodState
addException e = over exceptions (\es -> nub $ e : es)

addExceptions :: [ExceptionType] -> ValueState -> ValueState
addExceptions es = over (methodState . exceptions) (\exs -> nub $ es ++ exs)

getExceptions :: MS [ExceptionType]
getExceptions = gets (^. exceptions)

addCall :: QualifiedName -> ValueState -> ValueState
addCall f = over (methodState . calls) (f:)

setScope :: ScopeTag -> MethodState -> MethodState
setScope = set currScope

getScope :: MS ScopeTag
getScope = gets (^. currScope)

setCurrMainFunc :: Bool -> MethodState -> MethodState
setCurrMainFunc = set currMainFunc

getCurrMainFunc :: MS Bool
getCurrMainFunc = gets (^. currMainFunc)

-- Helpers

ifElemError :: (Eq a) => a -> [a] -> String -> [a]
ifElemError e es err = if e `elem` es then error err else e : es