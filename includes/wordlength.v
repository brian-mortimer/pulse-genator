//////////////////////////////////////////////////////////////////////////////////
// University of Limerick
// Author: Karl Rinne
// Create Date: 26/08/2015
// Module Name: wordlength.v
// Target Platform and Devices: generic
//////////////////////////////////////////////////////////////////////////////////

// Constant function to determine the wordlength required to encode a value.
// Intended use: Verilog2001 allows the use of constant functions any place
// a constant expression value is required, e.g. the definition of widths of vectors.

function integer wordlength (input integer value);
    for (wordlength=0; value>0; wordlength=wordlength+1) value=value>>1;
endfunction
