import Socket
import CommonLib
import Foundation

fileprivate let bufferSize = 1024

@main
public struct Proxy {
    
    public static func main() {
        
        
        func copyMessage(from fromFD: CInt, to toFd: CInt) {
            var readBytes: Int = 0
            var timeout = timeval(tv_sec: 1, tv_usec: 0)
            var numberOfDropped = 0.0
            var numberOfReceived = 0.0
            while true{
                var buffer = [CChar](repeating: 0, count: bufferSize)
                setsockopt(fromFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                readBytes = read(fromFD, &buffer, bufferSize)
                print("received: \(String(cString: buffer))")
                numberOfReceived += 1
                let dropRate = Int.random(in: 1...2)
                if dropRate == 1 {
                    let writeBytes = write(toFd, buffer, readBytes)
                } else {
                    numberOfDropped += 1
                }
                if readBytes == 0 {
                    break
                }
                
                var askBuffer = [CChar](repeating: 0, count: bufferSize)
                setsockopt(toFd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                let askReadBytes = read(toFd, &askBuffer, bufferSize)
                let askWriteBytes = write(fromFD, askBuffer, askReadBytes)
//                print("writes: \(String(cString: askBuffer))")
                
            }
        }
        
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
        var counter = 0
        do {
            try socketManger.netWorkSnake(from: senderIp!, to: receiverIp!)
            var counter = 0
            copyMessage(from: socketManger.serverAcceptFD!, to: socketManger.toSocketFD!)
            
        } catch (let err ) {
            print(err)
        }
    }
}
