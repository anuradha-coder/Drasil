module Drasil.NoPCM.Assumptions where --all of this file is exported

import Language.Drasil
import Utils.Drasil

import Data.Drasil.Concepts.Documentation (model, assumpDom, material_)

import Data.Drasil.Quantities.PhysicalProperties (vol)
import Data.Drasil.Quantities.Thermodynamics (boilPt, meltPt)

import Data.Drasil.Concepts.Thermodynamics as CT (heat)
import qualified Data.Drasil.Quantities.Thermodynamics as QT (temp)

import Drasil.SWHS.Assumptions (assumpTEO, assumpHTCC, assumpCWTAT,
  assumpLCCCW, assumpTHCCoT, assumpTHCCoL, assumpS14, assumpPIT)
import Drasil.SWHS.Concepts (tank, water)
-- import Drasil.SWHS.References (swhsCitations)
import Drasil.SWHS.Unitals (volHtGen, tempC, tempInit, tempW, htCapW, wDensity)

-------------------------
-- 4.2.1 : Assumptions --
-------------------------

assumptions :: [ConceptInstance]
assumptions = [assumpTEO, assumpHTCC, assumpCWTAT, assumpDWCoW, assumpSHECoW,
  assumpLCCCW, assumpTHCCoT, assumpTHCCoL, assumpCTNTD, assumpWAL, assumpPIT,
  assumpNIHGBW, assumpAPT]
  
assumpS3, assumpS4, assumpS5, assumpS9_npcm, assumpS12, assumpS13 :: Sentence
assumpDWCoW, assumpSHECoW, assumpCTNTD, assumpNIHGBW, assumpAPT,
  assumpWAL :: ConceptInstance

assumpS3 = 
  foldlSent [S "The", phrase water, S "in the", phrase tank,
  S "is fully mixed, so the", phrase tempW `isThe`
  S "same throughout the entire", phrase tank]

assumpS4 = 
  foldlSent [S "The", phrase wDensity, S "has no spatial variation; that is"
  `sC` S "it is constant over their entire", phrase vol]

assumpDWCoW = cic "assumpDWCoW" assumpS4
  "Density-Water-Constant-over-Volume" assumpDom

assumpS5 = 
  foldlSent [S "The", phrase htCapW, S "has no spatial variation; that", 
  S "is, it is constant over its entire", phrase vol]

assumpSHECoW = cic "assumpSHECoW" assumpS5
  "Specific-Heat-Energy-Constant-over-Volume" assumpDom

assumpS9_npcm = 
  foldlSent [S "The", phrase model, S "only accounts for charging",
  S "of the tank" `sC` S "not discharging. The", phrase tempW, S "can only",
  S "increase, or remain constant; it cannot decrease. This implies that the",
  phrase tempInit, S "is less than (or equal to) the", phrase tempC]

assumpCTNTD = cic "assumpCTNTD" assumpS9_npcm
  "Charging-Tank-No-Temp-Discharge" assumpDom

assumpS12 = 
  S "No internal" +:+ phrase heat +:+ S "is generated by the water; therefore, the"
  +:+ phrase volHtGen +:+. S "is zero"

assumpNIHGBW = cic "assumpNIHGBW" assumpS12
  "No-Internal-Heat-Generation-By-Water" assumpDom

assumpWAL = cic "assumpWAL" (assumpS14 $ phrase material_ +:+
  sParen (phrase water +:+ S "in this case")) "Water-Always-Liquid" assumpDom

assumpS13 = 
  S "The pressure in the" +:+ phrase tank +:+ S "is atmospheric, so the" +:+
  phrase meltPt `sAnd` phrase boilPt +:+ S "of water are" +:+
  S (show (0 :: Integer)) :+: Sy (unit_symb QT.temp) `sAnd`
  S (show (100 :: Integer)) :+: Sy (unit_symb QT.temp) `sC` S "respectively"

assumpAPT = cic "assumpAPT" assumpS13
  "Atmospheric-Pressure-Tank" assumpDom
