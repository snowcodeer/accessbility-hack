//
//  SerialTerminalView.swift
//  BLEApp
//

import SwiftUI

struct SerialTerminalView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var inputText = ""
    @State private var centreValue: Double = 90
    @State private var dirValue: Double = 90

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Spacer()
                Button(action: {
                    bluetoothManager.receivedMessages.removeAll()
                }) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Messages display
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(bluetoothManager.receivedMessages.enumerated()), id: \.offset) { index, message in
                            HStack {
                                if message.hasPrefix("→ ") {
                                    // Sent message
                                    Spacer()
                                    Text(message.dropFirst(2))
                                        .font(.system(.body, design: .monospaced))
                                        .padding(8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                } else {
                                    // Received message
                                    Text(message)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(8)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                    Spacer()
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding()
                }
                .modifier(ScrollClipModifier())
                .onChange(of: bluetoothManager.receivedMessages.count) { _ in
                    // Auto-scroll to bottom
                    if let lastIndex = bluetoothManager.receivedMessages.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))

            Divider()

            // Controls Section
            VStack(spacing: 16) {
                // Centre Control
                VStack(spacing: 8) {
                    HStack {
                        Text("Centre: \(Int(centreValue))°")
                            .font(.headline)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        Slider(value: $centreValue, in: 0...180, step: 1)
                        Button(action: {
                            sendCommand("centre = \(Int(centreValue))\r\n")
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Dir Control
                VStack(spacing: 8) {
                    HStack {
                        Text("Dir: \(Int(dirValue))°")
                            .font(.headline)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        Slider(value: $dirValue, in: 0...180, step: 1)
                        Button(action: {
                            sendCommand("dir(\(Int(dirValue)))\r\n")
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            // Bottom navbar
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    TextField("Type command...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let command = inputText + "\r\n"
        bluetoothManager.sendText(command)
        inputText = ""
    }

    private func sendCommand(_ command: String) {
        bluetoothManager.sendText(command)
    }
}

// MARK: - Preview
struct SerialTerminalView_Previews: PreviewProvider {
    static var previews: some View {
        SerialTerminalView(bluetoothManager: BluetoothManager())
    }
}
