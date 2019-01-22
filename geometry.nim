import math

type Vec*[N: static[int], T] = object
    pos: array[N, T]

type
    Vec3*[T] = Vec[3, T]
    Vec3f* = Vec3[float]
    Vec4*[T] = Vec[4, T]
    Vec4f* = Vec4[float]

proc newVec*[T](x, y, z: T): Vec3[T] = Vec3[T](pos: [x, y, z])
proc newVec*[T](x, y, z, w: T): Vec4[T] = Vec4[T](pos: [x, y, z, w])

proc `[]`*[N, T](vec: Vec[N, T], i: int): T = vec.pos[i]
proc `[]=`*[N, T](vec: var Vec[N, T], i: int, val: T) = vec.pos[i] = val

proc x*[N, T](vec: Vec[N, T]): T = vec.pos[0]
proc y*[N, T](vec: Vec[N, T]): T = vec.pos[1]
proc z*[N, T](vec: Vec[N, T]): T = vec.pos[2]
proc w*[N, T](vec: Vec[N, T]): T = vec.pos[3]

proc `*`*[N, T](a: Vec[N, T], b: Vec[N, T]): T =
    for i in 0..N - 1:
        result += (a[i] * b[i])

proc `+`*[N, T](a: Vec[N, T], b: Vec[N, T]): Vec[N, T] =
    result = newVec(T(0), T(0), T(0))

    for i in 0..N - 1:
        result[i] = a[i] + b[i]

proc `-`*[N, T](a: Vec[N, T], b: Vec[N, T]): Vec[N, T] =
    result = newVec(T(0), T(0), T(0))

    for i in 0..N - 1:
        result[i] = a[i] - b[i]

proc `*`*[N, T, U](a: Vec[N, T], b: U): Vec[N, T] =
    result = newVec(T(0), T(0), T(0))

    for i in 0..N - 1:
        result[i] = a[i] * b

proc `-`*[N, T](a: Vec[N, T]): Vec[N, T] = a * T(-1)

proc norm*(vec: Vec3f): float =
    let (x, y, z) = (vec.x, vec.y, vec.z)
    (x*x + y*y + z*z).sqrt()

proc normalize*[T](vec: Vec3[T], l = T(1)): Vec3[T] =
    vec * (l / vec.norm())

proc cross*[T](a: Vec3[T], b: Vec3[T]): Vec3[T] =
    newVec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)

proc `$`*[N, T](vec: Vec[N, T]): string =
    for i in 0..N - 1:
        result &= $vec[i] & " "
