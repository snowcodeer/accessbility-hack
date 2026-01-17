//
//  SerialTerminalView.swift
//  BLEApp
//

import SwiftUI

struct SerialTerminalView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) var dismiss
    @State private var inputText = ""
    @State private var centreValue: Double = 90
    @State private var dirValue: Double = 90

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
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
                        .frame(height: geometry.size.height * 0.45)
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
                VStack(spacing: 8) {
                    // Centre Control
                    VStack(spacing: 4) {
                        HStack {
                            Text("Centre: \(Int(centreValue))°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            // Test different formats
                            Button("=") {
                                sendCommand("centre = \(Int(centreValue))\r\n")
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        HStack {
                            Slider(value: $centreValue, in: 0...180, step: 1)
                            Button(action: {
                                sendCommand("centre(\(Int(centreValue)))\r\n")
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Dir Control
                    VStack(spacing: 4) {
                        HStack {
                            Text("Dir: \(Int(dirValue))°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        HStack {
                            Slider(value: $dirValue, in: 0...180, step: 1)
                            Button(action: {
                                sendCommand("dir(\(Int(dirValue)))\r\n")
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Button Controls
                    HStack(spacing: 12) {
                        Button(action: {
                            sendCommand("button1\r\n")
                        }) {
                            Text("Button 1")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            sendCommand("button2\r\n")
                        }) {
                            Text("Button 2")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                Divider()

                // Manual Input
                HStack {
                    TextField("Type command...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Serial Terminal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        bluetoothManager.receivedMessages.removeAll()
                    }) {
                        Image(systemName: "trash")
                    }
                }
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
