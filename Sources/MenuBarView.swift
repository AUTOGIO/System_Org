import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var ollamaManager: OllamaManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Actions
            VStack(spacing: 4) {
                Text("Quick Actions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ForEach(automationManager.automations.filter { $0.isEnabled }.prefix(5)) { automation in
                    Button(action: { automationManager.runAutomation(automation) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            
                            Text(automation.name)
                                .font(.caption)
                            
                            Spacer()
                            
                            if automationManager.runningAutomations.contains(automation.id) {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Menu Items
            VStack(spacing: 0) {
                Button(action: { NSApp.activate(ignoringOtherApps: true) }) {
                    HStack {
                        Image(systemName: "window.open")
                        Text("Open Main Window")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary)
                
                Divider()
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .frame(width: 250)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AutomationManager())
}
