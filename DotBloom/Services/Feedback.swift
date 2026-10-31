import AVFoundation
import UIKit

/// Haptics plus synthesized tones. Each link plays the next note of a
/// pentatonic scale, so longer chains literally sound better.
@MainActor
final class Feedback {
    static let shared = Feedback()

    var soundOn = true
    var hapticsOn = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var notes: [AVAudioPCMBuffer] = []
    private var chord: AVAudioPCMBuffer?
    private var thud: AVAudioPCMBuffer?
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notifier = UINotificationFeedbackGenerator()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.5
        // C major pentatonic across two and a half octaves.
        let semitones = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31]
        notes = semitones.compactMap { tone(frequency: 523.25 * pow(2, Double($0) / 12), duration: 0.18, format: format) }
        chord = tone(frequencies: [523.25, 659.25, 783.99, 1046.5], duration: 0.5, format: format)
        thud = tone(frequency: 196, duration: 0.12, format: format)
        try? engine.start()
    }

    func link(_ index: Int) {
        if hapticsOn { light.impactOccurred(intensity: min(1, 0.4 + Double(index) * 0.08)) }
        guard !notes.isEmpty else { return }
        play(notes[min(max(index, 0), notes.count - 1)])
    }

    func loop() {
        if hapticsOn { rigid.impactOccurred() }
        play(chord)
    }

    func clear(count: Int) {
        if hapticsOn { rigid.impactOccurred(intensity: min(1, 0.3 + Double(count) * 0.05)) }
    }

    func burst() {
        if hapticsOn { notifier.notificationOccurred(.warning) }
        play(thud)
    }

    func win() {
        if hapticsOn { notifier.notificationOccurred(.success) }
        play(chord)
    }

    func lose() {
        if hapticsOn { notifier.notificationOccurred(.error) }
        play(thud)
    }

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard soundOn, let buffer else { return }
        if !engine.isRunning { try? engine.start() }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.stop()
        p.scheduleBuffer(buffer, at: nil)
        p.play()
    }

    private func tone(frequency: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        tone(frequencies: [frequency], duration: duration, format: format)
    }

    /// Soft bell: sine partials with a fast attack and exponential decay.
    private func tone(frequencies: [Double], duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let count = AVAudioFrameCount(duration * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        let gain = 0.35 / Double(frequencies.count)
        for i in 0..<Int(count) {
            let t = Double(i) / rate
            let envelope = min(1, t / 0.005) * exp(-t * 9)
            var sample = 0.0
            for f in frequencies {
                sample += sin(2 * .pi * f * t) + 0.25 * sin(4 * .pi * f * t)
            }
            data[i] = Float(sample * gain * envelope)
        }
        return buffer
    }
}
