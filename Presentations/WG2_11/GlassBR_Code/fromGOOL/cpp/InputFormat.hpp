#include "InputParameters.hpp"
#ifndef InputFormat_h
#define InputFormat_h

#include <string>
#include <vector>

using std::string;
using std::vector;
using std::ifstream;
using std::ofstream;

namespace GlassBR {
    
    
    void get_input(string filename, InputParameters &inparams);
}

#endif
