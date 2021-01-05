import iface, unittest

iface DataFrame[T]:
  ## comment
  proc getElem(): T

type
  ConcreteDataFrame[T] = ref object of RootRef
    e: T

proc newDataFrame[T](v: T): ConcreteDataFrame[T] =
  result.new
  result.e = v

proc getElem[T](d: ConcreteDataFrame[T]): T = d.e
proc foo[T](d: DataFrame[T]): T = d.getElem()

suite "iface and generics":
  test "runtime":
    let d = newDataFrame(5)
    check foo(d.to(DataFrame[int])) == 5
    let s = newDataFrame("hi")
    check foo(s.to(DataFrame[string])) == "hi"

  test "compile time":
    const s = static:
      let s = newDataFrame("hi")
      foo(s.to(DataFrame[string]))
    check s == "hi"
