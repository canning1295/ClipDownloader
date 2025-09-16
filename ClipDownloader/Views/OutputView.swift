import SwiftUI
import AppKit

struct OutputPanel: View {
    @ObservedObject var viewModel: ClipViewModel
    @State private var showingFolderPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Output")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Output Folder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Folder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Output folder path", text: .constant(viewModel.request.outputFolder.path))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        
                        Button("Choose...") {
                            showFilePicker()
                        }
                        .keyboardShortcut("o", modifiers: .command)
                    }
                    
                    if let folderError = viewModel.validationErrors.first(where: { $0 == ValidationError.outputFolderNotExists }) {
                        Text(folderError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Filename Template
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Filename Template")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Menu("Presets") {
                            ForEach(FilenameTemplating.predefinedTemplates, id: \.name) { preset in
                                Button(preset.name) {
                                    viewModel.request.filenameTemplate = preset.template
                                    viewModel.updateFilenamePreview()
                                }
                            }
                        }
                        .font(.caption)
                    }
                    
                    TextField("Filename template", text: $viewModel.request.filenameTemplate)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.request.filenameTemplate) { _ in
                            viewModel.updateFilenamePreview()
                        }
                    
                    // Template validation errors
                    ForEach(viewModel.templateErrors, id: \.localizedDescription) { error in
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Available tokens help
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available tokens:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("{title} {id} {start} {end} {res} {container} {uploader} {date} {duration}")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    // Live preview
                    if !viewModel.filenamePreview.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.filenamePreview)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(4)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            viewModel.updateFilenamePreview()
        }
    }
    
    private func showFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = viewModel.request.outputFolder
        panel.prompt = "Choose Output Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.request.outputFolder = url
                viewModel.validateInput()
                viewModel.savePreferences()
            }
        }
    }
}

#Preview {
    OutputPanel(viewModel: ClipViewModel())
        .frame(width: 500)
}