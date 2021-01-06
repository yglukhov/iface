import iface, unittest

iface Animal:
  proc say(): string
  proc test2()

type
  Dog = ref object of RootRef
    testCalled: bool

proc say(d: Dog): string = "bark"
proc test2(d: Dog) =
  d.testCalled = true

proc doSmth(a: Animal): string =
  a.test2()
  a.say()

proc createVoldemortObject(): Animal =
  type
    Hidden = ref object of RootRef
  proc say(h: Hidden): string = "hsss"
  proc test2(h: Hidden) = discard
  localIfaceConvert(Animal, Hidden())

suite "iface":
  test "runtime":
    let d = Dog.new()
    check doSmth(d) == "bark"
    check d.testCalled

  test "compile time":
    const s = static:
      let d = Dog.new()
      let res = doSmth(d)
      doAssert(d.testCalled)
      res
    check s == "bark"

  test "implement interface in proc (voldemort)":
    check doSmth(createVoldemortObject()) == "hsss"

  test "implement interface in proc (voldemort) compile time":
    const d = doSmth(createVoldemortObject())
    check d == "hsss"
