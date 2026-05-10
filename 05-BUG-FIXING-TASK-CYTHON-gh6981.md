# Bug-fixing assignment: Cython gh-6981

You are assigned to fix Cython issue gh-6981 against current Cython `master`.

The user-facing regression is that Cython can generate duplicate C++ helper definitions for `std::vector[double] -> Python` conversion. The minimal reproducer is in the parent repository as `minimal_bug.pyx`; turn it into a Cython regression test, then fix the compiler so the generated C++ contains only one definition of `__pyx_convert_vector_to_py_double`.

## Verified facts

I verified the report in `04-REPORT-BISECTION-CYTHON.md` locally.

- Current Cython `master` at `ab85b37b6` generates two definitions of `__pyx_convert_vector_to_py_double` for `minimal_bug.pyx`.
- The reported first bad commit `ed2b40be6cad736ab39cffa2503d816ef2c6741e` also generates two definitions.
- Its parent `fdbca9960dc484dd21b580dac72074659c5d6047` generates one definition.
- With Python headers installed, the parent generated C++ compiles, while the bad commit and current `master` fail with:

```text
error: redefinition of 'PyObject* __pyx_convert_vector_to_py_double(const std::vector<double>&)'
```

The trigger shape in the report is also verified. On current `master`, either of these simplifications makes the duplicate disappear:

- remove the extension-type property that returns `self.p.v`;
- keep the property but change `def f(vector[double] x=[]):` to a non-default argument.

So the regression requires two independent requests for the same C++ conversion utility:

```cython
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
        def __get__(self):
            return self.p.v

def f(vector[double] x=[]):
    pass
```

## Regression test

Add a Cython test before fixing the compiler and confirm that it fails. The natural location is either:

- `tests/compile/cpp_vector_to_py_dedup_T6981.pyx`, because the failure is a generated C++ compile error; or
- `tests/run/cpp_vector_to_py_dedup_T6981.pyx`, if you add a tiny doctest and want to follow Cython's preference for bug tests in `tests/run`.

Cython's developer docs say bug tests should be named with the ticket number, preferably in `tests/run`, and `tests/run` tests use doctests. For this issue, `tests/compile` is acceptable because successful C++ compilation is the behavior under test.

Suggested compile test:

```cython
# mode: compile
# tag: cpp

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
        def __get__(self):
            return self.p.v

def f(vector[double] x=[]):
    pass
```

Run the focused test with something like:

```bash
cd cython
python runtests.py -vv --backends=cpp cpp_vector_to_py_dedup_T6981
```

After the fix, also run nearby C++ conversion/default tests:

```bash
cd cython
python runtests.py -vv --backends=cpp cpp_stl_conversion cyfunction_defaults_cpp cpp_templates_nested fused_cpp
```

Use `CFLAGS=-O0` if local test runs are slow.

## Investigation map

Start with these files:

- `Cython/Compiler/PyrexTypes.py`: `CppClassType.create_to_py_utility_code()` builds the `vector.to_py` utility name and calls `env.use_utility_code(...)`.
- `Cython/Utility/CppConvert.pyx`: contains the `vector.to_py` Cython utility template that generates `__pyx_convert_vector_to_py_double`.
- `Cython/Compiler/Code.py`: `UtilityCode.__hash__`, `UtilityCode.__eq__`, and `GlobalState.use_utility_code()` are responsible for utility-code deduplication.
- `Cython/Compiler/Nodes.py`: the extension property and Python function/default argument paths eventually request conversion utilities.
- `Cython/Compiler/ExprNodes.py`: `PyCFunctionNode` and `CodeObjectNode` changed in the bad commit.
- `Cython/Compiler/FusedNode.py`: touched heavily by the bad commit; probably not the direct cause here, but relevant because the commit changed code-object ownership.

When debugging, instrument `GlobalState.use_utility_code()` temporarily to print utility `name`, `file`, hash, and the first line that differs between duplicate utility objects. Do not leave this instrumentation in the patch.

## Hypotheses and fix avenues

Hypothesis 1: the two `CythonUtilityCode` objects for `vector.to_py` are not equal even though they generate the same C function name.

Why it fits: the generated file contains one prototype but two identical-looking function bodies in `module_code`. `GlobalState.use_utility_code()` deduplicates by object equality/hash, so duplicate emission means the utility objects differ before emission or bypass the normal dedup path.

How to check: log the `UtilityCode` `_parts_tuple`, `name`, `file`, `compiler_directives`, and generated `impl` for both requests. Look for differences in source markers, directive state, line numbers, code-object state, or error-label metadata.

Possible fix: make equality/hash for Cython utility code ignore non-semantic differences, or canonicalize the utility before it reaches `GlobalState.use_utility_code()`. Be conservative: do not merge utility code that has different C names, different type substitutions, different directives that change generated C, or different dependencies.

Hypothesis 2: directive inheritance changed, causing the same C++ conversion utility to be generated in two directive contexts.

Why it fits: `CppClassType.create_to_py_utility_code()` calls `CythonUtilityCode.filter_inherited_directives(env.directives)`. The bad commit changed internal default/getter generation paths, including `CompilerDirectivesNode.for_internal(...)`. If the property getter and function-default path now see different directive dicts, `CythonUtilityCode.load(...)` may produce two different utility objects with the same C `cname`.

How to check: compare the filtered directives passed to `CythonUtilityCode.load("vector.to_py", "CppConvert.pyx", ...)` for the property getter path and the default-argument path.

Possible fix: ensure utility code generated for built-in C++ conversions uses a stable, module-level directive set, or further filter directives so only directives that can actually affect the utility code remain. Preserve directives that intentionally affect utility code, such as bounds/wrap behavior if used by a utility.

Hypothesis 3: `std::vector[double]` type caching is too local.

Why it fits: `create_to_py_utility_code()` returns early when `self.to_py_function` is already set, but that cache lives on the type instance. The property path and default-argument path may hold different `CppClassType` instances for the same specialized `std::vector[double]`. Before `ed2b40be6cad`, global utility dedup still masked this; after the commit, it no longer does.

How to check: log `id(self)`, `self.cname`, `self.specialization_name()`, and `self.to_py_function` in `CppClassType.create_to_py_utility_code()`. If two different type objects produce the same `cname`, the type-local cache is insufficient on its own.

Possible fix: do not rely on the type object cache for correctness. Ensure `GlobalState.use_utility_code()` deduplicates equal conversion helpers reliably. A more targeted alternative is a module-level map from conversion helper C name to utility code for C++ container conversions, but prefer an existing Cython-wide dedup mechanism if possible.

Hypothesis 4: the default-argument wrapper/getter path requests the same conversion utility during code generation instead of declaration analysis.

Why it fits: the duplicate disappears when `x=[]` is removed. Function defaults for non-Python C++ arguments need conversion support for `__defaults__`. The bad commit changed `PyCFunctionNode`/`CodeObjectNode` ownership and moved some generation work around. This may have shifted a utility-code request into a context where the same utility is emitted twice.

How to check: set breakpoints or temporary prints in `PyCFunctionNode.analyse_types()`, `PyCFunctionNode.generate_result_code()`, `DefNode.generate_function_definitions()`, and `PyClassPropertyNode`/property getter generation paths. Confirm when `vector.to_py` is requested.

Possible fix: move the default-argument conversion utility request back to analysis/declaration time, or make the defaults getter use the module/global scope consistently when requesting utility code. Avoid special-casing only `vector[double]`; the fix should work for `vector[int]`, `list[double]`, `map[...]`, and other C++ conversion utilities.

Hypothesis 5: generated Cython utility code is being emitted directly into `module_code` in a way that bypasses the shared `utility_code_def` dedup expectation.

Why it fits: `Cython/Utility/CppConvert.pyx` utilities are written in Cython, not plain C utility fragments. They are compiled into C functions and appear in `module_code`. If two Cython utility modules are generated independently, plain `UtilityCode` dedup may be too late or keyed on generated code that differs slightly.

How to check: inspect the `CythonUtilityCode` class and its generated module fragments. Determine whether `vector.to_py` reaches `GlobalState.use_utility_code()` once or twice, and whether the duplicate body is produced by a nested Cython compilation step.

Possible fix: add or restore a stable cache key for Cython utility code based on utility name, source file, Tempita context, and filtered directives. If generated code must differ in non-semantic comments only, strip or normalize those differences before equality/hash.

## Constraints

- Do not fix this by renaming one helper. Both call sites must call the same conversion helper.
- Do not hide the issue by adding `inline`, `static inline`, or preprocessor guards around the duplicate body. The compiler should emit one helper definition per helper C name.
- Do not special-case only `double`; use this MWE as a symptom of a generic utility-code deduplication bug.
- Keep the patch narrow. The bad commit touched PEP-669 monitoring, code objects, fused functions, defaults, and tracing; this issue is likely in the intersection of utility-code generation and the new code-object/default path, not in all of PEP-669.

## Acceptance criteria

- The new `T6981` test fails before the fix and passes after it.
- Generated C++ for the MWE contains exactly one definition of:

```text
static PyObject *__pyx_convert_vector_to_py_double(std::vector<double>  const &__pyx_v_v)
```

- The focused `--backends=cpp` tests listed above pass.
- The fix does not change generated helper names or public Cython behavior except removing duplicate helper emission.

## Bug-fix report and PR text

Write a short report after the fix. Include:

- root cause, stated in terms of Cython internals;
- why the first bad commit exposed it;
- the chosen fix and why broader alternatives were rejected;
- tests added and commands run;
- any remaining risk, especially around utility-code deduplication and directive-specific utility code.

Suggested PR title:

```text
Fix duplicate C++ conversion utility emission for vector defaults
```

Suggested PR summary:

```text
Fixes gh-6981 by ensuring Cython emits only one C++ `vector.to_py`
conversion helper when the same `std::vector[T]` conversion is requested
from both an extension-type property getter and a Python function default
argument path.

Adds a C++ regression test for the minimized reproducer from gh-6981. The
test failed with a duplicate definition of
`__pyx_convert_vector_to_py_double` before this change.
```

Suggested PR test section:

```text
Tests:
- python runtests.py -vv --backends=cpp cpp_vector_to_py_dedup_T6981
- python runtests.py -vv --backends=cpp cpp_stl_conversion cyfunction_defaults_cpp cpp_templates_nested fused_cpp
```
