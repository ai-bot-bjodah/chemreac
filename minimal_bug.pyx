# Reproducer for cython/cython#6981
# Duplicate definition of __pyx_convert_vector_to_py_double in generated C++.
#
# Trigger: template cppclass with vector[T] member returned from a property
#          combined with a module-level function taking vector[double] with a
#          default empty-list argument.
#
# Reproduces with Cython >= 3.1.0; clean with Cython 3.0.x.

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
