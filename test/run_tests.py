import sys
from pathlib import Path

from cocotb_tools.runner import get_runner


def test_cpu(testcase_args=None):
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "alu_pkg.sv",
        proj_path / "cpu_pkg.sv",
        proj_path / "alu.sv",
        proj_path / "control.sv",
        proj_path / "idu.sv",
        proj_path / "register_file.sv",
        proj_path / "cpu.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="cpu",
        always=True,
        waves=False,
        build_args=["-g2012", "-Wall"],
    )
    import fnmatch
    import glob
    import importlib

    test_module_files = glob.glob(str(proj_path / "test" / "test_*.py"))
    all_test_modules = [
        f.stem for f in map(Path, test_module_files) if f.stem != "test_utils"
    ]

    testcases = None
    if testcase_args:
        # Load all test modules to find all defined functions
        all_tests = []
        for mod_name in all_test_modules:
            test_module = importlib.import_module(mod_name)
            all_tests.extend(
                [name for name in dir(test_module) if name.startswith("test_")]
            )

        # Expand any wildcards
        testcases = []
        for pattern in testcase_args:
            # Handle comma-separated list in a single arg just in case
            for sub_pattern in pattern.split(","):
                matches = fnmatch.filter(all_tests, sub_pattern)
                if matches:
                    testcases.extend(matches)
                else:
                    # If no match but not a wildcard, add it anyway (might be exact)
                    testcases.append(sub_pattern)

    runner.test(hdl_toplevel="cpu", test_module=all_test_modules, testcase=testcases)


if __name__ == "__main__":
    import os

    test_cpu(sys.argv[1:])
    test_cpu(sys.argv[1:])
