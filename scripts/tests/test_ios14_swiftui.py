import importlib.util
import pathlib
import tempfile
import unittest


class SwiftUICompatibilityTests(unittest.TestCase):
    def test_known_iOS_14_failures_are_caught(self):
        script = pathlib.Path(__file__).resolve().parents[1] / "check_ios14_swiftui.py"
        spec = importlib.util.spec_from_file_location("swiftui_preflight", script)
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        with tempfile.TemporaryDirectory() as tmp:
            source = pathlib.Path(tmp) / "Sample.swift"
            source.write_text("""
Text("hi").bold().monospacedDigit()
Button("Restart", action: restart).fontWeight(.semibold)
""")
            issues = checker.check([source])
            self.assertEqual(len(issues), 3)
            source.write_text("""
Text("hi").font(.system(size: 20, weight: .bold, design: .monospaced))
Button(action: restart) { Text("Restart").fontWeight(.semibold) }
""")
            self.assertEqual(checker.check([source]), [])


if __name__ == "__main__":
    unittest.main()
