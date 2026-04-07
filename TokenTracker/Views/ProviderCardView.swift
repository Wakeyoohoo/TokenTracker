import SwiftUI

/// Card view for a single provider showing usage, tokens, quota progress
struct ProviderCardView: View {
    @ObservedObject var viewModel: TokenTrackerViewModel
    let config: ProviderConfig
    let usage: UsageData
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: icon + name + cost
            HStack {
                Circle()
                    .fill(config.brandColor)
                    .frame(width: 8, height: 8)
                
                Image(systemName: config.iconName)
                    .font(.caption)
                    .foregroundColor(config.brandColor)
                
                Text(config.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isCurrencyQuota, let total = usage.totalQuota, total > 0 {
                    Text("总量 \(total.formattedBalanceValue(usage.currency))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(config.brandColor)
                } else if let total = usage.totalQuota, total > 0 {
                    Text("总量 \(total.formattedQuotaValue)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(config.brandColor)
                } else if usage.cost > 0 {
                    Text(usage.cost.formattedCurrency(usage.currency))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(config.brandColor)
                }
            }
            
            // Error message
            if let error = usage.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .textSelection(.enabled)
            }
            
            // Token counts
            if usage.inputTokens > 0 || usage.outputTokens > 0 {
                HStack(spacing: 12) {
                    Label("In: \(usage.inputTokens.formattedTokens)", systemImage: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Label("Out: \(usage.outputTokens.formattedTokens)", systemImage: "arrow.up.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Total: \(usage.totalTokens.formattedTokens)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quota & Balance Info
            if let percentage = usage.usagePercentage {
                // Show full progress bar when quota info is fully available
                VStack(alignment: .leading, spacing: 2) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(progressColor(percentage))
                                .frame(width: geometry.size.width * CGFloat(percentage), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text(percentage.formattedPercentage)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        if let total = usage.totalQuota {
                            if let used = usage.usedAmount, used > 0 {
                                Text("已用 \(formatBalance(used)) / \(formatBalance(total))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            } else if let remaining = usage.remainingBalance {
                                Text("剩余 \(formatBalance(remaining)) / \(formatBalance(total))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        } else {
                            if let remaining = usage.remainingBalance {
                                Text("剩余: \(remaining.formattedCurrency(usage.currency))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            if let total = usage.totalQuota {
                                Text("/ \(total.formattedCurrency(usage.currency))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else if let remaining = usage.remainingBalance {
                HStack {
                    Spacer()
                    if let total = usage.totalQuota {
                        if let used = usage.usedAmount, used > 0 {
                            Text("已用 \(formatBalance(used)) / \(formatBalance(total))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        } else {
                            Text("剩余 \(formatBalance(remaining)) / \(formatBalance(total))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    } else {
                        Text("剩余余额: \(remaining.formattedCurrency(usage.currency))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let refreshExpiryTimestamp = usage.refreshExpiryTimestamp {
                HStack {
                    Spacer()
                    // 优化：当面板隐藏时，通过 .id() 强制销毁并重新挂载，从而真正释放 TimelineView 的内部计时器
                    if viewModel.isPopoverVisible {
                        TimelineView(.periodic(from: .now, by: 60.0)) { context in
                            Text("重置:" + resetCountdownText(expiryTimestamp: refreshExpiryTimestamp, now: context.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .id("TimelineView-Main-\(config.id)")
                    } else {
                        Text("重置:" + resetCountdownText(expiryTimestamp: refreshExpiryTimestamp, now: Date()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            if let weeklyRefreshExpiryTimestamp = usage.weeklyRefreshExpiryTimestamp {
                HStack {
                    Spacer()
                    if viewModel.isPopoverVisible {
                        TimelineView(.periodic(from: .now, by: 60.0)) { context in
                            Text("周重置:" + resetCountdownText(expiryTimestamp: weeklyRefreshExpiryTimestamp, now: context.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .id("TimelineView-Weekly-\(config.id)")
                    } else {
                        Text("周重置:" + resetCountdownText(expiryTimestamp: weeklyRefreshExpiryTimestamp, now: Date()))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            // Model breakdown (expandable)
            if !usage.modelBreakdown.isEmpty {
                Divider().padding(.vertical, 2)
                
                Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() } }) {
                    HStack {
                        Text(isMiniMax ? "模型额度明细" : "模型消耗明细")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(usage.modelBreakdown.count) 个")
                            .font(.caption2)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle()) // Make the whole row click-friendly
                }
                .buttonStyle(.borderless)
                .focusable(false)
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(usage.modelBreakdown) { model in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(model.modelName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if (model.totalQuota ?? 0) > 0, let remaining = modelRemaining(model), let total = model.totalQuota {
                                        let used = max(total - remaining, 0)
                                        Text("已用 \(formatBalance(used)) / \(formatBalance(total))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    } else {
                                        Text(model.cost.formattedCurrency(usage.currency))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                }

                                if let refreshExpiryTimestamp = model.refreshExpiryTimestamp {
                                    if viewModel.isPopoverVisible {
                                        TimelineView(.periodic(from: .now, by: 60.0)) { context in
                                            Text("重置:" + resetCountdownText(expiryTimestamp: refreshExpiryTimestamp, now: context.date))
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }
                                        .id("TimelineView-ModelReset-\(model.id)")
                                    } else {
                                        Text("重置:" + resetCountdownText(expiryTimestamp: refreshExpiryTimestamp, now: Date()))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                }

                                if let weeklyRefreshExpiryTimestamp = model.weeklyRefreshExpiryTimestamp {
                                    if viewModel.isPopoverVisible {
                                        TimelineView(.periodic(from: .now, by: 60.0)) { context in
                                            Text("周重置:" + resetCountdownText(expiryTimestamp: weeklyRefreshExpiryTimestamp, now: context.date))
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }
                                        .id("TimelineView-ModelWeekly-\(model.id)")
                                    } else {
                                        Text("周重置:" + resetCountdownText(expiryTimestamp: weeklyRefreshExpiryTimestamp, now: Date()))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                                
                                // Model-specific progress bar (e.g. for MiniMax quotas)
                                if let total = model.totalQuota, total > 0 {
                                    let used = modelRemaining(model) != nil
                                        ? max(total - (modelRemaining(model) ?? 0), 0)
                                        : model.cost
                                    let percentage = min(used / total, 1.0)
                                    HStack {
                                        Text(percentage.formattedPercentage)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .frame(width: 32, alignment: .leading)
                                        
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.gray.opacity(0.15))
                                                    .frame(height: 3)
                                                
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(progressColor(percentage))
                                                    .frame(width: geometry.size.width * CGFloat(percentage), height: 3)
                                            }
                                        }
                                        .frame(height: 3)
                                        
                                        if let remaining = modelRemaining(model) {
                                            let used = max(total - remaining, 0)
                                            Text("已用 \(formatBalance(used)) / \(formatBalance(total))")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        } else {
                                            Text("\(model.cost.formattedCurrency("")) / \(total.formattedCurrency(""))")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(6)
                    .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(config.brandColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func progressColor(_ percentage: Double) -> Color {
        if percentage > 0.9 { return .red }
        if percentage > 0.7 { return .orange }
        return config.brandColor
    }

    private var isMiniMax: Bool {
        config.providerType == .miniMax
    }

    private var isCurrencyQuota: Bool {
        let currency = usage.currency
        return !currency.isEmpty && currency != "Tokens" && currency != "Percent" && !currency.contains("单位") && !currency.contains("额度")
    }

    private func formatBalance(_ value: Double) -> String {
        if isCurrencyQuota {
            return value.formattedBalanceValue(usage.currency)
        } else {
            return value.formattedQuotaValue
        }
    }

    private func modelRemaining(_ model: ModelUsage) -> Double? {
        if let remaining = model.remainingQuota {
            return remaining
        }
        if let total = model.totalQuota {
            return max(total - model.cost, 0)
        }
        return nil
    }

    private func resetCountdownText(expiryTimestamp: TimeInterval, now: Date) -> String {
        let remainingSeconds = max(Int(expiryTimestamp - now.timeIntervalSince1970), 0)
        if remainingSeconds == 0 {
            return "已到"
        }
        let roundedMinutes = Int(ceil(Double(remainingSeconds) / 60.0))
        let hours = roundedMinutes / 60
        let minutes = roundedMinutes % 60
        return "\(hours)小时\(minutes)分钟"
    }
}
