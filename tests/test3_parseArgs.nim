import iface, unittest, strutils

suite "parse args":
  test "1":
    privateTestParseArgs Animal:
      proc foo()

    check:
      name == "Animal"
      isPublic == false
      genericParams == ""
      parents == ""
      strip(body) == "proc foo()"

  test "2":
    privateTestParseArgs *Animal:
      proc foo()

    check:
      name == "Animal"
      isPublic == true
      genericParams == ""
      parents == ""
      strip(body) == "proc foo()"

  test "3":
    privateTestParseArgs Animal[T, V] of A[T], B[T, V]:
      proc foo()

    check:
      name == "Animal"
      isPublic == false
      strip(genericParams) == "[T; V]"
      strip(parents) == """A[T]
B[T, V]"""
      strip(body) == "proc foo()"

  test "4":
    privateTestParseArgs *Animal[T, V] of A[T], B[T, V]:
      proc foo()

    check:
      name == "Animal"
      isPublic == true
      strip(genericParams) == "[T; V]"
      strip(parents) == """A[T]
B[T, V]"""
      strip(body) == "proc foo()"
