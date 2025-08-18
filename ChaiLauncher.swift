//
//  ChaiLauncher.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/4/25.
//

import SwiftUI
import Speech            // speech‐to‐text
import AVFoundation      // audio session + TTS

/// 1) The launcher button + container
struct ChaiLauncher<Content: View>: View {
    @State private var isOpen = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Your existing app content
            content

            // Floating Chai button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { withAnimation { isOpen.toggle() } }) {
                        Image("Chai")
                            .renderingMode(.original)
                            .resizable()
                            .frame(width: 40, height: 56)
                    }
                    .padding()
                }
            }

            // Overlay chat panel when open
            if isOpen {
                ChaiChatView(isOpen: $isOpen)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

/// 2) The chat panel, now with speech‐to‐text and proper audio session setup
struct ChaiChatView: View {
    @Binding var isOpen: Bool
    @EnvironmentObject private var agent: ChaiAgent

    @State private var draft: String = ""
    @State private var isRecording = false
    @State private var audioEngine = AVAudioEngine()
    @State private var speechTask: SFSpeechRecognitionTask?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chai").font(.headline)
                Spacer()
                Button(action: { withAnimation { isOpen = false } }) {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
            }
            .padding()
            Divider()

            // Messages list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(agent.messages) { msg in
                        HStack {
                            if msg.sender == .chai { Spacer() }
                            Text(msg.text)
                                .padding(8)
                                .background(
                                    msg.sender == .user
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(.systemGray6)
                                )
                                .cornerRadius(8)
                            if msg.sender == .user { Spacer() }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }

            Divider()

            // Input bar with mic + text field + send
            HStack {
                Button { toggleRecording() } label: {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.title2)
                }

                TextField("Ask Chai…", text: $draft)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Send") {
                    stopRecording()
                    agent.send(draft)
                    draft = ""
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding(.trailing, 16)
        .padding(.bottom, 80)
        .onAppear {
            agent.greet()
            requestPermissions()
        }
    }

    // MARK: – Permissions

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    // MARK: – Recording

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        let input = audioEngine.inputNode
        let format = input.inputFormat(forBus: 0)               // ← use inputFormat
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
            req.append(buf)
        }

        audioEngine.prepare()
        do { try audioEngine.start() }
        catch {
            print("⚠️ audioEngine start failed:", error)
            return
        }
        isRecording = true

        speechTask = SFSpeechRecognizer()?.recognitionTask(with: req) { result, _ in
            if let text = result?.bestTranscription.formattedString {
                draft = text
            }
        }
    }


        private func stopRecording() {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            speechTask?.cancel()
            isRecording = false

            // Deactivate session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
