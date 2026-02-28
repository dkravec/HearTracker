//
//  CardListComponents.swift
//  HearingAidBattery
//
//  Created by Daniel Kravec on 2026-02-27.
//

import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 66.0 / 255.0, green: 44.0 / 255.0, blue: 104.0 / 255.0),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 420)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
}

struct CardRowContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        CardRowContainer {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func appBackground() -> some View {
        ZStack {
            AppBackgroundView()
            self
        }
    }
}
