import SwiftUI

struct OptionsPanel: View {
    @ObservedObject var viewModel: ClipViewModel
    @State private var showingAdvanced = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Options")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Quality Picker
                HStack {
                    Text("Quality:")
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("Quality", selection: $viewModel.request.quality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    
                    Spacer()
                }
                
                // Container Picker
                HStack {
                    Text("Container:")
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("Container", selection: $viewModel.request.container) {
                        ForEach(Container.allCases, id: \.self) { container in
                            Text(container.displayName).tag(container)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    
                    Spacer()
                }
                
                // Clip Accuracy
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clip Accuracy:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Accuracy.allCases, id: \.self) { accuracy in
                            HStack {
                                RadioButton(
                                    isSelected: viewModel.request.accuracy == accuracy,
                                    action: { viewModel.request.accuracy = accuracy }
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(accuracy.displayName)
                                        .font(.subheadline)
                                    Text(accuracy.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.leading, 8)
                }
                
                // Advanced Options (Disclosure)
                DisclosureGroup("Advanced Options", isExpanded: $showingAdvanced) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Download Sections Toggle
                        Toggle("Download only the selected section (experimental)", 
                               isOn: $viewModel.request.useDownloadSections)
                            .help("Uses yt-dlp's --download-sections feature. May not work with all videos.")
                        
                        Divider()
                        
                        // Video Bitrate (only for re-encoding)
                        if viewModel.request.accuracy == .frameAccurate && !viewModel.request.container.isAudioOnly {
                            HStack {
                                Text("Video Bitrate:")
                                    .frame(width: 120, alignment: .leading)
                                
                                Slider(
                                    value: Binding(
                                        get: { viewModel.request.videoBitrateMbps ?? 5.0 },
                                        set: { viewModel.request.videoBitrateMbps = $0 }
                                    ),
                                    in: 0.5...20.0,
                                    step: 0.5
                                ) {
                                    Text("Video Bitrate")
                                } minimumValueLabel: {
                                    Text("0.5")
                                } maximumValueLabel: {
                                    Text("20")
                                }
                                .frame(maxWidth: 200)
                                
                                Text("\(String(format: "%.1f", viewModel.request.videoBitrateMbps ?? 5.0)) Mbps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60)
                                
                                Spacer()
                            }
                        }
                        
                        // Audio Bitrate
                        if viewModel.request.accuracy == .frameAccurate {
                            HStack {
                                Text("Audio Bitrate:")
                                    .frame(width: 120, alignment: .leading)
                                
                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.request.audioBitrateKbps ?? 160) },
                                        set: { viewModel.request.audioBitrateKbps = Int($0) }
                                    ),
                                    in: 64...320,
                                    step: 16
                                ) {
                                    Text("Audio Bitrate")
                                } minimumValueLabel: {
                                    Text("64")
                                } maximumValueLabel: {
                                    Text("320")
                                }
                                .frame(maxWidth: 200)
                                
                                Text("\(viewModel.request.audioBitrateKbps ?? 160) kbps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onChange(of: viewModel.request.container) { container in
            // Auto-adjust accuracy for audio-only containers
            if container.isAudioOnly && viewModel.request.accuracy == .keyframeCopy {
                viewModel.request.accuracy = .frameAccurate
            }
        }
    }
}

// MARK: - Radio Button Component

struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.primary, lineWidth: 1)
                    .frame(width: 16, height: 16)
                
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OptionsPanel(viewModel: ClipViewModel())
        .frame(width: 500)
}