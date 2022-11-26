//
//  ContentView.swift
//  Comp7005 ProxyGUI
//
//  Created by Raymond Xu on 2022-11-23.
//

import SwiftUI
import Socket
import CommonLib
import Foundation
import Charts
import Combine

fileprivate let bufferSize = 1024

struct DropPerSec:Identifiable {
    let id = UUID()
    var dopRate: Double
    var second: Int
}

class ViewModel: ObservableObject {
    
    var isAck: Bool
    let didChange = PassthroughSubject<ViewModel,Never>()
    
    @Published var dropRates = [DropPerSec]()
    @Published var realtimeDropRate = 0.0
    @Published var rate = 0.0 {
        willSet{
            didChange.send(self)
        }
    }
    
    var actualDropDate: Int {
        Int(abs(100 - rate))
    }
    
    var titleString: String {
        isAck ? "Sender Status" : "Receiver Status"
    }
    
    init(_ isAck: Bool) {
        self.isAck = isAck
    }
    
}

struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SocketStatusView: View {
    @ObservedObject var vm: ViewModel
    
    var body: some View {
        VStack{
            Text(vm.titleString)
            Chart {
                ForEach(vm.dropRates) { item in
                    LineMark(
                        x: .value("Time", item.second),
                        y: .value("Drop Rate", item.dopRate)
                    )
                }
            }
            
            Slider(value: $vm.rate,
                   in: 0...100,
                   step: 10){
                Text(String.init(format: "Slide bar to select your drop rate %.0f%", vm.rate))
            }
            Text(String.init(format: "The Actual drop rate %.2f%", vm.realtimeDropRate))
        }
    }
}

struct ContentView: View {
    
    @StateObject var vm = ViewModel(true)
    @StateObject var ackVm = ViewModel(false)
    
    @State var receiveSYN = 0
    @State var sendSYN = 0
    @State var receivedACK = 0
    @State var sendACK = 0
    
    var body: some View {
        VStack {
            //MARK: SYN
            SocketStatusView(vm: vm)
            SocketStatusView(vm: ackVm)
            HStack {
                    Text("The number Of packets received from sender: \(receiveSYN)\nThe number Of packets sent to receiver: \(sendSYN)").foregroundColor(.green)
                        .multilineTextAlignment(.leading)
                        .padding(10)
            
                Text("The number Of packets received from received: \(receiveSYN)\nThe number Of packets sent to sender: \(sendSYN)").foregroundColor(.blue)
                    .multilineTextAlignment(.leading)
                    .padding(10)
            }
            Button(action: {
                DispatchQueue.global().async {
                    launchProxy()
                }
            } ) { Text("Start Proxy") }
                .buttonStyle(GrowingButton())
        }
        .padding()
    }
    
    
    func launchProxy() {
        func copyMessage(from fromFD: CInt, to toFd: CInt) {
            var readBytes: Int = 0
            var timeout = timeval(tv_sec: 1, tv_usec: 0)
            var numberOfDropped = 0.0
            var numberOfReceived = 0.0
            var numberACKOfDropped = 0.0
            var numberACKOfReceived = 0.0
            var second = 0
            while true{
                var buffer = [CChar](repeating: 0, count: bufferSize)
                setsockopt(fromFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                readBytes = read(fromFD, &buffer, bufferSize)
//                print("received: \(String(cString: buffer))")
                if readBytes > 0 {
                    numberOfReceived += 1.0
                    DispatchQueue.main.async {
                        receiveSYN += 1
                    }
                }
                let dropRate = Int.random(in: 1...100)
                if dropRate <= vm.actualDropDate {
                    let writeBytes = write(toFd, buffer, readBytes)
                    DispatchQueue.main.async {
                        sendSYN += 1
                    }
                } else {
                    numberOfDropped += 1
                }
                if readBytes == 0 {
                    break
                }
                DispatchQueue.main.async {
                    vm.realtimeDropRate = numberOfDropped / numberOfReceived * 100
                    print("SYN DROP RATE: \(vm.realtimeDropRate)")
                    let dropDate = DropPerSec(dopRate: vm.realtimeDropRate, second: second)
                    vm.dropRates.append(dropDate)
                }
                second += 1
                var askBuffer = [CChar](repeating: 0, count: bufferSize)
                setsockopt(toFd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                let askReadBytes = read(toFd, &askBuffer, bufferSize)
                if askReadBytes > 0 {
                    numberACKOfReceived += 1
                    DispatchQueue.main.async {
                        receivedACK += 1
                    }
//                    print("received: \(String(cString: askBuffer))")
                }
                let ackDropRate = Int.random(in: 1...100)
                if ackDropRate <= ackVm.actualDropDate {
                    let askWriteBytes = write(fromFD, askBuffer, askReadBytes)
                    DispatchQueue.main.async {
                        sendACK += 1
                    }
                } else {
                    numberACKOfDropped += 1.0
                }
                DispatchQueue.main.async {
                    ackVm.realtimeDropRate = numberACKOfDropped / numberACKOfReceived * 100
                    print("ACK DROP RATE: \(ackVm.realtimeDropRate)")
                    let dropDate = DropPerSec(dopRate: ackVm.realtimeDropRate, second: second)
                    ackVm.dropRates.append(dropDate)
                }
               
            }
        }
        
        let argParser = ArgParser.proxyArgParser
        do {
            try argParser.parse()
        } catch(let err) {
            print(err)
        }
        let portNumber: UInt16 = argParser.portNumber ?? 2222
        let receiverPortNumber: UInt16 = argParser.receiverPortNumber!
        let socketManger = SocketManager(isForServer: false,
                                         serverIP: "",
                                         port: portNumber,
                                         receiverPort: receiverPortNumber)
        
        let receiverIp = argParser.receiverIp
        do {
            try socketManger.netWorkSnake(to: receiverIp!)
            copyMessage(from: socketManger.serverAcceptFD!, to: socketManger.toSocketFD!)
            
        } catch (let err ) {
            
            print(err)
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
