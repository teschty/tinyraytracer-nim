import geometry
import math
import strformat

type Light = ref object
    pos: Vec3f
    intensity: float

proc newLight(p: Vec3f, i: float): Light =
    Light(pos: p, intensity: i)

type Material = ref object
    refractiveIndex: float
    albedo: Vec4f
    diffuseColor: Vec3f
    specularExponent: float

proc newMaterial(r: float, a: Vec4f, color: Vec3f, spec: float): Material =
    Material(refractiveIndex: r, albedo: a, diffuseColor: color, specularExponent: spec)

proc newMaterial(): Material =
    Material(refractiveIndex: 1, albedo: newVec(0.9, 0.0, 0.0, 0.0), diffuseColor: newVec(0.0, 0.0, 0.0), specularExponent: 0.0)

type Sphere = ref object
    center: Vec3f
    radius: float
    material: Material

proc newSphere(c: Vec3f, r: float, m: Material): Sphere =
    Sphere(center: c, radius: r, material: m)

proc rayIntersect(sphere: Sphere, orig: Vec3f, dir: Vec3f, t0: var float): bool =
    let (center, radius) = (sphere.center, sphere.radius)

    let L = center - orig
    let tca = L * dir
    let d2 = L * L - tca * tca

    if d2 > radius * radius: return false

    let thc = (radius * radius - d2).sqrt()
    t0 = tca - thc
    let t1 = tca + thc

    if t0 < 0: t0 = t1

    return not (t0 < 0)

proc reflect(i: Vec3f, n: Vec3f): Vec3f =
    i - n * 2.0 * (i * n)

proc refract(I: Vec3f, N: Vec3f, refractiveIndex: float): Vec3f =
    var cosi = -max(-1.0, min(1.0, I * N))
    var etai = 1.0
    var etat = refractiveIndex

    var n = N

    if cosi < 0:
        cosi = -cosi
        (etai, etat) = (etat, etai)
        n = -N

    let eta = etai / etat
    let k = 1 - eta * eta * (1 - cosi * cosi)
    
    if k < 0:
        return newVec(0.0, 0.0, 0.0) 
    else:
        return I * eta + n * (eta * cosi - k.sqrt())

proc sceneIntersect(orig: Vec3f, dir: Vec3f, spheres: seq[Sphere], hit: var Vec3f, N: var Vec3f, material: var Material): bool =
    var spheresDist = high(float)

    for sphere in spheres:
        var distI: float

        if sphere.rayIntersect(orig, dir, distI) and distI < spheresDist:
            spheresDist = distI
            hit = orig + dir * distI
            N = (hit - sphere.center).normalize()
            material = sphere.material

    var checkerboardDist = high(float)
    if dir.y.abs() > 1e-3:
        let d = -(orig.y + 4) / dir.y
        let pt = orig + dir * d

        if d > 0 and pt.x.abs() < 10 and pt.z < -10 and pt.z > -30 and d < spheresDist:
            checkerboardDist = d
            hit = pt
            N = newVec(0.0, 1.0, 0.0)

            if ((int(0.5 * hit.x + 1000) + int(0.5 * hit.z)) and 1) != 0:
                material.diffuseColor = newVec(1.0, 1.0, 1.0) * 0.3
            else:
                material.diffuseColor = newVec(1.0, 0.7, 0.3) * 0.3

    return min(spheresDist, checkerboardDist) < 1000

proc castRay(orig: Vec3f, dir: Vec3f, spheres: seq[Sphere], lights: seq[Light], depth: int = 0): Vec3f = 
    var 
        point = newVec(0.0, 0.0, 0.0)
        N = newVec(0.0, 0.0, 0.0)
        material = newMaterial()

    if depth > 4 or not sceneIntersect(orig, dir, spheres, point, N, material):
        return newVec(0.2, 0.7, 0.8)
    
    let reflectDir = reflect(dir, N).normalize()
    let refractDir = refract(dir, N, material.refractiveIndex).normalize()
    let reflectOrig = if reflectDir * N < 0: point - N * 1e-3 else: point + N * 1e-3 
    let refractOrig = if refractDir * N < 0: point - N * 1e-3 else: point + N * 1e-3
    let reflectColor = castRay(reflectOrig, reflectDir, spheres, lights, depth + 1)
    let refractColor = castRay(refractOrig, refractDir, spheres, lights, depth + 1) 

    var diffuseLightIntensity = 0.0
    var specularLightIntensity = 0.0

    for light in lights:
        let lightDir = (light.pos - point).normalize()
        let lightDistance = (light.pos - point).norm()

        let shadowOrig = if lightDir * N < 0: point - N * 1e-3 else: point + N * 1e-3
        var shadowPt = newVec(0.0, 0.0, 0.0)
        var shadowN = newVec(0.0, 0.0, 0.0)
        var tmpMaterial = newMaterial()

        if sceneIntersect(shadowOrig, lightDir, spheres, shadowPt, shadowN, tmpMaterial) and (shadowPt - shadowOrig).norm() < lightDistance:
            continue

        diffuseLightIntensity += light.intensity * max(0.0, lightDir * N)
        specularLightIntensity += pow(max(0.0, -reflect(-lightDir, N) * dir), material.specularExponent) * light.intensity

    return material.diffuseColor * diffuseLightIntensity * material.albedo[0] + newVec(1.0, 1.0, 1.0) * specularLightIntensity * material.albedo[1] + reflectColor * material.albedo[2] + refractColor * material.albedo[3]
    
proc render(spheres: seq[Sphere], lights: seq[Light]) =
    let (width, height, fov) = (1024, 768, int(PI / 2.0))
    var framebuffer = newSeq[Vec3f](width * height)

    for j in 0..height - 1:
        for i in 0..width - 1:
            let x = (2 * (float(i) + 0.5) / float(width) - 1.0) * (float(fov) / 2.0).tan() * float(width) / float(height)
            let y = -(2 * (float(j) + 0.5) / float(height) - 1.0) * (float(fov) / 2.0).tan()

            let dir = newVec(x, y, -1.0).normalize()
            framebuffer[i + j * width] = castRay(newVec(0.0, 0.0, 0.0), dir, spheres, lights)

    let output = open("out.ppm", fmWrite)
    output.write fmt("P6\n{width} {height}\n255\n")

    var i = 0
    for c in framebuffer:
        let m = max(c[0], max(c[1], c[2]))

        var c = c
        if m > 1: 
            c = c * (1.0 / m)

        for j in 0..2:
            let clamped = max(0.0, c[j])
            output.write char(255 * clamped)

        i += 1

    output.close()

let ivory =     newMaterial(1.0, newVec(0.6,  0.3, 0.1, 0.0), newVec(0.4, 0.4, 0.3), 50.0)
let glass =     newMaterial(1.5, newVec(0.0,  0.5, 0.1, 0.8), newVec(0.6, 0.7, 0.8), 125.0)
let redRubber = newMaterial(1.0, newVec(0.9,  0.1, 0.0, 0.0), newVec(0.3, 0.1, 0.1), 10.0)
let mirror =    newMaterial(1.0, newVec(0.0, 10.0, 0.8, 0.0), newVec(1.0, 1.0, 1.0), 1425.0)

let spheres = @[
    newSphere(newVec(-3.0,  0.0, -16.0), 2, ivory),
    newSphere(newVec(-1.0, -1.5, -12.0), 2, glass),
    newSphere(newVec( 1.5, -0.5, -18.0), 3, redRubber),
    newSphere(newVec( 7.0,  5.0, -18.0), 4, mirror)
]

let lights = @[
    newLight(newVec(-20.0, 20.0,  20.0), 1.5),
    newLight(newVec( 30.0, 50.0, -25.0), 1.8),
    newLight(newVec( 30.0, 20.0,  30.0), 1.7)
]

render(spheres, lights)
