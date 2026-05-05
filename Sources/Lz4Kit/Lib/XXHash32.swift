// XXH32 (Yann Collet) — 32-bit non-cryptographic hash. Required by
// the .lz4 v1.6.x frame format header checksum (HC byte = bits 8-15
// of xxh32(FLG||BD||extras)).
//
// Public-domain reference implementation, ~50 lines. Used internally
// by `Lz4Frame` only — not part of Lz4Kit's public API.

internal enum XXHash32 {
    static let prime1: UInt32 = 0x9E3779B1
    static let prime2: UInt32 = 0x85EBCA77
    static let prime3: UInt32 = 0xC2B2AE3D
    static let prime4: UInt32 = 0x27D4EB2F
    static let prime5: UInt32 = 0x165667B1

    @inline(__always)
    private static func rotl(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x << n) | (x >> (32 - n))
    }

    @inline(__always)
    private static func round(_ acc: UInt32, _ input: UInt32) -> UInt32 {
        rotl(acc &+ input &* prime2, 13) &* prime1
    }

    @inline(__always)
    private static func read32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i])
            | (UInt32(b[i + 1]) << 8)
            | (UInt32(b[i + 2]) << 16)
            | (UInt32(b[i + 3]) << 24)
    }

    static func hash(_ bytes: [UInt8], seed: UInt32 = 0) -> UInt32 {
        let length = bytes.count
        var i = 0
        var h32: UInt32

        if length >= 16 {
            var v1 = seed &+ prime1 &+ prime2
            var v2 = seed &+ prime2
            var v3 = seed
            var v4 = seed &- prime1
            while i + 16 <= length {
                v1 = round(v1, read32(bytes, i)); i += 4
                v2 = round(v2, read32(bytes, i)); i += 4
                v3 = round(v3, read32(bytes, i)); i += 4
                v4 = round(v4, read32(bytes, i)); i += 4
            }
            h32 = rotl(v1, 1) &+ rotl(v2, 7) &+ rotl(v3, 12) &+ rotl(v4, 18)
        } else {
            h32 = seed &+ prime5
        }
        h32 = h32 &+ UInt32(length)

        while i + 4 <= length {
            h32 = h32 &+ read32(bytes, i) &* prime3
            h32 = rotl(h32, 17) &* prime4
            i += 4
        }
        while i < length {
            h32 = h32 &+ UInt32(bytes[i]) &* prime5
            h32 = rotl(h32, 11) &* prime1
            i += 1
        }
        h32 ^= h32 >> 15
        h32 = h32 &* prime2
        h32 ^= h32 >> 13
        h32 = h32 &* prime3
        h32 ^= h32 >> 16
        return h32
    }
}
