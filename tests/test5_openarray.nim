import iface, unittest

{.experimental: "views".}

type
  Span[T] = object
    p: openArray[T]

  Tensor1 = ref object
    shape: array[1, int]
  Tensor2 = ref object
    shape: array[2, int]
  TensorSeq = ref object
    shape: seq[int]

iface *AnyShape:
  proc rank(): int
  proc shape(): openArray[int]

proc shape(t: Tensor1): openArray[int] =
  t.shape.toOpenArray(0, t.shape.high)

proc shape(t: Tensor2): openArray[int] =
  t.shape.toOpenArray(0, t.shape.high)

proc shape(t: TensorSeq): openArray[int] =
  t.shape.toOpenArray(0, t.shape.high)

proc rank(t: Tensor1 | Tensor2 | TensorSeq): int = 1

proc toSpan(s: openArray[int]): Span[int] = Span[int](p: s)

suite "openArray return values":

  test "direct dispatch":
    let a = Tensor1(shape: [5])
    check a.to(AnyShape).rank() == 1
    check a.to(AnyShape).shape()[0] == 5

  test "generic dispatch":
    let b = Tensor2(shape: [2, 4])
    check b.to(AnyShape).rank() == 1
    check b.to(AnyShape).shape()[0] == 2
    check b.to(AnyShape).shape()[1] == 4

  test "seq-backed dispatch":
    let c = TensorSeq(shape: @[6, 7, 8])
    check c.to(AnyShape).shape()[0] == 6
    check c.to(AnyShape).shape()[2] == 8

  test "borrowed wrapper over the erased result":
    let b = Tensor2(shape: [2, 4])
    let s = Span[int](p: b.to(AnyShape).shape())
    check s.p[0] == 2
    check s.p[1] == 4

  test "result survives in a proc":
    proc firstShape(i: AnyShape): int =
      Span[int](p: i.shape()).p[0]

    check firstShape(Tensor1(shape: [7]).to(AnyShape)) == 7
    check firstShape(Tensor2(shape: [3, 9]).to(AnyShape)) == 3
    check firstShape(TensorSeq(shape: @[1, 5]).to(AnyShape)) == 1
