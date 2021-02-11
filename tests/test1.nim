import iface, unittest

import more/animal

type
  Dog = ref object of RootRef
    testCalled: bool

proc say(d: Dog): string = "bark"
proc test2(d: Dog) =
  d.testCalled = true

proc getFriend(d: Dog): Animal =
  d.testCalled = true
  return toAnimal(Dog())

proc doSmth(a: Animal): string =
  a.test2()
  a.say()

proc createVoldemortObject(): Animal =
  type
    Hidden = ref object of RootRef
  proc say(h: Hidden): string = "hsss"
  proc test2(h: Hidden) = discard
  proc getFriend(h: Hidden): Animal = discard
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

  test "extract concrete type":
    type Shark = ref object of RootObj
    var i: Animal = Dog()
    check i.to(Dog) != nil
    check i.to(Shark) == nil
    when not defined(js):
      # Currently nim emits wrong JS code for this
      check i.to(ref int) == nil

  test "extract concrete type compile time":
    type Shark = ref object of RootRef
    const ok = static:
      var i: Animal = Dog()
      i.to(Dog) != nil and i.to(Shark) == nil and i.to(ref int) == nil
    check ok
