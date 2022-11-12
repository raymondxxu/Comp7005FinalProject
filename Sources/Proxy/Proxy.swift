@main
public struct Proxy {
    public private(set) var text = "Hello, World!"

    public static func main() {
        print(Proxy().text)
    }
}
