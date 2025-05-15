//
//  ContentView.swift
//  NoClog
//
//  Created by Simon on 2025/4/3.
//

import SwiftUI

struct ContentView: View {
    let xpcClient: XPCClientProtocol//demo
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

/*#Preview {
    ContentView()
}*/

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let mockedXPC = MockedXPCCLient()
        ContentView(xpcClient: mockedXPC)
    }
}
