import SwiftUI

struct AIAdviceView: View {
    @Environment(AIAdviceViewModel.self) private var vm

    @State private var showAPIKeySheet = false

    var body: some View {
        NavigationStack {
            @Bindable var vm = vm

            VStack(spacing: 0) {
                if vm.messages.isEmpty {
                    topicSelectionView
                } else {
                    chatView
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                inputBar
            }
            .navigationTitle("AI 육아 조언")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAPIKeySheet = true
                        } label: {
                            Label("API 키 설정", systemImage: "key.fill")
                        }

                        if !vm.messages.isEmpty {
                            Button(role: .destructive) {
                                vm.clearChat()
                            } label: {
                                Label("대화 초기화", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAPIKeySheet) {
                APIKeySheet()
            }
            .onAppear {
                if !vm.hasAPIKey {
                    showAPIKeySheet = true
                }
            }
        }
    }

    // MARK: - Topic Selection

    private var topicSelectionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink.opacity(0.7))

                    Text("무엇이 궁금하세요?")
                        .font(.title3.weight(.semibold))

                    Text("주제를 선택하거나 직접 질문해보세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("AI 조언은 참고용이며 의료 전문가의 진단이나 처방을 대체하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(AIAdviceViewModel.topics, id: \.title) { topic in
                        Button {
                            Task { await vm.send(topic.prompt) }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: topic.icon)
                                    .font(.title2)
                                    .foregroundStyle(.pink)
                                Text(topic.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if vm.isLoading {
                        HStack {
                            ProgressView()
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: vm.messages.count) {
                withAnimation {
                    if let lastId = vm.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("질문을 입력하세요...", text: Bindable(vm).inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await vm.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading
                        ? .gray : .pink)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: AIAdviceViewModel.ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    AIGeneratedLabel()
                }

                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(message.role == .user
                        ? Color.pink.opacity(0.15)
                        : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}

// MARK: - AI Generated Label

struct AIGeneratedLabel: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
            Text(AIGuardrailService.aiLabel)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.purple.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - API Key Sheet

private struct APIKeySheet: View {
    @Environment(AIAdviceViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-...", text: $key)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Anthropic API 키")
                } footer: {
                    Text("console.anthropic.com에서 API 키를 발급받을 수 있습니다. 키는 기기에만 저장됩니다.")
                }
            }
            .navigationTitle("API 키 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        vm.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                key = vm.apiKey
            }
        }
        .presentationDetents([.medium])
    }
}
