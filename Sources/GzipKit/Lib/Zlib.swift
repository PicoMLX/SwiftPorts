import Foundation
import CZlib

/// Lower-level zlib API — raw deflate/inflate plus zlib-wrapped
/// (RFC 1950) and gzip-wrapped (RFC 1952) framing. Sibling to
/// ``Gzip`` (which is the file/stream-oriented gzip CLI engine);
/// ``Zlib`` is the in-memory `Data` ↔ `Data` engine the JS-runtime
/// `node:zlib` module backing needs.
///
/// The wrap mode is a single parameter — same windowBits convention
/// zlib itself uses for `deflateInit2`:
///
/// - ``Wrap/raw`` — windowBits `-15`, no header / trailer (RFC 1951).
/// - ``Wrap/zlib`` — windowBits `15`, zlib framing + Adler-32 trailer
///   (RFC 1950). The default; matches Node's `deflateSync`.
/// - ``Wrap/gzip`` — windowBits `31` (`15 + 16`), gzip framing +
///   CRC-32 trailer (RFC 1952). Matches Node's `gzipSync`.
///
/// Errors carry the underlying zlib return code so callers can map
/// to platform-specific error names (Node-style `Z_DATA_ERROR` /
/// `Z_BUF_ERROR` / etc.).
public enum Zlib {

    private static let chunkSize = 64 * 1024

    /// Stream wrapping mode for `compress` / `decompress`.
    public enum Wrap: Sendable, Equatable {
        /// Raw deflate (RFC 1951) — no header, no trailer.
        /// `windowBits = -15`. Matches Node's `deflateRawSync` /
        /// `inflateRawSync`.
        case raw
        /// zlib framing (RFC 1950) — 2-byte header, Adler-32
        /// trailer. `windowBits = 15`. Matches Node's
        /// `deflateSync` / `inflateSync`.
        case zlib
        /// gzip framing (RFC 1952) — gzip header, CRC-32 trailer.
        /// `windowBits = 15 + 16 = 31`. Matches Node's `gzipSync`
        /// / `gunzipSync`. Same wire format `Gzip.compress` /
        /// `Gzip.decompress` produce, but here you get the raw
        /// `Data` API rather than file-oriented helpers.
        case gzip

        var deflateWindowBits: Int32 {
            switch self {
            case .raw:  return -15
            case .zlib: return 15
            case .gzip: return 15 + 16
            }
        }

        var inflateWindowBits: Int32 {
            // For decompression, gzip and zlib wrappers can be
            // auto-detected via `+ 32`. We keep wrap-specific
            // values here so a caller asking for `.zlib` rejects a
            // gzip stream (and vice versa) — same strictness as the
            // matching JS APIs.
            switch self {
            case .raw:  return -15
            case .zlib: return 15
            case .gzip: return 15 + 16
            }
        }
    }

    // MARK: Compress

    /// Compress arbitrary bytes. The output is wrapped per ``Wrap``.
    ///
    /// - Parameters:
    ///   - data: Input bytes.
    ///   - wrap: Output framing. Defaults to ``Wrap/zlib``.
    ///   - level: zlib compression level (`Z_DEFAULT_COMPRESSION`,
    ///     `Z_NO_COMPRESSION` … `Z_BEST_COMPRESSION`). Defaults to
    ///     `Z_DEFAULT_COMPRESSION` (`-1`).
    /// - Returns: Compressed bytes.
    /// - Throws: ``ZlibError`` on any zlib failure; carries the
    ///   underlying rc + `stream.msg`.
    public static func compress(
        _ data: Data,
        wrap: Wrap = .zlib,
        level: Int32 = Z_DEFAULT_COMPRESSION
    ) async throws -> Data {
        var stream = z_stream()
        let initRC = deflateInit2_(
            &stream,
            level,
            Z_DEFLATED,
            wrap.deflateWindowBits,
            8,                    // memLevel — zlib's standard default
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size))
        guard initRC == Z_OK else {
            throw ZlibError(kind: .compress, rc: initRC,
                            message: streamMessage(&stream))
        }
        defer { deflateEnd(&stream) }

        var output = Data()
        var inputBytes = [UInt8](data)
        let inputCount = inputBytes.count
        var outputBuffer = [UInt8](repeating: 0, count: chunkSize)

        try inputBytes.withUnsafeMutableBufferPointer { inPtr in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inputCount)

            var done = false
            while !done {
                try Task.checkCancellation()
                try outputBuffer.withUnsafeMutableBufferPointer { outPtr in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    let r = deflate(&stream, Z_FINISH)
                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        output.append(outPtr.baseAddress!, count: written)
                    }
                    switch r {
                    case Z_STREAM_END: done = true
                    case Z_OK, Z_BUF_ERROR: break
                    default:
                        throw ZlibError(
                            kind: .compress, rc: r,
                            message: streamMessage(&stream))
                    }
                }
            }
        }
        return output
    }

    // MARK: Decompress

    /// Decompress arbitrary bytes, expecting the framing specified
    /// by `wrap`.
    ///
    /// - Parameters:
    ///   - data: Input bytes (raw / zlib / gzip per `wrap`).
    ///   - wrap: Expected framing. Defaults to ``Wrap/zlib``.
    /// - Returns: Decompressed bytes.
    /// - Throws: ``ZlibError`` on any zlib failure; carries the rc
    ///   + `stream.msg`. Truncated streams surface as `Z_BUF_ERROR`
    ///   ("incomplete stream"); corrupted as `Z_DATA_ERROR`.
    public static func decompress(
        _ data: Data,
        wrap: Wrap = .zlib
    ) async throws -> Data {
        var stream = z_stream()
        let initRC = inflateInit2_(
            &stream,
            wrap.inflateWindowBits,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size))
        guard initRC == Z_OK else {
            throw ZlibError(kind: .decompress, rc: initRC,
                            message: streamMessage(&stream))
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        var inputBytes = [UInt8](data)
        let inputCount = inputBytes.count
        var outputBuffer = [UInt8](repeating: 0, count: chunkSize)

        try inputBytes.withUnsafeMutableBufferPointer { inPtr in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inputCount)

            var done = false
            while !done {
                try Task.checkCancellation()
                try outputBuffer.withUnsafeMutableBufferPointer { outPtr in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    let r = inflate(&stream, Z_NO_FLUSH)
                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        output.append(outPtr.baseAddress!, count: written)
                    }
                    switch r {
                    case Z_STREAM_END:
                        done = true
                    case Z_OK:
                        break
                    case Z_BUF_ERROR:
                        // We hand inflate the entire input upfront
                        // with a 64 KiB output window each iteration,
                        // so the only realistic cause of Z_BUF_ERROR
                        // is starved input — a truncated stream.
                        throw ZlibError(
                            kind: .decompress, rc: Z_BUF_ERROR,
                            message: "incomplete stream (truncated input)")
                    case Z_NEED_DICT:
                        // The input is a zlib stream that was
                        // compressed with a preset dictionary; the
                        // matching dictionary must be supplied via
                        // `inflateSetDictionary` before decompression
                        // can proceed. We don't expose a dictionary
                        // parameter, so this is an error path here —
                        // surface it with the matching Node-style code.
                        throw ZlibError(
                            kind: .decompress, rc: Z_NEED_DICT,
                            message: "preset dictionary required " +
                                     "but not supplied")
                    default:
                        throw ZlibError(
                            kind: .decompress, rc: r,
                            message: streamMessage(&stream))
                    }
                }
            }
        }
        return output
    }

    // MARK: Synchronous variants
    //
    // Mirrors of `compress`/`decompress` without the `async` and
    // without `Task.checkCancellation()` calls. Purpose-built for
    // hosts that have to expose blocking compress/decompress —
    // e.g. JavaScriptCore-backed JS runtimes implementing the
    // Node `zlib.gzipSync` / `inflateSync` family, where the JS
    // contract is "block the interpreter until done". Bodies are
    // identical otherwise.

    /// Synchronous counterpart of ``compress(_:wrap:level:)``. Same
    /// semantics, no cancellation. Use when the caller is on a
    /// thread that can't `await` (typically a JS-runtime sync hook).
    public static func compressSync(
        _ data: Data,
        wrap: Wrap = .zlib,
        level: Int32 = Z_DEFAULT_COMPRESSION
    ) throws -> Data {
        var stream = z_stream()
        let initRC = deflateInit2_(
            &stream,
            level,
            Z_DEFLATED,
            wrap.deflateWindowBits,
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size))
        guard initRC == Z_OK else {
            throw ZlibError(kind: .compress, rc: initRC,
                            message: streamMessage(&stream))
        }
        defer { deflateEnd(&stream) }

        var output = Data()
        var inputBytes = [UInt8](data)
        let inputCount = inputBytes.count
        var outputBuffer = [UInt8](repeating: 0, count: chunkSize)

        try inputBytes.withUnsafeMutableBufferPointer { inPtr in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inputCount)

            var done = false
            while !done {
                try outputBuffer.withUnsafeMutableBufferPointer { outPtr in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    let r = deflate(&stream, Z_FINISH)
                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        output.append(outPtr.baseAddress!, count: written)
                    }
                    switch r {
                    case Z_STREAM_END: done = true
                    case Z_OK, Z_BUF_ERROR: break
                    default:
                        throw ZlibError(
                            kind: .compress, rc: r,
                            message: streamMessage(&stream))
                    }
                }
            }
        }
        return output
    }

    /// Synchronous counterpart of ``decompress(_:wrap:)``. Same
    /// semantics, no cancellation. Use from sync-only hosts.
    public static func decompressSync(
        _ data: Data,
        wrap: Wrap = .zlib
    ) throws -> Data {
        var stream = z_stream()
        let initRC = inflateInit2_(
            &stream,
            wrap.inflateWindowBits,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size))
        guard initRC == Z_OK else {
            throw ZlibError(kind: .decompress, rc: initRC,
                            message: streamMessage(&stream))
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        var inputBytes = [UInt8](data)
        let inputCount = inputBytes.count
        var outputBuffer = [UInt8](repeating: 0, count: chunkSize)

        try inputBytes.withUnsafeMutableBufferPointer { inPtr in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inputCount)

            var done = false
            while !done {
                try outputBuffer.withUnsafeMutableBufferPointer { outPtr in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    let r = inflate(&stream, Z_NO_FLUSH)
                    let written = chunkSize - Int(stream.avail_out)
                    if written > 0 {
                        output.append(outPtr.baseAddress!, count: written)
                    }
                    switch r {
                    case Z_STREAM_END:
                        done = true
                    case Z_OK:
                        break
                    case Z_BUF_ERROR:
                        throw ZlibError(
                            kind: .decompress, rc: Z_BUF_ERROR,
                            message: "incomplete stream (truncated input)")
                    default:
                        throw ZlibError(
                            kind: .decompress, rc: r,
                            message: streamMessage(&stream))
                    }
                }
            }
        }
        return output
    }

    // MARK: Helpers

    /// Read the optional `stream.msg` C string, if zlib populated one.
    private static func streamMessage(_ stream: UnsafeMutablePointer<z_stream>) -> String? {
        guard let cstr = stream.pointee.msg else { return nil }
        let s = String(cString: cstr)
        return s.isEmpty ? nil : s
    }
}

/// Error thrown by ``Zlib/compress(_:wrap:level:)`` /
/// ``Zlib/decompress(_:wrap:)``. Carries the zlib return code +
/// optional message so callers can render Node-style
/// `Z_DATA_ERROR` / `Z_BUF_ERROR` / `Z_MEM_ERROR` etc. names from
/// the rc.
public struct ZlibError: Error, CustomStringConvertible, Sendable {
    public enum Operation: Sendable, Equatable {
        case compress, decompress
    }

    /// Which side of the stream raised this.
    public let kind: Operation

    /// The raw zlib return code. Maps to symbolic names like
    /// `Z_DATA_ERROR` (`-3`), `Z_BUF_ERROR` (`-5`), `Z_MEM_ERROR`
    /// (`-4`), `Z_VERSION_ERROR` (`-6`), `Z_STREAM_ERROR` (`-2`).
    public let rc: Int32

    /// `stream.msg` if zlib populated it, else `nil`. Tends to be
    /// nil for trivial errors (truncation) and populated for
    /// validation failures (bad header / checksum).
    public let message: String?

    public init(kind: Operation, rc: Int32, message: String? = nil) {
        self.kind = kind
        self.rc = rc
        self.message = message
    }

    public var description: String {
        let opLabel = kind == .compress ? "compress" : "decompress"
        if let message {
            return "zlib \(opLabel) failed: \(message) (rc=\(rc))"
        }
        return "zlib \(opLabel) failed: rc=\(rc)"
    }

    /// Node-style symbolic name for this error's `rc`. Useful when
    /// surfacing the error to JS callers expecting `Z_DATA_ERROR`
    /// etc. on the JS Error's `code` field.
    public var code: String {
        switch rc {
        case Z_NEED_DICT:      return "Z_NEED_DICT"
        case Z_STREAM_ERROR:   return "Z_STREAM_ERROR"
        case Z_DATA_ERROR:     return "Z_DATA_ERROR"
        case Z_MEM_ERROR:      return "Z_MEM_ERROR"
        case Z_BUF_ERROR:      return "Z_BUF_ERROR"
        case Z_VERSION_ERROR:  return "Z_VERSION_ERROR"
        default:               return "Z_ERRNO"
        }
    }
}
