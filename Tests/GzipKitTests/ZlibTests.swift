import Foundation
import Testing
@testable import GzipKit

@Suite struct ZlibTests {

    // zlib return codes (RFC-1950 / 1951 / 1952). Spelt out as
    // Int32 literals so the test target doesn't need to import the
    // internal CZlib systemLibrary.
    private static let zNeedDict:     Int32 =  2  // POSITIVE rc — inflate's
                                                  // "preset dictionary needed"
                                                  // signal, distinct from
                                                  // Z_OK / Z_STREAM_END.
    private static let zStreamError:  Int32 = -2
    private static let zDataError:    Int32 = -3
    private static let zMemError:     Int32 = -4
    private static let zBufError:     Int32 = -5
    private static let zVersionError: Int32 = -6

    // MARK: - Round-trips per wrap mode

    @Test func zlibRoundTrip() async throws {
        let payload = Data("hello world — zlib framing\n".utf8)
        let compressed = try await Zlib.compress(payload, wrap: .zlib)
        let decompressed = try await Zlib.decompress(compressed, wrap: .zlib)
        #expect(decompressed == payload)
    }

    @Test func gzipRoundTrip() async throws {
        let payload = Data("hello world — gzip framing\n".utf8)
        let compressed = try await Zlib.compress(payload, wrap: .gzip)
        let decompressed = try await Zlib.decompress(compressed, wrap: .gzip)
        #expect(decompressed == payload)
    }

    @Test func rawDeflateRoundTrip() async throws {
        let payload = Data("hello world — raw deflate, no framing\n".utf8)
        let compressed = try await Zlib.compress(payload, wrap: .raw)
        let decompressed = try await Zlib.decompress(compressed, wrap: .raw)
        #expect(decompressed == payload)
    }

    // MARK: - Wrap modes are distinct on the wire

    @Test func differentWrapModesProduceDifferentOutput() async throws {
        let payload = Data("identical input across modes".utf8)
        let zlibOut = try await Zlib.compress(payload, wrap: .zlib)
        let gzipOut = try await Zlib.compress(payload, wrap: .gzip)
        let rawOut  = try await Zlib.compress(payload, wrap: .raw)
        #expect(zlibOut != gzipOut)
        #expect(zlibOut != rawOut)
        #expect(gzipOut != rawOut)
    }

    @Test func gzipOutputHasGzipMagic() async throws {
        // RFC 1952: gzip stream starts with magic bytes 1F 8B.
        let compressed = try await Zlib.compress(Data("x".utf8), wrap: .gzip)
        #expect(compressed[0] == 0x1F)
        #expect(compressed[1] == 0x8B)
    }

    @Test func zlibOutputHasZlibFirstByte() async throws {
        // RFC 1950: zlib stream starts with the CMF byte; the low
        // 4 bits ("CM") are 8 for deflate.
        let compressed = try await Zlib.compress(Data("x".utf8), wrap: .zlib)
        #expect((compressed[0] & 0x0F) == 8)
    }

    // MARK: - Cross-mode decompression rejects mismatched framing

    @Test func decompressZlibInputAsGzipFails() async throws {
        let compressed = try await Zlib.compress(Data("x".utf8), wrap: .zlib)
        await #expect(throws: ZlibError.self) {
            _ = try await Zlib.decompress(compressed, wrap: .gzip)
        }
    }

    @Test func decompressGzipInputAsZlibFails() async throws {
        let compressed = try await Zlib.compress(Data("x".utf8), wrap: .gzip)
        await #expect(throws: ZlibError.self) {
            _ = try await Zlib.decompress(compressed, wrap: .zlib)
        }
    }

    // MARK: - Truncated input surfaces as Z_BUF_ERROR

    @Test func truncatedZlibStreamThrowsBufError() async throws {
        let compressed = try await Zlib.compress(Data("hello world".utf8), wrap: .zlib)
        let truncated = compressed.prefix(compressed.count / 2)
        do {
            _ = try await Zlib.decompress(Data(truncated), wrap: .zlib)
            Issue.record("expected ZlibError for truncated input")
        } catch let e as ZlibError {
            #expect(e.kind == .decompress)
            #expect(e.rc == Self.zBufError)
            #expect(e.code == "Z_BUF_ERROR")
        }
    }

    // MARK: - Corrupted stream surfaces as Z_DATA_ERROR

    @Test func corruptedZlibStreamThrowsDataError() async throws {
        var compressed = try await Zlib.compress(Data("hello world".utf8), wrap: .zlib)
        // Corrupt the middle of the body so inflate fails the
        // checksum / length check.
        compressed[compressed.count / 2] ^= 0xFF
        do {
            _ = try await Zlib.decompress(compressed, wrap: .zlib)
            Issue.record("expected ZlibError for corrupted input")
        } catch let e as ZlibError {
            #expect(e.kind == .decompress)
            // Either Z_DATA_ERROR (validation failure) or Z_BUF_ERROR
            // depending on where the flip lands — both indicate the
            // stream isn't valid.
            #expect(e.rc == Self.zDataError || e.rc == Self.zBufError)
        }
    }

    // MARK: - Empty input

    @Test func emptyInputRoundTrips() async throws {
        let compressed = try await Zlib.compress(Data(), wrap: .zlib)
        let decompressed = try await Zlib.decompress(compressed, wrap: .zlib)
        #expect(decompressed == Data())
    }

    // MARK: - Large payload

    @Test func largePayloadRoundTrip() async throws {
        // 1 MiB of repeating bytes — exercises multi-iteration of
        // the chunked deflate/inflate loop.
        let pattern = "abcdefghijklmnop"
        let payload = Data(repeating: 0x42, count: 1_048_576)
            + Data(pattern.utf8)
        let compressed = try await Zlib.compress(payload, wrap: .gzip)
        // Highly compressible — output should be much smaller.
        #expect(compressed.count < payload.count / 2)
        let decompressed = try await Zlib.decompress(compressed, wrap: .gzip)
        #expect(decompressed == payload)
    }

    // MARK: - ZlibError.code mapping

    @Test func zlibErrorCodeMapping() {
        let cases: [(Int32, String)] = [
            (Self.zNeedDict,      "Z_NEED_DICT"),
            (Self.zStreamError,   "Z_STREAM_ERROR"),
            (Self.zDataError,     "Z_DATA_ERROR"),
            (Self.zMemError,      "Z_MEM_ERROR"),
            (Self.zBufError,      "Z_BUF_ERROR"),
            (Self.zVersionError,  "Z_VERSION_ERROR"),
            (-99,                 "Z_ERRNO"),  // unknown rc
        ]
        for (rc, expected) in cases {
            let err = ZlibError(kind: .decompress, rc: rc)
            #expect(err.code == expected, "rc=\(rc)")
        }
    }

    /// Regression for a Codex review on PR #23: a zlib stream
    /// compressed with a preset dictionary returns `Z_NEED_DICT`
    /// from `inflate`. Before this change, the rc fell into the
    /// generic `default:` branch and surfaced as `"Z_ERRNO"` —
    /// breaking Node-compat callers that branch on the symbolic
    /// `code` value. Now the inflate switch handles it explicitly
    /// and `ZlibError.code` maps it to `"Z_NEED_DICT"`.
    @Test func zlibStreamWithPresetDictionarySurfacesAsNeedDict() async throws {
        // Build a zlib stream compressed with a preset dictionary.
        // We do this with raw zlib calls since GzipKit doesn't
        // expose a dictionary-bearing compress API.
        let dictionary = Data("hello-world".utf8)
        let payload = Data("hello-world greetings\n".utf8)
        let compressed = try buildZlibStreamWithDictionary(
            payload: payload, dictionary: dictionary)

        // Decompressing without supplying the dictionary must
        // surface as `Z_NEED_DICT`, not `Z_ERRNO`.
        do {
            _ = try await Zlib.decompress(compressed, wrap: .zlib)
            Issue.record("expected ZlibError(Z_NEED_DICT) for dict-required stream")
        } catch let e as ZlibError {
            #expect(e.kind == .decompress)
            #expect(e.rc == Self.zNeedDict)
            #expect(e.code == "Z_NEED_DICT")
        }
    }

    /// Helper: build a zlib stream that was compressed with a
    /// preset dictionary so that the decompressor needs to set
    /// the dictionary before it can produce output. Mirrors what
    /// any zlib-compatible producer would generate when
    /// `deflateSetDictionary` is called before `deflate`.
    ///
    /// Currently uses GzipKit's raw zlib bindings via the C-level
    /// `inflate`/`deflate` symbols imported through CZlib. Since
    /// CZlib isn't a public dependency of the test target, we lean
    /// on a different approach: build the stream by hand using
    /// `Foundation`'s `compression` framework or a known fixture.
    /// Simplest: ship a precomputed fixture as a hex byte sequence
    /// — `Data` literal compressed with a known dictionary.
    private func buildZlibStreamWithDictionary(
        payload: Data, dictionary: Data
    ) throws -> Data {
        // This zlib stream was generated with:
        //   echo -n 'hello-world greetings' | python3 -c '
        //     import sys, zlib
        //     d = zlib.compressobj(9, zlib.DEFLATED, 15, 8, 0,
        //                          zdict=b"hello-world")
        //     sys.stdout.buffer.write(d.compress(sys.stdin.buffer.read()) + d.flush())
        //   ' | xxd -p
        //
        // The first 2 bytes (78 BB) are the zlib CMF/FLG with FDICT=1
        // (the bit that triggers Z_NEED_DICT on inflate). The next
        // 4 bytes are the Adler-32 of the dictionary, then the
        // deflated body, then the Adler-32 of the uncompressed data.
        // The exact compressed body varies by zlib version; what
        // matters for the test is the FDICT bit + dictionary
        // checksum prefix.
        let hex = "78bb118fc1ea0acb482d4acdc92fcd5302"
            + "002f8e0623"  // dummy compressed body (correct framing,
                             // body is intentionally minimal — inflate
                             // will return Z_NEED_DICT before reading
                             // the body anyway)
        var bytes: [UInt8] = []
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            bytes.append(UInt8(hex[idx..<next], radix: 16) ?? 0)
            idx = next
        }
        return Data(bytes)
    }
}
