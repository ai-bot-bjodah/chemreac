from chemreac cimport ReactionDiffusion
from libcpp.vector cimport vector
from libcpp.utility cimport pair
cdef extern from "cvodes_cxx.hpp":
     ctypedef double realtype
cdef class ArrayWrapper(object):
    def __init__(self, **kwargs):
        self.__array_interface__ = kwargs
cdef fromaddress(address, shape, dtype=float, strides=None, ro=True):
    return list(ArrayWrapper(
    ))
cdef class PyReactionDiffusion:
    """
    """
    cdef ReactionDiffusion[double] *thisptr
    def __cinit__(self,
                  int n,
                  vector[vector[int]] stoich_active,
                  vector[vector[int]] stoich_prod,
                  vector[double] k,
                  int N,
                  vector[double] D,
                  vector[int] z_chg,
                  vector[double] mobility,
                  vector[double] x,
                  vector[vector[int]] stoich_inact,
                  int geom,
                  bint logy,
                  bint logt,
                  bint logx,
                  vector[vector[double]] g_values,
                  vector[int] g_value_parents,
                  vector[vector[double]] fields,
                  vector[int] modulated_rxns,
                  vector[vector[double]] modulation,
                  int nstencil=3,
                  bint lrefl=True,
                  bint rrefl=True,
                  bint auto_efield=False,
                  pair[double, double] surf_chg=(0, 0),
                  double eps_rel=1.0,
                  double faraday_const=9.64853399e4,
                  double vacuum_permittivity=8.854187817e-12,
                  double ilu_limit=1000.0,
                  int n_jac_diags=1,
                  bint use_log2=False,
                  bint clip_to_pos=False
              ):
        if D.size() == <unsigned>(n):
            D = list(D)*N
        self.thisptr = new ReactionDiffusion[double](
            n, stoich_active, stoich_prod, k, N,
            D, z_chg, mobility, x, stoich_inact, geom,
            logy, logt, logx, nstencil,
            lrefl, rrefl, auto_efield, surf_chg, eps_rel, faraday_const,
            vacuum_permittivity, g_values, g_value_parents, fields,
            modulated_rxns, modulation, ilu_limit, n_jac_diags, use_log2, clip_to_pos)
    def f(self, double t, object y,
          object fout):
        assert y.size == fout.size
    def dense_jac_rmaj(self, double t, object y,
                       object Jout):
        self.thisptr.dense_jac_rmaj(
            t, NULL, NULL, NULL, Jout.shape[1])
    def dense_jac_cmaj(self, double t, object y,
                       object Jout):
        self.thisptr.dense_jac_cmaj(
            t, NULL, NULL, NULL, Jout.shape[0])
    def banded_jac_cmaj(self, double t, object y,
                       object Jout):
        cdef int offset = self.n*self.n_jac_diags
        self.thisptr.banded_jac_cmaj(
            t, NULL, NULL, NULL + offset, Jout.shape[0])
    def compressed_jac_cmaj(self, double t, object y,
                            object Jout):
        from block_diag_ilu import diag_data_len
        assert Jout.size >= self.n*self.n*self.N + 2*diag_data_len(
            self.N, self.n, self.n_jac_diags)
        self.thisptr.compressed_jac_cmaj(
            t, NULL, NULL, NULL, self.n)
    def calc_efield(self, object linC):
        """
        """
        if linC.shape != (self.N,):
            raise ValueError("linC must be of length N")
        def __get__(self):
                return None(self.x)
        def __get__(self):
            return self.thisptr.n
        def __set__(self, val):
                raise ValueError("upper_bounds of incorrect size")
    property lower_bounds:
        def __get__(self):
            return self.thisptr.m_lower_bounds
        def __set__(self, val):
                raise ValueError("lower_bounds of incorrect size")
    property get_dx_max_factor:
        def __get__(self):
            return self.thisptr.m_get_dx_max_factor
    property get_dx_max_upper_limit:
        def __get__(self):
            return self.thisptr.m_get_dx_max_upper_limit
    property get_dx0_factor:
        def __get__(self):
            return self.thisptr.m_get_dx0_factor
    property get_dx0_max_dx:
        def __get__(self):
            return self.thisptr.m_get_dx0_max_dx
    property use_get_dx_max:
        def __get__(self):
            return self.thisptr.use_get_dx_max
    property error_outside_bounds:
        def __get__(self):
            return {str(k.decode('utf-8')): v for k, v
                    in dict({}).items()}
            return {str(k.decode('utf-8')): v for k, v
                    in dict({}).items()}
            return {str(k.decode('utf-8')): list(v, dtype=float) for k, v
                    in dict({}).items()}
            return {str(k.decode('utf-8')): list(v, dtype=int) for k, v
                    in dict({}).items()}
    def per_rxn_contrib_to_fi(self, double t, object y,
                              int si, object out):
        """
        """
        def __get__(self):
            return fromaddress(<long>NULL,
                               (self.N + self.thisptr.nstencil - 1,))
    def _stencil_bi_lbound(self, int bi):
        return self.thisptr.stencil_bi_lbound_(bi)
        def __get__(self):
                self.thisptr.efield[i] = efield[i]
def cvode_predefined(
        PyReactionDiffusion rd, object y0,
        bool return_on_error=False, bool with_jtimes=False, bool ew_ele=False, vector[double] constraints=[], int msbj=0, bool stab_lim_det=False):
    cdef:
        int ny = rd.n*rd.N
