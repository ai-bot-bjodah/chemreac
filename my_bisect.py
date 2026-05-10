import subprocess
import re

with open("test_chemreac6.pyx", "r") as f:
    content = f.read()

def test_file(text):
    with open("mwe_candidate.pyx", "w") as f:
        f.write(text)
    res = subprocess.run("PYTHONPATH=cython python3 cython/cython.py -3 --cplus -I chemreac/include -I external/anyode/cython_def mwe_candidate.pyx", shell=True, capture_output=True)
    if res.returncode != 0:
        return "COMPILE_ERROR\n" + res.stderr.decode()
    with open("mwe_candidate.cpp", "r") as f:
        cpp = f.read()
    return cpp.count("static PyObject *__pyx_convert_vector_to_py_double(std::vector<double>  const &__pyx_v_v) {") > 1

print("Original:", test_file(content))

# Let's drop properties one by one
props = re.findall(r'(    property [a-zA-Z_0-9]+:(?:(?!\n    (?:property|def|#)).)*)', content, flags=re.DOTALL)
print("Found", len(props), "properties")

for i in range(len(props)):
    test_content = content.replace(props[i], "")
    res = test_file(test_content)
    if res == False: # if dropping this property fixed the duplication!
        print(f"Removing property {i} FIXED the duplication!")
        print("Property was:")
        print(props[i])
