import SwiftUI

// Wraps the existing DashboardWebViewController (WKWebView-based charts UI)
struct WebDashboardView: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> DashboardWebViewController {
        return DashboardWebViewController()
    }

    func updateNSViewController(_ nsViewController: DashboardWebViewController, context: Context) {
        // No-op for now. The controller already updates its own data on appear.
    }
}


