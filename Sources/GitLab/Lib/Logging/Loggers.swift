import Logging

public enum Loggers {
    public static let api = Logger(label: "com.swiftgl.api")
    public static let auth = Logger(label: "com.swiftgl.auth")
    public static let cmd = Logger(label: "com.swiftgl.cmd")
}
