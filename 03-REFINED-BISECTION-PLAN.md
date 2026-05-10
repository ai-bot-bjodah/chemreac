# Refined Bisection & Minimization Plan

This document details the strategy for 1) completely minimizing the bug reproducer to eliminate all external C++ and project-specific dependencies, and 2) bisecting the Cython repository to find the exact commit that introduced the regression.

## Phase 1: Further Minimization of the MWE

The current `mwe.pyx` still relies on `chemreac` C++ headers (`ReactionDiffusion`) and other local project files. The goal is to reduce this to a single, standalone `.pyx` file (and at most one small `.hpp` or `.pxd` file if strictly necessary) that anyone can run without the `chemreac` project context.

### Step-by-Step Minimization Strategy:

1. **Inline C++ Dependencies:**
   - Remove the `cimport` for `ReactionDiffusion` and replace it with an inline declaration using `cdef extern from *`.
   - Create a dummy C++ struct inside the `extern` block that only contains the members needed to make the remaining Python code compile (e.g., a dummy `n` variable, or a dummy `efield` vector).

   *Example Inline C++:*
   ```cython
   cdef extern from *:
       cdef cppclass ReactionDiffusion[T]:
           int n
           # Add minimal fields required by remaining properties
   ```

2. **Strip Class Methods:**
   - Remove methods like `dense_jac_rmaj`, `calc_efield`, and `per_rxn_contrib_to_fi` entirely. Test if the duplication still occurs.
   - If the duplication stops, restore the method but simplify its internal logic to the bare minimum required to maintain the bug.

3. **Simplify Properties and `ArrayWrapper`:**
   - The `ArrayWrapper` and `fromaddress` constructs are likely noise. Attempt to remove them and change the property returns to simple static values (e.g., `return [1.0, 2.0]`).
   - Reduce the number of properties. The current MWE has multiple `property` blocks. Drop them one by one to find the exact property that triggers the conflict.

4. **Simplify `cvode_predefined`:**
   - Reduce the signature of the freestanding `cvode_predefined` function.
   - Remove all arguments except the ones involving C++ `vector` types (like `vector[double] constraints=[]`).
   - Check if removing the default argument `[]` or changing its type resolves the duplication. This is often a critical trigger for utility code generation.

5. **Final Output:**
   - A single `minimal_bug.pyx` file under 50 lines of code with zero external dependencies.

---

## Phase 2: Cython Git Bisection Strategy

Once we have a standalone `minimal_bug.pyx`, we can use `git bisect` on the Cython repository to pinpoint the exact commit that introduced the `__pyx_convert_vector_to_py_double` duplication.

The issue mentions this is a regression from `3.0.12` to `3.1.0+`. 

### Step-by-Step Bisection:

1. **Prepare the Test Script (`bisect_test.sh`):**
   Create a shell script in the root of the workspace that runs Cython against the minimal MWE and checks the result.

   ```bash
   #!/bin/bash
   # bisect_test.sh
   
   # Go to the root directory where minimal_bug.pyx lives
   cd "$(dirname "$0")" || exit 125
   
   # Cythonize the file using the current state of the cython repo
   PYTHONPATH=cython python3 cython/cython.py -3 --cplus minimal_bug.pyx > cython_output.log 2>&1
   
   # Check if compilation failed (could be due to unrelated breakages in Cython master)
   if [ $? -ne 0 ]; then
       # If compilation fails completely, we skip this commit
       exit 125
   fi
   
   # Count the number of definitions in the generated C++ file
   COUNT=$(grep -c "static PyObject \*__pyx_convert_vector_to_py_double(std::vector<double>  const &__pyx_v_v) {" minimal_bug.cpp)
   
   if [ "$COUNT" -gt 1 ]; then
       # Duplicate found -> Bad commit
       exit 1
   elif [ "$COUNT" -eq 1 ] || [ "$COUNT" -eq 0 ]; then
       # No duplicate -> Good commit
       exit 0
   else
       # Unexpected state -> Skip
       exit 125
   fi
   ```
   Make the script executable: `chmod +x bisect_test.sh`

2. **Initialize Git Bisect:**
   Navigate into the `cython` git submodule and start the bisection process.

   ```bash
   cd cython
   git bisect start
   ```

3. **Mark Known Good and Bad Commits:**
   Mark the current state (or `master`) as bad, and the known working release tag (`3.0.12`) as good.

   ```bash
   git bisect bad HEAD
   git bisect good 3.0.12
   ```

4. **Run the Automated Bisection:**
   Let Git automatically run through the commits using the test script.

   ```bash
   git bisect run ../bisect_test.sh
   ```

5. **Analyze the Result:**
   Git will output the first bad commit. This commit hash, along with its commit message and diff, will provide the exact context on why Cython's utility code deduplication started failing for this specific C++ vector interaction.

6. **Cleanup:**
   ```bash
   git bisect reset
   ```