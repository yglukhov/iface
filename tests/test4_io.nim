import iface, unittest
import std/options

import more/io

type Null[T] = ref object of RootObj

proc read*[T](self: Null[T], buffer: openArray[T]): Option[int] =
  result = some(buffer.len)

proc write*[T](self: Null[T], buffer: openArray[T], num: var int) =
  num = buffer.len

proc close*[T](self: Null[T]) =
  discard

implem Null[T], Reader[T], Writer[T], Closer, WriteCloser[T]
# TODO: iface should automatically detect that implementing WriteCloser[T] means
# that it must generate a vtable for Closer and Writer[T]

suite "io":
  test "io":
    var null = new(Null[char])
    var reader = null.to(Reader[char])
    var n = reader.read(@['q'])
    check n.is_some
    check n.get == 1
    let vtables = reader.private_vTable.private_vtables(reader.private_obj)
    check vtables[0] of Reader[char].VTable
    check vtables[1] of Writer[char].VTable
    var writer = reader.to(Writer[char])
    #var writer = null.to(Writer[char])
    var num: int
    writer.write(@['q', 'w'], num)
    check num == 2
    var closer = writer.to(WriteCloser[char])
    closer.close()
