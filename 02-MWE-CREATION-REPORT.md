✦ I've successfully created a Minimal Working Example (MWE) from chemreac that reproduces the duplicate __pyx_convert_vector_to_py_double issue described in
  cython/cython#6981.

  The MWE consists of exactly two files: mwe.pyx and a simple reproduction script reproduce.sh.

  Cython deduplication logic for C++ vector utility codes breaks in this specific environment when ReactionDiffusion[double] template instantiation mixes with
  properties that trigger vector-to-Python conversions alongside cvode_predefined passing a default list [] to a vector[double] argument.

  How to reproduce it

  Run the shell script I created in the root directory:
   1 ./reproduce.sh

  Output:

   1 warning: mwe.pyx:116:12: Unreachable code
   2 warning: mwe.pyx:131:8: Unreachable code
   3 Counting definitions of '__pyx_convert_vector_to_py_double' in mwe.cpp:
   4 2
   5 If the count is 2, the bug (cython#6981) has been successfully reproduced.

  The bug triggers when Cython 3.1.0+ (compiled natively from the cython git submodule) inadvertently generates the exact same underlying vector.to_py C++
  utility function (__pyx_convert_vector_to_py_double) twice into the generated mwe.cpp file.

  The mwe.pyx file was algorithmically reduced from chemreac/_chemreac.pyx to precisely the exact class methods and properties that interfere to cause Cython's
  utility code deduplication to fail.