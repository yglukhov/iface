import iface, unittest

type
  Dog = ref object of RootRef
    name: string

proc say(d: Dog): string = return d.name & " barks"
proc greet(d: Dog): string = return "hello from " & d.name

iface *Speaker:
  proc say(): string

iface *Greeter:
  proc say(): string
  proc greet(): string

proc makeSpeaker(d: Dog): Speaker =
  return d.to(Greeter).to(Speaker)

suite "iface to iface":
  test "runtime":
    let d = Dog(name: "rex")
    let g = d.to(Greeter)
    check g.say() == "rex barks"
    check g.greet() == "hello from rex"

  test "interface as payload":
    check makeSpeaker(Dog(name: "rex")).say() == "rex barks"
