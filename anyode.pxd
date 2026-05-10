from libcpp.string cimport string
from libcpp.unordered_map cimport unordered_map
from libcpp.vector cimport vector

cdef extern from *:
     cdef cppclass Info:
        unordered_map[string, vector[double]] nfo_vecdbl
