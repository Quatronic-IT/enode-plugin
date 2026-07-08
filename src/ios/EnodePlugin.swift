import Foundation
import LinkKit

@objc(EnodePlugin)
class EnodePlugin: CDVPlugin {

    private var handler: Handler?

    @objc(openLinkUI:)
    func openLinkUI(command: CDVInvokedUrlCommand) {
        guard let linkToken = command.argument(at: 0) as? String else {
            send(error: "Invalid arguments", callbackId: command.callbackId)
            return
        }
        presentLinkUI(linkToken: linkToken, callbackId: command.callbackId)
    }

    private func presentLinkUI(linkToken: String, callbackId: String) {
        guard let viewController = self.viewController else {
            send(error: "No view controller available to present Link UI", callbackId: callbackId)
            return
        }

        let handler = Handler(linkToken: linkToken) { [weak self] linkResult in
            guard let self = self else { return }
            self.handler = nil
            switch linkResult {
            case .success:
                self.send(success: callbackId)
            case .failure(let error):
                self.handle(error, callbackId: callbackId)
            }
        }
        self.handler = handler
        handler.present(from: viewController)
    }

    private func handle(_ error: LinkError, callbackId: String) {
        switch error {
        case .cancelledByUser, .dismissedViaDismissFunction:
            sendCancelled(callbackId: callbackId)
        case .earlyExitRequestedFromFrontend:
            // The SDK's own webview reached an "early exit" state (e.g. an unsupported
            // vehicle/scope combination) rather than the user explicitly tapping cancel or
            // a hard backend failure. Mapped to `cancelled` since linking did not complete -
            // this is a judgment call given O11's 3-state contract (success/cancelled/error);
            // revisit if O11 ever needs to distinguish this from a plain user cancel.
            sendCancelled(callbackId: callbackId)
        case .missingLinkToken:
            send(error: "Missing link token", callbackId: callbackId)
        case .malformedLinkToken:
            send(error: "Malformed link token", callbackId: callbackId)
        case .backendError(let message):
            // HumanReadableMessage's exact shape isn't documented publicly; string
            // interpolation falls back to its description either way.
            send(error: "\(message)", callbackId: callbackId)
        case .unknown:
            send(error: "Unknown LinkKit error", callbackId: callbackId)
        }
    }

    private func send(success callbackId: String) {
        let payload: [String: Any] = ["status": "success"]
        let result = CDVPluginResult(status: .ok, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }

    private func sendCancelled(callbackId: String) {
        let payload: [String: Any] = ["status": "cancelled"]
        let result = CDVPluginResult(status: .ok, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }

    private func send(error message: String, callbackId: String) {
        let payload: [String: Any] = ["status": "error", "message": message]
        let result = CDVPluginResult(status: .error, messageAs: payload)
        commandDelegate.send(result, callbackId: callbackId)
    }
}
