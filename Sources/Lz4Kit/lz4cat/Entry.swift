#if canImport(Compression) || os(Linux) || os(Windows)
import Lz4Command

@main
struct Entry {
    static func main() async {
        await Lz4cat.main()
    }
}
#else
@main struct Entry { static func main() {} }
#endif
