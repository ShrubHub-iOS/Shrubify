import pathlib
import subprocess
import sys
import tempfile
import unittest


class ErrorExtractorTests(unittest.TestCase):
    def test_plain_and_color_encoded(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as folder:
            log = pathlib.Path(folder) / "test.log"
            output = pathlib.Path(folder) / "errors.txt"
            log.write_text("""Sources/Test.swift:12:3: error: missing member
SomeJob   Sources/Test.swift:13:5: ^[[1;31merror: ^[[1;39mwrong availability^[[0;0m
Sources/Test.swift:40:3: warning: other issue
make[4]: *** Error 1
""")
            subprocess.run([sys.executable, str(root / "extract_build_errors.py"), str(log), "--output", str(output)], check=True, capture_output=True)
            result = output.read_text()
            self.assertIn("missing member", result)
            self.assertIn("wrong availability", result)
            self.assertNotIn("warning:", result)


if __name__ == "__main__":
    unittest.main()
