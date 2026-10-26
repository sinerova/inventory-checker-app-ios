//
//  ProductAvailabilityList.swift
//  InventoryWatch
//

import SwiftUI

struct ProductAvailabilityList: View {
    let country: Country
    let token: String
    let emptyTokenMessage: String
    let skuData: SKUData?
    let availableSkus: Set<String>
    let pickupInfo: [String: (count: Int, quote: String?)]
    let preferredSKUs: Set<String>
    let productURL: (String) -> URL?
    let categoryURL: () -> URL?
    let showPDPPreview: Bool
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let productFont = useLargeText ? Font.title.weight(.medium) : Font.body.weight(.medium)

        if token.isEmpty {
            Text(emptyTokenMessage)
                .foregroundColor(.secondary)
        } else if let data = skuData {
            let filtered = data.orderedSKUs.filter { sku in
                let isAvailable = availableSkus.contains(sku)
                if preferredSKUs.isEmpty { return isAvailable }
                return isAvailable && preferredSKUs.contains(sku)
            }
            if filtered.isEmpty {
                Text("No models available in-store.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filtered, id: \.self) { partNumber in
                    let name = data.productName(forSKU: partNumber) ?? partNumber
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(name)
                                .font(productFont)
                            Spacer()
                        }
                        if showPDPPreview, let preview = productURL(partNumber)?.absoluteString {
                            Text(preview)
                                .font(useLargeText ? .caption : .caption2)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        if let info = pickupInfo[partNumber] {
                            let countText = info.count == 1 ? "1 store" : "\(info.count) stores"
                            let quoteText = info.quote ?? "Available for pickup"
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .imageScale(.small)
                                Text("Pickup: \(quoteText) • \(countText)")
                            }
                            .font(useLargeText ? .caption : .caption2)
                            .fontWeight(colorSchemeContrast == .increased ? .semibold : .regular)
                            .foregroundColor(.green)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Available for pickup: \(quoteText), at \(countText)")
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                    .imageScale(.small)
                                Text("Pickup: Unavailable")
                            }
                            .font(useLargeText ? .caption : .caption2)
                            .fontWeight(colorSchemeContrast == .increased ? .semibold : .regular)
                            .foregroundColor(.secondary)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Pickup: Unavailable")
                        }
                        if let targetURL = productURL(partNumber) ?? categoryURL() {
                            Button(action: {
                                openURL(targetURL)
                            }) {
                                Text("Order Online")
                                    .font(useLargeText ? .caption : .caption2)
                                    .fontWeight(colorSchemeContrast == .increased ? .semibold : .medium)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Order \(name) online")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } else {
            Text("No SKUs available")
                .foregroundColor(.secondary)
        }
    }
}