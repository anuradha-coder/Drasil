{-# Language TemplateHaskell, TypeFamilies #-}
module Language.Drasil.Chunk.Constrained (
    ConstrainedChunk(..)
  , ConstrConcept(..)
  , constrained, cuc, cvc, cvc', constrained', cuc', constrainedNRV'
  , cnstrw
  ) where

import Control.Lens ((^.), makeLenses, view)

import Language.Drasil.Chunk.Constrained.Core (Constraint(..))
import Language.Drasil.Expr (Expr(..))
import Language.Drasil.Chunk.Attribute.Core (Attributes)
import Language.Drasil.Chunk.Quantity
import Language.Drasil.Chunk.DefinedQuantity
import Language.Drasil.Chunk.Unitary
import Language.Drasil.Unit(UnitDefn)
import Language.Drasil.Chunk.VarChunk
import Language.Drasil.Chunk.Unital (ucs)
import Language.Drasil.Chunk.Concept
import Language.Drasil.NounPhrase
import Language.Drasil.Space
import Language.Drasil.Symbol (Symbol)
import Language.Drasil.Classes (HasUID(uid), NamedIdea(term), Idea(getA),
  Definition(defn), ConceptDomain(cdom, DOM), Concept, HasSymbol(symbol),
  IsUnit, Constrained(constraints), HasReasVal(reasVal), HasAttributes(attributes))

-- | ConstrainedChunks are 'Symbolic Quantities'
-- with 'Constraints' and maybe typical value
data ConstrainedChunk = ConstrainedChunk { _qd :: QuantityDict
                                         , _constr :: [Constraint]
                                         , _reasV :: Maybe Expr
                                         }
makeLenses ''ConstrainedChunk

instance HasUID        ConstrainedChunk where uid = qd . uid
instance NamedIdea     ConstrainedChunk where term = qd . term
instance Idea          ConstrainedChunk where getA = getA . view qd
instance HasSpace      ConstrainedChunk where typ = qd . typ
instance HasSymbol     ConstrainedChunk where symbol c = symbol (c^.qd)
instance Quantity      ConstrainedChunk where getUnit = getUnit . view qd
instance Constrained   ConstrainedChunk where constraints = constr
instance HasReasVal    ConstrainedChunk where reasVal     = reasV
instance Eq            ConstrainedChunk where c1 == c2 = (c1 ^. qd . uid) == (c2 ^. qd . uid)
instance HasAttributes ConstrainedChunk where attributes = qd . attributes

-- | Creates a constrained chunk from a symbolic quantity
constrained :: (HasAttributes c, Quantity c) => c -> [Constraint] -> Expr -> ConstrainedChunk
constrained q cs ex = ConstrainedChunk (qw q) cs (Just ex)

-- | Creates a constrained unitary
cuc :: (HasAttributes u, IsUnit u, DOM u ~ ConceptChunk) => String -> NP -> Symbol -> u
                -> Space -> [Constraint] -> Expr  -> ConstrainedChunk
cuc i t s u space cs rv =
  ConstrainedChunk (qw (unitary i t s u space)) cs (Just rv)

-- | Creates a constrained varchunk
cvc :: String -> NP -> Symbol -> Space -> [Constraint] -> Expr -> Attributes -> ConstrainedChunk
cvc i des sym space cs rv atts = ConstrainedChunk (qw (vc i des sym space atts)) cs (Just rv)

cvc' :: String -> NP -> Symbol -> Space -> [Constraint] -> Attributes -> ConstrainedChunk
cvc' i des sym space cs atts = ConstrainedChunk (qw (vc i des sym space atts)) cs Nothing

-- | ConstrConcepts are 'Conceptual Symbolic Quantities'
-- with 'Constraints' and maybe a reasonable value
data ConstrConcept = ConstrConcept { _defq :: DefinedQuantityDict
                                   , _constr' :: [Constraint]
                                   , _reasV' :: Maybe Expr
                                   , _unit' :: Maybe UnitDefn
                                   }
makeLenses ''ConstrConcept

instance HasUID        ConstrConcept where uid = defq . uid
instance NamedIdea     ConstrConcept where term = defq . term
instance Idea          ConstrConcept where getA = getA . view defq
instance HasSpace      ConstrConcept where typ = defq . typ
instance HasSymbol     ConstrConcept where symbol c = symbol (c^.defq)
instance Quantity      ConstrConcept where getUnit = view unit'
instance Definition    ConstrConcept where defn = defq . defn
instance ConceptDomain ConstrConcept where
  type DOM ConstrConcept = ConceptChunk
  cdom = defq . cdom
instance Concept       ConstrConcept where
instance Constrained   ConstrConcept where constraints  = constr'
instance HasReasVal    ConstrConcept where reasVal      = reasV'
instance Eq            ConstrConcept where c1 == c2 = (c1 ^.defq.uid) == (c2 ^.defq.uid)
instance HasAttributes ConstrConcept where attributes = defq . attributes

constrained' :: (HasAttributes c, Quantity c, Concept c, IsUnit u, DOM c ~ ConceptChunk, DOM u ~ ConceptChunk) =>
  c -> Symbol -> Space -> u -> Attributes -> [Constraint] -> Expr -> Maybe UnitDefn -> ConstrConcept
constrained' q sym space un atts cs rv = ConstrConcept (cqs (cw q) sym space atts) cs (Just rv)

constrainedNRV' :: (HasAttributes c, Quantity c, Concept c, IsUnit u, DOM c ~ ConceptChunk, DOM u ~ ConceptChunk) => 
  c -> Symbol -> Space -> u -> Attributes -> [Constraint] -> Maybe UnitDefn -> ConstrConcept
constrainedNRV' q sym space un atts cs mub = ConstrConcept (cqs (cw q) sym space atts) cs Nothing mub

cuc' :: (IsUnit u, DOM u ~ ConceptChunk) => String -> NP -> String -> Symbol -> u
            -> Space -> [Constraint] -> Attributes -> Expr -> Maybe UnitDefn -> ConstrConcept
cuc' nam trm desc sym un space cs atts rv mub =
  ConstrConcept (cqs (cw (ucs nam trm desc sym un space [])) sym space atts) cs (Just rv) mub

constrained' :: (HasAttributes c, Quantity c, Concept c, DOM c ~ ConceptChunk) =>
  c -> Symbol -> Space -> Attributes -> [Constraint] -> Expr -> ConstrConcept
constrained' q sym space atts cs rv = ConstrConcept (cqs (cw q) sym space atts) cs (Just rv)

constrainedNRV' :: (HasAttributes c, Quantity c, Concept c, DOM c ~ ConceptChunk) => 
  c -> Symbol -> Space -> Attributes -> [Constraint] -> ConstrConcept
constrainedNRV' q sym space atts cs = ConstrConcept (cqs (cw q) sym space atts) cs Nothing

cuc' :: (IsUnit u, DOM u ~ ConceptChunk) => String -> NP -> String -> Symbol -> u
                  -> Space -> [Constraint] -> Attributes -> Expr -> ConstrConcept
cuc' nam trm desc sym un space cs atts rv =
  ConstrConcept (cqs (cw (ucs nam trm desc sym un space [])) sym space atts) cs (Just rv)

cnstrw :: (HasAttributes c, Quantity c, Constrained c, HasReasVal c) => c -> ConstrainedChunk
cnstrw c = ConstrainedChunk (qw c) (c ^. constraints) (c ^. reasVal)