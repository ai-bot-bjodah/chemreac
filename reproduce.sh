#!/bin/bash

# Cythonize the MWE file to C++
PYTHONPATH=cython python3 cython/cython.py -3 --cplus -I chemreac/include -I external/anyode/cython_def mwe.pyx

# Check the generated C++ file for duplicate utility code definitions
echo "Counting definitions of '__pyx_convert_vector_to_py_double' in mwe.cpp:"
grep -c "static PyObject \*__pyx_convert_vector_to_py_double(std::vector<double>  const &__pyx_v_v) {" mwe.cpp

echo "If the count is 2, the bug (cython#6981) has been successfully reproduced."
