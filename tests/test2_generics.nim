import iface, unittest

import more/animal

type
  ConcreteAnimal[T] = ref object of RootRef
    e: T

proc newAnimal[T](v: T): ConcreteAnimal[T] =
  result.new
  result.e = v

proc getElem[T](d: ConcreteAnimal[T]): T = d.e
proc foo[T](d: GenericAnimal[T]): T = d.getElem()

suite "iface and generics":
  test "runtime":
    let d = newAnimal(5)
    check foo(d.to(GenericAnimal[int])) == 5
    let s = newAnimal("hi")
    check foo(s.to(GenericAnimal[string])) == "hi"

  test "compile time":
    const s = static:
      let s = newAnimal("hi")
      foo(s.to(GenericAnimal[string]))
    check s == "hi"
