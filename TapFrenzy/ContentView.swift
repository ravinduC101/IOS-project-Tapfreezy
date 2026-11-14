//
//  ContentView.swift
//  TapFrenzy
//
//  One big TAP button. A countdown runs from the chosen round length.
//  Every tap is +1. When time hits zero the round ends and shows the
//  final score plus the best score so far (saved with @AppStorage).
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Game phases

/// The three states the game can be in: idle → playing → over → idle …
enum GamePhase {
    case idle      // waiting for the first tap
    case playing   // timer is running, taps score points
    case over      // time's up, showing results
}

// MARK: - Main view

struct ContentView: View {

    // Game state
    @State private var phase: GamePhase = .idle
    @State private var score = 0
    @State private var timeRemaining: Double = 10
    @State private var endDate = Date()
    @State private var isNewBest = false

    // Stretch goal: round length picker (5s / 10s / 20s)
    @State private var roundLength = 10
    private let roundOptions = [5, 10, 20]

    // Stretch goal: animated score
    @State private var scorePulse = false

    // Persisted across launches
    @AppStorage("highScore") private var highScore = 0
    @AppStorage("gamesPlayed") private var gamesPlayed = 0

    // Ticks 20× a second. We only act on it while playing.
    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let buttonSize = min(geo.size.width, geo.size.height) * (isLandscape ? 0.55 : 0.62)

            ZStack {
                background

                Group {
                    if isLandscape {
                        HStack(spacing: 40) {
                            VStack(spacing: 20) {
                                header
                                scoreBoard
                                timerView
                                roundPicker
                            }
                            .frame(maxWidth: 320)
                            tapButton(size: buttonSize)
                        }
                    } else {
                        VStack(spacing: 24) {
                            header
                            scoreBoard
                            timerView
                            Spacer(minLength: 0)
                            tapButton(size: buttonSize)
                            Spacer(minLength: 0)
                            roundPicker
                            statsRow
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                if phase == .over {
                    gameOverCard
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .onReceive(ticker) { _ in tick() }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: phase)
    }

    // MARK: - Pieces of the UI

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.09, blue: 0.20),
                     Color(red: 0.20, green: 0.10, blue: 0.32)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        Text("Tap Frenzy")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
    }

    private var scoreBoard: some View {
        VStack(spacing: 2) {
            Text("SCORE")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            Text("\(score)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .scaleEffect(scorePulse ? 1.18 : 1.0)
                .contentTransition(.numericText())
        }
    }

    private var timerView: some View {
        VStack(spacing: 8) {
            Text(timerLabel)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(phase == .playing ? timerColor : .white.opacity(0.7))

            // Timer bar
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(timerColor)
                        .frame(width: bar.size.width * timeFraction)
                }
            }
            .frame(height: 8)
        }
    }

    private func tapButton(size: CGFloat) -> some View {
        Button(action: handleTap) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.42, blue: 0.55),
                                     Color(red: 0.85, green: 0.15, blue: 0.40)],
                            center: .topLeading, startRadius: 10, endRadius: size
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.5).opacity(0.5),
                            radius: 24, y: 10)
                Text("TAP")
                    .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(phase == .over)
        .accessibilityLabel("Tap button")
        .accessibilityHint(phase == .idle ? "Tap to start the round" : "Tap to score")
    }

    private var roundPicker: some View {
        Picker("Round length", selection: $roundLength) {
            ForEach(roundOptions, id: \.self) { seconds in
                Text("\(seconds)s").tag(seconds)
            }
        }
        .pickerStyle(.segmented)
        .disabled(phase == .playing)
        .opacity(phase == .playing ? 0.4 : 1)
        .onChange(of: roundLength) { _, newValue in
            if phase == .idle { timeRemaining = Double(newValue) }
        }
    }

    private var statsRow: some View {
        HStack {
            Label("Best \(highScore)", systemImage: "trophy.fill")
            Spacer()
            Label("Played \(gamesPlayed)", systemImage: "gamecontroller.fill")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
    }

    private var gameOverCard: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Time's up")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                Text("YOUR SCORE")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Text("\(score)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if isNewBest {
                    Text("🎉 New best!")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                Text("Best: \(highScore)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Button(action: resetGame) {
                    Text("Play Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.85, green: 0.15, blue: 0.40))
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(32)
        }
    }

    // MARK: - Derived values

    private var timeFraction: CGFloat {
        CGFloat(max(0, min(1, timeRemaining / Double(roundLength))))
    }

    /// Stretch goal: green → amber → red as time runs out.
    private var timerColor: Color {
        timeFraction > 0.5 ? .green : (timeFraction > 0.25 ? .orange : .red)
    }

    private var timerLabel: String {
        switch phase {
        case .idle:    return "tap to start"
        case .playing: return String(format: "%.1fs", timeRemaining)
        case .over:    return "0.0s"
        }
    }

    // MARK: - Game logic

    private func handleTap() {
        switch phase {
        case .idle:
            startGame()
            addPoint()          // the first tap counts too
        case .playing:
            addPoint()
        case .over:
            break               // ignored; use Play Again
        }
    }

    private func startGame() {
        score = 0
        isNewBest = false
        timeRemaining = Double(roundLength)
        endDate = Date().addingTimeInterval(Double(roundLength))
        phase = .playing
    }

    private func addPoint() {
        score += 1
        haptic()
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { scorePulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { scorePulse = false }
        }
    }

    /// Runs on every timer tick. Uses the real end date so the
    /// countdown stays accurate even if a tick is delayed.
    private func tick() {
        guard phase == .playing else { return }
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
        if timeRemaining <= 0 { endGame() }
    }

    private func endGame() {
        phase = .over
        gamesPlayed += 1
        if score > highScore {
            highScore = score
            isNewBest = true
        }
    }

    private func resetGame() {
        score = 0
        isNewBest = false
        timeRemaining = Double(roundLength)
        phase = .idle
    }

    /// Stretch goal: haptic feedback on each tap.
    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Button style

/// Squashes the button slightly while it is held down.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
