## \file OutputFormat.py
# \author Thulasi Jegatheesan
# \brief Provides the function for writing outputs
## \brief Writes the output values to output.txt
# \param T_W temperature of the water: the average kinetic energy of the particles within the water (degreeC)
# \param E_W change in heat energy in the water: change in thermal energy within the water (J)
def write_output(T_W, E_W):
    outputfile = open("output.txt", "w")
    print("T_W = ", end="", file=outputfile)
    print(T_W, file=outputfile)
    print("E_W = ", end="", file=outputfile)
    print(E_W, file=outputfile)
    outputfile.close()
