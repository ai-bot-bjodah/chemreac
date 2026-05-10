#!/bin/bash
# bisect_test.sh — used by: git bisect run ../bisect_test.sh
# Run from inside the cython submodule directory.
#
# Exit codes:
#   0   → good (no duplicate)
#   1   → bad  (duplicate found)
#   125 → skip (Cython itself broken at this commit)

cd "$(dirname "$0")" || exit 125

PYTHONPATH=cython python3 cython/cython.py -3 --cplus minimal_bug.pyx > bisect_cython.log 2>&1
if [ $? -ne 0 ]; then
    exit 125
fi

COUNT=$(grep -c \
    "static PyObject \*__pyx_convert_vector_to_py_double(std::vector<double>  const &__pyx_v_v) {" \
    minimal_bug.cpp 2>/dev/null || echo 0)

if [ "$COUNT" -gt 1 ]; then
    exit 1   # bad: duplicate definition present
else
    exit 0   # good: only one definition
fi
