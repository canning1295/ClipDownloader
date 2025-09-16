import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ClipViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ScrollView {
                VStack(spacing: 20) {
                    // Source Panel
                    SourcePanel(viewModel: viewModel)
                    
                    Divider()
                    
                    // Options Panel
                    OptionsPanel(viewModel: viewModel)
                    
                    Divider()
                    
                    // Output Panel
                    OutputPanel(viewModel: viewModel)
                    
                    Divider()
                    
                    // Progress and Controls
                    ProgressAndControlsPanel(viewModel: viewModel)
                }
                .padding()
            }
            
            // Console log area (collapsible)
            ConsoleLogPanel(viewModel: viewModel)
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            viewModel.loadPreferences()
        }
        .alert("Error", isPresented: .constant(viewModel.orchestrator.currentError != nil)) {
            Button("OK") {
                viewModel.orchestrator.currentError = nil
            }
        } message: {
            if let error = viewModel.orchestrator.currentError {
                Text(error.localizedDescription)
            }
        }
        .alert("Success", isPresented: .constant(viewModel.orchestrator.stage == .finished && viewModel.orchestrator.resultFile != nil)) {
            Button("Reveal in Finder") {
                viewModel.orchestrator.revealInFinder()
            }
            Button("OK") {}
        } message: {
            Text("Clip created successfully!")
        }
    }
}

// MARK: - Source Panel

struct SourcePanel: View {
    @ObservedObject var viewModel: ClipViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Source")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("YouTube URL")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("https://youtube.com/watch?v=...", text: $viewModel.request.url)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.request.url) { _ in
                        viewModel.validateInput()
                    }
                
                if let urlError = viewModel.validationErrors.first(where: { 
                    [ValidationError.emptyURL, ValidationError.invalidURL].contains($0)
                }) {
                    Text(urlError.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("0:00", text: $viewModel.request.startTime)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: viewModel.request.startTime) { _ in
                            viewModel.validateInput()
                        }
                    
                    if let startError = viewModel.validationErrors.first(where: { $0 == ValidationError.invalidStartTime }) {
                        Text(startError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("1:00", text: $viewModel.request.endTime)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: viewModel.request.endTime) { _ in
                            viewModel.validateInput()
                        }
                    
                    if let endError = viewModel.validationErrors.first(where: { 
                        [ValidationError.invalidEndTime, ValidationError.endTimeNotAfterStart, ValidationError.clipTooShort].contains($0)
                    }) {
                        Text(endError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Show help popover
                }) {
                    Image(systemName: "questionmark.circle")
                }
                .help("Time format: SS, MM:SS, or HH:MM:SS")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Progress and Controls Panel

struct ProgressAndControlsPanel: View {
    @ObservedObject var viewModel: ClipViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Overall progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.orchestrator.stage.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(viewModel.orchestrator.overallProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: viewModel.orchestrator.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                
                // Stage-specific progress
                if viewModel.orchestrator.stage == .downloading {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Download Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(viewModel.orchestrator.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: viewModel.orchestrator.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(y: 0.8)
                    }
                } else if viewModel.orchestrator.stage == .cutting {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Cutting Progress")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(viewModel.orchestrator.cuttingProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: viewModel.orchestrator.cuttingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(y: 0.8)
                    }
                }
            }
            
            // Control buttons
            HStack {
                Button(action: {
                    Task {
                        await viewModel.startJob()
                    }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Download Clip")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStartJob)
                .keyboardShortcut("r", modifiers: .command)
                
                if viewModel.orchestrator.isRunning {
                    Button(action: {
                        viewModel.cancelJob()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle")
                            Text("Cancel")
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(".", modifiers: .command)
                }
                
                Spacer()
                
                if viewModel.orchestrator.stage == .finished, let _ = viewModel.orchestrator.resultFile {
                    Button(action: {
                        viewModel.orchestrator.revealInFinder()
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Reveal in Finder")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Console Log Panel

struct ConsoleLogPanel: View {
    @ObservedObject var viewModel: ClipViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle
            HStack {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        Text("Console Log")
                        Spacer()
                        Text("(\(viewModel.orchestrator.logMessages.count))")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.separatorColor))
            
            // Console content
            if isExpanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(viewModel.orchestrator.logMessages) { logMessage in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(logMessage.formattedTimestamp)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Text("[\(logMessage.type.rawValue)]")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(colorForLogType(logMessage.type))
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Text(logMessage.message)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .id(logMessage.id)
                            }
                        }
                    }
                    .frame(height: 200)
                    .background(Color(NSColor.textBackgroundColor))
                    .onChange(of: viewModel.orchestrator.logMessages.count) { _ in
                        if let lastMessage = viewModel.orchestrator.logMessages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func colorForLogType(_ type: LogType) -> Color {
        switch type {
        case .debug: return .gray
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    ContentView()
}