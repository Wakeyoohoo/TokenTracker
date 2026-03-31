import Foundation

/// Claude CLI Provider - uses `claude status --json` to fetch subscription usage
struct ClaudeCLIProvider: UsageProvider {
    static var providerType: ProviderType { .claudeCLI }

    func fetchUsage(config: ProviderConfig) async throws -> UsageData {
        // Verify claude CLI is installed
        guard let claudePath = findClaudeBinary() else {
            return UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: "Claude CLI 未安装。请从 https://code.claude.com 下载安装。"
            )
        }

        let result = await runClaudeStatus(claudePath: claudePath)

        switch result {
        case .success(let output):
            return parseClaudeStatus(output: output, config: config)
        case .failure(let error):
            return UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: error.localizedDescription
            )
        }
    }

    /// Finds the claude binary path
    private func findClaudeBinary() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !path.isEmpty
        else { return nil }
        return path
    }

    /// Runs `claude status --json` and returns the output
    private func runClaudeStatus(claudePath: String) async -> Result<String, Error> {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = ["status", "--json"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Set environment to avoid UI prompts
            var env = ProcessInfo.processInfo.environment
            env["CLAUDE_NOinteractive"] = "1"
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env

            // Use non-blocking approach
            var completed = false
            let lock = NSLock()

            process.terminationHandler = { proc in
                lock.lock()
                defer { lock.unlock() }
                guard !completed else { return }
                completed = true

                let exitCode = proc.terminationStatus

                if exitCode != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(returning: .failure(NSError(domain: "ClaudeCLI", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: "Claude CLI 错误 (exit \(exitCode)): \(errorStr.prefix(200))"])))
                    return
                }

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: outputData, encoding: .utf8) else {
                    continuation.resume(returning: .failure(NSError(domain: "ClaudeCLI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取 Claude CLI 输出"])))
                    return
                }

                continuation.resume(returning: .success(output))
            }

            do {
                try process.run()
            } catch {
                lock.lock()
                defer { lock.unlock() }
                guard !completed else { return }
                completed = true
                continuation.resume(returning: .failure(NSError(domain: "ClaudeCLI", code: -2, userInfo: [NSLocalizedDescriptionKey: "启动 Claude CLI 失败: \(error.localizedDescription)"])))
                return
            }

            // Timeout after 15 seconds
            Task {
                try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
                lock.lock()
                defer { lock.unlock() }
                guard !completed else { return }
                completed = true
                process.terminate()
                continuation.resume(returning: .failure(NSError(domain: "ClaudeCLI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Claude CLI 超时 (15秒)"])))
            }
        }
    }

    /// Parses the JSON output from `claude status --json`
    private func parseClaudeStatus(output: String, config: ProviderConfig) -> UsageData {
        guard let data = output.data(using: .utf8) else {
            return UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: "无法解析 Claude CLI 输出"
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: "JSON 解析失败: \(output.prefix(100))"
            )
        }

        // Check for error indicators in the response
        if let ok = json["ok"] as? Bool, !ok {
            let hint = json["hint"] as? String ?? json["pane_preview"] as? String ?? ""
            return UsageData.error(
                providerId: config.id,
                providerName: config.displayName,
                message: hint.isEmpty ? "Claude 返回错误" : hint
            )
        }

        // Parse session (5h) usage
        var sessionPercent: Double = 0
        var sessionResets: String = ""
        var sessionResetsAt: Date?

        if let session = json["session_5h"] as? [String: Any] {
            sessionPercent = (session["pct_used"] as? NSNumber)?.doubleValue ?? 0
            sessionResets = session["resets"] as? String ?? ""
            // Parse ISO8601 reset time
            if let resetsAtStr = session["resets_at"] as? String {
                sessionResetsAt = ISO8601DateFormatter().date(from: resetsAtStr)
            }
        }

        // Parse weekly usage (all models)
        var weeklyPercent: Double?
        var weeklyResetsAt: Date?

        if let weekAll = json["seven_day"] as? [String: Any] {
            weeklyPercent = (weekAll["utilization"] as? NSNumber)?.doubleValue
            if let resetsAtStr = weekAll["resets_at"] as? String {
                weeklyResetsAt = ISO8601DateFormatter().date(from: resetsAtStr)
            }
        } else if let weekAll = json["week_all_models"] as? [String: Any] {
            weeklyPercent = (weekAll["pct_used"] as? NSNumber)?.doubleValue
        } else if let weekAll = json["week_all"] as? [String: Any] {
            weeklyPercent = (weekAll["pct_used"] as? NSNumber)?.doubleValue
        }

        // Parse Sonnet-specific weekly usage
        var sonnetPercent: Double?
        if let sonnet = json["week_sonnet"] as? [String: Any] {
            sonnetPercent = (sonnet["pct_used"] as? NSNumber)?.doubleValue
        } else if let sonnet = json["week_sonnet_only"] as? [String: Any] {
            sonnetPercent = (sonnet["pct_used"] as? NSNumber)?.doubleValue
        }

        // Parse Opus-specific weekly usage
        var opusPercent: Double?

        if let opus = json["week_opus"] as? [String: Any] {
            opusPercent = (opus["pct_used"] as? NSNumber)?.doubleValue
        }

        // Account info
        let accountEmail = (json["account_email"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let accountOrg = (json["account_org"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let loginMethod = (json["login_method"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Build status message
        var statusParts: [String] = []
        if sessionPercent > 0 {
            statusParts.append("Session: \(String(format: "%.1f", sessionPercent))%")
        }
        if let wp = weeklyPercent {
            statusParts.append("Weekly: \(String(format: "%.1f", wp))%")
        }
        if let sp = sonnetPercent {
            statusParts.append("Sonnet: \(String(format: "%.1f", sp))%")
        }
        if let op = opusPercent {
            statusParts.append("Opus: \(String(format: "%.1f", op))%")
        }
        if !sessionResets.isEmpty {
            statusParts.append("Resets: \(sessionResets)")
        }
        if let email = accountEmail, !email.isEmpty {
            statusParts.append("Account: \(email)")
        }
        if let org = accountOrg, !org.isEmpty {
            statusParts.append("Org: \(org)")
        }
        if let method = loginMethod, !method.isEmpty {
            statusParts.append("Login: \(method)")
        }

        // Build model breakdown
        var modelBreakdown: [ModelUsage] = []

        if let sp = sonnetPercent {
            modelBreakdown.append(ModelUsage(
                modelName: "claude-sonnet",
                inputTokens: 0,
                outputTokens: 0,
                cost: 0,
                totalQuota: 100,
                remainingQuota: max(0, 100 - sp)
            ))
        }

        if let op = opusPercent {
            modelBreakdown.append(ModelUsage(
                modelName: "claude-opus",
                inputTokens: 0,
                outputTokens: 0,
                cost: 0,
                totalQuota: 100,
                remainingQuota: max(0, 100 - op)
            ))
        }

        return UsageData(
            providerId: config.id,
            providerName: config.displayName,
            inputTokens: 0,
            outputTokens: 0,
            cost: 0,
            currency: "Percent",
            totalQuota: 100,
            usedAmount: sessionPercent,
            remainingBalance: max(0, 100 - sessionPercent),
            refreshExpiryTimestamp: sessionResetsAt?.timeIntervalSince1970,
            weeklyRefreshExpiryTimestamp: weeklyResetsAt?.timeIntervalSince1970,
            modelBreakdown: modelBreakdown,
            fetchedAt: Date(),
            errorMessage: statusParts.isEmpty ? nil : statusParts.joined(separator: " | "),
            rawResponse: output
        )
    }
}
