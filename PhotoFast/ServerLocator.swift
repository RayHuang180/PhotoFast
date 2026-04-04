import Foundation
import Network

class ServerLocator: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    // 當找到伺服器時，這個變數會自動更新並通知 SwiftUI
    @Published var serverURL: URL?
    
    private var netServiceBrowser: NetServiceBrowser!
    private var activeService: NetService?

    override init() {
        super.init()
        startBrowsing()
    }

    func startBrowsing() {
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser.delegate = self
        // 尋找我們在 Python 設定好的服務名稱
        netServiceBrowser.searchForServices(ofType: "_photofast._tcp.", inDomain: "local.")
    }

    // 💡 發現服務時觸發
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("🔍 發現區網服務: \(service.name)")
        activeService = service
        activeService?.delegate = self
        // 開始解析這台伺服器的真實 IP 和 Port
        activeService?.resolve(withTimeout: 5.0)
    }

    // 💡 成功解析出 IP 和 Port 時觸發
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let hostName = sender.hostName {
            // 自動組合成你需要的 API 網址
            let urlString = "http://\(hostName):\(sender.port)/upload"
            DispatchQueue.main.async {
                self.serverURL = URL(string: urlString)
                print("✅ 成功鎖定伺服器位址: \(urlString)")
            }
        }
    }
    
    // 服務消失時 (例如電腦關機或關掉程式)
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DispatchQueue.main.async {
            self.serverURL = nil
            print("❌ 伺服器已離線")
        }
    }
}

