//
//  ContentView.swift
//  LidarModelApp2
//
//  Created by Andre Grossberg on 4/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var submittedExportRequest = false
    @State private var exportedURL: URL?
    var body: some View {
        VStack {
            ARWrapper(submittedExportRequest: $submittedExportRequest, exportedURL: $exportedURL)
            Button(action: {
                submittedExportRequest.toggle()
            }) {
                Text("Export")
            }.padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
