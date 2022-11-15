import Socket
import CommonLib
import Foundation

@main
public struct Proxy {

    public static func main() {
        let argParser = ArgParser.proxyArgParser
        do {
            try argParser.parse()
        } catch(let err) {
            print(err)
        }
        let portNumber: UInt16 = argParser.portNumber ?? 2222
        let socketManger = SocketManager(isForServer: false,
                                         serverIP: "",
                                         port: portNumber)

        let senderIp = argParser.senderIp
        let receiverIp = argParser.receiverIp
        var fromFD: CInt = 0
        var toFD: CInt = 0
        do {
            try socketManger.netWorkSnake(from: senderIp!, to: receiverIp!)
        } catch (let err ) {
            print(err)
        }
    }
}
