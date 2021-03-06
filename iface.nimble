# Package

version       = "0.1.0"
author        = "Yuriy Glukhov"
description   = "Fat pointer interfaces with compile-time reflection"
license       = "MIT"

# Dependencies

requires "nim >= 1.0.4"

import oswalkdir, os

proc runTests(nimCmd = "c", nimFlags = "") =
  for f in oswalkdir.walkDir("tests"):
    let sf = f.path.splitFile()
    if sf.ext == ".nim":
      var done = false
      while not done:
        try:
          exec "nim " & nimCmd & " -r " & nimFlags & " " & f.path
          done = true
        except:
          echo "Failed to compile. Is it beacuse of https://github.com/nim-lang/Nim/issues/16613 ???"

task test, "Run tests":
  runTests("c", "--gc:orc")
  runTests("cpp", "--gc:orc")
  runTests("c")
  runTests("cpp")
  runTests("js")
