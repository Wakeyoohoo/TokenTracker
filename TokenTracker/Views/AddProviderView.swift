import SwiftUI

/// Form for adding a custom provider via UI
struct AddProviderView: View {
    @ObservedObject var viewModel: TokenTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var iconName = "cloud"
    @State private var brandColorHex = "#6B7280"
    @State private var baseURL = ""
    @State private var path = ""
    @State private var method = "GET"
    @State private var authType: EndpointConfig.AuthType = .bearer
    @State private var authHeader = "Authorization"
    @State private var authPrefix = "Bearer "
    @State private var balanceKeyPath = ""
    @State private var remainingKeyPath = ""
    @State private var currency = "CNY"
    @State private var apiKey = ""
    
    private let iconOptions = [
        "cloud", "star", "bolt", "flame", "cpu",
        "brain", "wand.and.stars", "tornado", "globe",
        "server.rack", "antenna.radiowaves.left.and.right"
    ]
    
    private let currencyOptions = ["USD", "CNY", "EUR", "GBP"]
    
    var body: some View {
        VStack(spacing: 0) {
            Text("添加自定义 Provider")
                .font(.headline)
                .padding()
            
            Divider()
            
            Form {
                Section("基本信息") {
                    TextField("名称", text: $displayName, prompt: Text("例: Moonshot AI"))
                    
                    Picker("图标", selection: $iconName) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Label(icon, systemImage: icon).tag(icon)
                        }
                    }
                    
                    TextField("品牌色 (Hex)", text: $brandColorHex, prompt: Text("#FF6B6B"))
                }
                
                Section("API 配置") {
                    TextField("Base URL", text: $baseURL, prompt: Text("https://api.example.com"))
                    TextField("路径", text: $path, prompt: Text("/v1/user/balance"))
                    
                    Picker("方法", selection: $method) {
                        Text("GET").tag("GET")
                        Text("POST").tag("POST")
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("认证方式", selection: $authType) {
                        Text("Bearer Token").tag(EndpointConfig.AuthType.bearer)
                        Text("API Key Header").tag(EndpointConfig.AuthType.apiKey)
                    }
                    
                    TextField("认证 Header", text: $authHeader, prompt: Text("Authorization"))
                    
                    if authType == .bearer {
                        TextField("认证前缀", text: $authPrefix, prompt: Text("Bearer "))
                    }
                    
                    SecureField("API Key", text: $apiKey, prompt: Text("输入 API Key"))
                }
                
                Section("响应映射 (JSON Key Path)") {
                    TextField("总额字段", text: $balanceKeyPath, prompt: Text("data.total_balance"))
                    TextField("剩余字段", text: $remainingKeyPath, prompt: Text("data.available_balance"))
                    
                    Picker("货币", selection: $currency) {
                        ForEach(currencyOptions, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("添加") {
                    addProvider()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(displayName.isEmpty || baseURL.isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 550)
    }
    
    private func addProvider() {
        let id = displayName
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        
        let endpointConfig = EndpointConfig(
            baseURL: baseURL,
            path: path,
            method: method,
            authType: authType,
            authHeader: authHeader,
            authPrefix: authPrefix,
            balanceKeyPath: balanceKeyPath.isEmpty ? nil : balanceKeyPath,
            remainingKeyPath: remainingKeyPath.isEmpty ? nil : remainingKeyPath,
            currencyKeyPath: nil,
            currency: currency
        )
        
        let config = ProviderConfig(
            id: id,
            displayName: displayName,
            iconName: iconName,
            brandColorHex: brandColorHex,
            isEnabled: true,
            apiKey: apiKey,
            providerType: .custom,
            endpointConfig: endpointConfig,
            isBuiltIn: false
        )
        
        viewModel.addCustomProvider(config)
    }
}
