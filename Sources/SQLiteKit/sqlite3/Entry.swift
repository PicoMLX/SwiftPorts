import Sqlite3Command

@main
struct Entry {
    static func main() async {
        await Sqlite3.main()
    }
}
