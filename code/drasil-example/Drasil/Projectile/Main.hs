module Main (main) where

import Language.Drasil.Code (Choices(..), CodeSpec, Comments(..), 
  ConstraintBehaviour(..), ImplementationType(..), Lang(..), Logging(..), 
  Structure(..), codeSpec)
import Language.Drasil.Generate (gen, genCode)
import Language.Drasil.Printers (DocSpec(DocSpec), DocType(SRS, Website))

import Drasil.Projectile.Body (printSetting, si, srs)

code :: CodeSpec
code = codeSpec si choices []

choices :: Choices
choices = Choices {
  lang = [Python, Cpp, CSharp, Java],
  impType = Program,
  logFile = "log.txt",
  logging = LogNone,
  comments = [CommentFunc],
  onSfwrConstraint = Warning,
  onPhysConstraint = Warning,
  inputStructure = Bundled
}

main :: IO()
main = do
  gen (DocSpec SRS     "Projectile_SRS") srs printSetting
  gen (DocSpec Website "Projectile_SRS") srs printSetting
  genCode choices code