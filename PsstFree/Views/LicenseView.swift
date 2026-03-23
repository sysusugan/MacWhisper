import SwiftUI

/// License activation view — shown in Settings sidebar
struct LicenseSettingsView: View {
    @ObservedObject private var licenseManager = LicenseManager.shared
    @State private var licenseKey = ""
    @State private var email = ""
    @State private var isActivating = false
    @State private var resultMessage = ""
    @State private var isError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("License")
                    .font(.system(size: 22, weight: .bold))

                // Status card
                statusCard

                // Activation form (when not licensed)
                if licenseManager.licenseState != .licensed {
                    activationForm
                }

                // Result message
                if !resultMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(isError ? .orange : .green)
                        Text(resultMessage)
                            .font(.system(size: 13))
                            .foregroundColor(isError ? .orange : .green)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill((isError ? Color.orange : Color.green).opacity(0.1)))
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(statusSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if licenseManager.licenseState == .licensed {
                    Button("Deactivate") {
                        licenseManager.deactivate()
                        resultMessage = ""
                    }
                    .foregroundColor(.red)
                }
            }

            if licenseManager.licenseState == .licensed, !licenseManager.licenseEmail.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(licenseManager.licenseEmail)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private var activationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activate License")
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                TextField("Email address", text: $email)
                    .textFieldStyle(.roundedBorder)

                TextField("License key", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Button(action: activate) {
                    if isActivating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text("Activate")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.isEmpty || isActivating)

                Spacer()

                Button("Buy License") {
                    if let url = URL(string: "https://psstfree.com/#pricing") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }

    private var statusColor: Color {
        switch licenseManager.licenseState {
        case .licensed: return .green
        case .trial: return .blue
        case .expired: return .red
        case .checking: return .gray
        }
    }

    private var statusTitle: String {
        switch licenseManager.licenseState {
        case .licensed: return "Licensed"
        case .trial: return "Free Trial"
        case .expired: return "Trial Expired"
        case .checking: return "Checking..."
        }
    }

    private var statusSubtitle: String {
        switch licenseManager.licenseState {
        case .licensed:
            return "Thank you for supporting Psst Free!"
        case .trial:
            return "\(licenseManager.trialDaysRemaining) days remaining in your free trial."
        case .expired:
            return "Your trial has ended. Enter a license key to continue using Psst Free."
        case .checking:
            return "Verifying license status..."
        }
    }

    private func activate() {
        isActivating = true
        resultMessage = ""

        Task {
            let result = await licenseManager.activate(key: licenseKey, email: email)
            isActivating = false

            switch result {
            case .success(let message):
                resultMessage = message
                isError = false
                licenseKey = ""
                email = ""
            case .failure(let message):
                resultMessage = message
                isError = true
            }
        }
    }
}
