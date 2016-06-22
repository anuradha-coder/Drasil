{-# OPTIONS -Wall #-} 
{-# LANGUAGE FlexibleContexts #-} 
module GlassBRBody1 where
import Data.Char (toLower)
import Language.Drasil.Printing.Helpers
import GlassBRExample1
import Language.Drasil.Spec (Sentence(..),sMap, Accent(..)) --May need to update imports to hide Ref.
                            --More likely setup an API or something to
                            --Restrict access for novice users.
import Language.Drasil.Unit (Unit(..), UnitDefn(..))
import Language.Drasil.SI_Units2 
import Language.Drasil.Chunk
import Control.Lens ((^.))
import Language.Drasil.Misc
import Language.Drasil.Document
import Language.Drasil.Reference
import Language.Drasil.Instances ()

this_si :: [UnitDefn]
this_si = map UU [metre, kilogram, second] ++ map UU [pascal, newton]

s1, s1_intro, s1_1, s1_1_intro, s1_1_table, s1_2, s1_2_intro, 
  s1_2_table, s1_3, s1_3_table, s2, s2_intro, s2_1, s2_1_intro,
  s2_2, s2_2_intro, s2_3, s2_3_intro, s3, s3_intro, s3_1, s3_1_intro,
  s3_2, s3_2_intro, s4, s4_intro, s4_1, s4_1_bullets, s4_2, s4_2_intro,
  s5, s5_intro, s5_1, s5_1_table, s5_2, s5_2_bullets, s6, s6_intro, s6_1, 
  s6_1_intro, s6_1_1, s6_1_1_intro, s6_1_1_bullets, s6_1_2, s6_1_2_intro, 
  s6_1_2_list, s6_1_3, s6_1_3_list, s6_2, s6_2_intro, s6_2_1, s6_2_1_intro, 
  s6_2_1_list, s6_2_2, s6_2_3, s6_2_4, s6_2_4_intro, s6_2_5, s6_2_5_intro,
  s6_2_5_table1, s6_2_5_table2, s6_2_5_intro2, s6_2_5_table3, s7, s7_intro,
  s7_list, s7_1, s7_1_intro, s8, s8_list, s9, s9_list, s10, s10_intro 
  , fig_glassbr, fig_2, fig_3:: LayoutObj

glassBR_srs :: Document  
glassBR_srs = Document (S "Software Requirements Specification for Glass-BR")
          (S "Nikitha Krithnan and Spencer Smith") [s1,s2,s3,s4,s5,s6,s7,s8,s9,s10]

s1 = Section 0 (S "Reference Material") [s1_intro, s1_1, s1_2, s1_3]

s1_intro = Paragraph (S "This section records information for easy reference")

s1_1 = Section 1 (S "Table of Units") [s1_1_intro, s1_1_table]

s1_1_intro = Paragraph (S "Throughout this document SI (Syst" :+: 
           (F Grave 'e') :+: S "me International d'Unit" :+:
           (F Acute 'e') :+: S "s) is employed as the unit system." :+:
           S " In addition to the basic units, several derived units are" :+: 
           S " employed as described below. For each unit, the symbol is" :+: 
           S " given followed by a description of the unit followed by " :+: 
           S "the SI name.")

s1_1_table = Table [S "Symbol", S "Description", S "Name"] (mkTable
  [(\x -> Sy (x ^. unit)),
   (\x -> (x ^. descr)),
   (\x -> S (x ^. name))
  ] this_si)
  (S "Table of Units") True

s1_2 = Section 1 (S "Table of Symbols") [s1_2_intro, s1_2_table]

s1_2_intro = Paragraph $ 
  S "The table that follows summarizes the symbols used in this " :+:
  S "document along with their units.  The symbols are listed in " :+:
  S "alphabetical order." 
  
s1_2_table = Table [S "Symbol", S "Units", S "Description"] (mkTable
  [(\ch -> U (ch ^. symbol)),  
   (\ch -> Sy $ ch ^. unit),
   (\ch -> ch ^. descr)
   ]
  glassBRSymbols)
  (S "Table of Symbols") False

s1_3 = Section 1 (S "Abbreviations and Acronyms") [s1_3_table]

s1_3_table = Table [S "Abbreviations", S "Full Form"] (mkTable
  [(\ch -> S $ ch ^. name),
   (\ch -> ch ^. descr)]
  acronyms)
  (S "Abbreviations and Acronyms") False

s2 = Section 0 (S "Introduction") [s2_intro, s2_1, s2_2, s2_3]

s2_intro = Paragraph $ 
  S "Software is helpful to efficiently and correctly predict the glass slab. " :+:
  S "The blast under consideration is any type of man-made explosion. The software, " :+:
  S "herein called Glass-BR aims to predict the blast risk involved with the glass " :+:
  S "slab using an intuitive interface. The following section provides an overview " :+:
  S "of the Software Requirements Specification (SRS) for Glass-BR. This section " :+:
  S "explains the purpose the document is designed to fulfil, the scope of the requirements " :+:
  S "and the organization of the document: what the document is based on and intended to portray."

s2_1 = Section 1 (S "Purpose of Document") [s2_1_intro]

s2_1_intro = Paragraph $
  S "The main purpose of this document is to predict whether a given glass slab is likely" :+:
  S " to resist a specified blast. The goals and theoretical models used in the Glass-BR " :+:
  S "code are provided, with an emphasis on explicitly identifying assumptions and " :+:
  S "unambiguous definitions. This document is intended to be used as a reference to " :+:
  S "provide all information necessary to understand and verify the analysis. The SRS is " :+:
  S "abstract because the contents say what problem is being solved, but not how to solve " :+:
  S "it. This document will be used as a starting point for subsequent development phases, " :+:
  S "including writing the design specification and the software verification and validation " :+:
  S "plan. The design document will show how the requirements are to be realized, including " :+:
  S "decisions on the numerical algorithms and programming environment. The verification and " :+:
  S "validation plan will show the steps that will be used to increase confidence in the " :+:
  S "software documentation and the implementation."
--newline?

s2_2 = Section 1 (S "Scope of Requirements") [s2_2_intro]

s2_2_intro = Paragraph $
  S "The scope of the requirements includes getting all input parameters related to the " :+:
  S "glass slab and also the parameters related to blast type. Given the input, Glass-BR " :+:
  S "is intended to use the data and predict whether the glass slab is safe to use or not."

s2_3 = Section 1 (S "Organization of Document") [s2_3_intro]

s2_3_intro = Paragraph $
  S "The organization of this document follows the template for an SRS for scientific " :+:
  S "computing software proposed by [1] and [2], with some aspects taken from Volere template " :+:
  S "16 [3]. The presentation follows the standard pattern of presenting goals, theories, " :+:
  S "definitions, and assumptions. For readers that would like a more bottom up approach, " :+:
  S "they can start reading the data definitions in Section 6.2.4 and trace back to find " :+:
  S "any additional information they require. The goal statements are refined to the " :+:
  S "theoretical models, and theoretical models to the instance models. The data definition " :+:
  S "are used to support the definitions of the different models." 

s3 = Section 0 (S "Stakeholders") [s3_intro, s3_1, s3_2]

s3_intro = Paragraph $
  S "This section describes the Stakeholders: the people who have an interest in the product."

s3_1 = Section 1 (S "The Client") [s3_1_intro]

s3_1_intro = Paragraph $
  S "The client for Glass-BR is a company named Entuitive. It is developed by Dr. Manuel " :+:
  S "Campidelli. The client has the final say on acceptance of the product."

s3_2 = Section 1 (S "The Customer") [s3_2_intro]

s3_2_intro = Paragraph $
  S "The customers are the end user of Glass-BR."

s4 = Section 0 (S "General System Description") [s4_intro, s4_1,s4_2]

s4_intro = Paragraph $
  S "This section provides general information about the system, identifies the interface " :+:
  S "between the system and its environment, and describes the user characteristics and the " :+:
  S "system constraints."

s4_1 = Section 1 (S "User Characteristics") [s4_1_bullets]

s4_1_bullets = BulletList $
  [(S "The end user of Glass-BR is expected to have completed at least the equivalent of " :+:
    S "the second year of an undergraduate degree in civil or structural engineering."),
  (S "The end user is expected to have an understanding of theory behind glass breakage " :+:
    S "and blast risk."),
  (S "The end user is expected to have basic computer literacy to handle the software.")]

s4_2 = Section 1 (S "System Constraints") [s4_2_intro]

s4_2_intro = Paragraph $
  S "N/A"

s5 = Section 0 (S "Scope of the Project") [s5_intro,s5_1,s5_2]

s5_intro = Paragraph $
  S "This section presents the scope of the project. It describes the expected use of " :+:
  S "Glass-BR as well as the inputs and outputs of each action. The use cases are " :+:
  S "input and output, which defines the action of getting the input and displaying the " :+:
  S "output."

s5_1 = Section 1 (S "Product Use Case Table") [s5_1_table]

-- Todo: figure out how to include s5_1_table

-- s5_1_table = Table [S "Use Case NO.", S "Use Case Name", S "Actor", S "Input and Output"] (mkTable
--  [(\x -> S $ x),(\x -> S $ x), (\x -> S $ x), (\x -> S $ x)],
--  [("1", "Inputs", "User", "Characteristics of the glass slab and of the blast. Details in 5.2."),
--  ("2", "Output", "Glass-BR", "Whether or not the glass slab is safe for the calculated load and supporting calculated values")])
--  (S "Use Case Table") True

s5_2 = Section 1 (S "Individual Product Use Cases") [s5_2_bullets]

s5_2_bullets = BulletList $
  [(S "Use Case 1 refers to the user providing input to Glass-BR for use within the analysis. " :+:
    S "There are two classes of inputs: glass geometry and blast type. The glass geometry " :+:
    S "based inputs include the dimensions of the glass plane, glass type and response " :+:
    S "type. The blast type input includes parameters like weight of charge, TNT equivalent " :+:
    S "factor and stand off distance from the point of explosion. These parameters describes " :+:
    S "charge weight and stand off blast. Another input the user gives is the tolerable " :+:
    S "value of probability of breakage."),
  (S " Use Case 2 Glass-BR outputs the glass slab will be safe by comparing whether capacity > " :+:
    S "demand. Capacity is the load resistance calculated and Demand is the requirement which " :+:
    S "is the 3 second duration equivalent pressure. The second condition is to check whether " :+:
    S "the calculated probability (Pb) is less than the tolerable probability (Pbtol ) which is " :+:
    S "obtained from the user as an input. If both conditions return true then its shown that " :+:
    S "the glass slab is safe to use, else if both returns false then the glass slab is " :+:
    S "considered unsafe. All the supporting calculated values are also displayed as output.")]

s6 = Section 0 (S "Specific System Description") [s6_intro, s6_1,s6_2]

s6_intro = Paragraph $ S "This section first presents the problem " :+:
  S "description, which gives a high-level view of the problem to be solved" :+:
  S ". This is followed by the solution characteristics specification, " :+:
  S "which presents the assumptions, theories, definitions."

s6_1 = Section 1 (S "Problem Description") [s6_1_intro, s6_1_1, s6_1_2, s6_1_3]

s6_1_intro = Paragraph $ S "A system is needed to efficiently and correctly" :+:
  S " predict the blast risk involved with the glass. " :+: S (gLassBR ^. name) :+:
  S " is a computer program " :+: S "developed to interpret the inputs to give " :+:
  S "out the outputs which predicts whether the glass slab can withstand the " :+:
  S "blast under the conditions."

s6_1_1 = Section 2 (S "Terminology and Definitions") [s6_1_1_intro,s6_1_1_bullets]
  
s6_1_1_intro = Paragraph $ S "This subsection provides a list of terms that " :+:
  S "are used in subsequent sections and their meaning, with the purpose of ":+:
  S "reducing ambiguity and making it easier to correctly understand the ":+:
  S "requirements:"

s6_1_1_bullets = BulletList $ map (\c -> S (capitalize (c ^. name)) :+:
  S " - " :+: (c ^. descr)) [aR, gbr, lite, glassTy, gtf, an, ft, hs, lateral, load, specDeLoad, lr, 
  ldl, nfl, glassWL, sdl, lsf, pb, specA, blaReGLa, eqTNTChar, sD]
  
s6_1_2 = Section 2 (physSysDescr ^. descr) [s6_1_2_intro,s6_1_2_list,fig_glassbr]

s6_1_2_intro = Paragraph $ S "The physical system of Glass-BR, as shown in " :+:
  (makeRef fig_glassbr) :+: S ", includes the following elements:"

fig_glassbr = Figure (S "The physical system") "physicalsystimage.png"
  
s6_1_2_list = SimpleList $ [
  (S "PS1", S "Glass Slab"), 
  (S "PS2", S "The point of explosion. Where the bomb,or any man made explosive, " :+:
   S "is located represents the " :+: S "The stand off distance is the distance" :+:
   S " between the point of explosion and the glass.")]

s6_1_3 = Section 2 ((goalStmt ^. descr) :+: S "s") [s6_1_3_list]

s6_1_3_list = SimpleList $ [
  (S "GS1", S "Analyze and predict whether the glass slab under " :+:
  S "consideration will be able to withstand the explosion of certain degree " :+:
  S "which is calculated based on user input.")]

s6_2 = Section 1 (S "Solution Characteristics Specification") 
  [s6_2_intro,s6_2_1,s6_2_2,s6_2_3,s6_2_4]

s6_2_intro = Paragraph $ S "This section explains all the assumptions" :+:
  S " considered and the " :+: (sMap (map toLower) (theoreticMod ^. descr)) :+:
  S " which as supported by the data definitions." 
  
s6_2_1 = Section 2 (assumption ^. descr :+: S "s") [s6_2_1_intro,s6_2_1_list]

s6_2_1_intro = Paragraph $ S "This section simplifies the original problem " :+:
  S "and helps in developing the theoretical model by filling in the " :+:
  S "missing information for the physical system. The numbers given in the " :+:
  S "square brackets refer to the " :+: (sMap (map toLower) (dataDefn ^. descr)) :+:
  S (" " ++ sqbrac (dataDefn ^. name)) :+: S ", or " :+:
  (sMap (map toLower) (instanceMod ^. descr)) :+: S (" " ++ 
  sqbrac (instanceMod ^. name)) :+: S ", in which the respective " :+: 
  (sMap (map toLower) $ assumption ^. descr) :+: S " is used."

s6_2_1_list =SimpleList $ [
  (S "A1", S "The standard E1300-09a for calculation applies only to monolithic, " :+:
    S "laminated, or insulating glass constructions of rectangular shape with continuous " :+:
    S "lateral support along one, two, three, or four edges. This practice assumes " :+:
    S "that (1) the supported glass edges for two, three and four-sided support conditions are " :+:
    S "simply supported and free to slip in plane; (2) glass supported on two sides " :+:
    S "acts as a simply supported beam and (3) glass supported on one side acts as " :+:
    S "a cantilever."), 
  (S "A2", S "This practice does not apply to any form of wired, patterned, etched, " :+:
    S "sandblasted, drilled, notched, or grooved glass with surface and edge treatments " :+:
    S "that alter the glass strength."),
  (S "A3", S "This system only considers the external explosion scenario for its calculations."),
  (S "A4", S "Standard values used for calculation in Glass-BR are: (a) " :+: (U $ sflawParamM ^. symbol) :+:
    S " = 7 " :+: Sy (sflawParamM ^. unit) :+: S " (b) " :+: (U $ sflawParamK ^. symbol) :+: S " = 2.86 * 10^(-53) " :+:
    Sy (sflawParamK ^. unit) :+: S " (c) " :+: (U $ mod_elas ^. symbol) :+: S " = 7.17 * 10^7 " :+:
    Sy (mod_elas ^. unit) :+: S " (d) " :+: (U $ load_dur ^. symbol) :+: S " = 3 " :+:
    Sy (load_dur ^. unit)),
  (S "A5", S "Glass under consideration is assumed to be a single lite. Hence the value of " :+:
    (U $ loadSF ^. symbol) :+: S " is equal to 1 for all calculations in Glass-BR."),
  (S "A6", S "Boundary conditions for the glass slab is assumed to be 4-sided support for " :+:
    S "calculations"),
  (S "A7", S "The response type considered in Glass-BR is flexural."),
  (S "A8", S "With reference to A4 the value of load distribution factor (" :+: (U $ loadDF ^. symbol) :+:
    S ") is a constant in Glass-BR. It is calculated by the equation: " :+: (U $ loadDF ^. symbol) :+:
    S " = " :+: (U $ load_dur ^. symbol) :+: S ". Using this, " :+: (U $ loadDF ^. symbol) :+: S " = " :+:
    S "0.27.")]
--equation in sentence.

s6_2_2 = Section 2 ((theoreticMod ^. descr) :+: S "s") (s6_2_2_TMods)
  
s6_2_2_TMods :: [LayoutObj]
s6_2_2_TMods = map Definition (map Theory [t1SafetyReq,t2SafetyReq])

s6_2_3 = Section 2 ((instanceMod ^. descr) :+: S "s") (s6_2_3_IMods)

s6_2_3_IMods :: [LayoutObj]
s6_2_3_IMods = map Definition (map Theory [probOfBr,calOfCap,calOfDe])

s6_2_4 = Section 2 ((dataDefn ^. descr) :+: S "s") (s6_2_4_intro:s6_2_4_DDefns)

s6_2_4_intro = Paragraph $ S "This section collects and defines all the data " :+:
  S "needed to build the instance models."

s6_2_4_DDefns ::[LayoutObj] 
s6_2_4_DDefns = map Definition (map Theory [hFromt,loadDurFac,strDisFac,nonFacLoad,gTF,dL,tolPre,
  tolStrDisFac])

s6_2_5 = Section 2 (S "Data Constraints") [s6_2_5_intro,s6_2_5_table1,s6_2_5_table2,s6_2_5_intro2,s6_2_5_table3]

s6_2_5_intro = Paragraph $
  S "Table 2 shows the data constraints on the input variables. The column physical constraints " :+:
  S "gives the physical limitations on the range of values that can be taken by the variable. " :+:
  S "The constraints are conservative, to give the user of the model the flexibility to experiment " :+:
  S "with unusual situations. The column of typical values is intended to provide a feel for a " :+:
  S "common scenario. The uncertainty column provides an estimate of the confidence with which " :+:
  S "the physical quantities can be measured. This information would be part of the input if one " :+:
  S "were performing an uncertainty quantification exercise. Table 3 gives the values of the " :+:
  S "specification parameters used in Table 2. ARmax is the refers to the maximum aspect ratio " :+:
  S "for the plate of glass."

--Todo:
--s6_2_5_table1 =
--s6_2_5_table2 =

s6_2_5_intro2 = Paragraph $
  S "Table 4 shows the constraints that must be satisfied by the output."

--Todo:
--s6_2_5_table3

s7 = Section 0 (S "Fuctional Requirements") [s7_intro, s7_list, s7_1]

s7_intro = Paragraph $
  S "The following section provides the functional requirements, the business tasks that the software " :+:
  S "is expected to complete."


s7_list = SimpleList $
  [(S "R1", S "Input the following quantities, which define the glass dimensions, type of glass, " :+:
    S "tolerable probability of failure and the characteristics of the blast:"),                               --table in simplelist
  (S "R2", S "The system shall set the known values as follows: - " :+: (U $ sflawParamM ^. symbol) :+:
    S ", " :+: (U $ sflawParamK ^. symbol) :+: S ", " :+: (U $ mod_elas ^. symbol) :+: S ", " :+:
    (U $ load_dur ^. symbol) :+: S " following A4" :+: S " - LDF following A8 - LSF following A5"),            --bullets in simplelist
  (S "R3", S "The system shall check the entered input values to ensure that they do not exceed the " :+:
    S "data constraints mentioned in 6.2.5. If any of the input parameters is out of bounds, an error " :+:
    S "message is displayed and the calculations stop."),
  (S "R4", S "Output the input quantities from R1 and the known quantities from R2"),
  (S "R5", S "If is_safe1 and is_safe2 (from T1 and T2) output the message " :+: Quote (S "For the given " :+:
    S "input parameters, the glass is considered safe.") :+: S " If the condition is false, then output the " :+:
    S "message " :+: Quote (S "For the given input parameters, the glass is NOT considered safe.")),
  (S "R6", S "Output the following quantities: - Probability of breakage (" :+: (U $ prob_br ^. symbol) :+:    -- bullets in simplelist
    S ") (IM1) - Load Resistance (LR) (IM2) - Applied load (demand) (" :+: (U $ demand ^. symbol) :+: 
    S ") (IM3) - Actual thickness (" :+: (U $ act_thick ^. symbol) :+: S ") (DD1) - Load Duration Factor " :+:
    S "(LDF) (DD2) - Stress Distribution Factor (" :+: (U $ sdf ^.symbol) :+: S ") (DD3) - Non Factored " :+:
    S "Load (NFL) (DD4) - Glass Type Factor (GTF) (DD5) - Dimensionless load (" :+: (U $ dimlessLoad ^. symbol) :+:
    S ") (DD6) - Tolerable load (" :+: (U $ tolLoad ^. symbol) :+: S ") (DD7) - Stress distribution factor " :+: 
    S "based on " :+: (U $ prob_br ^. symbol) :+: S " (" :+: (U $ sdf_tol ^. symbol) :+: S ") (DD8) -Aspect Ratio" :+:
    S "(AR = a/b)")]

s7_1 = Section 1 (S "Nonfunctional Requirements") [s7_1_intro]

s7_1_intro = Paragraph $
    S "Given the small size, and relative simplicity, of this problem, performance is not a priority. Any " :+:
    S "reasonable implementation will be very quick and use minimal storage. Rather than performance, the " :+:
    S "priority nonfunctional requirements are correctness, verifiability, understandability, reusability, " :+:
    S "maintainability and portability."

s8 = Section 0 (S "Likely Changes") [s8_list]

s8_list = SimpleList $
  [(S "LC1", S "A3 - The system currently only calculates for external blast risk. In the future calculations " :+:
    S "can be added for the internal blast risk."),
  (S "LC2", S "A4, A8 - Currently the values for " :+: (U $ sflawParamM ^. symbol) :+: S ", " :+: (U $ sflawParamK ^. symbol) :+:
  S ", and " :+: (U $ mod_elas ^. symbol) :+: S " are assumed to be the same for all glass. In the future these " :+:
  S "values can be changed to variable inputs."),
  (S "LC3", S "A5 - The software may be changed to accommodate more than a single lite."),
  (S "LC4", S "A6 - The software may be changed to accommodate more boundary conditions than 4-sided support."),
  (S "LC5", S "A7 - The software may be changed to consider more than just flexure of the glass.")]

s9 = Section 0 (S "References") [s9_list]

s9_list = SimpleList $
  [(S "[1]", S "N. Koothoor, " :+: Quote (S "A document drive approach to certifying scientific computing software,") :+:
    S " Master's thesis, McMaster University, Hamilton, Ontario, Canada, 2013."),
  (S "[2]", S "W. S. Smith and L. Lai, " :+: Quote (S "A new requirements template for scientific computing,") :+:
    S " in Proceedings of the First International Workshop on Situational Requirements Engineering Processes " :+:
    S "- Methods, Techniques and Tools to Support Situation-Specific Requirements Engineering Processes, " :+:
    S "SREP'05 (J.Ralyt" :+: (F Acute 'e') :+: S ", P.Agerfalk, and N.Kraiem, eds.), (Paris, France), pp. 107-121, " :+:
    S "In conjunction with 13th IEEE International Requirements Engineering Conference, 2005."),
  (S "[3]", S "J. Robertson and S. Robertson, " :+: Quote (S "Volere requirements specification template edition 16.") :+:
    S " " :+: Quote (S "www.cs.uic.edu/ i442/VolereMaterials/templateArchive16/c Volere template16.pdf") :+: S ", 2012."),
  (S "[4]", S "ASTM Standards Committee, " :+: Quote (S "Standard practice for determining load resistance of glass in " :+:
    S "buildings,") :+: S " Standard E1300-09a, American Society for Testing and Material (ASTM), 2009."),
  (S "[5]", S "ASTM,developed by subcommittee C1408,Book of standards 15.02, " :+: Quote (S "Standard specification for " :+:
    S "flat glass,C1036.")),
  (S "[6]", S "ASTM,developed by subcommittee C14.08,Book of standards 15.02, " :+: Quote (S "Specification for heat " :+:
    S "treated flat glass-Kind HS, kind FT coated and uncoated glass,C1048."))]

s10 = Section 0 (S "Appendix") [s10_intro,fig_2,fig_3]

s10_intro = Paragraph $
  S "This appendix holds the graphs (Figure 2 and Figure 3) used for interpolating values needed in the models."

fig_2 = Figure (S "Figure 2: 3 second equivalent pressure (" :+: U (demand ^. symbol) :+: S ") versus Stand off " :+:
  S "distance (SD) versus charge weight (" :+: U (sflawParamM ^. symbol) :+: S ")") "ASTM_F2248-09.png"

fig_3 = Figure (S "Figure 3: Non dimensional lateral load (" :+: U (dimlessLoad ^. symbol) :+: S ") versus Aspect " :+:
  S "ratio versus Stress distribution factor (" :+: U (sdf ^. symbol) :+: S ")") "ASTM_F2248-09_BeasonEtAl.png"
