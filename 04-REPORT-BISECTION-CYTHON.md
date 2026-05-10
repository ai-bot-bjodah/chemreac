# Results

## Phase 1 — Minimal Reproducer (minimal_bug.pyx)

Reduced from 138 lines to 14 lines, zero external dependencies:

```cython
# Trigger: template cppclass with vector[T] member returned from a property
# + module-level function taking vector[double] with default [] arg.
from libcpp.vector cimport vector
cdef extern from *:
    """
    #include <vector>
    template<class T> struct RD { std::vector<T> v; };
    """
    cdef cppclass RD[T]:
        vector[T] v
cdef class C:
    cdef RD[double] *p
    property v:
        def __get__(self): return self.p.v
def f(vector[double] x=[]):
    pass
```

The exact trigger combination is: template cppclass with vector[T] member returned from a property AND a module-level def with vector[double] x=[] default
arg. Both conditions are required.

## Phase 2 — Bisection Result

First bad commit: ed2b40be6cad

 "Implement PEP-669 sys.monitoring support (GH-6144)" — Stefan Behnel, 2024-08-21

The relevant part of that commit: "Clean up the ownership of code objects between functions and their def/cpdef wrappers — fused functions use a separate
code object for each specialisation." This change in Code.py broke utility code deduplication — __pyx_convert_vector_to_py_double now gets emitted once per
specialisation scope instead of once globally.